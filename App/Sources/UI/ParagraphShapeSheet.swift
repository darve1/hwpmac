// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// rhwp's paragraph property units. Queries report margins, indent, spacing
/// and non-percent line spacing in layout pixels (96 dpi). The setter takes
/// margins, indent and non-percent line spacing at the stored ParaShape scale,
/// doubled HWPUNIT (1 pt = 200), and the space before/after a paragraph in
/// HWPUNIT (1 pt = 100). These are the scales the query converts back from.
enum ParagraphUnits {
    static func points(fromPixels pixels: Double) -> Double { pixels * 72 / 96 }
    static func marginValue(points: Double) -> Double { (points * 200).rounded() }
    static func lineSpacingValue(points: Double) -> Double { (points * 200).rounded() }
    static func spacingValue(points: Double) -> Double { (points * 100).rounded() }
}

/// Setter properties from queried ones, for 모양 복사: the same values in the
/// keys and units the engine takes.
enum FormatCopy {
    private static let charKeys = ["bold", "italic", "underline", "strikethrough", "superscript", "subscript",
                                   "emboss", "engrave", "outlineType", "fontSize", "textColor", "shadeColor",
                                   "ratios", "spacings"]

    static func character(from props: JSONValue) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for key in charKeys { if let value = props[key] { result[key] = value } }
        if let family = props["fontFamily"]?.string, !family.isEmpty { result["fontName"] = .string(family) }
        return result
    }

    static func paragraph(from props: JSONValue) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        let points = { (key: String) in props[key]?.number.map(ParagraphUnits.points(fromPixels:)) }
        if let alignment = props["alignment"] { result["alignment"] = alignment }
        for key in ["marginLeft", "marginRight", "indent"] {
            if let value = points(key) { result[key] = .number(ParagraphUnits.marginValue(points: value)) }
        }
        for key in ["spacingBefore", "spacingAfter"] {
            if let value = points(key) { result[key] = .number(ParagraphUnits.spacingValue(points: value)) }
        }
        if let type = props["lineSpacingType"]?.string, let spacing = props["lineSpacing"]?.number {
            result["lineSpacingType"] = .string(type)
            result["lineSpacing"] = .number(type == "Percent" ? spacing
                : ParagraphUnits.lineSpacingValue(points: ParagraphUnits.points(fromPixels: spacing)))
        }
        return result
    }
}

/// 문단 모양: alignment, margins, first-line indent, line spacing and the
/// space before and after the selected paragraphs, in points.
@MainActor
final class ParagraphShapeSheet: NSObject {
    private static let alignments: [(key: String, title: String)] = [
        ("justify", "양쪽"), ("left", "왼쪽"), ("right", "오른쪽"), ("center", "가운데"),
        ("distribute", "배분"), ("split", "나눔"),
    ]
    /// rhwp's line spacing types; the first is a percentage, the others points.
    private static let spacingTypes: [(key: String, title: String)] = [
        ("Percent", "글자에 따라 (%)"), ("Fixed", "고정 값 (pt)"), ("SpaceOnly", "여백만 지정 (pt)"),
        ("Minimum", "최소 (pt)"),
    ]
    private static let firstLines = ["보통", "들여쓰기", "내어쓰기"]

    private let alignment = NSPopUpButton()
    private let marginLeft = ParagraphShapeSheet.pointField()
    private let marginRight = ParagraphShapeSheet.pointField()
    private let firstLine = NSPopUpButton()
    private let indent = ParagraphShapeSheet.pointField()
    private let spacingType = NSPopUpButton()
    private let spacing = ParagraphShapeSheet.pointField()
    private let spacingBefore = ParagraphShapeSheet.pointField()
    private let spacingAfter = ParagraphShapeSheet.pointField()
    private let apply: ([String: JSONValue]) -> Void
    private var window: NSWindow?

    private init(apply: @escaping ([String: JSONValue]) -> Void) {
        self.apply = apply
        super.init()
    }

