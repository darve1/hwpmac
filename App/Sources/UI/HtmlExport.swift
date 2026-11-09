// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import Foundation
import UniformTypeIdentifiers

/// HTML and Word (.doc) export, built as the web editor builds it: each
/// section's clipboard HTML fragment from the engine, unwrapped and joined,
/// in an HTML document — for Word with the Office namespaces, which Word
/// opens as an HTML-based .doc.
enum HtmlExport {
    enum Format {
        case html, word

        var fileExtension: String { self == .html ? "html" : "doc" }
        var contentType: UTType {
            self == .html ? .html : UTType(filenameExtension: "doc") ?? .data
        }
    }

    /// The body of an engine fragment, without its clipboard wrapper.
    static func unwrap(_ fragment: String) -> String {
        var inner = fragment
        if let open = fragment.range(of: "<body[^>]*>", options: [.regularExpression, .caseInsensitive]),
           let close = fragment.range(of: "</body>", options: .caseInsensitive, range: open.upperBound..<fragment.endIndex) {
            inner = String(fragment[open.upperBound..<close.lowerBound])
        }
        return inner
            .replacingOccurrences(of: "<!--StartFragment-->", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "<!--EndFragment-->", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// A complete document from the engine's `{"sections":[…]}`.
    static func document(_ sections: JSONValue, title: String, format: Format) -> String {
        var parts: [String] = []
        if case let .array(items)? = sections["sections"] {
            parts = items.compactMap(\.string).map(unwrap).filter { !$0.isEmpty }
        }
        let opening = format == .html
            ? "<!DOCTYPE html>\n<html lang=\"ko\">"
            : "<html xmlns:o=\"urn:schemas-microsoft-com:office:office\" "
                + "xmlns:w=\"urn:schemas-microsoft-com:office:word\" xmlns=\"http://www.w3.org/TR/REC-html40\">"
        return """
        \(opening)
        <head>
        <meta charset="utf-8" />
        <title>\(escape(title))</title>
        </head>
        <body>
        \(parts.joined(separator: "\n"))
        </body>
        </html>
        """
    }
}
