// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// Stacks every page vertically and renders only the pages being drawn.
///
/// One layout pixel is drawn as one point. Pages are rendered synchronously on
/// the main thread, which owns the session.
final class PagesView: NSView {
    private static let gap: CGFloat = 24
    private static let cacheLimit = 12

    private let session: RhwpSession
    private let pageRects: [CGRect]
    private var cache: [Int: (scale: Double, image: CGImage)] = [:]
    private var cacheOrder: [Int] = []

    init(session: RhwpSession, pageSizes: [CGSize]) {
        self.session = session
        let width = (pageSizes.map(\.width).max() ?? 0) + 2 * Self.gap
        var y = Self.gap
        var rects: [CGRect] = []
        for size in pageSizes {
            rects.append(CGRect(x: (width - size.width) / 2, y: y, width: size.width, height: size.height))
            y += size.height + Self.gap
        }
        pageRects = rects
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: y))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.underPageBackgroundColor.setFill()
        dirtyRect.fill()

        for (page, rect) in pageRects.enumerated() where rect.intersects(dirtyRect) {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 6
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.set()
            NSColor.white.setFill()
            rect.fill()
            NSGraphicsContext.restoreGraphicsState()

            do {
                let image = try pageImage(page)
                NSImage(cgImage: image, size: rect.size)
                    .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            } catch {
                drawFailure(error, in: rect)
            }
        }
    }

    /// Device pixels per layout pixel, so pages stay sharp when magnified.
    private var renderScale: Double {
        let backing = Double(window?.backingScaleFactor ?? 2)
        let magnification = Double(enclosingScrollView?.magnification ?? 1)
        return (backing * max(magnification, 1) * 2).rounded(.up) / 2
    }

    private func pageImage(_ page: Int) throws -> CGImage {
        let scale = renderScale
        if let cached = cache[page], cached.scale == scale {
            return cached.image
        }
        let image = try session.renderPage(page, scale: scale)
        cache[page] = (scale, image)
        cacheOrder.removeAll { $0 == page }
        cacheOrder.append(page)
        if cacheOrder.count > Self.cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
        return image
    }

    private func drawFailure(_ error: Error, in rect: CGRect) {
        let message = "이 쪽을 그리지 못했습니다.\n\(error)" as NSString
        message.draw(in: rect.insetBy(dx: 24, dy: 24), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.systemRed,
        ])
    }
}
