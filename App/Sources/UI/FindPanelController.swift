// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// Find and replace for the frontmost document window.
final class FindPanelController: NSWindowController, NSTextFieldDelegate {
    static let shared = FindPanelController()

    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let caseSensitive = NSButton(checkboxWithTitle: "대/소문자 구분", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private weak var observedView: PagesView?

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 150),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: true
        )
        panel.title = "찾기 및 바꾸기"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        super.init(window: panel)

        findField.placeholderString = "찾을 내용"
        replaceField.placeholderString = "바꿀 내용"
        findField.delegate = self
        status.textColor = .secondaryLabelColor
        let buttons = NSStackView(views: [
            button("이전", #selector(findPrevious(_:))),
            button("다음", #selector(findNext(_:))),
            button("바꾸기", #selector(replace(_:))),
            button("모두 바꾸기", #selector(replaceAll(_:))),
        ])
        let stack = NSStackView(views: [findField, replaceField, caseSensitive, buttons, status])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        for field in [findField, replaceField] {
            field.widthAnchor.constraint(equalToConstant: 408).isActive = true
        }
        panel.contentView = stack
        panel.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    /// The editing view of the document window behind the panel.
    private var pagesView: PagesView? {
        let controller = (NSApp.mainWindow ?? NSApp.orderedWindows.first { $0.windowController is DocumentWindowController })?
            .windowController as? DocumentWindowController
        let view = controller?.pagesView
        if let view, view !== observedView {
            observedView = view
            view.onSearchResult = { [weak self] result in self?.show(result) }
        }
        return view
    }

    func showPanel(focusReplace: Bool) {
        showWindow(nil)
        window?.makeFirstResponder(focusReplace ? replaceField : findField)
    }

    @objc func findNext(_ sender: Any?) {
        status.stringValue = ""
        pagesView?.find(findField.stringValue, forward: true, caseSensitive: caseSensitive.state == .on)
    }

    @objc func findPrevious(_ sender: Any?) {
        status.stringValue = ""
        pagesView?.find(findField.stringValue, forward: false, caseSensitive: caseSensitive.state == .on)
    }

    @objc func replace(_ sender: Any?) {
        status.stringValue = ""
        pagesView?.replace(findField.stringValue, with: replaceField.stringValue, caseSensitive: caseSensitive.state == .on)
    }

    @objc func replaceAll(_ sender: Any?) {
        status.stringValue = ""
        pagesView?.replaceAll(findField.stringValue, with: replaceField.stringValue, caseSensitive: caseSensitive.state == .on)
    }

    /// Return in the find field finds the next match.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        findNext(nil)
        return true
    }

    private func show(_ result: JSONValue) {
        if let count = result["count"]?.number {
            status.stringValue = "\(Int(count))개를 바꿨습니다."
        } else if result["found"]?.bool == false {
            status.stringValue = "찾을 수 없습니다."
            NSSound.beep()
        }
    }
}
