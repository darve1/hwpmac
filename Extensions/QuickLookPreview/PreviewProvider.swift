// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import Foundation
import Quartz
import UniformTypeIdentifiers

/// Finder Quick Look preview: the first pages of the document as a PDF.
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    private static let maxPages = 10

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let data = try Data(contentsOf: request.fileURL)
        let pdf = try PageRenderer.pdf(from: data, maxPages: Self.maxPages, scale: 1.5)
        return QLPreviewReply(dataOfContentType: .pdf, contentSize: pdf.firstPageSize) { _ in pdf.data }
    }
}
