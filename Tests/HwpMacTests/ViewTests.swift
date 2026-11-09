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
