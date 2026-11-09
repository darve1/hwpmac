// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import XCTest
@testable import HwpMac

/// Drives PagesView through NSTextInputClient the way the macOS Korean
/// 2-set input method does, on a blank document, and checks the text that
/// rhwp ends up holding — also after a save and reopen.
@MainActor
final class TextInputTests: XCTestCase {
    private var engine: DocumentEngine!
    private var view: PagesView!

    override func setUp() async throws {
        engine = try DocumentEngine(data: Data(), name: "test engine")
        view = PagesView(engine: engine)
        view.beginEditingAtStart()
        settle()
    }

    override func tearDown() async throws {
        engine.close()
    }

    /// Waits for the engine to finish submitted work and delivers its snapshots.
    private func settle() {
        _ = try? engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    private func documentText() throws -> String {
        try engine.sync { editor in
            let selection = editor.selection
            try editor.execute(.selectAll)
            defer { if let selection { _ = try? editor.select(selection) } }
            return try editor.copy()
        }
    }

    private func mark(_ text: String) {
        view.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0),
                           replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func insert(_ text: String) {
        view.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    /// ㅎ ㅏ ㄴ ㄱ ㅡ ㄹ: the input method commits 한 when ㄱ cannot join it,
    /// then composes 글 and commits it on space.
    func testTypingHangulWord() throws {
        for step in ["ㅎ", "하", "한"] { mark(step) }
        insert("한")
        settle()
        for step in ["ㄱ", "그", "글"] { mark(step) }
        XCTAssertTrue(view.hasMarkedText())
        XCTAssertEqual(view.markedRange(), NSRange(location: 1, length: 1))
        insert("글")
        insert(" ")
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(view.markedRange().location, NSNotFound)
        XCTAssertEqual(try documentText(), "한글 ")
    }

    /// Typing faster than the engine: every keystroke is queued before any is
    /// applied, so the engine sees one coalesced batch.
    func testBurstOfKeystrokesBeforeEngineCatchesUp() throws {
        for (marks, syllable) in [(["ㄷ", "대"], "대"), (["ㅎ", "하", "한"], "한"), (["ㅁ", "미", "민"], "민"),
                                  (["ㄱ", "구", "국"], "국")] {
            for step in marks { mark(step) }
            insert(syllable)
        }
        XCTAssertEqual(try documentText(), "대한민국")
    }

    func testEscapeCancelsComposition() throws {
        insert("가")
        mark("ㄴ")
        mark("나")
        view.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(try documentText(), "가")
    }

    /// Clicking elsewhere or saving commits the composition instead of losing it.
    func testCommitInputKeepsComposedText() throws {
        mark("ㄷ")
        mark("다")
        view.commitInput()
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(try documentText(), "다")
    }

    func testBackspaceUndoAndRedo() throws {
        insert("가나")
        view.doCommand(by: #selector(NSResponder.deleteBackward(_:)))
        XCTAssertEqual(try documentText(), "가")
        view.undo(nil)
        XCTAssertEqual(try documentText(), "가나")
        view.redo(nil)
        XCTAssertEqual(try documentText(), "가")
    }

    /// Option-return 한자 conversion: the input method reads the syllable
    /// before the caret, marks it with a replacement range, then inserts the
    /// chosen 한자 over that range.
    func testHanjaConversionReplacesPrecedingSyllable() throws {
        insert("대한")
        XCTAssertEqual(view.attributedSubstring(forProposedRange: NSRange(location: 1, length: 1), actualRange: nil)?.string, "한")
        view.setMarkedText("한", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 1, length: 1))
        XCTAssertTrue(view.hasMarkedText())
        XCTAssertEqual(view.markedRange(), NSRange(location: 1, length: 1))
        view.insertText("韓", replacementRange: NSRange(location: 1, length: 1))
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(try documentText(), "대韓")
    }

    func testReturnSplitsParagraph() throws {
        insert("첫째")
        view.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        insert("둘째")
        let text = try documentText()
        XCTAssertTrue(text.hasPrefix("첫째"), text)
        XCTAssertTrue(text.hasSuffix("둘째"), text)
        XCTAssertTrue(text.contains("\n"), text)
    }

    /// The composed text survives serialization in both formats.
    func testComposedTextSurvivesSaveAndReopen() throws {
        for step in ["ㅎ", "하", "한"] { mark(step) }
        insert("한")
        mark("ㄱ")
        mark("그")
        mark("글")
        view.commitInput()
        for format in [SaveFormat.hwp, .hwpx] {
            let prepared = try engine.sync { editor in
                let prepared = try editor.session.prepareSave(format)
                try editor.session.cancelSave(prepared.token)
                return prepared
            }
            XCTAssertEqual(prepared.report?.losses.count ?? 0, 0, "\(format)")
            let reopened = try DocumentEngine(data: prepared.data, name: "reopened")
            defer { reopened.close() }
            let text = try reopened.sync { editor in
                try editor.select(.collapsed(at: .documentStart))
                try editor.execute(.selectAll)
                return try editor.copy()
            }
            XCTAssertEqual(text, "한글", "\(format)")
        }
    }

    // MARK: Local composition (used while the engine is slow)

    func testLocalCompositionTypesSameText() throws {
        view.compositionPolicy = .local
        for (marks, syllable) in [(["ㄷ", "대"], "대"), (["ㅎ", "하", "한"], "한")] {
            for step in marks { mark(step) }
            XCTAssertTrue(view.hasMarkedText())
            insert(syllable)
        }
        mark("ㅁ")
        mark("미")
        mark("민")
        view.commitInput()
        XCTAssertEqual(try documentText(), "대한민")
    }

    func testLocalCompositionEscapeSendsNothing() throws {
        view.compositionPolicy = .local
        insert("가")
        mark("ㄴ")
        mark("나")
        view.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(try documentText(), "가")
    }

    /// 한자 conversion replaces existing text, so it always composes in the engine.
    func testLocalPolicyStillConvertsHanjaInEngine() throws {
        view.compositionPolicy = .local
        insert("대한")
        settle()
        view.setMarkedText("한", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 1, length: 1))
        view.insertText("韓", replacementRange: NSRange(location: 1, length: 1))
        XCTAssertEqual(try documentText(), "대韓")
    }

    /// Typed text shows at the caret before the engine applies it, and the
    /// echo goes away once a snapshot includes it.
    func testEchoShowsUntilEngineCatchesUp() throws {
        view.compositionPolicy = .local
        insert("가")
        mark("ㄴ")
        XCTAssertTrue(view.isShowingTypingOverlay)
        view.commitInput()
        settle()
        XCTAssertFalse(view.isShowingTypingOverlay)
        XCTAssertEqual(try documentText(), "가ㄴ")
    }

    func testSnapshotReportsCaretAfterEdits() throws {
        insert("가나다")
        settle()
        XCTAssertEqual(view.selectedRange(), NSRange(location: 3, length: 0))
    }
}

final class CoalesceTests: XCTestCase {
    private typealias Operation = DocumentEngine.Operation

