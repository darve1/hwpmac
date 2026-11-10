// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// Asks for a number of rows and columns, for 표 만들기 and 셀 나누기.
enum TableSizePrompt {
    static let limit = 256

    @MainActor
    static func ask(title: String, in window: NSWindow, rows: Int = 3, columns: Int = 3) -> (Int, Int)? {
        let rowField = field(rows)
        let columnField = field(columns)
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "줄 개수:"), rowField],
            [NSTextField(labelWithString: "칸 개수:"), columnField],
        ])
        grid.rowSpacing = 8
        grid.frame = NSRect(x: 0, y: 0, width: 200, height: 56)

        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = grid
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = rowField
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let size = (rowField.integerValue, columnField.integerValue)
        guard (1...limit).contains(size.0), (1...limit).contains(size.1) else {
            NSSound.beep()
            return nil
        }
        return size
    }

    @MainActor
    private static func field(_ value: Int) -> NSTextField {
        let field = NSTextField(string: String(value))
        let formatter = NumberFormatter()
        formatter.minimum = 1
        formatter.maximum = NSNumber(value: limit)
        formatter.allowsFloats = false
        field.formatter = formatter
        field.widthAnchor.constraint(equalToConstant: 80).isActive = true
        return field
    }
}
