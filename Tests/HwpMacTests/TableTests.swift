// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import Rhwp
import XCTest
@testable import HwpMac

/// Tables through PagesView: inserting one, typing into cells, Tab between
/// cells, row/column edits, and the result after a save and reopen.
@MainActor
final class TableTests: XCTestCase {
    private var engine: DocumentEngine!
    private var view: PagesView!

    override func setUp() async throws {
        engine = try DocumentEngine(data: Data(), name: "test engine")
        view = PagesView(engine: engine)
        view.beginEditingAtStart()
        settle()
    }

    override func tearDown() async throws {
        engine.close()
    }

    private func settle() {
        _ = try? engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    private func insert(_ text: String) {
        view.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        settle()
    }

    private func tab(backward: Bool = false) {
        view.doCommand(by: backward ? #selector(NSResponder.insertBacktab(_:)) : #selector(NSResponder.insertTab(_:)))
        settle()
    }

    private var focus: TextPosition { get throws { try XCTUnwrap(engine.sync { $0.selection?.focus }) } }

    /// The text rhwp reads from the document saved as `format`, cells included.
    private func savedText(_ format: SaveFormat, of engine: DocumentEngine? = nil) throws -> String {
        let engine = engine ?? self.engine!
        let prepared = try engine.prepareSave(format)
        try engine.cancelSave(prepared.token)
        XCTAssertEqual(prepared.report?.losses.count ?? 0, 0, "\(format)")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(format.rawValue)
        try prepared.data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try Rhwp.readText(inputFile: url).text
    }

    /// Inserts a table through the engine (the menu item asks for its size).
    private func insertTable(rows: Int, columns: Int) {
        _ = engine.submit(.action(.insertTable(rows: rows, columns: columns)))
        settle()
    }

    func testTypingIntoCellsWithTab() throws {
        insertTable(rows: 2, columns: 2)
        XCTAssertEqual(try focus.cellPath.first?.cell, 0)
        insert("이름")
        tab()
        insert("홍길동")
        XCTAssertEqual(try focus.cellPath.first?.cell, 1)
        tab(backward: true)
        XCTAssertEqual(try focus.cellPath.first?.cell, 0)
        let text = try savedText(.hwpx)
        XCTAssertTrue(text.contains("이름"), text)
        XCTAssertTrue(text.contains("홍길동"), text)
    }

    func testTabInLastCellAddsRow() throws {
        insertTable(rows: 1, columns: 2)
        tab()
        tab()
        XCTAssertEqual(try focus.cellPath.first?.cell, 2)
    }

    func testTableMenuItemsNeedCaretInCell() throws {
        let item = NSMenuItem(title: "줄 지우기", action: #selector(PagesView.deleteRow(_:)), keyEquivalent: "")
        XCTAssertFalse(view.validateMenuItem(item))
        insertTable(rows: 2, columns: 2)
        XCTAssertTrue(view.validateMenuItem(item))
        let create = NSMenuItem(title: "표 만들기", action: #selector(PagesView.insertTable(_:)), keyEquivalent: "")
        XCTAssertFalse(view.validateMenuItem(create))
    }

    func testFormattingInCell() throws {
        insertTable(rows: 1, columns: 1)
        insert("굵게")
        view.selectAll(nil)
        settle()
        view.toggleBold(nil)
        settle()
        XCTAssertEqual(try engine.sync { try $0.query(.charProperties) }["bold"]?.bool, true)
    }

    func testFindReachesCellText() throws {
        insertTable(rows: 1, columns: 2)
        tab()
        insert("찾을 말")
        view.beginEditingAtStart()
        settle()
        view.find("찾을", forward: true, caseSensitive: false)
        settle()
        XCTAssertEqual(try focus.cellPath.first?.cell, 1)
        XCTAssertEqual(view.selectedRange(), NSRange(location: 0, length: 2))
    }

    func testSplitTableAndInsertSeveralRows() throws {
        insertTable(rows: 3, columns: 2)
        _ = engine.submit(.action(.insertRow(below: true, count: 2)))
        settle()
        tab()
        tab()
        // Row 1 now: split there, the caret moves into the new table below.
        let before = try focus.paragraph
        _ = engine.submit(.action(.splitTable))
        settle()
        XCTAssertEqual(try focus.paragraph, before + 2)
        XCTAssertEqual(try focus.cellPath.first?.cell, 0)
        let split = try savedText(.hwpx)
        XCTAssertFalse(split.isEmpty)
    }

    func testRefusedEditExplainsWhyInKorean() {
        XCTAssertEqual(DocumentEngine.unsupportedMessage("a selection cannot cross a table-cell boundary"),
                       "선택 범위가 표 셀 경계를 넘을 수 없습니다.")
        XCTAssertTrue(DocumentEngine.unsupportedMessage("something else").hasPrefix("이 위치는"))
        XCTAssertEqual(DocumentEngine.argumentMessage("the caret is not in a table"), "캐럿이 표 안에 있지 않습니다.")
        XCTAssertEqual(DocumentEngine.argumentMessage("같은 이름의 책갈피가 이미 등록되어 있습니다."),
                       "같은 이름의 책갈피가 이미 등록되어 있습니다.")
    }

    /// Cell text survives serialization in both formats.
    func testCellTextSurvivesSaveAndReopen() throws {
        insertTable(rows: 2, columns: 2)
        insert("가")
        tab()
        insert("나")
        _ = engine.submit(.action(.insertRow(below: true)))
        settle()
        for format in [SaveFormat.hwp, .hwpx] {
            let prepared = try engine.prepareSave(format)
            try engine.cancelSave(prepared.token)
            let reopened = try DocumentEngine(data: prepared.data, name: "reopened")
            defer { reopened.close() }
            let text = try savedText(.hwpx, of: reopened)
            XCTAssertTrue(text.contains("가") && text.contains("나"), "\(format): \(text)")
        }
    }
}

@MainActor
final class ObjectTests: XCTestCase {
    /// A 4×2 PNG.
    private static let png = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGP4z8DwHxkzoAsAAA8hD/EEN8afAAAAAElFTkSuQmCC")!

    func testInsertPickRotateAndDeletePicture() throws {
        let engine = try DocumentEngine(data: Data(), name: "objects")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("그림 앞", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("picture.png")
        try Self.png.write(to: url)
        try view.insertPicture(from: url)
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let picture = try XCTUnwrap(view.pickableObjects(page: 0).first { $0.kind == "image" })
        // 4 px wide at 75 HWPUNIT per pixel is 300 HWPUNIT, i.e. 4 layout pixels.
        XCTAssertEqual(picture.frame.width, 4, accuracy: 0.5)
        let picked = view.object(atPage: 0, x: picture.frame.midX, y: picture.frame.midY)
        XCTAssertEqual(picked?.address, picture.address)
        view.selectObject(picked)
        view.rotatePictureRight(nil)
        _ = try engine.sync { _ in }
        XCTAssertEqual(try engine.query(.pictureProperties(picture.address))["rotationAngle"]?.number, 90)

        view.doCommand(by: #selector(NSResponder.deleteBackward(_:)))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNil(view.selectedObject)
        XCTAssertFalse(view.pickableObjects(page: 0).contains { $0.kind == "image" })
        XCTAssertEqual(try engine.documentText(), "그림 앞")
    }
}
