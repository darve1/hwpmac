// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
//
// Edit-path check: for each input, apply one fixed L1 edit script through
// DocumentEditor (the same code the app's text view drives), save as HWP and
// HWPX, reopen both and check that the edits survived. Prints one JSON line
// per input. Saved files are kept in the output directory for checking in 한글.
//
// With --format the script also makes the first marker bold and red and
// centers its paragraph (L2), and the check reads those properties back.
//
// With --cell the script edits the first cell of the first table among the
// first body paragraphs instead (L3): it types the cell marker, composes a
// syllable, splits the cell paragraph and types again, then undoes and redoes.
//
// usage: hwpmac-edit-check [--format | --cell] <output-dir> <input>...

import Foundation
import Rhwp

let formatting = CommandLine.arguments.contains("--format")
let cellMode = CommandLine.arguments.contains("--cell")
let arguments = CommandLine.arguments.filter { $0 != "--format" && $0 != "--cell" }
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: hwpmac-edit-check [--format | --cell] <output-dir> <input>...\n".utf8))
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
/// The cell script leaves "[셀]각" and, in a new cell paragraph, "둘째 줄".
let cellMarker = "[셀]각"
let cellSecondMarker = "둘째 줄"
let maxControlProbe = 8

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

/// The first marker's range in `paragraph`.
func markerSelection(_ paragraph: Int) -> TextSelection {
    let start = TextPosition(section: 0, paragraph: paragraph, scalarOffset: 0)
    return TextSelection(anchor: start, focus: start.offset(by: firstMarker.unicodeScalars.count))
}

/// The first two paragraphs of a cell of the reopened file, joined by a newline,
/// read from the model: layout-based text extraction wraps lines in narrow cells,
/// and plain-text copy refuses ranges holding objects. Each paragraph is read
/// through the input-method context at its start (a bounded window of its text).
func cellText(_ url: URL, cell: TextPosition) throws -> String {
    let editor = try DocumentEditor(session: RhwpSession(data: Data(contentsOf: url)))
    var second = cell
    second.cellPath[second.cellPath.count - 1].paragraph += 1
    return try [cell, second].map { position in
        try editor.select(.collapsed(at: position))
        return try editor.surroundingText().text
    }.joined(separator: "\n")
}

/// Whether the reopened file still has the --format properties on the marker.
func formattingKept(_ url: URL, paragraph: Int) throws -> Bool {
    let editor = try DocumentEditor(session: RhwpSession(data: Data(contentsOf: url)))
    try editor.select(markerSelection(paragraph))
    let char = try editor.query(.charProperties)
    let para = try editor.query(.paraProperties)
    return char["bold"]?.bool == true && char["textColor"]?.string?.lowercased() == "#ff0000"
        && para["alignment"]?.string == "center"
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
        var editedCell: TextPosition?
        var timings: [Double] = []
        func timed(_ body: () throws -> Void) throws {
            let start = clock.now
            try body()
            timings.append(milliseconds(clock.now - start))
        }
        if cellMode {
            let cell = try stage("find-table-cell") { () -> TextPosition in
                // The first cell of the first table, among the first body
                // paragraphs, whose first paragraph accepts text.
                for paragraph in 0..<maxParagraphProbe {
                    for control in 0..<maxControlProbe {
                        let position = TextPosition(section: 0, paragraph: paragraph, scalarOffset: 0,
                                                    cellPath: [CellPathEntry(control: control, cell: 0, paragraph: 0)])
                        do {
                            try editor.select(.collapsed(at: position))
                            try timed { try editor.insertText("[셀]") }
                            return position
                        } catch let RhwpNativeHostError.failed(code, _) where code == "unsupported" || code == "invalidArgument" {
                            continue
                        }
                    }
                }
                throw RhwpNativeHostError.failed(code: "unsupported", message: "no editable table cell")
            }
            result["editedCell"] = ["paragraph": cell.paragraph, "control": cell.cellPath[0].control]
            editedCell = cell
            try stage("cell-script") {
                for preedit in ["ㄱ", "가", "각"] { try timed { try editor.setMarkedText(preedit) } }
                try timed { try editor.insertText("각") }
                try timed { try editor.execute(.splitParagraph) }
                try timed { try editor.insertText(cellSecondMarker) }
                try timed { try editor.undo() }
                try timed { try editor.redo() }
            }
        } else {
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
            if formatting {
                try stage("format") {
                    try editor.select(markerSelection(paragraph))
                    try timed { try editor.apply(.charFormat(["bold": .bool(true), "textColor": .string("#ff0000")])) }
                    try timed { try editor.apply(.paraFormat(["alignment": .string("center")])) }
                }
            }
        }
        timings.sort()
        result["editMillis"] = ["median": timings[timings.count / 2], "max": timings.last ?? 0]

        for format in [SaveFormat.hwp, .hwpx] {
            let url = base.appendingPathExtension("edited.\(format.rawValue)")
            let report = try stage("save-\(format.rawValue)") { try save(session, as: format, to: url) }
            let (pageCount, text) = try stage("reopen-\(format.rawValue)") { try reread(url) }
            var checks: [String: Any] = [
                "losses": lossSummary(report),
                "reopenedPages": pageCount,
                "markersFound": try stage("reread-cell-\(format.rawValue)") { () -> Bool in
                    guard let editedCell else { return text.contains(firstMarker) && text.contains(secondMarker) }
                    return try cellText(url, cell: editedCell).hasPrefix(cellMarker + "\n" + cellSecondMarker)
                },
                "textDelta": text.count - (baseline[format.rawValue] ?? 0),
            ]
            if formatting, let paragraph = result["editedParagraph"] as? Int {
                checks["formattingKept"] = try stage("reread-format-\(format.rawValue)") {
                    try formattingKept(url, paragraph: paragraph)
                }
            }
            result[format.rawValue] = checks
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
