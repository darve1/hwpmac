// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import XCTest

/// Hancom's HWP spec license requires this sentence in the product's UI,
/// manual, help and source wherever those exist.
final class AttributionTests: XCTestCase {
    private let sentence = "본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다."

    func testHelpContainsAttribution() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Help", withExtension: "md"))
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains(sentence))
    }

    func testInfoPlistCopyrightContainsAttribution() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String, sentence)
    }

    func testEverySourceFileStartsWithAttribution() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directories = ["App/Sources", "Extensions", "Importers", "Services", "Tools", "Tests"].map { root.appendingPathComponent($0) }
        var checked = 0
        for directory in directories {
            let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }.filter { ["swift", "c", "m"].contains($0.pathExtension) } ?? []
            for file in files {
                let firstLine = try String(contentsOf: file, encoding: .utf8).split(separator: "\n").first ?? ""
                XCTAssertEqual(firstLine, "// \(sentence)", file.lastPathComponent)
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 10)
    }
}
