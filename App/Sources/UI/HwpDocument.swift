// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// A read-only HWP/HWPX document (milestone 1: open and view).
final class HwpDocument: NSDocument {
    private(set) var session: RhwpSession?
    private(set) var pageSizes: [CGSize] = []

    override class var autosavesInPlace: Bool {
        false
    }

    // Documents are read on the main thread (concurrent reading is off by
    // default), which is also where the session is used afterwards.
    override func read(from data: Data, ofType typeName: String) throws {
        let session = try RhwpSession(data: data)
        pageSizes = try (0..<session.pageCount).map { try session.pageSize($0) }
        self.session = session
    }

    override func makeWindowControllers() {
        guard let session else { return }
        addWindowController(DocumentWindowController(session: session, pageSizes: pageSizes))
    }
}
