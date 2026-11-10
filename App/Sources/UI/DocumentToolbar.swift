// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 도구 상자: the window toolbar. Items send their actions up the responder
/// chain, so they act on the focused document view like the menu items do.
@MainActor
final class DocumentToolbar: NSObject, NSToolbarDelegate {
    struct Item {
        let identifier: NSToolbarItem.Identifier
        let label: String
        let symbol: String
        let action: Selector
    }

    static let basic: [Item] = [
        item("save", "저장", "square.and.arrow.down", #selector(NSDocument.save(_:))),
        item("undo", "실행 취소", "arrow.uturn.backward", #selector(PagesView.undo(_:))),
        item("redo", "실행 복귀", "arrow.uturn.forward", #selector(PagesView.redo(_:))),
        item("find", "찾기", "magnifyingglass", #selector(DocumentWindowController.showFind(_:))),
        item("print", "인쇄", "printer", #selector(NSDocument.printDocument(_:))),
    ]

    static let format: [Item] = [
        item("bold", "굵게", "bold", #selector(PagesView.toggleBold(_:))),
        item("italic", "기울임", "italic", #selector(PagesView.toggleItalic(_:))),
        item("underline", "밑줄", "underline", #selector(PagesView.toggleUnderlineStyle(_:))),
        item("smaller", "글자 작게", "textformat.size.smaller", #selector(PagesView.decreaseFontSize(_:))),
        item("larger", "글자 크게", "textformat.size.larger", #selector(PagesView.increaseFontSize(_:))),
        item("left", "왼쪽 정렬", "text.alignleft", #selector(PagesView.alignLeft(_:))),
        item("center", "가운데 정렬", "text.aligncenter", #selector(PagesView.alignCenter(_:))),
        item("right", "오른쪽 정렬", "text.alignright", #selector(PagesView.alignRight(_:))),
        item("justify", "양쪽 정렬", "text.justify", #selector(PagesView.alignJustified(_:))),
        item("bullets", "글머리표", "list.bullet", #selector(PagesView.toggleBullets(_:))),
        item("numbering", "문단 번호", "list.number", #selector(PagesView.toggleNumbering(_:))),
        item("table", "표 만들기", "tablecells", #selector(PagesView.insertTable(_:))),
        item("picture", "그림", "photo", #selector(PagesView.insertPicture(_:))),
    ]

    private static func item(_ name: String, _ label: String, _ symbol: String, _ action: Selector) -> Item {
        Item(identifier: NSToolbarItem.Identifier("hwpmac." + name), label: label, symbol: symbol, action: action)
    }

    private static let all = basic + format

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "HwpMacDocumentToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        return toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.basic.map(\.identifier) + [.space] + Self.format.map(\.identifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.all.map(\.identifier) + [.space, .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let spec = Self.all.first(where: { $0.identifier == identifier }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = spec.label
        item.paletteLabel = spec.label
        item.toolTip = spec.label
        item.image = NSImage(systemSymbolName: spec.symbol, accessibilityDescription: spec.label)
        item.action = spec.action
        item.autovalidates = true
        return item
    }
}
