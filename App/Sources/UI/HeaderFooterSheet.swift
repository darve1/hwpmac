// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 머리말/꼬리말: edits the text of a header or footer of the caret's section.
/// Fields show as bracketed tokens while editing and are stored as rhwp's field
/// markers (U+0015 page number, U+0016 page count, U+0017 file name).
@MainActor
final class HeaderFooterSheet: NSObject {
    static let fields: [(marker: Character, token: String, title: String)] = [
        ("\u{15}", "[쪽 번호]", "쪽 번호"), ("\u{16}", "[전체 쪽 수]", "전체 쪽 수"), ("\u{17}", "[파일 이름]", "파일 이름"),
    ]

    /// Editing text from stored text: markers become tokens.
    static func editable(_ stored: String) -> String {
        fields.reduce(stored) { $0.replacingOccurrences(of: String($1.marker), with: $1.token) }
    }

    /// Stored text from editing text: tokens become markers; other control
    /// characters (tabs) are dropped, as the engine does not take them.
    static func stored(_ editable: String) -> String {
        let text = fields.reduce(editable.replacingOccurrences(of: "\r\n", with: "\n")) {
            $0.replacingOccurrences(of: $1.token, with: String($1.marker))
        }
        let markers = Set(fields.map(\.marker))
        return String(text.filter { $0 == "\n" || markers.contains($0) || !($0.unicodeScalars.first?.properties.generalCategory == .control) })
    }

    private let engine: any DocumentEngineClient
    private let apply: (EditAction) -> Void
    private let kind = NSSegmentedControl(labels: ["머리말", "꼬리말"], trackingMode: .selectOne, target: nil, action: nil)
    private let pages = NSPopUpButton()
    private let textView = NSTextView()
    private let status = NSTextField(labelWithString: "")
    private var window: NSWindow?

    private init(engine: any DocumentEngineClient, isHeader: Bool, apply: @escaping (EditAction) -> Void) {
        self.engine = engine
        self.apply = apply
        super.init()
        kind.selectedSegment = isHeader ? 0 : 1
    }

    static func present(engine: any DocumentEngineClient, isHeader: Bool, in parent: NSWindow,
                        apply: @escaping (EditAction) -> Void) {
        let sheet = HeaderFooterSheet(engine: engine, isHeader: isHeader, apply: apply)
        let window = sheet.makeWindow()
        sheet.window = window
        sheet.reload(nil)
        parent.beginSheet(window) { _ in _ = sheet }
    }

    private var slot: HeaderFooterSlot {
        HeaderFooterSlot(isHeader: kind.selectedSegment == 0,
                         applyTo: HeaderFooterSlot.Pages(rawValue: pages.indexOfSelectedItem) ?? .both)
    }

    private func makeWindow() -> NSWindow {
        kind.target = self
        kind.action = #selector(reload(_:))
        pages.addItems(withTitles: ["양쪽", "짝수 쪽", "홀수 쪽"])
        pages.target = self
        pages.action = #selector(reload(_:))

        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 420).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
        textView.autoresizingMask = [.width]
        textView.frame = NSRect(x: 0, y: 0, width: 420, height: 110)

        let fieldButtons = NSStackView(views: [NSTextField(labelWithString: "넣기:")] + Self.fields.enumerated().map {
            let button = NSButton(title: $0.element.title, target: self, action: #selector(insertField(_:)))
            button.tag = $0.offset
            return button
        })
        let remove = NSButton(title: "지우기", target: self, action: #selector(remove(_:)))
        let cancel = NSButton(title: "취소", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let ok = NSButton(title: "설정", target: self, action: #selector(confirm(_:)))
        ok.keyEquivalent = "\r"
        ok.keyEquivalentModifierMask = [.command]
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [remove, spacer, cancel, ok])
        buttons.widthAnchor.constraint(equalTo: scroll.widthAnchor).isActive = true

        status.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [NSStackView(views: [kind, pages]), scroll, fieldButtons, status, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.title = "머리말/꼬리말"
        window.contentView = stack
        window.initialFirstResponder = textView
        return window
    }

    @objc private func reload(_ sender: Any?) {
        let current = try? engine.query(.headerFooter(slot))
        let exists = current?["exists"]?.bool == true
        textView.string = Self.editable(current?["text"]?.string ?? "")
        if !exists {
            status.stringValue = "아직 없습니다. 설정하면 새로 만듭니다."
        } else if current?["plain"]?.bool == false {
            status.stringValue = "글자와 필드 말고 다른 개체(그림, 표 등)가 있습니다. 설정하면 그 개체는 지워집니다."
        } else {
            status.stringValue = ""
        }
    }

    @objc private func insertField(_ sender: NSButton) {
        textView.insertText(Self.fields[sender.tag].token, replacementRange: textView.selectedRange())
        window?.makeFirstResponder(textView)
    }

    @objc private func remove(_ sender: Any?) {
        let slot = slot
        end()
        apply(.deleteHeaderFooter(slot))
    }

    @objc private func confirm(_ sender: Any?) {
        let slot = slot
        let text = Self.stored(textView.string)
        end()
        apply(.setHeaderFooter(slot, text: text))
    }

    @objc private func cancel(_ sender: Any?) { end() }

    private func end() {
        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
