// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

final class DocumentWindowController: NSWindowController, NSMenuItemValidation {
    private let scrollView = NSScrollView()
    private let toolbarDelegate = DocumentToolbar()
    let pagesView: PagesView

    init(engine: any DocumentEngineClient) {
        pagesView = PagesView(engine: engine)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        scrollView.contentView = CenteringClipView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 4
        scrollView.backgroundColor = .underPageBackgroundColor
        scrollView.documentView = pagesView
        window.contentView = scrollView
        window.toolbar = toolbarDelegate.makeToolbar()
        window.toolbarStyle = .unifiedCompact
        window.center()
        super.init(window: window)

        pagesView.onStatus = { [weak window] message in
            window?.subtitle = message ?? ""
        }
        pagesView.onDocumentChange = { [weak self] snapshot in
            (self?.document as? HwpDocument)?.syncEditedState(isDirty: snapshot.isDirty)
        }
        window.makeFirstResponder(pagesView)
        pagesView.beginEditingAtStart()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Commits any input-method composition so a save includes it.
    func commitInput() {
        pagesView.commitInput()
    }

    @objc func showFind(_ sender: Any?) {
        FindPanelController.shared.showPanel(focusReplace: false)
    }

    @objc func showReplace(_ sender: Any?) {
        FindPanelController.shared.showPanel(focusReplace: true)
    }

    @objc func findNext(_ sender: Any?) {
        FindPanelController.shared.findNext(sender)
    }

    @objc func findPrevious(_ sender: Any?) {
        FindPanelController.shared.findPrevious(sender)
    }

    @objc func restartEngine(_ sender: Any?) {
        (document as? HwpDocument)?.restartEngine()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(restartEngine(_:)) {
            return (document as? HwpDocument)?.engine?.canRestart ?? false
        }
        return true
    }

    @objc func zoomToActualSize(_ sender: Any?) {
        scrollView.animator().magnification = 1
    }

    @objc func zoomIn(_ sender: Any?) {
        scrollView.animator().magnification = min(scrollView.magnification * 1.25, scrollView.maxMagnification)
    }

    @objc func zoomOut(_ sender: Any?) {
        scrollView.animator().magnification = max(scrollView.magnification / 1.25, scrollView.minMagnification)
    }

    /// 폭 맞춤: the widest page fills the window's width.
    @objc func zoomToFitWidth(_ sender: Any?) {
        let span = pagesView.largestPageSpan
        guard span.width > 0 else { return }
        setMagnification(scrollView.contentSize.width / span.width)
    }

    /// 쪽 맞춤: a whole page fits in the window.
    @objc func zoomToFitPage(_ sender: Any?) {
        let span = pagesView.largestPageSpan
        guard span.width > 0, span.height > 0 else { return }
        let size = scrollView.contentSize
        setMagnification(min(size.width / span.width, size.height / span.height))
    }

    /// 배율…: a zoom percentage typed in.
    @objc func showZoomPrompt(_ sender: Any?) {
        guard let window else { return }
        let field = NSTextField(string: String(Int((scrollView.magnification * 100).rounded())))
        field.frame = NSRect(x: 0, y: 0, width: 80, height: 24)
        let alert = NSAlert()
        alert.messageText = "배율 (%)"
        alert.informativeText = "\(Int(scrollView.minMagnification * 100))~\(Int(scrollView.maxMagnification * 100))%"
        alert.accessoryView = field
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, field.doubleValue > 0 else { return }
            self?.setMagnification(field.doubleValue / 100)
        }
    }

    var magnification: CGFloat { scrollView.magnification }

    private func setMagnification(_ value: CGFloat) {
        scrollView.magnification = min(max(value, scrollView.minMagnification), scrollView.maxMagnification)
    }
}

/// Keeps the pages horizontally centered when the window (for example in
/// full screen) is wider than the document, instead of pinning them left.
private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var bounds = super.constrainBoundsRect(proposedBounds)
        if let documentFrame = documentView?.frame, bounds.width > documentFrame.width {
            bounds.origin.x = documentFrame.minX - (bounds.width - documentFrame.width) / 2
        }
        return bounds
    }
}
