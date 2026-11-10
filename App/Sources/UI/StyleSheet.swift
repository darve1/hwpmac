// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 스타일: the document's paragraph styles — rename them, change their 글자 모양
/// and 문단 모양, add one from the caret's paragraph, delete one. Paragraphs that
/// use a style follow its changes.
@MainActor
final class StyleSheet: NSObject {
    private let engine: any DocumentEngineClient
    private let apply: (EditAction) -> Void
    private let styles = NSPopUpButton()
    private let name = NSTextField()
    private let englishName = NSTextField()
    private let next = NSPopUpButton()
    private let status = NSTextField(labelWithString: "")
    private var list: [JSONValue] = []
    private var window: NSWindow?

    private init(engine: any DocumentEngineClient, apply: @escaping (EditAction) -> Void) {
        self.engine = engine
        self.apply = apply
        super.init()
    }

    static func present(engine: any DocumentEngineClient, in parent: NSWindow, apply: @escaping (EditAction) -> Void) {
        let sheet = StyleSheet(engine: engine, apply: apply)
        let window = sheet.makeWindow()
        sheet.window = window
        sheet.reload(select: nil)
        parent.beginSheet(window) { _ in _ = sheet }
    }

    private var selectedId: Int? { list.indices.contains(styles.indexOfSelectedItem) ? styles.indexOfSelectedItem : nil }

    private func makeWindow() -> NSWindow {
        styles.target = self
        styles.action = #selector(styleChanged(_:))
        for field in [name, englishName] { field.widthAnchor.constraint(equalToConstant: 220).isActive = true }
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "스타일:"), styles],
            [NSTextField(labelWithString: "이름:"), name],
            [NSTextField(labelWithString: "영문 이름:"), englishName],
            [NSTextField(labelWithString: "다음 문단:"), next],
        ])
        grid.rowSpacing = 6
        grid.column(at: 0).xPlacement = .trailing
        let buttons = NSStackView(views: [
            NSButton(title: "글자 모양…", target: self, action: #selector(editCharacter(_:))),
            NSButton(title: "문단 모양…", target: self, action: #selector(editParagraph(_:))),
            NSButton(title: "이름 바꾸기", target: self, action: #selector(rename(_:))),
        ])
        let manage = NSStackView(views: [
            NSButton(title: "새 스타일…", target: self, action: #selector(add(_:))),
            NSButton(title: "지우기", target: self, action: #selector(remove(_:))),
        ])
        let done = NSButton(title: "닫기", target: self, action: #selector(close(_:)))
        done.keyEquivalent = "\r"
        status.textColor = .secondaryLabelColor
        let note = NSTextField(wrappingLabelWithString: "바꾼 모양은 그 스타일을 쓰는 문단에 바로 적용됩니다. 바탕글은 지울 수 없습니다.")
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = 340
        let stack = NSStackView(views: [grid, buttons, manage, note, status, done])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.title = "스타일"
        window.contentView = stack
        return window
    }

    /// Reads the style list; selects `id`, or the caret paragraph's style.
    private func reload(select id: Int?) {
        let result = (try? engine.query(.styles)) ?? .null
        if case let .array(items)? = result["styles"] { list = items } else { list = [] }
        let titles = list.map { $0["name"]?.string ?? "" }
        styles.removeAllItems()
        styles.addItems(withTitles: titles.enumerated().map { "\($0.offset + 1). \($0.element)" })
        next.removeAllItems()
        next.addItems(withTitles: titles.enumerated().map { "\($0.offset + 1). \($0.element)" })
        let selected = id ?? result["current"]?.number.map(Int.init) ?? 0
        styles.selectItem(at: min(max(selected, 0), max(list.count - 1, 0)))
        styleChanged(nil)
    }

    @objc private func styleChanged(_ sender: Any?) {
        guard let id = selectedId else { return }
        name.stringValue = list[id]["name"]?.string ?? ""
        englishName.stringValue = list[id]["englishName"]?.string ?? ""
        next.selectItem(at: Int(list[id]["nextStyleId"]?.number ?? Double(id)))
    }

    private func detail(_ key: String) -> JSONValue {
        guard let id = selectedId else { return .null }
        return (try? engine.query(.styleDetail(id)))?[key] ?? .null
    }

    @objc private func editCharacter(_ sender: Any?) {
        guard let window, let id = selectedId else { return NSSound.beep() }
        CharacterShapeSheet.present(detail("charProps"), in: window) { [weak self] props in
            self?.apply(.updateStyle(id: id, props: [:], charProps: props, paraProps: [:]))
            self?.reload(select: id)
        }
    }

    @objc private func editParagraph(_ sender: Any?) {
        guard let window, let id = selectedId else { return NSSound.beep() }
        ParagraphShapeSheet.present(detail("paraProps"), in: window) { [weak self] props in
            self?.apply(.updateStyle(id: id, props: [:], charProps: [:], paraProps: props))
            self?.reload(select: id)
        }
    }

    @objc private func rename(_ sender: Any?) {
        guard let id = selectedId else { return NSSound.beep() }
        let text = name.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return NSSound.beep() }
        apply(.updateStyle(id: id, props: [
            "name": .string(text), "englishName": .string(englishName.stringValue),
            "nextStyleId": .number(Double(max(next.indexOfSelectedItem, 0))),
        ], charProps: [:], paraProps: [:]))
        reload(select: id)
        status.stringValue = "\"\(text)\" 스타일을 고쳤습니다."
    }

    /// 새 스타일: named by the user, starting from the selected style's 모양.
    @objc private func add(_ sender: Any?) {
        guard let window, let id = selectedId else { return NSSound.beep() }
        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        let alert = NSAlert()
        alert.messageText = "새 스타일"
        alert.informativeText = "\"\(list[id]["name"]?.string ?? "")\"의 모양으로 시작합니다."
        alert.accessoryView = field
        alert.addButton(withTitle: "추가")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard response == .alertFirstButtonReturn, !text.isEmpty, let self else { return }
            self.apply(.createStyle(name: text, basedOn: id))
            self.reload(select: self.list.count)
            self.status.stringValue = "\"\(text)\" 스타일을 추가했습니다."
        }
    }

    @objc private func remove(_ sender: Any?) {
        guard let window, let id = selectedId, id > 0 else { return NSSound.beep() }
        let alert = NSAlert()
        alert.messageText = "\"\(list[id]["name"]?.string ?? "")\" 스타일을 지울까요?"
        alert.informativeText = "이 스타일을 쓰던 문단은 바탕글이 됩니다."
        alert.addButton(withTitle: "지우기")
        alert.addButton(withTitle: "취소")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.apply(.deleteStyle(id))
            self.reload(select: id - 1)
        }
    }

    @objc private func close(_ sender: Any?) {
        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
