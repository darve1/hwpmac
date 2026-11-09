// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

final class DocumentWindowController: NSWindowController {
    private let scrollView = NSScrollView()
    private let pagesView: PagesView

    init(editor: DocumentEditor, pageSizes: [CGSize]) {
        pagesView = PagesView(editor: editor, pageSizes: pageSizes)
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
        window.center()
        super.init(window: window)

        pagesView.onStatus = { [weak window] message in
            window?.subtitle = message ?? ""
        }
        pagesView.onDocumentChange = { [weak self] in
            (self?.document as? HwpDocument)?.syncEditedState()
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

    @objc func zoomToActualSize(_ sender: Any?) {
        scrollView.animator().magnification = 1
    }

    @objc func zoomIn(_ sender: Any?) {
        scrollView.animator().magnification = min(scrollView.magnification * 1.25, scrollView.maxMagnification)
    }

    @objc func zoomOut(_ sender: Any?) {
        scrollView.animator().magnification = max(scrollView.magnification / 1.25, scrollView.minMagnification)
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
