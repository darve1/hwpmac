// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// Stacks every page vertically and edits body text.
///
/// The view never waits for the engine: edits are submitted to the
/// `DocumentEngine`, whose snapshots update the caret and selection, and pages
/// are rendered asynchronously (a stale page stays visible until its new
/// image arrives). One layout pixel is drawn as one point.
final class PagesView: NSView, @MainActor NSTextInputClient, NSMenuItemValidation {
    private static let gap: CGFloat = 24
    private static let cacheLimit = 12

    let engine: any DocumentEngineClient
    /// Called after document contents change, e.g. to update the edited state.
    var onDocumentChange: ((DocumentEngine.Snapshot) -> Void)?
    /// Short user-facing status, such as why an edit was refused; nil clears it.
    var onStatus: ((String?) -> Void)?

    private var snapshot: DocumentEngine.Snapshot
    private var pageRects: [CGRect] = []

    /// The size a page needs on screen, with the gap around it, at 100 %:
    /// the widest page, and the tallest, for fitting the zoom to the window.
    var largestPageSpan: CGSize {
        CGSize(width: (pageRects.map(\.width).max() ?? 0) + Self.gap * 2,
               height: (pageRects.map(\.height).max() ?? 0) + Self.gap * 2)
    }
    private var cache: [Int: (scale: Double, revision: UInt64, image: CGImage)] = [:]
    /// The editing marks the cached pages were rendered with.
    private var renderedMarks = EditorMarks()
    private var cacheOrder: [Int] = []
    private var rendering: Set<Int> = []
    private let insertionIndicator = NSTextInsertionIndicator()
    private var caretRect: CGRect?
    private var selectionRects: [CGRect] = []
    private var markedRects: [CGRect] = []

    // Input-method state answers NSTextInputClient queries immediately,
    // ahead of the engine catching up. `markedStart` is a paragraph offset; it
    // comes from the last snapshot unless the input method gave a range.
    private var markedText = ""
    private var markedStart: Int?

    enum CompositionPolicy {
        /// Local while the engine is slow (`DocumentEngine.isSlow`).
        case automatic
        case engine
        case local
    }

    /// Where uncommitted input-method text lives. In the engine it is laid out
    /// in the document; locally it is drawn over the caret and only committed
    /// syllables reach the engine, which then re-paginates once per syllable
    /// instead of once per keystroke.
    var compositionPolicy = CompositionPolicy.automatic
    private var localComposition = false
    /// Text submitted but not yet in a snapshot, drawn at the caret ("echo").
    /// Valid only while nothing but inserts is pending, since other edits can
    /// move the caret.
    private var echo: [(sequence: UInt64, text: String)] = []
    private var echoValid = true
    private var overlayRect: CGRect?

    /// The engine has not yet answered operations submitted since this time.
    private var waitingSince: Date?
    private var lastSubmitted: UInt64 = 0
    private var stallTimer: Timer?
    private static let stallSeconds: TimeInterval = 15

