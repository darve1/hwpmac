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

    func testEasyFormulaSumsTheCellsAboveAndSurvivesSave() throws {
        insertTable(rows: 3, columns: 1)
        insert("1200")
        view.doCommand(by: #selector(NSResponder.moveDown(_:)))
        settle()
        insert("34")
        view.doCommand(by: #selector(NSResponder.moveDown(_:)))
        settle()
        XCTAssertEqual(try focus.cellPath.first?.cell, 2)
        let sum = NSMenuItem(title: "블록 합계", action: #selector(PagesView.applyEasyFormula(_:)), keyEquivalent: "")
        sum.representedObject = "=SUM(ABOVE)"
        XCTAssertTrue(view.validateMenuItem(sum))
        view.applyEasyFormula(sum)
        settle()
        XCTAssertTrue(try savedText(.hwp).contains("1234"))
        view.addThousandsSeparators(nil)
        settle()
        XCTAssertTrue(try savedText(.hwpx).contains("1,234"))
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
        XCTAssertEqual(try engine.query(.objectProperties(picture.address))["rotationAngle"]?.number, 90)

        view.doCommand(by: #selector(NSResponder.deleteBackward(_:)))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNil(view.selectedObject)
        XCTAssertFalse(view.pickableObjects(page: 0).contains { $0.kind == "image" })
        XCTAssertEqual(try engine.documentText(), "그림 앞")
    }
}

@MainActor
final class ShapeTests: XCTestCase {
    func testInsertShapeAndPickIt() throws {
        let engine = try DocumentEngine(data: Data(), name: "shapes")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("도형", replacementRange: NSRange(location: NSNotFound, length: 0))
        let item = NSMenuItem(title: "타원", action: #selector(PagesView.insertShape(_:)), keyEquivalent: "")
        item.tag = 1
        // The menu command needs the view to know the caret is in body text.
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        view.insertShape(item)
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let shape = try XCTUnwrap(view.pickableObjects(page: 0).first { $0.kind == "shape" })
        // 30 mm is about 113 layout pixels.
        XCTAssertEqual(shape.frame.width, 30 / 25.4 * 96, accuracy: 1)
        view.selectObject(view.object(atPage: 0, x: shape.frame.midX, y: shape.frame.midY))
        XCTAssertEqual(view.selectedObject?.address, shape.address)
        let front = NSMenuItem(title: "맨 앞으로", action: #selector(PagesView.bringObjectToFront(_:)), keyEquivalent: "")
        XCTAssertTrue(view.validateMenuItem(front))
        view.deleteSelectedObject(nil)
        _ = try engine.sync { _ in }
        XCTAssertFalse(view.pickableObjects(page: 0).contains { $0.kind == "shape" })
    }
    func testGroupAndUngroupShapes() throws {
        let engine = try DocumentEngine(data: Data(), name: "group")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("묶기", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        for tag in [0, 1] {
            let item = NSMenuItem(title: "도형", action: #selector(PagesView.insertShape(_:)), keyEquivalent: "")
            item.tag = tag
            view.insertShape(item)
            _ = try engine.sync { _ in }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        let shapes = view.pickableObjects(page: 0).filter { $0.kind == "shape" }
        XCTAssertEqual(shapes.count, 2)
        let group = NSMenuItem(title: "개체 묶기", action: #selector(PagesView.groupObjects(_:)), keyEquivalent: "")
        view.selectObject(shapes[0])
        XCTAssertFalse(view.validateMenuItem(group))
        view.toggleObjectInSelection(shapes[1])
        XCTAssertEqual(view.selectedObjects.count, 2)
        XCTAssertTrue(view.validateMenuItem(group))
        view.groupObjects(group)
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let objects = view.pickableObjects(page: 0)
        XCTAssertEqual(objects.map(\.kind), ["group"])
        // The new group is selected, as in the web editor.
        XCTAssertEqual(view.selectedObject?.kind, "group")
        XCTAssertEqual(view.selectedObjects.count, 1)

        let hwp = try engine.prepareSave(.hwp)
        try engine.cancelSave(hwp.token)
        let reopened = try DocumentEngine(data: hwp.data, name: "reopened")
        defer { reopened.close() }
        _ = try reopened.sync { try $0.select(.collapsed(at: .documentStart)) }
        let reopenedObjects = try XCTUnwrap(reopened.query(.pageObjects(page: 0))["controls"])
        guard case let .array(items) = reopenedObjects else { return XCTFail("no objects") }
        XCTAssertEqual(items.compactMap { $0["type"]?.string }.filter { $0 == "group" }.count, 1)

        view.ungroupObject(nil)
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(view.pickableObjects(page: 0).filter { $0.kind == "shape" }.count, 2)
    }

    /// 개체 속성 on a shape and 캡션 넣기 on a table both survive saving in each format.
    func testShapePropertiesAndTableCaptionSurviveSave() throws {
        let engine = try DocumentEngine(data: Data(), name: "object properties")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("개체", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let item = NSMenuItem(title: "직사각형", action: #selector(PagesView.insertShape(_:)), keyEquivalent: "")
        view.insertShape(item)
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let shape = try XCTUnwrap(view.pickableObjects(page: 0).first { $0.kind == "shape" })
        let props = try engine.query(.objectProperties(shape.address))
        XCTAssertEqual(props["kind"]?.string, "shape")
        // Reading the sheet back changes nothing, colours included.
        XCTAssertEqual(ObjectPropertiesSheet(props) { _ in }.changedProperties(), [:])
        let red = ObjectPropertiesSheet.colorRef(.init(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        XCTAssertEqual(red, 0x0000FF)
        _ = engine.submit(.action(.setObjectProperties(shape.address, [
            "borderColor": .number(red), "fillType": .string("solid"), "fillBgColor": .number(0x00FF00),
        ])))
        view.selectObject(shape)
        view.toggleCaption(nil)
        _ = try engine.sync { _ in }

        // With no object picked, 캡션 넣기 applies to the caret's table.
        view.selectObject(nil)
        view.beginEditingAtStart()
        _ = engine.submit(.action(.insertTable(rows: 1, columns: 1)))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let caption = NSMenuItem(title: "캡션 넣기", action: #selector(PagesView.toggleCaption(_:)), keyEquivalent: "")
        XCTAssertTrue(view.validateMenuItem(caption))
        view.toggleCaption(caption)
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(view.validateMenuItem(caption))
        XCTAssertEqual(caption.title, "캡션 빼기")
        let focus = try XCTUnwrap(engine.sync { $0.selection?.focus })
        let table = ObjectAddress(section: focus.section, paragraph: focus.paragraph, control: try XCTUnwrap(focus.cellPath.first).control)
        let shapeAddress = try XCTUnwrap(view.pickableObjects(page: 0).first { $0.kind == "shape" }).address

        for format in [SaveFormat.hwp, .hwpx] {
            let prepared = try engine.prepareSave(format)
            try engine.cancelSave(prepared.token)
            let reopened = try DocumentEngine(data: prepared.data, name: "reopened")
            defer { reopened.close() }
            _ = try reopened.sync { try $0.select(.collapsed(at: .documentStart)) }
            let shapeProps = try reopened.query(.objectProperties(shapeAddress))
            XCTAssertEqual(shapeProps["borderColor"]?.number, 0x0000FF, "\(format)")
            XCTAssertEqual(shapeProps["fillBgColor"]?.number, 0x00FF00, "\(format)")
            XCTAssertEqual(shapeProps["hasCaption"]?.bool, true, "\(format)")
            XCTAssertEqual(try reopened.query(.objectProperties(table))["hasCaption"]?.bool, true, "\(format)")
        }
    }
}

@MainActor
final class NoteTests: XCTestCase {
    /// 각주 넣기, 고치기 and typing after the number; the note survives saving in each format.
    func testFootnoteInsertEditAndSave() throws {
        let engine = try DocumentEngine(data: Data(), name: "notes")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let edit = NSMenuItem(title: "각주/미주 고치기…", action: #selector(PagesView.editNote(_:)), keyEquivalent: "")
        XCTAssertFalse(view.validateMenuItem(edit))
        _ = engine.submit(.action(.insertNote(kind: "footnote", text: "각주 글")))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(view.validateMenuItem(edit))
        XCTAssertEqual(try engine.query(.noteAtCaret)["text"]?.string, "각주 글")
        _ = engine.submit(.action(.setNoteText("고친 각주")))
        view.insertText("본문", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        // The number takes one place in the paragraph; the text typed after it follows it.
        let typed = try engine.sync { editor -> String in
            let at = { TextPosition(section: 0, paragraph: 0, scalarOffset: $0) }
            try editor.select(TextSelection(anchor: at(1), focus: at(3)))
            return try editor.copy()
        }
        XCTAssertEqual(typed, "본문")

        for format in [SaveFormat.hwp, .hwpx] {
            let prepared = try engine.prepareSave(format)
            try engine.cancelSave(prepared.token)
            XCTAssertEqual(prepared.report?.losses.count ?? 0, 0, "\(format)")
            let reopened = try DocumentEngine(data: prepared.data, name: "reopened")
            defer { reopened.close() }
            _ = try reopened.sync { try $0.select(.collapsed(at: TextPosition(section: 0, paragraph: 0, scalarOffset: 1))) }
            let note = try reopened.query(.noteAtCaret)
            XCTAssertEqual(note["kind"]?.string, "footnote", "\(format)")
            XCTAssertEqual(note["text"]?.string, "고친 각주", "\(format)")
        }
    }
}

@MainActor
final class EquationTests: XCTestCase {
    /// 수식 넣기 at the caret, picking it, 수식 고치기 and saving in each format.
    func testEquationInsertPickEditAndSave() throws {
        let engine = try DocumentEngine(data: Data(), name: "equation")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("식 ", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        _ = engine.submit(.action(.insertEquation(script: "a over b", fontSize: 1000)))
        view.insertText(" 끝", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let equation = try XCTUnwrap(view.pickableObjects(page: 0).first { $0.kind == "equation" })
        view.selectObject(view.object(atPage: 0, x: equation.frame.midX, y: equation.frame.midY))
        XCTAssertEqual(view.selectedObject?.kind, "equation")
        let rotate = NSMenuItem(title: "회전", action: #selector(PagesView.rotatePictureRight(_:)), keyEquivalent: "")
        XCTAssertFalse(view.validateMenuItem(rotate))
        _ = engine.submit(.action(.setObjectProperties(equation.address, ["script": .string("x^2 + 1")])))
        _ = try engine.sync { _ in }

        for format in [SaveFormat.hwp, .hwpx] {
            let prepared = try engine.prepareSave(format)
            try engine.cancelSave(prepared.token)
            XCTAssertEqual(prepared.report?.losses.count ?? 0, 0, "\(format)")
            let reopened = try DocumentEngine(data: prepared.data, name: "reopened")
            defer { reopened.close() }
            _ = try reopened.sync { try $0.select(.collapsed(at: .documentStart)) }
            let props = try reopened.query(.objectProperties(equation.address))
            XCTAssertEqual(props["kind"]?.string, "equation", "\(format)")
            XCTAssertEqual(props["script"]?.string, "x^2 + 1", "\(format)")
        }
    }
}
