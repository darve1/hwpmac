// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

final class DocumentWindowController: NSWindowController {
    private let scrollView = NSScrollView()

    init(session: RhwpSession, pageSizes: [CGSize]) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 4
        scrollView.backgroundColor = .underPageBackgroundColor
        scrollView.documentView = PagesView(session: session, pageSizes: pageSizes)
        window.contentView = scrollView
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
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
