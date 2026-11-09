// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import CoreGraphics
import Foundation

/// What the UI needs from a document engine, whether it runs in this process
/// (`DocumentEngine`, used by tools and tests) or in the sandboxed XPC
/// service (`RemoteDocumentEngine`, used by the app).
protocol DocumentEngineClient: AnyObject {
    var initialPageSizes: [CGSize] { get }
    /// Delivered on the main thread after every batch of operations.
    @MainActor var onSnapshot: ((DocumentEngine.Snapshot) -> Void)? { get set }
    /// Whether the last batch that changed the document was slow.
    var isSlow: Bool { get }

    /// Queues an operation; returns its sequence number (see `Snapshot.appliedSequence`).
    @discardableResult
    func submit(_ operation: DocumentEngine.Operation) -> UInt64
    /// Renders a page after queued operations; `completion` runs on the main thread.
    func render(page: Int, scale: Double, completion: @escaping @MainActor @Sendable (CGImage?, UInt64) -> Void)

    // Calls that wait for the engine to finish queued operations.
    func copySelection() throws -> String
    func surroundingText(timeout: TimeInterval) throws -> ImeContext
    func prepareSave(_ format: SaveFormat) throws -> PreparedSave
    /// Returns whether the document is still dirty.
    func acknowledgeSave(_ token: UInt64) throws -> Bool
    func cancelSave(_ token: UInt64) throws
    /// The whole document as plain text; the selection is left unchanged.
    func documentText() throws -> String

    func close()

    /// Whether `restart()` can stop a stuck engine (only an out-of-process one can).
    var canRestart: Bool { get }
    /// Stops the engine process; its documents must be reopened.
    func restart()
}

extension DocumentEngineClient {
    var canRestart: Bool { false }
    func restart() {}
}

/// A rendered page as raw pixels, for crossing the XPC boundary.
struct PixelFrame: Sendable {
    var data: Data
    var width: Int
    var height: Int
    var stride: Int

    /// rhwp renders premultiplied RGBA in sRGB.
    func makeImage() -> CGImage? {
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        guard data.count >= stride * height,
              let provider = CGDataProvider(data: data as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: stride,
                       space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }
}
