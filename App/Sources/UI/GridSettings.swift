// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 격자 보기: a guide grid over the pages, starting at the body text corner
/// as the web editor's default does. It only draws; the document is unchanged.
struct GridSettings: Equatable {
    enum Pattern: String, CaseIterable {
        case dots, horizontal, vertical, both

        var title: String {
            switch self {
            case .dots: "점"
            case .horizontal: "가로줄"
            case .vertical: "세로줄"
            case .both: "가로·세로줄"
            }
        }
    }

    var visible = false
    var pattern = Pattern.dots
    /// Spacing in millimetres, 1–100 as in the web editor.
    var horizontalMm = 3.0
    var verticalMm = 3.0

    private static let key = "GridSettings"

    static func load(_ defaults: UserDefaults = .standard) -> GridSettings {
        var settings = GridSettings()
        guard let stored = defaults.dictionary(forKey: key) else { return settings }
        settings.visible = stored["visible"] as? Bool ?? false
        settings.pattern = (stored["pattern"] as? String).flatMap(Pattern.init(rawValue:)) ?? .dots
        settings.horizontalMm = clamp(stored["horizontalMm"] as? Double ?? 3)
        settings.verticalMm = clamp(stored["verticalMm"] as? Double ?? 3)
        return settings
    }

    func save(_ defaults: UserDefaults = .standard) {
        defaults.set(["visible": visible, "pattern": pattern.rawValue, "horizontalMm": horizontalMm,
                      "verticalMm": verticalMm], forKey: Self.key)
    }

    static func clamp(_ millimetres: Double) -> Double { min(max(millimetres.isFinite ? millimetres : 3, 1), 100) }

    /// Grid positions along one axis: every `step` from `origin`, both ways, within `lower…upper`.
    static func positions(origin: Double, step: Double, lower: Double, upper: Double) -> [Double] {
        guard step > 0, upper > lower else { return [] }
        var position = origin - (((origin - lower) / step).rounded(.down)) * step
        var result: [Double] = []
        while position <= upper {
            result.append(position)
            position += step
        }
        return result
    }

    /// Draws the grid over `page` (view coordinates) from `origin` (the body text corner).
    func draw(in page: CGRect, origin: CGPoint, scale: Double) {
        let pixelsPerMm = 96 / 25.4
        let columns = Self.positions(origin: origin.x, step: horizontalMm * pixelsPerMm, lower: page.minX, upper: page.maxX)
        let rows = Self.positions(origin: origin.y, step: verticalMm * pixelsPerMm, lower: page.minY, upper: page.maxY)
        NSGraphicsContext.saveGraphicsState()
        page.clip()
        let hairline = 1 / max(scale, 0.1)
        NSColor.systemBlue.withAlphaComponent(0.35).set()
        switch pattern {
        case .dots:
            let size = 1.5 * hairline
            for x in columns {
                for y in rows { CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size).fill() }
            }
        case .horizontal, .vertical, .both:
            let path = NSBezierPath()
            path.lineWidth = hairline
            if pattern != .vertical {
                for y in rows {
                    path.move(to: CGPoint(x: page.minX, y: y))
                    path.line(to: CGPoint(x: page.maxX, y: y))
                }
            }
            if pattern != .horizontal {
                for x in columns {
                    path.move(to: CGPoint(x: x, y: page.minY))
                    path.line(to: CGPoint(x: x, y: page.maxY))
                }
            }
            path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// 격자 설정: pattern and spacing.
@MainActor
enum GridSettingsSheet {
    static func present(_ current: GridSettings, in window: NSWindow, apply: @escaping (GridSettings) -> Void) {
        let pattern = NSPopUpButton()
        pattern.addItems(withTitles: GridSettings.Pattern.allCases.map(\.title))
        pattern.selectItem(at: GridSettings.Pattern.allCases.firstIndex(of: current.pattern) ?? 0)
        let horizontal = NSTextField(string: String(format: "%g", current.horizontalMm))
        let vertical = NSTextField(string: String(format: "%g", current.verticalMm))
        for field in [horizontal, vertical] { field.widthAnchor.constraint(equalToConstant: 60).isActive = true }
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "모양:"), pattern],
            [NSTextField(labelWithString: "가로 간격 (mm):"), horizontal],
            [NSTextField(labelWithString: "세로 간격 (mm):"), vertical],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.frame = NSRect(x: 0, y: 0, width: 260, height: 90)
        let alert = NSAlert()
        alert.messageText = "격자 설정"
        alert.informativeText = "격자는 화면에만 보이고 문서에는 저장되지 않습니다. 간격은 1~100mm."
        alert.accessoryView = grid
        alert.addButton(withTitle: "설정")
        alert.addButton(withTitle: "취소")
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            var next = current
            next.visible = true
            next.pattern = GridSettings.Pattern.allCases[max(pattern.indexOfSelectedItem, 0)]
            next.horizontalMm = GridSettings.clamp(horizontal.doubleValue)
            next.verticalMm = GridSettings.clamp(vertical.doubleValue)
            apply(next)
        }
    }
}
