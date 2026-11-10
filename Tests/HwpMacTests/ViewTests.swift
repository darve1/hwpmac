// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import XCTest
@testable import HwpMac

@MainActor
final class ZoomTests: XCTestCase {
    func testFitWidthAndFitPage() throws {
        let engine = try DocumentEngine(data: Data(), name: "zoom")
        defer { engine.close() }
        let controller = DocumentWindowController(engine: engine)
        let window = try XCTUnwrap(controller.window)
        window.setContentSize(NSSize(width: 600, height: 500))
        let span = controller.pagesView.largestPageSpan
        XCTAssertGreaterThan(span.width, 0)

        controller.zoomToFitWidth(nil)
        let widthFit = controller.magnification
        XCTAssertLessThan(widthFit, 1)
        controller.zoomToFitPage(nil)
        // A whole A4 page is taller than wide, so it needs a smaller zoom.
        XCTAssertLessThan(controller.magnification, widthFit)
        XCTAssertGreaterThanOrEqual(controller.magnification, 0.25)
    }
}

@MainActor
final class GoToPageTests: XCTestCase {
    func testGoToSecondPagePutsCaretThere() throws {
        let engine = try DocumentEngine(data: Data(), name: "goto")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("첫 쪽", replacementRange: NSRange(location: NSNotFound, length: 0))
        view.insertPageBreak(nil)
        view.insertText("둘째 쪽", replacementRange: NSRange(location: NSNotFound, length: 0))
        view.beginEditingAtStart()
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(view.pageCount, 2)
        view.goToPage(1)
        _ = try engine.sync { _ in }
        XCTAssertEqual(try engine.sync { $0.selection?.focus.paragraph }, 1)
    }
}

@MainActor
final class EditorMarksTests: XCTestCase {
    private final class Pixels: @unchecked Sendable {
        var data = Data()
    }

