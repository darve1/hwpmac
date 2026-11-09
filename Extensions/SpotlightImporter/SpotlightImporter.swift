// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import CoreSpotlight
import Rhwp

/// Gives Spotlight the text of HWP/HWPX documents, so Finder and Spotlight
/// search find them by their contents.
final class SpotlightImporter: CSImportExtension {
    /// Spotlight indexes a bounded amount of text per file anyway.
    private static let maxCharacters = 1_000_000

    override func update(_ attributes: CSSearchableItemAttributeSet, forFileAt contentURL: URL) throws {
        let document = try Rhwp.readText(inputFile: contentURL)
        attributes.textContent = String(document.text.prefix(Self.maxCharacters))
        if let pageCount = document.pageCount {
            attributes.pageCount = NSNumber(value: pageCount)
        }
    }
}
