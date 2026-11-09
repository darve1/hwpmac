// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 글자 모양: font, size, width ratio, letter spacing, colours and attributes
/// of the selected text. Ratio and spacing apply to all seven language groups,
/// as the web editor's toolbar does.
@MainActor
final class CharacterShapeSheet: NSObject {
    private static let attributes: [(key: String, title: String)] = [
        ("bold", "진하게"), ("italic", "기울임"), ("underline", "밑줄"), ("strikethrough", "취소선"),
        ("superscript", "위 첨자"), ("subscript", "아래 첨자"), ("emboss", "양각"), ("engrave", "음각"),
    ]

    private let font = NSComboBox()
    private let size = CharacterShapeSheet.numberField(minimum: 1, maximum: 4096, fraction: 1)
    private let ratio = CharacterShapeSheet.numberField(minimum: 50, maximum: 200, fraction: 0)
    private let spacing = CharacterShapeSheet.numberField(minimum: -50, maximum: 50, fraction: 0)
    private let textColor = NSColorWell()
    private let shadeColor = NSColorWell()
    private var checkboxes: [String: NSButton] = [:]
    private let original: JSONValue
    private let apply: ([String: JSONValue]) -> Void
    private var window: NSWindow?

    private init(_ current: JSONValue, apply: @escaping ([String: JSONValue]) -> Void) {
        original = current
        self.apply = apply
        super.init()
    }

    static func present(_ current: JSONValue, in parent: NSWindow, apply: @escaping ([String: JSONValue]) -> Void) {
        let sheet = CharacterShapeSheet(current, apply: apply)
        let window = sheet.makeWindow()
        sheet.window = window
        parent.beginSheet(window) { _ in _ = sheet }
    }

    private static func numberField(minimum: Double, maximum: Double, fraction: Int) -> NSTextField {
        let field = NSTextField(string: "")
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = fraction
        formatter.maximumFractionDigits = fraction
        formatter.minimum = NSNumber(value: minimum)
        formatter.maximum = NSNumber(value: maximum)
        field.formatter = formatter
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 70).isActive = true
        return field
    }

    static func color(_ hex: String?) -> NSColor? {
        guard let hex, hex.hasPrefix("#"), hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    static func hex(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
        return String(format: "#%02x%02x%02x", channel(rgb.redComponent), channel(rgb.greenComponent),
                      channel(rgb.blueComponent))
    }

    private static func first(_ value: JSONValue?) -> Double? {
        if case let .array(values)? = value { return values.first?.number }
        return nil
    }

    private func makeWindow() -> NSWindow {
        font.addItems(withObjectValues: NSFontManager.shared.availableFontFamilies)
        font.completes = true
        font.stringValue = original["fontFamily"]?.string ?? ""
        font.widthAnchor.constraint(equalToConstant: 220).isActive = true
        size.doubleValue = (original["fontSize"]?.number ?? 1000) / 100
        ratio.doubleValue = Self.first(original["ratios"]) ?? 100
        spacing.doubleValue = Self.first(original["spacings"]) ?? 0
        textColor.color = Self.color(original["textColor"]?.string) ?? .black
        shadeColor.color = Self.color(original["shadeColor"]?.string) ?? .white

        var rows: [[NSView]] = [
            [label("글꼴"), font],
            [label("크기 (pt)"), size],
            [label("장평 (%)"), ratio],
            [label("자간 (%)"), spacing],
            [label("글자 색"), textColor],
            [label("음영 색"), shadeColor],
        ]
        let boxes = Self.attributes.map { attribute -> NSButton in
            let box = NSButton(checkboxWithTitle: attribute.title, target: nil, action: nil)
            box.state = original[attribute.key]?.bool == true ? .on : .off
            checkboxes[attribute.key] = box
            return box
        }
        let firstRow = NSStackView(views: Array(boxes.prefix(4)))
        let secondRow = NSStackView(views: Array(boxes.suffix(4)))
        let attributeStack = NSStackView(views: [firstRow, secondRow])
        attributeStack.orientation = .vertical
        attributeStack.alignment = .leading
        rows.append([label("속성"), attributeStack])
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.column(at: 0).xPlacement = .trailing
        for row in 4...5 {
            grid.cell(atColumnIndex: 1, rowIndex: row).contentView?.widthAnchor.constraint(equalToConstant: 44).isActive = true
        }

        let ok = NSButton(title: "설정", target: self, action: #selector(confirm(_:)))
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: "취소", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let stack = NSStackView(views: [grid, NSStackView(views: [cancel, ok])])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.title = "글자 모양"
        window.contentView = stack
        return window
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }

    /// Only the properties the user changed, so mixed selections keep the rest.
    func changedProperties() -> [String: JSONValue] {
        var props: [String: JSONValue] = [:]
        let family = font.stringValue.trimmingCharacters(in: .whitespaces)
        if !family.isEmpty, family != original["fontFamily"]?.string { props["fontName"] = .string(family) }
        let fontSize = (size.doubleValue * 100).rounded()
        if fontSize != original["fontSize"]?.number { props["fontSize"] = .number(fontSize) }
        let ratioValue = ratio.doubleValue.rounded()
        if ratioValue != Self.first(original["ratios"]) {
            props["ratios"] = .array(Array(repeating: .number(ratioValue), count: 7))
        }
        let spacingValue = spacing.doubleValue.rounded()
        if spacingValue != Self.first(original["spacings"]) {
            props["spacings"] = .array(Array(repeating: .number(spacingValue), count: 7))
        }
        let text = Self.hex(textColor.color)
        if text != original["textColor"]?.string?.lowercased() { props["textColor"] = .string(text) }
        let shade = Self.hex(shadeColor.color)
        if shade != original["shadeColor"]?.string?.lowercased() { props["shadeColor"] = .string(shade) }
        for (key, box) in checkboxes where (box.state == .on) != (original[key]?.bool == true) {
            props[key] = .bool(box.state == .on)
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
