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
    private var cache: [Int: (scale: Double, revision: UInt64, image: CGImage)] = [:]
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
        drawOverlay()
    }

    // MARK: Typing echo and local composition

    private var overlayFont: NSFont {
        NSFont.systemFont(ofSize: min(max((caretRect?.height ?? 13) * 0.8, 8), 72))
    }

    private var echoText: String {
        echoValid ? echo.map(\.text).joined() : ""
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
        engine.submit(operation)
    }

    private func submitInsert(_ text: String) {
        let sequence = engine.submit(.insert(text))
        if usesLocalComposition {
            echo.append((sequence, text))
        }
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
        echo.removeAll { $0.sequence <= snapshot.appliedSequence }
        if echo.isEmpty { echoValid = true }
        if let sizes = snapshot.pageSizes {
            layOutPages(sizes)
            needsDisplay = true
        }
        if snapshot.contentsChanged {
            setNeedsDisplay(visibleRect)
            onDocumentChange?(snapshot)
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

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
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
            engine.submit(.mark(text))
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
        guard selection.anchor.paragraph == selection.focus.paragraph else {
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
