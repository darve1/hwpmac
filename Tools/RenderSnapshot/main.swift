// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
//
// Renders one page through the same RhwpSession the app uses and writes a PNG,
// with timings as JSON on stdout. Not sandboxed, so it can read any corpus file.
//
// usage: hwpmac-render-snapshot <input.hwp|hwpx> <page> <scale> <output.png>

import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 5, let page = Int(arguments[2]), let scale = Double(arguments[3]) else {
    FileHandle.standardError.write(Data("usage: hwpmac-render-snapshot <input> <page> <scale> <output.png>\n".utf8))
    exit(64)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[4])

do {
    let clock = ContinuousClock()
    let data = try Data(contentsOf: input)
    let start = clock.now
    let session = try RhwpSession(data: data)
    let opened = clock.now
    let size = try session.pageSize(page)
    let image = try session.renderPage(page, scale: scale)
    let rendered = clock.now

    guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw RhwpSessionError.imageCreationFailed }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw RhwpSessionError.imageCreationFailed }

    func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
    let summary: [String: Any] = [
        "ok": true,
        "pageCount": session.pageCount,
        "page": page,
        "pageSize": ["width": size.width, "height": size.height],
        "image": ["width": image.width, "height": image.height],
        "openSeconds": seconds(opened - start),
        "renderSeconds": seconds(rendered - opened),
    ]
    let json = try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys])
    print(String(decoding: json, as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data("{\"ok\":false,\"error\":\"\(error)\"}\n".utf8))
    exit(1)
}
