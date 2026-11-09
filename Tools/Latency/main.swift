// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
//
// Typing latency through DocumentEngine, the app's editing path.
//
// Types the same Korean text (composition steps included) three ways:
//  - waited:  waits for the engine after every keystroke (the old synchronous behavior)
//  - burst:   submits every keystroke at once, as if typed faster than the engine
//  - paced:   one keystroke every 1/8 s, a fast typist
//  - pacedLocal: as paced, but composition previews stay in the view (the
//             app does this while the engine is slow), so only committed
//             syllables reach the engine
// and reports how long submitting took on the calling thread and how long
// until the engine caught up. Prints JSON.
//
// usage: hwpmac-latency <input.hwp|hwpx> [mode...]

import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: hwpmac-latency <input> [mode...]\n".utf8))
    exit(64)
}

/// 대한민국 만세: composition steps per syllable, then the committed syllable.
let syllables: [([String], String)] = [
    (["ㄷ", "대"], "대"), (["ㅎ", "하", "한"], "한"), (["ㅁ", "미", "민"], "민"), (["ㄱ", "구", "국"], "국"),
    ([], " "), (["ㅁ", "마", "만"], "만"), (["ㅅ", "세"], "세"),
]
let keystrokes: [DocumentEngine.Operation] = syllables.flatMap { marks, text in
    marks.map { DocumentEngine.Operation.mark($0) } + [.insert(text)]
}

let clock = ContinuousClock()
func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}

func editableEngine(_ data: Data) throws -> (DocumentEngine, Int) {
    let engine = try DocumentEngine(data: data, name: "latency")
    let paragraph = try engine.sync { editor -> Int in
        for paragraph in 0..<200 {
            let position = TextPosition(section: 0, paragraph: paragraph, scalarOffset: 0)
            do {
                try editor.select(.collapsed(at: position))
                try editor.insertText("x")
                try editor.undo()
                return paragraph
            } catch {
                continue
            }
        }
        throw EngineThreadError.stopped
    }
    return (engine, paragraph)
}

func run(_ mode: String, data: Data) throws -> [String: Any] {
    let (engine, paragraph) = try editableEngine(data)
    defer { engine.close() }
    var submitTimes: [Double] = []
    var waits: [Double] = []
    let start = clock.now
    for (index, keystroke) in keystrokes.enumerated() {
        if mode.hasPrefix("paced") {
            Thread.sleep(until: Date(timeIntervalSinceNow: max(0, 0.125 * Double(index) - seconds(clock.now - start))))
        }
        if mode == "pacedLocal", case .mark = keystroke { continue }
        let before = clock.now
        engine.submit(keystroke)
        submitTimes.append(seconds(clock.now - before))
        if mode == "waited" {
            let waitStart = clock.now
            try engine.sync { _ in }
            waits.append(seconds(clock.now - waitStart))
        }
    }
    let lastSubmit = clock.now
    try engine.sync(timeout: 600) { _ in }
    let caughtUp = clock.now
    let text = try engine.sync { editor -> String in
        try editor.commitMarkedText()
        return try editor.surroundingText().text
    }
    waits.sort()
    return [
        "mode": mode,
        "editedParagraph": paragraph,
        "keystrokes": keystrokes.count,
        "maxSubmitMillis": (submitTimes.max() ?? 0) * 1000,
        "totalSeconds": seconds(caughtUp - start),
        "lagAfterLastKeystrokeSeconds": seconds(caughtUp - lastSubmit),
        "medianWaitPerKeystrokeSeconds": waits.isEmpty ? NSNull() : waits[waits.count / 2],
        "textOK": text.contains("대한민국 만세"),
    ]
}

do {
    let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
    var results: [[String: Any]] = []
    let modes = arguments.count > 2 ? Array(arguments.dropFirst(2)) : ["waited", "burst", "paced", "pacedLocal"]
    for mode in modes {
        results.append(try run(mode, data: data))
    }
    let json = try JSONSerialization.data(withJSONObject: ["input": arguments[1], "runs": results], options: [.sortedKeys])
    print(String(decoding: json, as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data("{\"ok\":false,\"error\":\"\(error)\"}\n".utf8))
    exit(1)
}