    private func describe(_ operations: [Operation]) -> [String] {
        operations.map {
            switch $0 {
            case let .insert(text): "insert(\(text))"
            case let .mark(text): "mark(\(text))"
            case .commitMarked: "commit"
            case let .drag(page, x, y): "drag(\(page),\(x),\(y))"
            case .command: "command"
            default: "other"
            }
        }
    }

    func testConsecutiveInsertsMerge() {
        XCTAssertEqual(describe(DocumentEngine.coalesce([.insert("가"), .insert("나"), .insert("다")])), ["insert(가나다)"])
    }

    func testOnlyLastPreviewSurvivesAndInsertReplacesIt() {
        let batch: [Operation] = [.mark("ㄱ"), .mark("가"), .mark("각"), .insert("각"), .mark("ㅎ")]
        XCTAssertEqual(describe(DocumentEngine.coalesce(batch)), ["insert(각)", "mark(ㅎ)"])
    }

    /// A typed syllable after a committed one: the preview is dropped and the
    /// two inserts become one edit.
    func testInsertAfterDroppedPreviewMergesWithPreviousInsert() {
        let batch: [Operation] = [.insert("대"), .mark("ㅎ"), .mark("하"), .mark("한"), .insert("한"), .insert(" ")]
        XCTAssertEqual(describe(DocumentEngine.coalesce(batch)), ["insert(대한 )"])
    }

    func testCommandsAreNotMerged() {
        let batch: [Operation] = [.insert("가"), .command(.deleteBackward), .insert("나")]
        XCTAssertEqual(describe(DocumentEngine.coalesce(batch)), ["insert(가)", "command", "insert(나)"])
    }

    func testOnlyLastDragSurvives() {
        let batch: [Operation] = [.drag(page: 0, x: 1, y: 1), .drag(page: 0, x: 2, y: 2)]
        XCTAssertEqual(describe(DocumentEngine.coalesce(batch)), ["drag(0,2.0,2.0)"])
    }
}
