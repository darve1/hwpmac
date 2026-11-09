// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import XCTest
@testable import HwpMac

/// Drives PagesView through NSTextInputClient the way the macOS Korean
/// 2-set input method does, on a blank document, and checks the text that
/// rhwp ends up holding — also after a save and reopen.
@MainActor
final class TextInputTests: XCTestCase {
    private var view: PagesView!

    override func setUp() async throws {
        let session = try RhwpSession(data: Data())
        let editor = try DocumentEditor(session: session)
        view = PagesView(editor: editor, pageSizes: [try session.pageSize(0)])
        view.beginEditingAtStart()
    }

    private func documentText(_ editor: DocumentEditor) throws -> String {
        try editor.execute(.selectAll)
        return try editor.copy()
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
        for step in ["ㄱ", "그", "글"] { mark(step) }
        XCTAssertTrue(view.hasMarkedText())
        XCTAssertEqual(view.markedRange(), NSRange(location: 1, length: 1))
        insert("글")
        insert(" ")
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(view.markedRange().location, NSNotFound)
        XCTAssertEqual(try documentText(view.editor), "한글 ")
    }

    func testEscapeCancelsComposition() throws {
        insert("가")
        mark("ㄴ")
        mark("나")
        view.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(try documentText(view.editor), "가")
    }

    /// Clicking elsewhere or saving commits the composition instead of losing it.
    func testCommitInputKeepsComposedText() throws {
        mark("ㄷ")
        mark("다")
        view.commitInput()
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(try documentText(view.editor), "다")
    }

    func testBackspaceUndoAndRedo() throws {
        insert("가나")
        view.doCommand(by: #selector(NSResponder.deleteBackward(_:)))
        XCTAssertEqual(try documentText(view.editor), "가")
        view.undo(nil)
        XCTAssertEqual(try documentText(view.editor), "가나")
        view.redo(nil)
        XCTAssertEqual(try documentText(view.editor), "가")
    }

    /// Option-return 한자 conversion: the input method reads the syllable
    /// before the caret, marks it with a replacement range, then inserts the
    /// chosen 한자 over that range.
    func testHanjaConversionReplacesPrecedingSyllable() throws {
        insert("대한")
        XCTAssertEqual(view.attributedSubstring(forProposedRange: NSRange(location: 1, length: 1), actualRange: nil)?.string, "한")
        view.setMarkedText("한", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 1, length: 1))
        XCTAssertTrue(view.hasMarkedText())
        view.insertText("韓", replacementRange: NSRange(location: 1, length: 1))
        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(try documentText(view.editor), "대韓")
    }

    func testReturnSplitsParagraph() throws {
        insert("첫째")
        view.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        insert("둘째")
        let text = try documentText(view.editor)
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
            let prepared = try view.editor.session.prepareSave(format)
            try view.editor.session.cancelSave(prepared.token)
            XCTAssertEqual(prepared.report?.losses.count ?? 0, 0, "\(format)")
            let reopened = try DocumentEditor(session: RhwpSession(data: prepared.data))
            try reopened.select(.collapsed(at: .documentStart))
            XCTAssertEqual(try documentText(reopened), "한글", "\(format)")
        }
    }
}
