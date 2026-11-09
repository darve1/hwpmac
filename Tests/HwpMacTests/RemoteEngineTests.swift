// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import PDFKit
import XCTest
@testable import HwpMac

/// The app's engine path: the bundled EngineService XPC process.
@MainActor
final class RemoteEngineTests: XCTestCase {
    func testEditRenderAndSaveThroughService() throws {
        let engine = try RemoteDocumentEngine(data: Data())
        defer { engine.close() }
        XCTAssertEqual(engine.initialPageSizes.count, 1)

        var snapshots: [DocumentEngine.Snapshot] = []
        engine.onSnapshot = { snapshots.append($0) }
        engine.submit(.select(.collapsed(at: .documentStart)))
        engine.submit(.mark("ㄱ"))
        engine.submit(.mark("가"))
        let last = engine.submit(.insert("가나다"))
        XCTAssertEqual(try engine.documentText(), "가나다")

        let rendered = expectation(description: "render")
        engine.render(page: 0, scale: 1) { image, _ in
            XCTAssertNotNil(image)
            rendered.fulfill()
        }
        wait(for: [rendered], timeout: 10)
        XCTAssertEqual(snapshots.last?.appliedSequence, last)

        let prepared = try engine.prepareSave(.hwpx)
        try engine.cancelSave(prepared.token)
        XCTAssertGreaterThan(prepared.data.count, 0)
        let reopened = try RemoteDocumentEngine(data: prepared.data)
        defer { reopened.close() }
        XCTAssertEqual(try reopened.documentText(), "가나다")
    }

    /// A stuck engine can be ended from the app; the connection reports it and
    /// a new engine starts on the next open.
    func testRestartEndsServiceAndNextOpenWorks() throws {
        let engine = try RemoteDocumentEngine(data: Data())
        let disconnected = expectation(description: "disconnect")
        engine.onDisconnect = { disconnected.fulfill() }
        XCTAssertTrue(engine.canRestart)
        engine.restart()
        wait(for: [disconnected], timeout: 10)
        engine.close()

        let next = try RemoteDocumentEngine(data: Data())
        defer { next.close() }
        next.submit(.select(.collapsed(at: .documentStart)))
        next.submit(.insert("다시"))
        XCTAssertEqual(try next.documentText(), "다시")
    }

    /// File > New: a blank document backed by the service, saved as HWP.
    func testNewDocumentIsBlankAndSavable() throws {
        let document = try HwpDocument(type: "com.hancom.hwp")
        defer { document.close() }
        let engine = try XCTUnwrap(document.engine)
        XCTAssertEqual(engine.initialPageSizes.count, 1)
        XCTAssertEqual(try engine.documentText(), "")
        let prepared = try engine.prepareSave(.hwp)
        try engine.cancelSave(prepared.token)
        XCTAssertGreaterThan(prepared.data.count, 0)
    }

    /// Print and PDF export: a vector PDF made inside the service, with real text.
    func testExportPDFHasTextOfEditedDocument() throws {
        let engine = try RemoteDocumentEngine(data: Data())
        defer { engine.close() }
        engine.submit(.select(.collapsed(at: .documentStart)))
        engine.submit(.insert("인쇄 시험"))
        let pdf = try XCTUnwrap(PDFDocument(data: try engine.exportPDF()))
        XCTAssertEqual(pdf.pageCount, 1)
        XCTAssertTrue(pdf.string?.contains("인쇄 시험") ?? false, pdf.string ?? "")
    }

    func testDetectsHWP3BySignature() {
        XCTAssertTrue(HwpDocument.isHWP3(Data("HWP Document File V3.00 \u{1a}\u{01}".utf8)))
        XCTAssertFalse(HwpDocument.isHWP3(Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])))
        XCTAssertFalse(HwpDocument.isHWP3(Data()))
    }

    func testServiceRejectsGarbageWithoutTakingTheAppDown() {
        XCTAssertThrowsError(try RemoteDocumentEngine(data: Data("이것은 한글 문서가 아닙니다".utf8)))
    }
}
