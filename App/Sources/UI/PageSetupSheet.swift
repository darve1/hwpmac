// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 편집 용지: paper size, orientation and margins of the caret's section, in
/// millimetres. rhwp keeps the portrait size with a landscape flag; the sheet
/// shows the size as laid out, like the web editor's dialog.
@MainActor
final class PageSetupSheet: NSObject {
    /// Paper presets in HWPUNIT (1/7200 inch), portrait, from rhwp-studio.
    static let presets: [(name: String, width: Double, height: Double)] = [
        ("A4", 59528, 84188), ("A3", 84188, 119055), ("B4", 72850, 103040),
        ("B5", 51502, 72850), ("Letter", 62208, 80496), ("Legal", 62208, 102816),
    ]
    static let unitsPerMillimetre = 7200 / 25.4

    private static let marginKeys: [(key: String, label: String)] = [
        ("marginTop", "위쪽"), ("marginBottom", "아래쪽"), ("marginLeft", "왼쪽"), ("marginRight", "오른쪽"),
        ("marginHeader", "머리말"), ("marginFooter", "꼬리말"), ("marginGutter", "제본"),
    ]

    private let paper = NSPopUpButton()
    private let orientation = NSSegmentedControl(labels: ["세로", "가로"], trackingMode: .selectOne, target: nil, action: nil)
    private let widthField = PageSetupSheet.millimetreField()
    private let heightField = PageSetupSheet.millimetreField()
    private var marginFields: [String: NSTextField] = [:]
    private let original: JSONValue
    private let apply: ([String: JSONValue]) -> Void
    private var window: NSWindow?

    private init(_ current: JSONValue, apply: @escaping ([String: JSONValue]) -> Void) {
        original = current
        self.apply = apply
        super.init()
    }

    /// Shows the sheet; `apply` gets the changed PageDef keys on OK.
    static func present(_ current: JSONValue, in parent: NSWindow, apply: @escaping ([String: JSONValue]) -> Void) {
        let sheet = PageSetupSheet(current, apply: apply)
        let window = sheet.makeWindow()
        sheet.window = window
        // The sheet keeps itself alive until it ends.
        parent.beginSheet(window) { _ in _ = sheet }
    }

    private static func millimetreField() -> NSTextField {
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

    private func millimetres(_ key: String) -> Double {
        (original[key]?.number ?? 0) / Self.unitsPerMillimetre
    }

    private func makeWindow() -> NSWindow {
        let landscape = original["landscape"]?.bool ?? false
        let (portraitWidth, portraitHeight) = (millimetres("width"), millimetres("height"))
        widthField.doubleValue = landscape ? portraitHeight : portraitWidth
        heightField.doubleValue = landscape ? portraitWidth : portraitHeight
        orientation.selectedSegment = landscape ? 1 : 0
        orientation.target = self
        orientation.action = #selector(orientationChanged(_:))

        paper.addItems(withTitles: Self.presets.map(\.name) + ["사용자 정의"])
        let width = original["width"]?.number ?? 0, height = original["height"]?.number ?? 0
        let preset = Self.presets.firstIndex { abs($0.width - width) < 30 && abs($0.height - height) < 30 }
        paper.selectItem(at: preset ?? Self.presets.count)
        paper.target = self
        paper.action = #selector(paperChanged(_:))

        var rows: [[NSView]] = [
            [label("용지 종류"), paper],
            [label("용지 방향"), orientation],
            [label("폭 (mm)"), widthField],
            [label("길이 (mm)"), heightField],
        ]
        for (key, title) in Self.marginKeys {
            let field = Self.millimetreField()
            field.doubleValue = millimetres(key)
            marginFields[key] = field
            rows.append([label("\(title) 여백 (mm)"), field])
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.column(at: 0).xPlacement = .trailing

        let ok = NSButton(title: "설정", target: self, action: #selector(confirm(_:)))
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: "취소", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, ok])
        let stack = NSStackView(views: [grid, buttons])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.title = "편집 용지"
        window.contentView = stack
        return window
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }

    @objc private func paperChanged(_ sender: Any?) {
        guard paper.indexOfSelectedItem < Self.presets.count else { return }
        let preset = Self.presets[paper.indexOfSelectedItem]
        let (width, height) = (preset.width / Self.unitsPerMillimetre, preset.height / Self.unitsPerMillimetre)
        let landscape = orientation.selectedSegment == 1
        widthField.doubleValue = landscape ? height : width
        heightField.doubleValue = landscape ? width : height
    }

    @objc private func orientationChanged(_ sender: Any?) {
        // Turning the paper swaps the laid-out width and height.
        let width = widthField.doubleValue
        let height = heightField.doubleValue
        let landscape = orientation.selectedSegment == 1
        if (landscape && width < height) || (!landscape && width > height) {
            widthField.doubleValue = height
            heightField.doubleValue = width
        }
    }

    @objc private func confirm(_ sender: Any?) {
        let landscape = orientation.selectedSegment == 1
        let units = { (millimetres: Double) in JSONValue.number((millimetres * Self.unitsPerMillimetre).rounded()) }
        var (width, height) = (widthField.doubleValue, heightField.doubleValue)
        guard width >= 10, height >= 10 else { return NSSound.beep() }
        // PageDef stores the portrait size.
        if landscape { swap(&width, &height) }
        var props: [String: JSONValue] = ["width": units(width), "height": units(height), "landscape": .bool(landscape)]
        for (key, field) in marginFields { props[key] = units(field.doubleValue) }
        end()
        apply(props)
    }

    @objc private func cancel(_ sender: Any?) { end() }

    private func end() {
        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