    private func pixels(_ engine: DocumentEngine) throws -> Data {
        let done = expectation(description: "render")
        let result = Pixels()
        engine.renderPixels(page: 0, scale: 1) { frame, _ in
            result.data = frame?.data ?? Data()
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return result.data
    }

    /// 문단 부호 draws on screen renders and changes neither text nor revision.
    func testParagraphMarksChangeOnlyTheRender() throws {
        let engine = try DocumentEngine(data: Data(), name: "marks")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("문단", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        let revision = try engine.sync { $0.revision }
        let plain = try pixels(engine)
        view.toggleParagraphMarks(nil)
        _ = try engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(view.editorMarks.paragraphMarks)
        XCTAssertNotEqual(try pixels(engine), plain)
        XCTAssertEqual(try engine.sync { $0.revision }, revision)
        XCTAssertEqual(try engine.documentText(), "문단")
    }
}

@MainActor
final class ColumnTests: XCTestCase {
    func testTwoColumnsFromTheMenu() throws {
        let engine = try DocumentEngine(data: Data(), name: "columns")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("다단", replacementRange: NSRange(location: NSNotFound, length: 0))
        let item = NSMenuItem(title: "둘", action: #selector(PagesView.setColumnCount(_:)), keyEquivalent: "")
        item.tag = 2
        view.setColumnCount(item)
        _ = try engine.sync { _ in }
        XCTAssertEqual(try engine.query(.columns)["count"]?.number, 2)
        XCTAssertEqual(try engine.query(.columns)["spacing"]?.number, 2268)
    }
}

@MainActor
final class HtmlExportTests: XCTestCase {
    func testUnwrapsClipboardFragment() {
        let fragment = "<html><body>\n<!--StartFragment--><p>가나</p><!--EndFragment-->\n</body></html>"
        XCTAssertEqual(HtmlExport.unwrap(fragment), "<p>가나</p>")
        XCTAssertEqual(HtmlExport.unwrap("<p>그대로</p>"), "<p>그대로</p>")
    }

    func testDocumentHasEngineTextAndEscapedTitle() throws {
        let engine = try DocumentEngine(data: Data(), name: "html")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        view.insertText("내보낼 글", replacementRange: NSRange(location: NSNotFound, length: 0))
        _ = try engine.sync { _ in }
        let html = HtmlExport.document(try engine.query(.documentHtml), title: "a<b", format: .word)
        XCTAssertTrue(html.contains("내보낼 글"))
        XCTAssertTrue(html.contains("<title>a&lt;b</title>"))
        XCTAssertTrue(html.contains("urn:schemas-microsoft-com:office:word"))
    }
}

@MainActor
final class ToolbarTests: XCTestCase {
    /// Every toolbar item's action is a command some responder implements.
    func testToolbarItemsReachTheirCommands() throws {
        let engine = try DocumentEngine(data: Data(), name: "toolbar")
        defer { engine.close() }
        let controller = DocumentWindowController(engine: engine)
        let toolbar = try XCTUnwrap(controller.window?.toolbar)
        XCTAssertEqual(toolbar.items.count, DocumentToolbar.basic.count + DocumentToolbar.format.count + 1)
        for spec in DocumentToolbar.basic + DocumentToolbar.format {
            let handled = [controller.pagesView as NSObject, controller, HwpDocument() as NSObject]
                .contains { $0.responds(to: spec.action) }
            XCTAssertTrue(handled, spec.label)
            XCTAssertNotNil(NSImage(systemSymbolName: spec.symbol, accessibilityDescription: nil), spec.symbol)
        }
    }
}

@MainActor
final class SectionTests: XCTestCase {
    func testSectionStartNumberAndPageBorder() throws {
        let engine = try DocumentEngine(data: Data(), name: "section")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        view.beginEditingAtStart()
        _ = engine.submit(.action(.setSectionDef(["pageNum": .number(3)])))
        let side: JSONValue = .object(["type": .number(1), "width": .number(1), "color": .string("#000000")])
        _ = engine.submit(.action(.setPageBorder(["borderTop": side, "fillType": .string("solid"), "fillColor": .string("#ffffe0")])))
        _ = try engine.sync { _ in }
        XCTAssertEqual(try engine.query(.sectionDef)["pageNum"]?.number, 3)
        let border = try engine.query(.pageBorder)
        XCTAssertEqual(border["borderTop"]?["type"]?.number, 1)
        XCTAssertEqual(border["fillColor"]?.string?.lowercased(), "#ffffe0")
    }
}

@MainActor
final class GridTests: XCTestCase {
    func testGridPositionsCoverThePageFromTheTextCorner() {
        XCTAssertEqual(GridSettings.positions(origin: 10, step: 4, lower: 0, upper: 20), [2, 6, 10, 14, 18])
        XCTAssertEqual(GridSettings.positions(origin: 0, step: 5, lower: 0, upper: 10), [0, 5, 10])
        XCTAssertEqual(GridSettings.positions(origin: 0, step: 0, lower: 0, upper: 10), [])
        XCTAssertEqual(GridSettings.clamp(0), 1)
        XCTAssertEqual(GridSettings.clamp(500), 100)
    }

    func testGridSettingsPersistAndToggleFromTheMenu() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "GridTests-\(UUID().uuidString)"))
        var settings = GridSettings(visible: true, pattern: .both, horizontalMm: 5, verticalMm: 10)
        settings.save(defaults)
        XCTAssertEqual(GridSettings.load(defaults), settings)
        settings.pattern = .dots
        XCTAssertNotEqual(GridSettings.load(defaults), settings)

        let engine = try DocumentEngine(data: Data(), name: "grid")
        defer { engine.close() }
        let view = PagesView(engine: engine)
        let original = view.grid
        defer { view.grid = original }
        view.grid.visible = false
        let revision = try engine.sync { $0.revision }
        let item = NSMenuItem(title: "격자 보기", action: #selector(PagesView.toggleGrid(_:)), keyEquivalent: "")
        view.toggleGrid(item)
        XCTAssertTrue(view.validateMenuItem(item))
        XCTAssertEqual(item.state, .on)
        // The grid is a view setting: the document does not change.
        XCTAssertEqual(try engine.sync { $0.revision }, revision)
    }
}
