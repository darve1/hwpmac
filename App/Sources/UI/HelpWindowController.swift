// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// Shows the bundled Help.md in a read-only text window.
final class HelpWindowController: NSWindowController {
    static let shared = HelpWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.title = "HwpMac 도움말"
        let scrollView = NSTextView.scrollableTextView()
        if let textView = scrollView.documentView as? NSTextView {
            textView.isEditable = false
            textView.textContainerInset = NSSize(width: 20, height: 20)
            textView.textStorage?.setAttributedString(Self.helpText())
        }
        window.contentView = scrollView
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private static func helpText() -> NSAttributedString {
        guard let url = Bundle.main.url(forResource: "Help", withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8),
              let text = try? NSMutableAttributedString(
                  markdown: markdown,
                  options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
              )
        else {
            return NSAttributedString(string: "도움말 파일을 찾지 못했습니다.")
        }
        text.addAttributes([.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.textColor],
                           range: NSRange(location: 0, length: text.length))
        return text
    }
}
