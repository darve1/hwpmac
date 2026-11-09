// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import CoreGraphics
import Foundation

/// One-shot renders for Quick Look. Each function opens, renders and closes a
/// session within one call, so it stays on the calling thread as rhwp requires.
enum PageRenderer {
    /// rhwp lays out pages in 96-per-inch pixels; PDF and Quick Look use points.
    static let pointsPerLayoutPixel = 72.0 / 96.0

    /// A PDF of the first `maxPages` pages, each page an image at `scale`
    /// device pixels per layout pixel.
    static func pdf(from data: Data, maxPages: Int, scale: Double) throws -> (data: Data, firstPageSize: CGSize) {
        let session = try RhwpSession(data: data)
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { throw RhwpSessionError.imageCreationFailed }
        var firstPageSize = CGSize.zero
        for page in 0..<min(session.pageCount, maxPages) {
            let size = try session.pageSize(page)
            var box = CGRect(x: 0, y: 0, width: size.width * pointsPerLayoutPixel, height: size.height * pointsPerLayoutPixel)
            if page == 0 { firstPageSize = box.size }
            let image = try session.renderPage(page, scale: scale)
            context.beginPage(mediaBox: &box)
            context.draw(image, in: box)
            context.endPage()
        }
        context.closePDF()
        return (output as Data, firstPageSize)
    }

    /// The first page scaled to fit `maxSize` points at `scale` device pixels per point.
    static func thumbnail(from data: Data, maxSize: CGSize, scale: Double) throws -> (image: CGImage, size: CGSize) {
        let session = try RhwpSession(data: data)
        let page = try session.pageSize(0)
        let fit = min(maxSize.width / page.width, maxSize.height / page.height)
        let image = try session.renderPage(0, scale: fit * scale)
        return (image, CGSize(width: page.width * fit, height: page.height * fit))
    }
}