    static func present(_ current: JSONValue, in parent: NSWindow, apply: @escaping ([String: JSONValue]) -> Void) {
        let sheet = ParagraphShapeSheet(apply: apply)
        let window = sheet.makeWindow(current)
        sheet.window = window
        parent.beginSheet(window) { _ in _ = sheet }
    }

    private static func pointField() -> NSTextField {
        let field = NSTextField(string: "")
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.minimum = 0
        formatter.maximum = 1000
        field.formatter = formatter
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 70).isActive = true
        return field
    }

    private func makeWindow(_ current: JSONValue) -> NSWindow {
        let points = { (key: String) in ParagraphUnits.points(fromPixels: current[key]?.number ?? 0) }
        alignment.addItems(withTitles: Self.alignments.map(\.title))
        alignment.selectItem(at: Self.alignments.firstIndex { $0.key == current["alignment"]?.string } ?? 0)
        marginLeft.doubleValue = points("marginLeft")
        marginRight.doubleValue = points("marginRight")
        let indentPoints = points("indent")
        firstLine.addItems(withTitles: Self.firstLines)
        firstLine.selectItem(at: indentPoints > 0 ? 1 : indentPoints < 0 ? 2 : 0)
        indent.doubleValue = abs(indentPoints)
        spacingType.addItems(withTitles: Self.spacingTypes.map(\.title))
        let type = Self.spacingTypes.firstIndex { $0.key == current["lineSpacingType"]?.string } ?? 0
        spacingType.selectItem(at: type)
        let lineSpacing = current["lineSpacing"]?.number ?? 160
        // Percent comes back as is, the other types in pixels.
        spacing.doubleValue = type == 0 ? lineSpacing : ParagraphUnits.points(fromPixels: lineSpacing)
        spacingBefore.doubleValue = points("spacingBefore")
        spacingAfter.doubleValue = points("spacingAfter")

        let rows: [[NSView]] = [
            [label("정렬"), alignment],
            [label("왼쪽 여백 (pt)"), marginLeft],
            [label("오른쪽 여백 (pt)"), marginRight],
            [label("첫 줄"), NSStackView(views: [firstLine, indent, label("pt")])],
            [label("줄 간격"), NSStackView(views: [spacingType, spacing])],
            [label("문단 위 (pt)"), spacingBefore],
            [label("문단 아래 (pt)"), spacingAfter],
        ]
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.column(at: 0).xPlacement = .trailing

        let ok = NSButton(title: "설정", target: self, action: #selector(confirm(_:)))
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: "취소", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let stack = NSStackView(views: [grid, NSStackView(views: [cancel, ok])])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.title = "문단 모양"
        window.contentView = stack
        return window
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }

    /// The paragraph property keys the engine takes, from the fields.
    func properties() -> [String: JSONValue] {
        let type = spacingType.indexOfSelectedItem
        var indentPoints = indent.doubleValue
        switch firstLine.indexOfSelectedItem {
        case 0: indentPoints = 0
        case 2: indentPoints = -indentPoints
        default: break
        }
        let lineSpacing = type == 0 ? min(max(spacing.doubleValue, 5), 500).rounded()
            : ParagraphUnits.lineSpacingValue(points: spacing.doubleValue)
        return [
            "alignment": .string(Self.alignments[alignment.indexOfSelectedItem].key),
            "marginLeft": .number(ParagraphUnits.marginValue(points: marginLeft.doubleValue)),
            "marginRight": .number(ParagraphUnits.marginValue(points: marginRight.doubleValue)),
            "indent": .number(ParagraphUnits.marginValue(points: indentPoints)),
            "lineSpacingType": .string(Self.spacingTypes[type].key),
            "lineSpacing": .number(lineSpacing),
            "spacingBefore": .number(ParagraphUnits.spacingValue(points: spacingBefore.doubleValue)),
            "spacingAfter": .number(ParagraphUnits.spacingValue(points: spacingAfter.doubleValue)),
        ]
    }

    @objc private func confirm(_ sender: Any?) {
        let props = properties()
        end()
        apply(props)
    }

    @objc private func cancel(_ sender: Any?) { end() }

    private func end() {
        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
