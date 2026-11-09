// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import Rhwp

/// Stacks every page vertically, renders the pages being drawn and edits body
/// text through a `DocumentEditor`.
///
/// One layout pixel is drawn as one point. Everything runs on the main thread,
/// which owns the session.
final class PagesView: NSView, @MainActor NSTextInputClient, NSMenuItemValidation {
    private static let gap: CGFloat = 24
    private static let cacheLimit = 12

    let editor: DocumentEditor
    /// Called after document contents change, e.g. to update the edited state.
    var onDocumentChange: (() -> Void)?
    /// Short user-facing status, such as why an edit was refused; nil clears it.
    var onStatus: ((String?) -> Void)?

    private var session: RhwpSession { editor.session }
    private var pageRects: [CGRect] = []
    private var cache: [Int: (scale: Double, revision: UInt64, image: CGImage)] = [:]
    private var cacheOrder: [Int] = []
    private let insertionIndicator = NSTextInsertionIndicator()
    private var caretRect: CGRect?
    private var selectionRects: [CGRect] = []
    private var markedRects: [CGRect] = []
    private var dragAnchor: TextPosition?

    init(editor: DocumentEditor, pageSizes: [CGSize]) {
        self.editor = editor
        super.init(frame: .zero)
        layOutPages(pageSizes)
        insertionIndicator.displayMode = .hidden
        addSubview(insertionIndicator)
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

        for (page, rect) in pageRects.enumerated() where rect.intersects(dirtyRect) {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 6
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.set()
            NSColor.white.setFill()
            rect.fill()
            NSGraphicsContext.restoreGraphicsState()

            do {
                let image = try pageImage(page)
                NSImage(cgImage: image, size: rect.size)
                    .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            } catch {
                drawFailure(error, in: rect)
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
    }

    /// Device pixels per layout pixel, so pages stay sharp when magnified.
    private var renderScale: Double {
        let backing = Double(window?.backingScaleFactor ?? 2)
        let magnification = Double(enclosingScrollView?.magnification ?? 1)
        return (backing * max(magnification, 1) * 2).rounded(.up) / 2
    }

    private func pageImage(_ page: Int) throws -> CGImage {
        let scale = renderScale
        if let cached = cache[page], cached.scale == scale, cached.revision == editor.revision {
            return cached.image
        }
        let image = try session.renderPage(page, scale: scale)
        cache[page] = (scale, editor.revision, image)
        cacheOrder.removeAll { $0 == page }
        cacheOrder.append(page)
        if cacheOrder.count > Self.cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
        return image
    }

    private func drawFailure(_ error: Error, in rect: CGRect) {
        let message = "이 쪽을 그리지 못했습니다.\n\(error)" as NSString
        message.draw(in: rect.insetBy(dx: 24, dy: 24), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.systemRed,
        ])
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
        perform { try editor.select(.collapsed(at: .documentStart)) }
    }

    /// Commits any input-method composition, e.g. before saving.
    func commitInput() {
        guard editor.hasMarkedText else { return }
        perform { try editor.commitMarkedText() }
        inputContext?.discardMarkedText()
    }

    /// Runs an edit, then refreshes layout, drawing and caret. Edits rhwp
    /// cannot apply at this position (tables, objects...) only beep and say why.
    @discardableResult
    private func perform(_ edit: () throws -> Any?) -> Bool {
        let revision = editor.revision
        do {
            _ = try edit()
            onStatus?(nil)
        } catch RhwpNativeHostError.failed(code: "unsupported", _) {
            NSSound.beep()
            onStatus?("이 위치는 아직 편집할 수 없습니다 (표, 개체 등이 있는 문단)")
            refreshAfterEdit(contentsChanged: editor.revision != revision)
            return false
        } catch {
            NSSound.beep()
            onStatus?("편집하지 못했습니다: \(error)")
            refreshAfterEdit(contentsChanged: editor.revision != revision)
            return false
        }
        refreshAfterEdit(contentsChanged: editor.revision != revision)
        return true
    }

    private func refreshAfterEdit(contentsChanged: Bool) {
        if contentsChanged {
            if let info = try? session.info(), info.pageCount != pageRects.count,
               let sizes = try? (0..<info.pageCount).map({ try session.pageSize($0) }) {
                layOutPages(sizes)
            }
            needsDisplay = true
            onDocumentChange?()
        }
        updateSelectionGeometry()
    }

    private func updateSelectionGeometry() {
        let oldRects = selectionRects + markedRects + [caretRect].compactMap { $0 }
        caretRect = nil
        selectionRects = []
        markedRects = []
        if let selection = editor.selection {
            if selection.isCollapsed {
                if let caret = try? session.caret(at: selection.focus) {
                    caretRect = viewRect(page: caret.page, x: caret.x, y: caret.y, width: 0, height: caret.height)
                }
            } else {
                selectionRects = rects(for: selection)
            }
        }
        if let marked = editor.markedSelection {
            markedRects = rects(for: marked)
        }
        for rect in oldRects + selectionRects + markedRects {
            setNeedsDisplay(rect.insetBy(dx: -2, dy: -2))
        }
        updateInsertionIndicator()
        if let caretRect {
            scrollToVisible(caretRect.insetBy(dx: -24, dy: -24))
        }
    }

    private func rects(for selection: TextSelection) -> [CGRect] {
        ((try? session.selectionRects(selection)) ?? []).compactMap {
            viewRect(page: $0.page, x: $0.bounds.x, y: $0.bounds.y, width: $0.bounds.width, height: $0.bounds.height)
        }
    }

    private func updateInsertionIndicator() {
        guard let caretRect, window?.firstResponder === self else {
            insertionIndicator.displayMode = .hidden
            return
        }
        insertionIndicator.frame = CGRect(x: caretRect.minX - 1, y: caretRect.minY, width: 2, height: caretRect.height)
        insertionIndicator.displayMode = .automatic
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
        guard let hit = hitTest(event) else { return }
        if event.modifierFlags.contains(.shift), let anchor = editor.selection?.anchor {
            dragAnchor = anchor
            perform { try editor.select(TextSelection(anchor: anchor, focus: hit)) }
        } else {
            dragAnchor = hit
            perform { try editor.select(.collapsed(at: hit)) }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        autoscroll(with: event)
        guard let anchor = dragAnchor, let hit = hitTest(event), hit != editor.selection?.focus else { return }
        perform { try editor.select(TextSelection(anchor: anchor, focus: hit)) }
    }

    override func mouseUp(with event: NSEvent) {
        dragAnchor = nil
    }

    private func hitTest(_ event: NSEvent) -> TextPosition? {
        let point = convert(event.locationInWindow, from: nil)
        guard let target = pagePoint(at: point) else { return nil }
        return try? session.hitTest(page: target.page, x: target.x, y: target.y).position
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
            perform { try editor.execute(command) }
        } else if selector == #selector(insertTab(_:)) {
            perform { try editor.insertText("\t") }
        } else if selector == #selector(cancelOperation(_:)) {
            perform { try editor.cancelMarkedText() }
        }
    }

    // MARK: Menu actions

    @objc func undo(_ sender: Any?) {
        perform { try editor.undo() }
    }

    @objc func redo(_ sender: Any?) {
        perform { try editor.redo() }
    }

    @objc func copy(_ sender: Any?) {
        guard let text = try? editor.copy() else { return NSSound.beep() }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc func cut(_ sender: Any?) {
        var text: String?
        perform { text = try editor.cut() }
        guard let text else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return NSSound.beep() }
        perform { try editor.paste(text) }
    }

    override func selectAll(_ sender: Any?) {
        perform { try editor.execute(.selectAll) }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)):
            return editor.isEditing && ((try? session.info().canUndo) ?? false)
        case #selector(redo(_:)):
            return editor.isEditing && ((try? session.info().canRedo) ?? false)
        case #selector(copy(_:)), #selector(cut(_:)):
            return !(editor.selection?.isCollapsed ?? true)
        case #selector(paste(_:)):
            return editor.isEditing && NSPasteboard.general.string(forType: .string) != nil
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
        if replacementRange.location != NSNotFound, !editor.hasMarkedText {
            selectParagraphRange(replacementRange)
        }
        perform { try editor.insertText(text) }
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let text = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        if replacementRange.location != NSNotFound, !editor.hasMarkedText {
            selectParagraphRange(replacementRange)
        }
        perform { try editor.setMarkedText(text) }
    }

    func unmarkText() {
        perform { try editor.commitMarkedText() }
    }

    func selectedRange() -> NSRange {
        guard let selection = editor.selection else { return NSRange(location: NSNotFound, length: 0) }
        guard selection.anchor.paragraph == selection.focus.paragraph else {
            return NSRange(location: selection.focus.scalarOffset, length: 0)
        }
        let start = min(selection.anchor.scalarOffset, selection.focus.scalarOffset)
        return NSRange(location: start, length: abs(selection.focus.scalarOffset - selection.anchor.scalarOffset))
    }

    func markedRange() -> NSRange {
        guard let start = editor.markedStart, !editor.markedText.isEmpty else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: start.scalarOffset, length: editor.markedText.utf16.count)
    }

    func hasMarkedText() -> Bool {
        editor.hasMarkedText
    }

    /// Lets input methods read text before converting it, e.g. 한자 conversion
    /// of the syllable before the caret (option-return).
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard range.location != NSNotFound, let context = try? editor.surroundingText() else { return nil }
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
        let rect = markedRects.first ?? caretRect ?? selectionRects.first ?? .zero
        guard let window else { return .zero }
        return window.convertToScreen(convert(rect, to: nil))
    }

    func characterIndex(for point: NSPoint) -> Int {
        NSNotFound
    }

    /// Selects a range given in this view's NSTextInputClient coordinates.
    private func selectParagraphRange(_ range: NSRange) {
        guard let focus = editor.selection?.focus else { return }
        var anchor = focus
        anchor.scalarOffset = range.location
        perform { try editor.select(TextSelection(anchor: anchor, focus: anchor.offset(by: range.length))) }
    }
}
