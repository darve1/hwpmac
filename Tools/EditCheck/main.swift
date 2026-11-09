// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
//
// Edit-path check: for each input, apply one fixed L1 edit script through
// DocumentEditor (the same code the app's text view drives), save as HWP and
// HWPX, reopen both and check that the edits survived. Prints one JSON line
// per input. Saved files are kept in the output directory for checking in 한글.
//
// usage: hwpmac-edit-check <output-dir> <input>...

import Foundation
import Rhwp

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: hwpmac-edit-check <output-dir> <input>...\n".utf8))
    exit(64)
}
let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

/// Text the script leaves in the document: "[편집]" + the syllable 각 typed
/// through composition, then a new paragraph "새 문단". The second composed
/// syllable 나 is deleted again, and one undo is redone.
let firstMarker = "[편집]각"
let secondMarker = "새 문단"
let maxParagraphProbe = 200

struct StageError: Error {
    let stage: String
    let underlying: Error
}

func stage<T>(_ name: String, _ body: () throws -> T) throws -> T {
    do { return try body() } catch { throw StageError(stage: name, underlying: error) }
}

let clock = ContinuousClock()

func milliseconds(_ duration: Duration) -> Double {
    (Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18) * 1000
}

func save(_ session: RhwpSession, as format: SaveFormat, to url: URL) throws -> SaveReport? {
    let prepared = try session.prepareSave(format)
    do {
        try prepared.data.write(to: url, options: [.withoutOverwriting])
    } catch {
        _ = try? session.cancelSave(prepared.token)
        throw error
    }
    try session.acknowledgeSave(prepared.token)
    return prepared.report
}

func reread(_ url: URL) throws -> (pageCount: Int, text: String) {
    let pageCount = try RhwpSession(data: Data(contentsOf: url)).pageCount
    let text = try Rhwp.readText(inputFile: url).text
    return (pageCount, text)
}

func lossSummary(_ report: SaveReport?) -> [String] {
    (report?.losses ?? []).map { "\($0.subject)/\($0.reason) \($0.path)" }
}

func check(_ input: URL, index: Int) -> [String: Any] {
    var result: [String: Any] = ["input": input.lastPathComponent]
    let base = outputDirectory.appendingPathComponent(String(format: "%04d", index))
    do {
        let data = try stage("read") { try Data(contentsOf: input) }
        let session = try stage("open") { try RhwpSession(data: data) }
        result["pageCount"] = session.pageCount

        // Baseline: the unedited document through the same save path.
        var baseline: [String: Int] = [:]
        for format in [SaveFormat.hwp, .hwpx] {
            let url = base.appendingPathExtension("base.\(format.rawValue)")
            _ = try stage("baseline-save-\(format.rawValue)") { try save(session, as: format, to: url) }
            baseline[format.rawValue] = try stage("baseline-read-\(format.rawValue)") { try reread(url).text.count }
        }

        let editor = try stage("editor") { try DocumentEditor(session: session) }
        var timings: [Double] = []
        func timed(_ body: () throws -> Void) throws {
            let start = clock.now
            try body()
            timings.append(milliseconds(clock.now - start))
        }
        // rhwp edits only plain body paragraphs; paragraphs holding controls
        // (section/column definitions, tables...) report "unsupported". Use the
        // first top-level paragraph of section 0 that accepts text.
        let paragraph = try stage("find-editable-paragraph") { () -> Int in
            for paragraph in 0..<maxParagraphProbe {
                do {
                    try editor.select(.collapsed(at: TextPosition(section: 0, paragraph: paragraph, scalarOffset: 0)))
                    try timed { try editor.insertText("[편집]") }
                    return paragraph
                } catch RhwpNativeHostError.failed(code: "unsupported", _) {
                    continue
                }
            }
            throw RhwpNativeHostError.failed(code: "unsupported", message: "no editable paragraph in the first \(maxParagraphProbe)")
        }
        result["editedParagraph"] = paragraph
        try stage("edit-script") {
            for preedit in ["ㄱ", "가", "각"] { try timed { try editor.setMarkedText(preedit) } }
            try timed { try editor.insertText("각") }
            for preedit in ["ㄴ", "나"] { try timed { try editor.setMarkedText(preedit) } }
            try timed { try editor.insertText("나") }
            try timed { try editor.execute(.deleteBackward) }
            try timed { try editor.execute(.splitParagraph) }
            try timed { try editor.insertText(secondMarker) }
            try timed { try editor.undo() }
            try timed { try editor.redo() }
        }
        timings.sort()
        result["editMillis"] = ["median": timings[timings.count / 2], "max": timings.last ?? 0]

        for format in [SaveFormat.hwp, .hwpx] {
            let url = base.appendingPathExtension("edited.\(format.rawValue)")
            let report = try stage("save-\(format.rawValue)") { try save(session, as: format, to: url) }
            let (pageCount, text) = try stage("reopen-\(format.rawValue)") { try reread(url) }
            result[format.rawValue] = [
                "losses": lossSummary(report),
                "reopenedPages": pageCount,
                "markersFound": text.contains(firstMarker) && text.contains(secondMarker),
                "textDelta": text.count - (baseline[format.rawValue] ?? 0),
            ]
        }
        result["ok"] = true
    } catch let error as StageError {
        result["ok"] = false
        result["stage"] = error.stage
        result["error"] = String(describing: error.underlying)
    } catch {
        result["ok"] = false
        result["error"] = String(describing: error)
    }
    return result
}

for (index, path) in arguments.dropFirst(2).enumerated() {
    let result = autoreleasepool { check(URL(fileURLWithPath: path), index: index) }
    let json = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(decoding: json, as: UTF8.self))
    fflush(stdout)
}
