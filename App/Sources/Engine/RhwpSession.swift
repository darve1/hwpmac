// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import CoreGraphics
import Foundation
import Rhwp

enum RhwpSessionError: Error {
    case imageCreationFailed
}

/// An open rhwp native session.
///
/// The native ABI binds every handle to the OS thread that opened it, so each
/// call checks that thread instead of relying on actor isolation.
final class RhwpSession {
    let handle: UInt64
    let pageCount: Int
    private let ownerThread = pthread_self()

    init(data: Data) throws {
        let opened = try Rhwp.sessionOpen(data: data)
        guard let handle = (opened["handle"] as? NSNumber)?.uint64Value,
              let pageCount = (opened["pageCount"] as? NSNumber)?.intValue
        else { throw RhwpNativeHostError.invalidResponse }
        self.handle = handle
        self.pageCount = pageCount
    }

    deinit {
        checkOwnerThread()
        try? Rhwp.sessionClose(handle: handle)
    }

    /// Page size in rhwp layout pixels (96 per inch).
    func pageSize(_ page: Int) throws -> CGSize {
        let response = try request(["op": "pageSize", "page": page])
        guard let size = response["size"] as? [String: Any],
              let width = (size["width"] as? NSNumber)?.doubleValue,
              let height = (size["height"] as? NSNumber)?.doubleValue
        else { throw RhwpNativeHostError.invalidResponse }
        return CGSize(width: width, height: height)
    }

    /// Renders a whole page; `scale` multiplies layout pixels.
    func renderPage(_ page: Int, scale: Double) throws -> CGImage {
        let frame = try request(["op": "render", "page": page, "scale": scale])
        guard let buffer = (frame["buffer"] as? NSNumber)?.uint64Value
        else { throw RhwpNativeHostError.invalidResponse }
        // The buffer's ownership ends here even if copying fails.
        defer { try? Rhwp.sessionBufferRelease(buffer: buffer) }

        guard let width = (frame["width"] as? NSNumber)?.intValue,
              let height = (frame["height"] as? NSNumber)?.intValue,
              let stride = (frame["stride"] as? NSNumber)?.intValue,
              let byteLength = (frame["byteLength"] as? NSNumber)?.intValue,
              frame["pixelFormat"] as? String == "rgba8Premultiplied",
              byteLength == stride * height
        else { throw RhwpNativeHostError.invalidResponse }

        let pixels = try Rhwp.sessionBufferCopy(buffer: buffer, byteLength: byteLength)
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        guard let provider = CGDataProvider(data: pixels as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: stride, space: colorSpace, bitmapInfo: bitmapInfo,
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              )
        else { throw RhwpSessionError.imageCreationFailed }
        return image
    }

    private func request(_ body: [String: Any]) throws -> [String: Any] {
        checkOwnerThread()
        return try Rhwp.sessionRequest(handle: handle, request: body)
    }

    private func checkOwnerThread() {
        precondition(pthread_equal(ownerThread, pthread_self()) != 0,
                     "rhwp session used off the thread that opened it")
    }
}