    init(engine: any DocumentEngineClient) {
        self.engine = engine
        snapshot = DocumentEngine.Snapshot(revision: 0)
        super.init(frame: .zero)
        layOutPages(engine.initialPageSizes)
        insertionIndicator.displayMode = .hidden
        addSubview(insertionIndicator)
        engine.onSnapshot = { [weak self] in self?.apply($0) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: Layout and drawing

    private func layOutPages(_ pageSizes: [CGSize]) {
        let width = (pageSizes.map(\.width).max() ?? 0) + 2 * Self.gap
        var y = Self.gap
        pageRects = pageSizes.map { size in
            defer { y += size.height + Self.gap }
            return CGRect(x: (width - size.width) / 2, y: y, width: size.width, height: size.height)
        }
        setFrameSize(CGSize(width: width, height: y))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.underPageBackgroundColor.setFill()
        dirtyRect.fill()

        let scale = renderScale
        for (page, rect) in pageRects.enumerated() where rect.intersects(dirtyRect) {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 6
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.set()
            NSColor.white.setFill()
            rect.fill()
            NSGraphicsContext.restoreGraphicsState()

            let cached = cache[page]
            if let cached {
                NSImage(cgImage: cached.image, size: rect.size)
                    .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
            if cached?.scale != scale || cached?.revision != snapshot.revision {
                requestRender(page, scale: scale)
            }
        }

        NSColor.selectedTextBackgroundColor.withAlphaComponent(0.45).setFill()
        for rect in selectionRects where rect.intersects(dirtyRect) {
            rect.fill(using: .multiply)
        }
        NSColor.textColor.setFill()
        for rect in markedRects where rect.intersects(dirtyRect) {
            CGRect(x: rect.minX, y: rect.maxY - 1.5, width: rect.width, height: 1.5).fill()
        }
        drawSelectedObject()
        drawOverlay()
    }

    // MARK: Typing echo and local composition

    private var overlayFont: NSFont {
        NSFont.systemFont(ofSize: min(max((caretRect?.height ?? 13) * 0.8, 8), 72))
    }

    private var echoText: String {
        echoValid ? echo.map(\.text).joined() : ""
    }

    /// A frame with eight handles around the picked object.
    private func drawSelectedObject() {
        guard let selected = selectedObject,
              let rect = viewRect(page: selected.page, x: selected.frame.minX, y: selected.frame.minY,
                                  width: selected.frame.width, height: selected.frame.height) else { return }
        NSColor.controlAccentColor.setStroke()
        let frame = NSBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
        frame.lineWidth = 1
        frame.stroke()
        let size: CGFloat = 6
        for x in [rect.minX, rect.midX, rect.maxX] {
            for y in [rect.minY, rect.midY, rect.maxY] where !(x == rect.midX && y == rect.midY) {
                let handle = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
                NSColor.white.setFill()
                handle.fill()
                NSColor.controlAccentColor.setStroke()
                NSBezierPath(rect: handle).stroke()
            }
        }
    }

    private func drawOverlay() {
        guard let overlayRect else { return }
        NSColor.textBackgroundColor.setFill()
        overlayRect.fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: overlayFont, .foregroundColor: NSColor.textColor]
        let echoed = echoText as NSString
        let marked = (localComposition ? markedText : "") as NSString
        let baseline = overlayRect.minY + (overlayRect.height - overlayFont.ascender + overlayFont.descender) / 2
        echoed.draw(at: CGPoint(x: overlayRect.minX + 1, y: baseline), withAttributes: attributes)
        let markedX = overlayRect.minX + 1 + echoed.size(withAttributes: attributes).width
        marked.draw(at: CGPoint(x: markedX, y: baseline), withAttributes: attributes)
        let markedWidth = marked.size(withAttributes: attributes).width
        NSColor.textColor.setFill()
        CGRect(x: markedX, y: overlayRect.maxY - 1.5, width: markedWidth, height: 1.5).fill()
    }

    /// Recomputes the overlay after the echo, local composition or caret changed.
    private func updateOverlay() {
        let text = echoText + (localComposition ? markedText : "")
        let newRect: CGRect? = caretRect.flatMap { caret in
            guard !text.isEmpty else { return nil }
            let width = (text as NSString).size(withAttributes: [.font: overlayFont]).width
            return CGRect(x: caret.minX, y: caret.minY, width: ceil(width) + 2, height: caret.height)
        }
        for rect in [overlayRect, newRect].compactMap({ $0 }) {
            setNeedsDisplay(rect.insetBy(dx: -2, dy: -2))
        }
        overlayRect = newRect
        updateInsertionIndicator()
    }

    /// Whether typed or composing text is currently drawn over the caret.
    var isShowingTypingOverlay: Bool {
        overlayRect != nil
    }

    private var usesLocalComposition: Bool {
        switch compositionPolicy {
        case .automatic: engine.isSlow
        case .engine: false
        case .local: true
        }
    }

    /// Submits an edit other than inserting text.
    private func submit(_ operation: DocumentEngine.Operation) {
        if !echo.isEmpty { echoValid = false }
        record(engine.submit(operation))
    }

    private func submitInsert(_ text: String) {
        let sequence = engine.submit(.insert(text))
        record(sequence)
        if usesLocalComposition {
            echo.append((sequence, text))
        }
    }

    private func record(_ sequence: UInt64) {
        lastSubmitted = sequence
        if waitingSince == nil { waitingSince = Date() }
    }

    // MARK: Stalled engine

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stallTimer?.invalidate()
        stallTimer = nil
        guard window != nil else { return }
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForStall() }
        }
    }

    /// Says so when the engine has been busy with an edit for a long time.
    private func checkForStall() {
        guard let waitingSince else { return }
        let seconds = Int(Date().timeIntervalSince(waitingSince))
        guard Double(seconds) >= Self.stallSeconds else { return }
        let hint = engine.canRestart ? " 파일 > 문서 엔진 다시 시작으로 끝낼 수 있습니다." : ""
        onStatus?("문서 엔진이 \(seconds)초째 편집을 처리하고 있습니다.\(hint)")
    }

    /// Device pixels per layout pixel, so pages stay sharp when magnified.
    private var renderScale: Double {
        let backing = Double(window?.backingScaleFactor ?? 2)
        let magnification = Double(enclosingScrollView?.magnification ?? 1)
        return (backing * max(magnification, 1) * 2).rounded(.up) / 2
    }

    private func requestRender(_ page: Int, scale: Double) {
        guard rendering.insert(page).inserted else { return }
        engine.render(page: page, scale: scale) { [weak self] image, revision in
            guard let self else { return }
            rendering.remove(page)
            guard let image else { return }
            cache[page] = (scale, revision, image)
            cacheOrder.removeAll { $0 == page }
            cacheOrder.append(page)
            if cacheOrder.count > Self.cacheLimit {
                cache[cacheOrder.removeFirst()] = nil
            }
            if pageRects.indices.contains(page) {
                setNeedsDisplay(pageRects[page])
            }
        }
    }

    // MARK: Engine snapshots

    private func apply(_ snapshot: DocumentEngine.Snapshot) {
        self.snapshot = snapshot
        if snapshot.marks != renderedMarks {
            // Keep showing the old pages until their re-renders arrive.
            renderedMarks = snapshot.marks
            for page in cache.keys { cache[page]?.revision = .max }
            needsDisplay = true
        }
        if snapshot.appliedSequence >= lastSubmitted { waitingSince = nil }
        echo.removeAll { $0.sequence <= snapshot.appliedSequence }
        if echo.isEmpty { echoValid = true }
        if let sizes = snapshot.pageSizes {
            layOutPages(sizes)
            needsDisplay = true
        }
        if snapshot.contentsChanged {
            setNeedsDisplay(visibleRect)
            onDocumentChange?(snapshot)
            refreshSelectedObject()
        }
        if let result = snapshot.lastResult {
            onSearchResult?(result)
        }
        if let failure = snapshot.failure {
            NSSound.beep()
            if !markedText.isEmpty {
                // The composition was refused; let the input method start over.
                clearMarkedText()
                inputContext?.discardMarkedText()
            }
            onStatus?(failure)
        } else {
            onStatus?(nil)
        }

        let oldRects = selectionRects + markedRects + [caretRect].compactMap { $0 }
        caretRect = snapshot.caret.flatMap { viewRect(page: $0.page, x: $0.x, y: $0.y, width: 0, height: $0.height) }
        selectionRects = viewRects(snapshot.selectionRects)
        markedRects = viewRects(snapshot.markedRects)
        for rect in oldRects + selectionRects + markedRects {
            setNeedsDisplay(rect.insetBy(dx: -2, dy: -2))
        }
        updateOverlay()
        if let caretRect {
            scrollToVisible(caretRect.insetBy(dx: -24, dy: -24))
        }
    }

    private func viewRects(_ rects: [SelectionRect]) -> [CGRect] {
        rects.compactMap {
            viewRect(page: $0.page, x: $0.bounds.x, y: $0.bounds.y, width: $0.bounds.width, height: $0.bounds.height)
        }
    }

    private func updateInsertionIndicator() {
        guard let caretRect, window?.firstResponder === self else {
            insertionIndicator.displayMode = .hidden
            return
        }
        let x = overlayRect?.maxX ?? caretRect.minX
        insertionIndicator.frame = CGRect(x: x - 1, y: caretRect.minY, width: 2, height: caretRect.height)
        insertionIndicator.displayMode = .automatic
    }

    // MARK: Coordinates

    /// The page under a view point and the point in that page's layout pixels.
    private func pagePoint(at point: CGPoint) -> (page: Int, x: Double, y: Double)? {
        guard let page = pageRects.firstIndex(where: { point.y < $0.maxY + Self.gap / 2 }) ?? pageRects.indices.last
        else { return nil }
        let rect = pageRects[page]
        let x = min(max(point.x, rect.minX), rect.maxX) - rect.minX
        let y = min(max(point.y, rect.minY), rect.maxY) - rect.minY
        return (page, x, y)
    }

    private func viewRect(page: Int, x: Double, y: Double, width: Double, height: Double) -> CGRect? {
        guard pageRects.indices.contains(page) else { return nil }
        let origin = pageRects[page].origin
        return CGRect(x: origin.x + x, y: origin.y + y, width: width, height: height)
    }

    // MARK: Editing

    /// Puts the caret at the start of the document so typing works without a click.
    func beginEditingAtStart() {
        submit(.select(.collapsed(at: .documentStart)))
    }

    /// Commits any input-method composition, e.g. before saving or moving the caret.
    func commitInput() {
        guard !markedText.isEmpty else { return }
        if localComposition {
            submitInsert(markedText)
        } else {
            submit(.commitMarked)
        }
        clearMarkedText()
        inputContext?.discardMarkedText()
    }

    private func clearMarkedText() {
        markedText = ""
        markedStart = nil
        localComposition = false
        updateOverlay()
    }

    override func becomeFirstResponder() -> Bool {
        defer { updateInsertionIndicator() }
        return true
    }

    override func resignFirstResponder() -> Bool {
        commitInput()
        insertionIndicator.displayMode = .hidden
        return true
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        commitInput()
        guard let target = pagePoint(at: convert(event.locationInWindow, from: nil)) else { return }
        if !event.modifierFlags.contains(.shift), let hit = object(atPage: target.page, x: target.x, y: target.y) {
            selectedObject = hit
            return
        }
        selectedObject = nil
        submit(.click(page: target.page, x: target.x, y: target.y,
                             extendSelection: event.modifierFlags.contains(.shift)))
    }

    override func mouseDragged(with event: NSEvent) {
        autoscroll(with: event)
        guard let target = pagePoint(at: convert(event.locationInWindow, from: nil)) else { return }
        submit(.drag(page: target.page, x: target.x, y: target.y))
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        interpretKeyEvents([event])
    }

    override func doCommand(by selector: Selector) {
        if selectedObject != nil {
            switch NSStringFromSelector(selector) {
            case "deleteBackward:", "deleteForward:":
                return deleteSelectedObject(nil)
            case "cancelOperation:":
                selectedObject = nil
                return
            default:
                selectedObject = nil
            }
        }
        let command: EditCommand? = switch NSStringFromSelector(selector) {
        case "moveLeft:": .moveLeft(extend: false)
        case "moveRight:": .moveRight(extend: false)
        case "moveUp:": .moveUp(extend: false)
        case "moveDown:": .moveDown(extend: false)
        case "moveLeftAndModifySelection:": .moveLeft(extend: true)
        case "moveRightAndModifySelection:": .moveRight(extend: true)
        case "moveUpAndModifySelection:": .moveUp(extend: true)
        case "moveDownAndModifySelection:": .moveDown(extend: true)
        case "moveToBeginningOfLine:", "moveToLeftEndOfLine:": .home(extend: false)
        case "moveToEndOfLine:", "moveToRightEndOfLine:": .end(extend: false)
        case "moveToBeginningOfLineAndModifySelection:", "moveToLeftEndOfLineAndModifySelection:": .home(extend: true)
        case "moveToEndOfLineAndModifySelection:", "moveToRightEndOfLineAndModifySelection:": .end(extend: true)
        case "deleteBackward:", "deleteBackwardByDecomposingPreviousCharacter:": .deleteBackward
        case "deleteForward:": .deleteForward
        case "insertNewline:", "insertLineBreak:", "insertParagraphSeparator:": .splitParagraph
        case "insertTab:" where inTable: .nextCell
        case "insertBacktab:" where inTable: .previousCell
        default: nil
        }
        if let command {
            commitInput()
            submit(.command(command))
        } else if selector == #selector(insertTab(_:)) {
            insertText("\t", replacementRange: NSRange(location: NSNotFound, length: 0))
        } else if selector == #selector(cancelOperation(_:)), !markedText.isEmpty {
            if !localComposition { submit(.cancelMarked) }
            clearMarkedText()
        }
    }

    // MARK: Menu actions

    @objc func undo(_ sender: Any?) {
        commitInput()
        submit(.undo)
    }

    @objc func redo(_ sender: Any?) {
        commitInput()
        submit(.redo)
    }

    @objc func copy(_ sender: Any?) {
        commitInput()
        guard let text = try? engine.copySelection() else { return NSSound.beep() }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Copy, then delete the selection as one more edit.
    @objc func cut(_ sender: Any?) {
        copy(sender)
        submit(.command(.deleteBackward))
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return NSSound.beep() }
        commitInput()
        submit(.paste(text))
    }

    override func selectAll(_ sender: Any?) {
        commitInput()
        submit(.command(.selectAll))
    }

    // MARK: Formatting

    private var hasSelection: Bool { !(snapshot.selection?.isCollapsed ?? true) }

    private func charFlag(_ key: String) -> Bool { snapshot.charProperties?[key]?.bool ?? false }

    private func applyChar(_ props: [String: JSONValue]) {
        guard hasSelection else { return NSSound.beep() }
        commitInput()
        submit(.action(.charFormat(props)))
    }

    private func applyPara(_ props: [String: JSONValue]) {
        commitInput()
        submit(.action(.paraFormat(props)))
    }

    @objc func toggleBold(_ sender: Any?) { applyChar(["bold": .bool(!charFlag("bold"))]) }
    @objc func toggleItalic(_ sender: Any?) { applyChar(["italic": .bool(!charFlag("italic"))]) }
    @objc func toggleUnderlineStyle(_ sender: Any?) { applyChar(["underline": .bool(!charFlag("underline"))]) }
    @objc func toggleStrikethrough(_ sender: Any?) { applyChar(["strikethrough": .bool(!charFlag("strikethrough"))]) }

    /// Superscript and subscript exclude each other, as do emboss and engrave.
    @objc func toggleSuperscript(_ sender: Any?) { toggleExclusive("superscript", "subscript") }
    @objc func toggleSubscript(_ sender: Any?) { toggleExclusive("subscript", "superscript") }
    @objc func toggleEmboss(_ sender: Any?) { toggleExclusive("emboss", "engrave") }
    @objc func toggleEngrave(_ sender: Any?) { toggleExclusive("engrave", "emboss") }

    private func toggleExclusive(_ key: String, _ other: String) {
        let on = !charFlag(key)
        applyChar(on ? [key: .bool(true), other: .bool(false)] : [key: .bool(false)])
    }

    private var hasOutline: Bool { (snapshot.charProperties?["outlineType"]?.number ?? 0) != 0 }

    @objc func toggleOutline(_ sender: Any?) { applyChar(["outlineType": .number(hasOutline ? 0 : 1)]) }

    /// 장평 (width ratio, 50–200 %) and 자간 (letter spacing, −50–50 %) in 1 % steps,
    /// set for all seven language groups as the web editor does.
    private func adjustCharArray(_ key: String, by delta: Double, default value: Double, range: ClosedRange<Double>) {
        let current: Double
        if case let .array(values)? = snapshot.charProperties?[key], let first = values.first?.number {
            current = first
        } else {
            current = value
        }
        let next = min(max((current + delta).rounded(), range.lowerBound), range.upperBound)
        applyChar([key: .array(Array(repeating: .number(next), count: 7))])
    }

    @objc func increaseCharRatio(_ sender: Any?) { adjustCharArray("ratios", by: 1, default: 100, range: 50...200) }
    @objc func decreaseCharRatio(_ sender: Any?) { adjustCharArray("ratios", by: -1, default: 100, range: 50...200) }
    @objc func increaseCharSpacing(_ sender: Any?) { adjustCharArray("spacings", by: 1, default: 0, range: -50...50) }
    @objc func decreaseCharSpacing(_ sender: Any?) { adjustCharArray("spacings", by: -1, default: 0, range: -50...50) }

    /// Font size in points from rhwp's 1/100 pt units.
    private var fontPoints: Double { (snapshot.charProperties?["fontSize"]?.number ?? 1000) / 100 }

    @objc func increaseFontSize(_ sender: Any?) { applyChar(["fontSize": .number((fontPoints + 1).rounded() * 100)]) }
    @objc func decreaseFontSize(_ sender: Any?) { applyChar(["fontSize": .number(max(fontPoints - 1, 1).rounded() * 100)]) }

    /// The selection's font as an NSFont, for the font panel.
    private var selectionFont: NSFont {
        let family = snapshot.charProperties?["fontFamily"]?.string ?? ""
        let size = CGFloat(fontPoints)
        return NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    @objc func showFontPanel(_ sender: Any?) {
        NSFontManager.shared.setSelectedFont(selectionFont, isMultiple: false)
        NSFontManager.shared.orderFrontFontPanel(sender)
    }

    /// From the font panel.
    @objc func changeFont(_ sender: Any?) {
        let font = NSFontManager.shared.convert(selectionFont)
        applyChar(["fontName": .string(font.familyName ?? font.fontName), "fontSize": .number((font.pointSize * 100).rounded())])
    }

    @objc func showTextColorPanel(_ sender: Any?) {
        NSColorPanel.shared.setTarget(self)
        NSColorPanel.shared.setAction(#selector(changeTextColor(_:)))
        NSColorPanel.shared.orderFront(sender)
    }

    @objc func changeTextColor(_ sender: Any?) {
        guard let color = NSColorPanel.shared.color.usingColorSpace(.sRGB) else { return }
        let hex = String(format: "#%02x%02x%02x", Int(color.redComponent * 255), Int(color.greenComponent * 255),
                         Int(color.blueComponent * 255))
        applyChar(["textColor": .string(hex)])
    }

    @objc func alignLeft(_ sender: Any?) { applyPara(["alignment": .string("left")]) }
    @objc func alignCenter(_ sender: Any?) { applyPara(["alignment": .string("center")]) }
    @objc func alignRight(_ sender: Any?) { applyPara(["alignment": .string("right")]) }
    @objc func alignJustified(_ sender: Any?) { applyPara(["alignment": .string("justify")]) }
    @objc func alignDistributed(_ sender: Any?) { applyPara(["alignment": .string("distribute")]) }
    @objc func alignSplit(_ sender: Any?) { applyPara(["alignment": .string("split")]) }

    /// Line spacing in percent from the menu item's tag.
    @objc func setLineSpacing(_ sender: NSMenuItem) {
        applyPara(["lineSpacingType": .string("Percent"), "lineSpacing": .number(Double(sender.tag))])
    }

    @objc func toggleNumbering(_ sender: Any?) {
        commitInput()
        submit(.action(.toggleNumbering))
    }

    @objc func toggleBullets(_ sender: Any?) {
        commitInput()
        submit(.action(.toggleBullet(nil)))
    }

    /// 10 % steps, down to 5 % as in the web editor.
    @objc func increaseLineSpacing(_ sender: Any?) { stepLineSpacing(by: 10) }
    @objc func decreaseLineSpacing(_ sender: Any?) { stepLineSpacing(by: -10) }

    private func stepLineSpacing(by delta: Double) {
        let current = snapshot.paraProperties?["lineSpacing"]?.number ?? 160
        applyPara(["lineSpacingType": .string("Percent"), "lineSpacing": .number(min(max(current + delta, 5), 500))])
    }

    /// One step of left margin, in points.
    private static let indentStep = 10.0

    @objc func increaseIndent(_ sender: Any?) {
        let margin = ParagraphUnits.points(fromPixels: snapshot.paraProperties?["marginLeft"]?.number ?? 0)
        applyPara(["marginLeft": .number(ParagraphUnits.marginValue(points: margin + Self.indentStep))])
    }

    @objc func decreaseIndent(_ sender: Any?) {
        let margin = ParagraphUnits.points(fromPixels: snapshot.paraProperties?["marginLeft"]?.number ?? 0)
        applyPara(["marginLeft": .number(ParagraphUnits.marginValue(points: max(margin - Self.indentStep, 0)))])
    }

    // MARK: Go to page

    var pageCount: Int { pageRects.count }

    /// Scrolls to page `index` (0-based) and puts the caret at the start of
    /// its body area, inside the top and left margins.
    func goToPage(_ index: Int) {
        guard pageRects.indices.contains(index) else { return NSSound.beep() }
        commitInput()
        scrollToVisible(NSRect(origin: pageRects[index].origin, size: CGSize(width: pageRects[index].width, height: 1)))
        let page = (try? engine.query(.pageDef)) ?? .null
        // HWPUNIT to layout pixels (1 px = 75 HWPUNIT at 96 dpi).
        let left = (page["marginLeft"]?.number ?? 0) / 75
        let top = ((page["marginTop"]?.number ?? 0) + (page["marginHeader"]?.number ?? 0)) / 75
        submit(.click(page: index, x: left + 2, y: top + 2, extendSelection: false))
    }

    @objc func showGoToPage(_ sender: Any?) {
        guard let window, pageCount > 0 else { return }
        let field = NSTextField(string: "1")
        field.frame = NSRect(x: 0, y: 0, width: 80, height: 24)
        let alert = NSAlert()
        alert.messageText = "쪽 찾아가기"
        alert.informativeText = "1~\(pageCount)쪽"
        alert.accessoryView = field
        alert.addButton(withTitle: "가기")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.goToPage(field.integerValue - 1)
        }
    }

    // MARK: Objects

    /// A picture or shape picked with a click, in page layout pixels.
    struct SelectedObject: Equatable {
        var address: ObjectAddress
        var kind: String
        var page: Int
        var frame: CGRect
        var zOrder: Double
    }

    private(set) var selectedObject: SelectedObject? {
        didSet { if oldValue != selectedObject { needsDisplay = true } }
    }

    /// Body pictures and shapes on `page` that a click can pick (not behind
    /// text, not in cells, headers or footers).
    func pickableObjects(page: Int) -> [SelectedObject] {
        guard snapshot.selection != nil, case let .array(items)? = (try? engine.query(.pageObjects(page: page)))?["controls"]
        else { return [] }
        return items.compactMap { item in
            guard let kind = item["type"]?.string, kind == "image" || kind == "shape",
                  item["wrap"]?.string != "behindText", item["cellIdx"] == nil, item["headerFooter"] == nil,
                  let section = item["secIdx"]?.number, let paragraph = item["paraIdx"]?.number,
                  let control = item["controlIdx"]?.number,
                  let x = item["x"]?.number, let y = item["y"]?.number, let w = item["w"]?.number, let h = item["h"]?.number
            else { return nil }
            return SelectedObject(address: ObjectAddress(section: Int(section), paragraph: Int(paragraph), control: Int(control)),
                                  kind: kind, page: page, frame: CGRect(x: x, y: y, width: w, height: h),
                                  zOrder: item["zOrder"]?.number ?? 0)
        }
    }

    /// The topmost pickable object under a page point, if any.
    func object(atPage page: Int, x: Double, y: Double) -> SelectedObject? {
        pickableObjects(page: page)
            .filter { $0.frame.contains(CGPoint(x: x, y: y)) }
            .max { $0.zOrder < $1.zOrder }
    }

    func selectObject(_ object: SelectedObject?) {
        selectedObject = object
    }

    /// After an edit the object may have moved or gone.
    private func refreshSelectedObject() {
        guard let selected = selectedObject else { return }
        let pages = [selected.page] + pageRects.indices.filter { $0 != selected.page }
        selectedObject = pages.lazy.compactMap { page in
            self.pickableObjects(page: page).first { $0.address == selected.address }
        }.first
    }

    private var selectedPicture: SelectedObject? { selectedObject?.kind == "image" ? selectedObject : nil }

    @objc func insertPicture(_ sender: Any?) {
        guard let window, inBody else { return NSSound.beep() }
        commitInput()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.insertPicture(from: url)
            } catch {
                self.onStatus?("그림을 넣지 못했습니다: \(error.localizedDescription)")
                NSSound.beep()
            }
        }
    }

    /// Formats rhwp embeds as they are; anything else (HEIC, WebP, …) goes in as PNG.
    private static let embeddableExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff"]

    func insertPicture(from url: URL) throws {
        var data = try Data(contentsOf: url)
        var fileExtension = url.pathExtension.lowercased()
        guard let bitmap = NSBitmapImageRep(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        if !Self.embeddableExtensions.contains(fileExtension) {
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileReadCorruptFile) }
            data = png
            fileExtension = "png"
        }
        let (pixelWidth, pixelHeight) = (max(bitmap.pixelsWide, 1), max(bitmap.pixelsHigh, 1))
        // 75 HWPUNIT per pixel at 96 dpi, scaled down to the text width as the web editor does.
        var width = Double(pixelWidth) * 75
        var height = Double(pixelHeight) * 75
        let page = (try? engine.query(.pageDef)) ?? .null
        if let paper = page["width"]?.number, let left = page["marginLeft"]?.number, let right = page["marginRight"]?.number {
            let landscape = page["landscape"]?.bool == true
            let column = (landscape ? page["height"]?.number ?? paper : paper) - left - right
            if column > 0, width > column {
                height *= column / width
                width = column
            }
        }
        submit(.action(.insertPicture(data: data, fileExtension: fileExtension, width: Int(width.rounded()),
                                      height: Int(height.rounded()), pixelWidth: pixelWidth, pixelHeight: pixelHeight)))
    }

    @objc func deleteSelectedObject(_ sender: Any?) {
        guard let selected = selectedObject else { return NSSound.beep() }
        selectedObject = nil
        submit(.action(.deleteObject(selected.address)))
    }

    private func reorder(_ operation: String) {
        guard let selected = selectedObject else { return NSSound.beep() }
        submit(.action(.objectOrder(selected.address, operation)))
    }

    @objc func bringObjectToFront(_ sender: Any?) { reorder("front") }
    @objc func bringObjectForward(_ sender: Any?) { reorder("forward") }
    @objc func sendObjectBackward(_ sender: Any?) { reorder("backward") }
    @objc func sendObjectToBack(_ sender: Any?) { reorder("back") }

    private func pictureProperties(_ picture: SelectedObject) -> JSONValue {
        (try? engine.query(.pictureProperties(picture.address))) ?? .null
    }

    /// Quarter turns, as 한글's 개체 회전 does.
    private func rotatePicture(by degrees: Double) {
        guard let picture = selectedPicture else { return NSSound.beep() }
        let angle = pictureProperties(picture)["rotationAngle"]?.number ?? 0
        var next = (angle + degrees).truncatingRemainder(dividingBy: 360)
        if next < 0 { next += 360 }
        submit(.action(.setPictureProperties(picture.address, ["rotationAngle": .number(next)])))
    }

    @objc func rotatePictureRight(_ sender: Any?) { rotatePicture(by: 90) }
    @objc func rotatePictureLeft(_ sender: Any?) { rotatePicture(by: -90) }

    private func flipPicture(_ key: String) {
        guard let picture = selectedPicture else { return NSSound.beep() }
        let flipped = pictureProperties(picture)[key]?.bool ?? false
        submit(.action(.setPictureProperties(picture.address, [key: .bool(!flipped)])))
    }

    @objc func flipPictureHorizontally(_ sender: Any?) { flipPicture("horzFlip") }
    @objc func flipPictureVertically(_ sender: Any?) { flipPicture("vertFlip") }

    /// 개체 속성…: size in millimetres, keeping the ratio if asked.
    @objc func showObjectProperties(_ sender: Any?) {
        guard let window, let picture = selectedPicture else { return NSSound.beep() }
        let props = pictureProperties(picture)
        let millimetres = { (units: Double?) in String(format: "%.1f", (units ?? 0) / PageSetupSheet.unitsPerMillimetre) }
        let width = NSTextField(string: millimetres(props["width"]?.number))
        let height = NSTextField(string: millimetres(props["height"]?.number))
        let keepRatio = NSButton(checkboxWithTitle: "가로세로 비율 유지", target: nil, action: nil)
        keepRatio.state = .on
        for field in [width, height] { field.widthAnchor.constraint(equalToConstant: 70).isActive = true }
        let grid = NSGridView(views: [[NSTextField(labelWithString: "너비 (mm):"), width],
                                      [NSTextField(labelWithString: "높이 (mm):"), height],
                                      [NSView(), keepRatio]])
        grid.frame = NSRect(x: 0, y: 0, width: 240, height: 84)
        let alert = NSAlert()
        alert.messageText = "개체 속성"
        alert.accessoryView = grid
        alert.addButton(withTitle: "설정")
        alert.addButton(withTitle: "취소")
        let original = (props["width"]?.number ?? 1, props["height"]?.number ?? 1)
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            var newWidth = width.doubleValue * PageSetupSheet.unitsPerMillimetre
            var newHeight = height.doubleValue * PageSetupSheet.unitsPerMillimetre
            if keepRatio.state == .on, original.0 > 0 {
                // The field the user changed decides; the other follows.
                if abs(newWidth - original.0) >= abs(newHeight - original.1) {
                    newHeight = newWidth * original.1 / original.0
                } else {
                    newWidth = newHeight * original.0 / original.1
                }
            }
            guard newWidth >= 1, newHeight >= 1 else { return NSSound.beep() }
            self?.submit(.action(.setPictureProperties(picture.address, [
                "width": .number(newWidth.rounded()), "height": .number(newHeight.rounded()),
            ])))
        }
    }

    // MARK: Links, bookmarks, symbols

    /// 하이퍼링크…: a link on the selection, or the address of the link at the caret.
    @objc func editHyperlink(_ sender: Any?) {
        guard let window, snapshot.selection != nil else { return NSSound.beep() }
        commitInput()
        let existing = (try? engine.query(.hyperlink))?["uri"]?.string
        guard existing != nil || hasSelection else { return NSSound.beep() }
        let field = NSTextField(string: existing ?? "https://")
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        let alert = NSAlert()
        alert.messageText = existing == nil ? "하이퍼링크 넣기" : "하이퍼링크 고치기"
        alert.informativeText = "웹 주소(http, https, mailto)"
        alert.accessoryView = field
        alert.addButton(withTitle: existing == nil ? "넣기" : "고치기")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            let uri = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard response == .alertFirstButtonReturn, !uri.isEmpty else { return }
            self?.submit(.action(existing == nil ? .insertHyperlink(uri) : .updateHyperlink(uri)))
        }
    }

    @objc func removeHyperlink(_ sender: Any?) {
        commitInput()
        submit(.action(.removeHyperlink))
    }

    @objc func addBookmark(_ sender: Any?) {
        guard let window, inBody else { return NSSound.beep() }
        commitInput()
        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        let alert = NSAlert()
        alert.messageText = "책갈피"
        alert.informativeText = "캐럿 자리에 붙일 이름"
        alert.accessoryView = field
        alert.addButton(withTitle: "넣기")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard response == .alertFirstButtonReturn, !name.isEmpty else { return }
            self?.submit(.action(.addBookmark(name)))
        }
    }

    /// 문자표: macOS's character viewer inserts through the input client.
    @objc func showSymbols(_ sender: Any?) {
        window?.makeFirstResponder(self)
        NSApp.orderFrontCharacterPalette(sender)
    }

    // MARK: Styles

    /// The document's paragraph styles (type 0) and the current one.
    func paragraphStyles() -> (styles: [(id: Int, name: String)], current: Int?) {
        guard snapshot.selection != nil, let result = try? engine.query(.styles),
              case let .array(items)? = result["styles"] else { return ([], nil) }
        let styles = items.compactMap { item -> (id: Int, name: String)? in
            guard item["type"]?.number == 0, let id = item["id"]?.number, let name = item["name"]?.string else { return nil }
            return (Int(id), name)
        }
        return (styles, result["current"]?.number.map { Int($0) })
    }

    /// A style menu item's tag is the style id.
    @objc func applyStyle(_ sender: NSMenuItem) {
        commitInput()
        submit(.action(.applyStyle(sender.tag)))
    }

    /// 한 수준 감소/증가: 개요 N to 개요 N±1, as the web editor does; other
    /// styles are left alone.
    private func changeOutlineLevel(by delta: Int) {
        let (styles, current) = paragraphStyles()
        let outline = { (name: String) -> Int? in
            guard name.hasPrefix("개요") else { return nil }
            return Int(name.dropFirst(2).trimmingCharacters(in: .whitespaces))
        }
        guard let current, let name = styles.first(where: { $0.id == current })?.name, let level = outline(name),
              let target = styles.first(where: { outline($0.name) == level + delta }) else { return NSSound.beep() }
        commitInput()
        submit(.action(.applyStyle(target.id)))
    }

    @objc func increaseOutlineLevel(_ sender: Any?) { changeOutlineLevel(by: 1) }
    @objc func decreaseOutlineLevel(_ sender: Any?) { changeOutlineLevel(by: -1) }

    // MARK: Editing marks

    var editorMarks: EditorMarks { snapshot.marks }

    private func setMarks(_ change: (inout EditorMarks) -> Void) {
        var marks = snapshot.marks
        change(&marks)
        submit(.marks(marks))
    }

    @objc func toggleParagraphMarks(_ sender: Any?) { setMarks { $0.paragraphMarks.toggle() } }
    @objc func toggleControlCodes(_ sender: Any?) { setMarks { $0.controlCodes.toggle() } }
    @objc func toggleTransparentBorders(_ sender: Any?) { setMarks { $0.transparentBorders.toggle() } }

    // MARK: Breaks and page setup

    /// Breaks go into body text only.
    private var inBody: Bool { snapshot.selection.map { $0.focus.cellPath.isEmpty } ?? false }

    @objc func insertPageBreak(_ sender: Any?) {
        commitInput()
        submit(.action(.insertPageBreak))
    }

    @objc func insertColumnBreak(_ sender: Any?) {
        commitInput()
        submit(.action(.insertColumnBreak))
    }

    /// Column count from the menu item's tag, 8 mm apart as the web editor sets them.
    @objc func setColumnCount(_ sender: NSMenuItem) {
        if snapshot.selection == nil { beginEditingAtStart() }
        commitInput()
        submit(.action(.setColumns(count: sender.tag, spacing: 2268)))
    }

    /// 다단 설정…: number of columns and the space between them.
    @objc func showColumnSettings(_ sender: Any?) {
        guard let window else { return }
        if snapshot.selection == nil { beginEditingAtStart() }
        commitInput()
        let current = (try? engine.query(.columns)) ?? .null
        let count = NSTextField(string: String(Int(current["count"]?.number ?? 1)))
        let spacing = NSTextField(string: String(format: "%.1f", (current["spacing"]?.number ?? 2268) / PageSetupSheet.unitsPerMillimetre))
        for field in [count, spacing] { field.widthAnchor.constraint(equalToConstant: 60).isActive = true }
        let grid = NSGridView(views: [[NSTextField(labelWithString: "단 개수:"), count],
                                      [NSTextField(labelWithString: "단 간격 (mm):"), spacing]])
        grid.frame = NSRect(x: 0, y: 0, width: 220, height: 56)
        let alert = NSAlert()
        alert.messageText = "다단 설정"
        alert.informativeText = "캐럿이 있는 구역에 적용합니다."
        alert.accessoryView = grid
        alert.addButton(withTitle: "설정")
        alert.addButton(withTitle: "취소")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, (1...255).contains(count.integerValue) else { return }
            let units = Int((spacing.doubleValue * PageSetupSheet.unitsPerMillimetre).rounded())
            self?.submit(.action(.setColumns(count: count.integerValue, spacing: min(max(units, 0), Int(Int16.max)))))
        }
    }

    @objc func showPageSetup(_ sender: Any?) {
        guard let window else { return }
        // Page setup belongs to the caret's section; before any click, the first.
        if snapshot.selection == nil { beginEditingAtStart() }
        commitInput()
        let current: JSONValue
        do {
            current = try engine.query(.pageDef)
        } catch {
            return NSSound.beep()
        }
        PageSetupSheet.present(current, in: window) { [weak self] props in
            self?.submit(.action(.setPageDef(props)))
        }
    }

    // MARK: Header and footer

    @objc func editHeader(_ sender: Any?) { showHeaderFooter(isHeader: true) }
    @objc func editFooter(_ sender: Any?) { showHeaderFooter(isHeader: false) }

    private func showHeaderFooter(isHeader: Bool) {
        guard let window else { return }
        if snapshot.selection == nil { beginEditingAtStart() }
        commitInput()
        HeaderFooterSheet.present(engine: engine, isHeader: isHeader, in: window) { [weak self] action in
            self?.submit(.action(action))
        }
    }

    /// 쪽 번호 넣기: the menu item's tag is rhwp's template (1–3 left, centre,
    /// right); positive tags go in the footer, negative ones in the header.
    @objc func insertPageNumber(_ sender: NSMenuItem) {
        if snapshot.selection == nil { beginEditingAtStart() }
        commitInput()
        submit(.action(.applyHeaderFooterTemplate(HeaderFooterSlot(isHeader: sender.tag < 0), template: abs(sender.tag))))
    }

    // MARK: Tables

    /// Whether the caret is in a table cell.
    private var inTable: Bool { !(snapshot.selection?.focus.cellPath.isEmpty ?? true) }

    private func applyTable(_ action: EditAction) {
        commitInput()
        submit(.action(action))
    }

    @objc func insertTable(_ sender: Any?) {
        guard let window, let (rows, columns) = TableSizePrompt.ask(title: "표 만들기", in: window) else { return }
        applyTable(.insertTable(rows: rows, columns: columns))
    }

    @objc func insertRowAbove(_ sender: Any?) { applyTable(.insertRow(below: false)) }
    @objc func insertRowBelow(_ sender: Any?) { applyTable(.insertRow(below: true)) }
    @objc func insertColumnLeft(_ sender: Any?) { applyTable(.insertColumn(right: false)) }
    @objc func insertColumnRight(_ sender: Any?) { applyTable(.insertColumn(right: true)) }
    @objc func deleteRow(_ sender: Any?) { applyTable(.deleteRow) }
    @objc func deleteColumn(_ sender: Any?) { applyTable(.deleteColumn) }
    @objc func mergeCellRight(_ sender: Any?) { applyTable(.mergeRight) }
    @objc func mergeCellDown(_ sender: Any?) { applyTable(.mergeDown) }
    @objc func deleteTable(_ sender: Any?) { applyTable(.deleteTable) }
    @objc func splitTable(_ sender: Any?) { applyTable(.splitTable) }
    @objc func attachNextTable(_ sender: Any?) { applyTable(.attachNextTable) }

    /// 줄/칸 추가…: where and how many.
    @objc func showInsertRowsColumns(_ sender: Any?) {
        guard let window else { return }
        let place = NSPopUpButton()
        place.addItems(withTitles: ["위쪽에 줄", "아래쪽에 줄", "왼쪽에 칸", "오른쪽에 칸"])
        place.selectItem(at: 1)
        let count = NSTextField(string: "1")
        count.widthAnchor.constraint(equalToConstant: 60).isActive = true
        let row = NSStackView(views: [place, count, NSTextField(labelWithString: "개")])
        row.frame = NSRect(x: 0, y: 0, width: 260, height: 26)
        let alert = NSAlert()
        alert.messageText = "줄/칸 추가"
        alert.accessoryView = row
        alert.addButton(withTitle: "추가")
        alert.addButton(withTitle: "취소")
        alert.beginSheetModal(for: window) { [weak self] response in
            let number = min(max(count.integerValue, 1), 256)
            guard response == .alertFirstButtonReturn else { return }
            switch place.indexOfSelectedItem {
            case 0: self?.applyTable(.insertRow(below: false, count: number))
            case 1: self?.applyTable(.insertRow(below: true, count: number))
            case 2: self?.applyTable(.insertColumn(right: false, count: number))
            default: self?.applyTable(.insertColumn(right: true, count: number))
            }
        }
    }

    @objc func splitCell(_ sender: Any?) {
        guard let window, let (rows, columns) = TableSizePrompt.ask(title: "셀 나누기", in: window, rows: 1, columns: 2)
        else { return }
        applyTable(.splitCell(rows: rows, columns: columns))
    }

    /// 모양 복사: the character and paragraph shape at the caret.
    private var copiedFormat: (character: [String: JSONValue], paragraph: [String: JSONValue])?

    @objc func copyFormat(_ sender: Any?) {
        guard let character = snapshot.charProperties, let paragraph = snapshot.paraProperties else { return NSSound.beep() }
        copiedFormat = (FormatCopy.character(from: character), FormatCopy.paragraph(from: paragraph))
        onStatus?("모양을 복사했습니다. 글자를 고른 뒤 모양 붙이기를 쓰세요.")
    }

    /// 모양 붙이기: the copied character shape onto the selection, the
    /// paragraph shape onto the paragraphs it touches.
    @objc func pasteFormat(_ sender: Any?) {
        guard let copiedFormat else { return NSSound.beep() }
        commitInput()
        if hasSelection { submit(.action(.charFormat(copiedFormat.character))) }
        submit(.action(.paraFormat(copiedFormat.paragraph)))
    }

    @objc func showCharacterShape(_ sender: Any?) {
        guard let window, hasSelection else { return NSSound.beep() }
        commitInput()
        let current = (try? engine.query(.charProperties)) ?? .null
        CharacterShapeSheet.present(current, in: window) { [weak self] props in
            self?.applyChar(props)
        }
    }

    @objc func showParagraphShape(_ sender: Any?) {
        guard let window, snapshot.selection != nil else { return NSSound.beep() }
        commitInput()
        let current = (try? engine.query(.paraProperties)) ?? .null
        ParagraphShapeSheet.present(current, in: window) { [weak self] props in
            self?.applyPara(props)
        }
    }

    // MARK: Find and replace

    /// The result of the last find or replace-all, delivered with the snapshot.
    var onSearchResult: ((JSONValue) -> Void)?

    func find(_ text: String, forward: Bool, caseSensitive: Bool) {
        guard !text.isEmpty else { return }
        commitInput()
        submit(.find(query: text, forward: forward, caseSensitive: caseSensitive))
    }

    /// Replaces the selection if it is a match, then finds the next one.
    func replace(_ text: String, with replacement: String, caseSensitive: Bool) {
        guard !text.isEmpty else { return }
        let selected = hasSelection ? ((try? engine.copySelection()) ?? "") : ""
        let matches = caseSensitive ? selected == text : selected.lowercased() == text.lowercased()
        if matches {
            submitInsert(replacement)
        }
        find(text, forward: true, caseSensitive: caseSensitive)
    }

    func replaceAll(_ text: String, with replacement: String, caseSensitive: Bool) {
        guard !text.isEmpty else { return }
        commitInput()
        submit(.action(.replaceAll(query: text, replacement: replacement, caseSensitive: caseSensitive)))
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let paraAlignment = snapshot.paraProperties?["alignment"]?.string
        switch menuItem.action {
        case #selector(toggleBold(_:)):
            menuItem.state = charFlag("bold") ? .on : .off
            return hasSelection
        case #selector(toggleItalic(_:)):
            menuItem.state = charFlag("italic") ? .on : .off
            return hasSelection
        case #selector(toggleUnderlineStyle(_:)):
            menuItem.state = charFlag("underline") ? .on : .off
            return hasSelection
        case #selector(toggleStrikethrough(_:)):
            menuItem.state = charFlag("strikethrough") ? .on : .off
            return hasSelection
        case #selector(toggleSuperscript(_:)):
            menuItem.state = charFlag("superscript") ? .on : .off
            return hasSelection
        case #selector(toggleSubscript(_:)):
            menuItem.state = charFlag("subscript") ? .on : .off
            return hasSelection
        case #selector(toggleEmboss(_:)):
            menuItem.state = charFlag("emboss") ? .on : .off
            return hasSelection
        case #selector(toggleEngrave(_:)):
            menuItem.state = charFlag("engrave") ? .on : .off
            return hasSelection
        case #selector(toggleOutline(_:)):
            menuItem.state = hasOutline ? .on : .off
            return hasSelection
        case #selector(increaseFontSize(_:)), #selector(decreaseFontSize(_:)), #selector(showFontPanel(_:)),
             #selector(showTextColorPanel(_:)), #selector(increaseCharRatio(_:)), #selector(decreaseCharRatio(_:)),
             #selector(increaseCharSpacing(_:)), #selector(decreaseCharSpacing(_:)):
            return hasSelection
        case #selector(alignDistributed(_:)):
            menuItem.state = paraAlignment == "distribute" ? .on : .off
            return snapshot.selection != nil
        case #selector(alignSplit(_:)):
            menuItem.state = paraAlignment == "split" ? .on : .off
            return snapshot.selection != nil
        case #selector(copyFormat(_:)):
            return snapshot.charProperties != nil
        case #selector(pasteFormat(_:)):
            return copiedFormat != nil && snapshot.selection != nil
        case #selector(showCharacterShape(_:)):
            return hasSelection
        case #selector(showParagraphShape(_:)):
            return snapshot.selection != nil
        case #selector(increaseLineSpacing(_:)), #selector(decreaseLineSpacing(_:)):
            return snapshot.selection != nil
        case #selector(toggleNumbering(_:)):
            menuItem.state = snapshot.paraProperties?["headType"]?.string == "Number" ? .on : .off
            return snapshot.selection != nil
        case #selector(toggleBullets(_:)):
            menuItem.state = snapshot.paraProperties?["headType"]?.string == "Bullet" ? .on : .off
            return snapshot.selection != nil
        case #selector(alignLeft(_:)):
            menuItem.state = paraAlignment == "left" ? .on : .off
            return snapshot.selection != nil
        case #selector(alignCenter(_:)):
            menuItem.state = paraAlignment == "center" ? .on : .off
            return snapshot.selection != nil
        case #selector(alignRight(_:)):
            menuItem.state = paraAlignment == "right" ? .on : .off
            return snapshot.selection != nil
        case #selector(alignJustified(_:)):
            menuItem.state = paraAlignment == "justify" ? .on : .off
            return snapshot.selection != nil
        case #selector(setLineSpacing(_:)):
            let spacing = snapshot.paraProperties?["lineSpacing"]?.number
            menuItem.state = spacing.map { Int($0) == menuItem.tag } ?? false ? .on : .off
            return snapshot.selection != nil
        case #selector(increaseIndent(_:)), #selector(decreaseIndent(_:)):
            return snapshot.selection != nil
        case #selector(insertPicture(_:)):
            return inBody
        case #selector(deleteSelectedObject(_:)):
            return selectedObject != nil
        case #selector(bringObjectToFront(_:)), #selector(bringObjectForward(_:)), #selector(sendObjectBackward(_:)),
             #selector(sendObjectToBack(_:)):
            // Stacking order is for shapes, as in the web editor.
            return selectedObject?.kind == "shape"
        case #selector(showObjectProperties(_:)), #selector(rotatePictureRight(_:)), #selector(rotatePictureLeft(_:)),
             #selector(flipPictureHorizontally(_:)), #selector(flipPictureVertically(_:)):
            return selectedPicture != nil
        case #selector(editHyperlink(_:)), #selector(removeHyperlink(_:)), #selector(showSymbols(_:)):
            return snapshot.selection != nil
        case #selector(addBookmark(_:)):
            return inBody
        case #selector(applyStyle(_:)), #selector(increaseOutlineLevel(_:)), #selector(decreaseOutlineLevel(_:)):
            return snapshot.selection != nil
        case #selector(toggleParagraphMarks(_:)):
            menuItem.state = snapshot.marks.paragraphMarks ? .on : .off
            return true
        case #selector(toggleControlCodes(_:)):
            menuItem.state = snapshot.marks.controlCodes ? .on : .off
            return true
        case #selector(toggleTransparentBorders(_:)):
            menuItem.state = snapshot.marks.transparentBorders ? .on : .off
            return true
        case #selector(insertPageBreak(_:)), #selector(insertColumnBreak(_:)):
            return inBody
        case #selector(setColumnCount(_:)), #selector(showColumnSettings(_:)):
            return true
        case #selector(showPageSetup(_:)):
            return true
        case #selector(insertTable(_:)):
            return snapshot.selection?.isCollapsed == true && !inTable
        case #selector(insertRowAbove(_:)), #selector(insertRowBelow(_:)), #selector(insertColumnLeft(_:)),
             #selector(insertColumnRight(_:)), #selector(deleteRow(_:)), #selector(deleteColumn(_:)),
             #selector(mergeCellRight(_:)), #selector(mergeCellDown(_:)), #selector(splitCell(_:)),
             #selector(deleteTable(_:)), #selector(splitTable(_:)), #selector(attachNextTable(_:)),
             #selector(showInsertRowsColumns(_:)):
            return snapshot.selection?.focus.cellPath.count == 1
        case #selector(undo(_:)):
            return snapshot.canUndo
        case #selector(redo(_:)):
            return snapshot.canRedo
        case #selector(copy(_:)), #selector(cut(_:)):
            return !(snapshot.selection?.isCollapsed ?? true)
        case #selector(paste(_:)):
            return snapshot.selection != nil && NSPasteboard.general.string(forType: .string) != nil
        default:
            return true
        }
    }

    // MARK: NSTextInputClient
    //
    // Ranges are UTF-16 offsets within the focus paragraph. That matches
    // rhwp's scalar offsets for Hangul and other BMP text; text outside the
    // BMP, and ranges across paragraphs, are approximations.

    func insertText(_ string: Any, replacementRange: NSRange) {
        let text = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        if markedText.isEmpty {
            selectParagraphRange(replacementRange)
        }
        submitInsert(text)
        clearMarkedText()
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let text = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        guard !text.isEmpty else {
            if !markedText.isEmpty, !localComposition { submit(.cancelMarked) }
            return clearMarkedText()
        }
        if markedText.isEmpty {
            // Replacing existing text (e.g. 한자 conversion) needs the engine.
            localComposition = replacementRange.location == NSNotFound && usesLocalComposition
            markedStart = selectParagraphRange(replacementRange)
                ?? snapshot.selection.map { $0.start.scalarOffset + echoText.unicodeScalars.count }
        }
        markedText = text
        if localComposition {
            updateOverlay()
        } else {
            record(engine.submit(.mark(text)))
        }
    }

    func unmarkText() {
        guard !markedText.isEmpty else { return }
        if localComposition {
            submitInsert(markedText)
        } else {
            submit(.commitMarked)
        }
        clearMarkedText()
    }

    func selectedRange() -> NSRange {
        if let markedStart, !markedText.isEmpty {
            return NSRange(location: markedStart + markedText.utf16.count, length: 0)
        }
        guard let selection = snapshot.selection else { return NSRange(location: NSNotFound, length: 0) }
        guard selection.anchor.paragraph == selection.focus.paragraph,
              selection.anchor.leafParagraph == selection.focus.leafParagraph else {
            return NSRange(location: selection.focus.scalarOffset, length: 0)
        }
        let start = min(selection.anchor.scalarOffset, selection.focus.scalarOffset)
        return NSRange(location: start, length: abs(selection.focus.scalarOffset - selection.anchor.scalarOffset))
    }

    func markedRange() -> NSRange {
        guard let markedStart, !markedText.isEmpty else { return NSRange(location: NSNotFound, length: 0) }
        return NSRange(location: markedStart, length: markedText.utf16.count)
    }

    func hasMarkedText() -> Bool {
        !markedText.isEmpty
    }

    /// Lets input methods read text before converting it, e.g. 한자 conversion
    /// of the syllable before the caret (option-return).
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard range.location != NSNotFound,
              let context = try? engine.surroundingText(timeout: 1)
        else { return nil }
        let scalars = Array(context.text.unicodeScalars)
        let lower = max(range.location - context.absoluteStartScalar, 0)
        let upper = min(range.location + range.length - context.absoluteStartScalar, scalars.count)
        guard lower <= upper else { return nil }
        actualRange?.pointee = NSRange(location: lower + context.absoluteStartScalar, length: upper - lower)
        var text = String.UnicodeScalarView()
        text.append(contentsOf: scalars[lower..<upper])
        return NSAttributedString(string: String(text))
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        let rect = overlayRect ?? markedRects.first ?? caretRect ?? selectionRects.first ?? .zero
        guard let window else { return .zero }
        return window.convertToScreen(convert(rect, to: nil))
    }

    func characterIndex(for point: NSPoint) -> Int {
        NSNotFound
    }

    /// Selects a range given in NSTextInputClient coordinates (see above) and
    /// returns its start; does nothing for NSNotFound.
    @discardableResult
    private func selectParagraphRange(_ range: NSRange) -> Int? {
        guard range.location != NSNotFound else { return nil }
        submit(.selectInFocusParagraph(location: range.location, length: range.length))
        return range.location
    }
}
