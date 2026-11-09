// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

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

    func testServiceRejectsGarbageWithoutTakingTheAppDown() {
        XCTAssertThrowsError(try RemoteDocumentEngine(data: Data("이것은 한글 문서가 아닙니다".utf8)))
    }
}
