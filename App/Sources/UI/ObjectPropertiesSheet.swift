// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 개체 속성 of a picture or shape: size, rotation and caption, plus line and
/// fill for shapes. Only changed values are sent, so the rest of the object
/// keeps what the document had.
@MainActor
final class ObjectPropertiesSheet: NSObject {
    private let width = NSTextField()
    private let height = NSTextField()
    private let keepRatio = NSButton(checkboxWithTitle: "가로세로 비율 유지", target: nil, action: nil)
    private let rotation = NSTextField()
    private let caption = NSButton(checkboxWithTitle: "캡션", target: nil, action: nil)
    private let lineColor = NSColorWell()
    private let lineWidth = NSTextField()
    private let fill = NSButton(checkboxWithTitle: "채우기", target: nil, action: nil)
    private let fillColor = NSColorWell()
    private let original: JSONValue
    private let apply: ([String: JSONValue]) -> Void
    private var window: NSWindow?

    private var isShape: Bool { original["kind"]?.string == "shape" }

    init(_ current: JSONValue, apply: @escaping ([String: JSONValue]) -> Void) {
        original = current
        self.apply = apply
        super.init()
        let millimetres = { (units: Double?) in ((units ?? 0) / PageSetupSheet.unitsPerMillimetre * 10).rounded() / 10 }
        width.doubleValue = millimetres(current["width"]?.number)
        height.doubleValue = millimetres(current["height"]?.number)
        keepRatio.state = .on
        rotation.doubleValue = current["rotationAngle"]?.number ?? 0
        caption.state = current["hasCaption"]?.bool == true ? .on : .off
        lineColor.color = Self.color(colorRef: current["borderColor"]?.number ?? 0)
        lineWidth.doubleValue = ((current["borderWidth"]?.number ?? 0) / PageSetupSheet.unitsPerMillimetre * 100).rounded() / 100
        fill.state = current["fillType"]?.string == "solid" ? .on : .off
        fillColor.color = Self.color(colorRef: current["fillBgColor"]?.number ?? 0xFFFFFF)
    }

    static func present(_ current: JSONValue, in parent: NSWindow, apply: @escaping ([String: JSONValue]) -> Void) {
        let sheet = ObjectPropertiesSheet(current, apply: apply)
        let window = sheet.makeWindow()
        sheet.window = window
        parent.beginSheet(window) { _ in _ = sheet }
    }

    /// HWP colours are COLORREF: 0x00BBGGRR.
    static func color(colorRef: Double) -> NSColor {
        let value = Int(colorRef)
        return NSColor(srgbRed: CGFloat(value & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat((value >> 16) & 0xFF) / 255, alpha: 1)
    }

    static func colorRef(_ color: NSColor) -> Double {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
        return Double(channel(rgb.redComponent) | channel(rgb.greenComponent) << 8 | channel(rgb.blueComponent) << 16)
    }

    private func makeWindow() -> NSWindow {
        for field in [width, height, rotation, lineWidth] { field.widthAnchor.constraint(equalToConstant: 70).isActive = true }
        for well in [lineColor, fillColor] { well.widthAnchor.constraint(equalToConstant: 44).isActive = true }
        var rows: [[NSView]] = [
            [NSTextField(labelWithString: "너비 (mm)"), width],
            [NSTextField(labelWithString: "높이 (mm)"), height],
            [NSView(), keepRatio],
            [NSTextField(labelWithString: "회전 (°)"), rotation],
        ]
        if isShape {
            rows.append([NSTextField(labelWithString: "선"), NSStackView(views: [lineColor, lineWidth, NSTextField(labelWithString: "mm")])])
            rows.append([NSTextField(labelWithString: "면"), NSStackView(views: [fill, fillColor])])
        }
        rows.append([NSView(), caption])
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
        window.title = "개체 속성"
        window.contentView = stack
        return window
    }

    /// The values that differ from the object's; nil when a size is not positive.
    func changedProperties() -> [String: JSONValue]? {
        var props: [String: JSONValue] = [:]
        let original = (self.original["width"]?.number ?? 0, self.original["height"]?.number ?? 0)
        var newWidth = width.doubleValue * PageSetupSheet.unitsPerMillimetre
        var newHeight = height.doubleValue * PageSetupSheet.unitsPerMillimetre
        let widthChanged = abs(newWidth - original.0) > 14
        let heightChanged = abs(newHeight - original.1) > 14
        if keepRatio.state == .on, original.0 > 0, original.1 > 0, widthChanged != heightChanged {
            // The field the user changed decides; the other follows.
            if widthChanged { newHeight = newWidth * original.1 / original.0 } else { newWidth = newHeight * original.0 / original.1 }
        }
        if widthChanged || heightChanged {
            // A straight line may be 0 high; anything else needs a size.
            guard newWidth >= 1, newHeight >= 1 || original.1 < 1 else { return nil }
            props["width"] = .number(newWidth.rounded())
            props["height"] = .number(newHeight.rounded())
        }
        var angle = rotation.doubleValue.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        if angle.rounded() != (self.original["rotationAngle"]?.number ?? 0) { props["rotationAngle"] = .number(angle.rounded()) }
        if isShape {
            let line = Self.colorRef(lineColor.color)
            if line != self.original["borderColor"]?.number { props["borderColor"] = .number(line) }
            let units = (lineWidth.doubleValue * PageSetupSheet.unitsPerMillimetre).rounded()
            // The field shows 0.01 mm; a smaller difference is rounding, not an edit.
            if abs(units - (self.original["borderWidth"]?.number ?? 0)) > 0.005 * PageSetupSheet.unitsPerMillimetre {
                props["borderWidth"] = .number(units)
            }
            let wasFilled = self.original["fillType"]?.string == "solid"
            let color = Self.colorRef(fillColor.color)
            if fill.state == .on, !wasFilled || color != self.original["fillBgColor"]?.number {
                props["fillType"] = .string("solid")
                props["fillBgColor"] = .number(color)
            } else if fill.state == .off, wasFilled {
                props["fillType"] = .string("none")
            }
        }
        if (caption.state == .on) != (self.original["hasCaption"]?.bool == true) {
            props.merge(Self.caption(caption.state == .on)) { $1 }
        }
        return props
    }

    /// 캡션 넣기 as the web editor does it: below, 30 mm wide, 3 mm away.
    static func caption(_ on: Bool) -> [String: JSONValue] {
        guard on else { return ["hasCaption": .bool(false)] }
        let millimetre = PageSetupSheet.unitsPerMillimetre
        return ["hasCaption": .bool(true), "captionDirection": .string("Bottom"), "captionVertAlign": .string("Top"),
                "captionWidth": .number((30 * millimetre).rounded()), "captionSpacing": .number((3 * millimetre).rounded()),
                "captionIncludeMargin": .bool(false)]
    }

    @objc private func confirm(_ sender: Any?) {
        guard let props = changedProperties() else { return NSSound.beep() }
        end()
        if !props.isEmpty { apply(props) }
    }

    @objc private func cancel(_ sender: Any?) { end() }

    private func end() {
        guard let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
