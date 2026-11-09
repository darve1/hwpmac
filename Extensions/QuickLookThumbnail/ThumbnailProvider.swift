// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import QuickLookThumbnailing

/// Finder icon thumbnail: the first page.
final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        do {
            let data = try Data(contentsOf: request.fileURL)
            let rendered = try PageRenderer.thumbnail(from: data, maxSize: request.maximumSize, scale: Double(request.scale))
            let reply = QLThumbnailReply(contextSize: rendered.size) { context in
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.fill(CGRect(origin: .zero, size: rendered.size))
                context.draw(rendered.image, in: CGRect(origin: .zero, size: rendered.size))
                return true
            }
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }
}
