// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 셀 속성: background, vertical alignment, inner margins and borders of the
/// caret's cell. Only changed values are sent, so the rest of the cell keeps
/// what the document had.
@MainActor
final class CellPropertiesSheet: NSObject {
    private let fill = NSButton(checkboxWithTitle: "배경색", target: nil, action: nil)
    private let fillColor = NSColorWell()
    private let alignment = NSPopUpButton()
    private let paddings: [(key: String, label: String, field: NSTextField)] = [
        ("paddingLeft", "왼쪽", NSTextField()), ("paddingRight", "오른쪽", NSTextField()),
        ("paddingTop", "위쪽", NSTextField()), ("paddingBottom", "아래쪽", NSTextField()),
    ]
    private let borders = NSPopUpButton()
    private let original: JSONValue
    private let apply: ([String: JSONValue]) -> Void
    private var window: NSWindow?

    private init(_ current: JSONValue, apply: @escaping ([String: JSONValue]) -> Void) {
        original = current
        self.apply = apply
        super.init()
    }

    static func present(_ current: JSONValue, in parent: NSWindow, apply: @escaping ([String: JSONValue]) -> Void) {
        let sheet = CellPropertiesSheet(current, apply: apply)
        let window = sheet.makeWindow()
        sheet.window = window
        parent.beginSheet(window) { _ in _ = sheet }
    }

    /// Border edits: all four sides solid black, or none.
    static func borders(solid: Bool) -> [String: JSONValue] {
        let side: JSONValue = .object(["type": .number(solid ? 1 : 0), "width": .number(1), "color": .string("#000000")])
        return Dictionary(uniqueKeysWithValues: ["borderLeft", "borderRight", "borderTop", "borderBottom"].map { ($0, side) })
    }

    private func makeWindow() -> NSWindow {
        fill.state = original["fillType"]?.string == "solid" ? .on : .off
        fillColor.color = CharacterShapeSheet.color(original["fillColor"]?.string) ?? .white
        alignment.addItems(withTitles: ["위", "가운데", "아래"])
        alignment.selectItem(at: Int(original["verticalAlign"]?.number ?? 0))
        borders.addItems(withTitles: ["그대로", "모두 실선", "모두 없음"])
        var rows: [[NSView]] = [
            [NSTextField(labelWithString: "배경"), NSStackView(views: [fill, fillColor])],
            [NSTextField(labelWithString: "세로 정렬"), alignment],
        ]
        for padding in paddings {
            padding.field.doubleValue = ((original[padding.key]?.number ?? 0) / PageSetupSheet.unitsPerMillimetre * 10).rounded() / 10
            padding.field.widthAnchor.constraint(equalToConstant: 60).isActive = true
            rows.append([NSTextField(labelWithString: "\(padding.label) 안 여백 (mm)"), padding.field])
        }
        rows.append([NSTextField(labelWithString: "테두리"), borders])
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.column(at: 0).xPlacement = .trailing
        fillColor.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let ok = NSButton(title: "설정", target: self, action: #selector(confirm(_:)))
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: "취소", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let stack = NSStackView(views: [grid, NSStackView(views: [cancel, ok])])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.title = "셀 속성"
        window.contentView = stack
        return window
    }

    func changedProperties() -> [String: JSONValue] {
        var props: [String: JSONValue] = [:]
        let wasFilled = original["fillType"]?.string == "solid"
        let color = CharacterShapeSheet.hex(fillColor.color)
        if fill.state == .on, !wasFilled || color != original["fillColor"]?.string?.lowercased() {
            props["fillType"] = .string("solid")
            props["fillColor"] = .string(color)
        } else if fill.state == .off, wasFilled {
            props["fillType"] = .string("none")
        }
        if alignment.indexOfSelectedItem != Int(original["verticalAlign"]?.number ?? 0) {
            props["verticalAlign"] = .number(Double(alignment.indexOfSelectedItem))
        }
        for padding in paddings {
            let units = (padding.field.doubleValue * PageSetupSheet.unitsPerMillimetre).rounded()
            if abs(units - (original[padding.key]?.number ?? 0)) > 14 { props[padding.key] = .number(units) }
        }
        switch borders.indexOfSelectedItem {
        case 1: props.merge(Self.borders(solid: true)) { $1 }
        case 2: props.merge(Self.borders(solid: false)) { $1 }
        default: break
        }
        return props
    }

    @objc private func confirm(_ sender: Any?) {
        let props = changedProperties()
        end()
        if !props.isEmpty { apply(props) }
    }

    @objc private func cancel(_ sender: Any?) { end() }

    private func end() {
        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
