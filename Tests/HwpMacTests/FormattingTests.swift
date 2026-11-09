// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import XCTest
@testable import HwpMac

/// Character and paragraph formatting and find/replace, driven through
/// PagesView's menu actions on a blank document and checked in rhwp's model —
/// also after a save and reopen.
@MainActor
final class FormattingTests: XCTestCase {
    private var engine: DocumentEngine!
    private var view: PagesView!
    private var searchResults: [JSONValue] = []

    override func setUp() async throws {
        engine = try DocumentEngine(data: Data(), name: "test engine")
        view = PagesView(engine: engine)
        view.onSearchResult = { [weak self] in self?.searchResults.append($0) }
        view.beginEditingAtStart()
        settle()
    }

    override func tearDown() async throws {
        engine.close()
    }

    private func settle() {
        _ = try? engine.sync { _ in }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    private func insert(_ text: String) {
        view.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        settle()
    }

    private func selectAll() {
        view.selectAll(nil)
        settle()
    }

    private func query(_ query: EditQuery, in engine: DocumentEngine? = nil) throws -> JSONValue {
        try (engine ?? self.engine).sync { try $0.query(query) }
    }

    func testBoldAppliesToSelectionAndUndoes() throws {
        insert("굵은 글자")
        selectAll()
        XCTAssertNotEqual(try query(.charProperties)["bold"]?.bool, true)
        view.toggleBold(nil)
        settle()
        XCTAssertEqual(try query(.charProperties)["bold"]?.bool, true)
        view.undo(nil)
        settle()
        XCTAssertNotEqual(try query(.charProperties)["bold"]?.bool, true)
        XCTAssertEqual(try engine.documentText(), "굵은 글자")
    }

    /// Toggling reads the current state from the snapshot, so a second toggle
    /// turns bold off again.
    func testSecondToggleRemovesBold() throws {
        insert("가나")
        selectAll()
        view.toggleBold(nil)
        settle()
        view.toggleBold(nil)
        settle()
        XCTAssertNotEqual(try query(.charProperties)["bold"]?.bool, true)
    }

    func testCharacterFormattingNeedsSelection() throws {
        insert("가나")
        let menuItem = NSMenuItem(title: "굵게", action: #selector(PagesView.toggleBold(_:)), keyEquivalent: "")
        XCTAssertFalse(view.validateMenuItem(menuItem))
        selectAll()
        XCTAssertTrue(view.validateMenuItem(menuItem))
    }

    func testFontSizeAndColor() throws {
        insert("크기")
        selectAll()
        let before = try XCTUnwrap(query(.charProperties)["fontSize"]?.number)
        view.increaseFontSize(nil)
        settle()
        XCTAssertEqual(try query(.charProperties)["fontSize"]?.number, (before / 100 + 1).rounded() * 100)
        NSColorPanel.shared.color = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        view.changeTextColor(nil)
        settle()
        XCTAssertEqual(try query(.charProperties)["textColor"]?.string?.lowercased(), "#ff0000")
    }

    func testParagraphAlignmentSpacingAndIndent() throws {
        insert("문단")
        view.alignCenter(nil)
        settle()
        XCTAssertEqual(try query(.paraProperties)["alignment"]?.string, "center")
        let spacing = NSMenuItem(title: "160%", action: #selector(PagesView.setLineSpacing(_:)), keyEquivalent: "")
        spacing.tag = 160
        view.setLineSpacing(spacing)
        settle()
        XCTAssertEqual(try query(.paraProperties)["lineSpacing"]?.number, 160)
        view.increaseIndent(nil)
        settle()
        view.increaseIndent(nil)
        settle()
        // Two 10 pt steps, reported in pixels.
        let margin = try XCTUnwrap(query(.paraProperties)["marginLeft"]?.number)
        XCTAssertEqual(ParagraphUnits.points(fromPixels: margin), 20, accuracy: 0.1)
        view.decreaseIndent(nil)
        settle()
        XCTAssertEqual(ParagraphUnits.points(fromPixels: try XCTUnwrap(query(.paraProperties)["marginLeft"]?.number)), 10,
                       accuracy: 0.1)
        XCTAssertTrue(view.validateMenuItem(spacing))
        XCTAssertEqual(spacing.state, .on)
    }

    func testFindSelectsNextMatchAndReportsMiss() throws {
        insert("사과 배 사과")
        view.beginEditingAtStart()
        settle()
        view.find("사과", forward: true, caseSensitive: false)
        settle()
        XCTAssertEqual(view.selectedRange(), NSRange(location: 0, length: 2))
        view.find("사과", forward: true, caseSensitive: false)
        settle()
        XCTAssertEqual(view.selectedRange(), NSRange(location: 5, length: 2))
        view.find("포도", forward: true, caseSensitive: false)
        settle()
        XCTAssertEqual(searchResults.last?["found"]?.bool, false)
    }

    func testReplaceAllReportsCount() throws {
        insert("a A a")
        view.replaceAll("a", with: "b", caseSensitive: true)
        settle()
        XCTAssertEqual(searchResults.last?["count"]?.number, 2)
        XCTAssertEqual(try engine.documentText(), "b A b")
        view.undo(nil)
        settle()
        XCTAssertEqual(try engine.documentText(), "a A a")
    }

    func testReplaceChangesSelectedMatchOnly() throws {
        insert("하나 하나")
        view.beginEditingAtStart()
        settle()
        view.find("하나", forward: true, caseSensitive: false)
        settle()
        view.replace("하나", with: "둘", caseSensitive: false)
        settle()
        XCTAssertEqual(try engine.documentText(), "둘 하나")
    }

    /// The 문단 모양 values go through the engine's units and come back the same.
    func testParagraphShapeRoundTrip() throws {
        insert("문단 모양")
        let props: [String: JSONValue] = [
            "alignment": .string("center"),
            "marginLeft": .number(ParagraphUnits.marginValue(points: 15)),
            "marginRight": .number(ParagraphUnits.marginValue(points: 5)),
            "indent": .number(ParagraphUnits.marginValue(points: -10)),
            "lineSpacingType": .string("Fixed"),
            "lineSpacing": .number(ParagraphUnits.lineSpacingValue(points: 20)),
            "spacingBefore": .number(ParagraphUnits.spacingValue(points: 6)),
            "spacingAfter": .number(ParagraphUnits.spacingValue(points: 4)),
        ]
        _ = engine.submit(.action(.paraFormat(props)))
        settle()
        let back = try query(.paraProperties)
        let points = { (key: String) in ParagraphUnits.points(fromPixels: back[key]?.number ?? .nan) }
        XCTAssertEqual(back["alignment"]?.string, "center")
        XCTAssertEqual(points("marginLeft"), 15, accuracy: 0.1)
        XCTAssertEqual(points("marginRight"), 5, accuracy: 0.1)
        XCTAssertEqual(points("indent"), -10, accuracy: 0.1)
        XCTAssertEqual(back["lineSpacingType"]?.string, "Fixed")
        XCTAssertEqual(points("lineSpacing"), 20, accuracy: 0.1)
        XCTAssertEqual(points("spacingBefore"), 6, accuracy: 0.1)
        XCTAssertEqual(points("spacingAfter"), 4, accuracy: 0.1)
    }

    /// The keys the 글자 모양 sheet sends: a font by name and a shade colour.
    func testFontNameAndShadeColor() throws {
        insert("글꼴")
        selectAll()
        _ = engine.submit(.action(.charFormat(["fontName": .string("함초롬바탕"), "shadeColor": .string("#ffff00")])))
        settle()
        let props = try query(.charProperties)
        XCTAssertEqual(props["fontFamily"]?.string, "함초롬바탕")
        XCTAssertEqual(props["shadeColor"]?.string?.lowercased(), "#ffff00")
    }

    func testHyperlinkOnSelectionThenRemoved() throws {
        insert("링크 글자")
        view.selectAll(nil)
        settle()
        _ = engine.submit(.action(.insertHyperlink("https://example.com")))
        settle()
        XCTAssertEqual(try engine.query(.hyperlink)["uri"]?.string, "https://example.com")
        view.removeHyperlink(nil)
        settle()
        XCTAssertEqual(try engine.query(.hyperlink), .null)
        XCTAssertEqual(try engine.documentText(), "링크 글자")
    }

    func testBookmarkNamesMustBeUnique() throws {
        insert("책갈피")
        _ = engine.submit(.action(.addBookmark("처음")))
        settle()
        var failure: String?
        view.onStatus = { if let message = $0 { failure = message } }
        _ = engine.submit(.action(.addBookmark("처음")))
        settle()
        XCTAssertNotNil(failure)
    }

    /// 모양 복사 from bold, centred text onto plain text in the next paragraph.
    func testCopyFormatOntoAnotherParagraph() throws {
        insert("서식")
        selectAll()
        view.toggleBold(nil)
        view.alignCenter(nil)
        settle()
        view.copyFormat(nil)
        view.doCommand(by: #selector(NSResponder.moveToEndOfLine(_:)))
        view.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        insert("평문")
        view.doCommand(by: #selector(NSResponder.moveToBeginningOfLineAndModifySelection(_:)))
        settle()
        view.alignLeft(nil)
        view.toggleBold(nil)
        settle()
        XCTAssertNotEqual(try query(.charProperties)["bold"]?.bool, true)
        view.pasteFormat(nil)
        settle()
        XCTAssertEqual(try query(.charProperties)["bold"]?.bool, true)
        XCTAssertEqual(try query(.paraProperties)["alignment"]?.string, "center")
    }

    /// 개요 1 → 개요 2 with one outline step, and back.
    func testOutlineLevelSteps() throws {
        insert("개요")
        let styles = view.paragraphStyles().styles
        let first = try XCTUnwrap(styles.first { $0.name.hasPrefix("개요") && $0.name.hasSuffix("1") })
        _ = engine.submit(.action(.applyStyle(first.id)))
        settle()
        XCTAssertEqual(view.paragraphStyles().current, first.id)
        view.increaseOutlineLevel(nil)
        settle()
        let second = try XCTUnwrap(styles.first { $0.name.hasPrefix("개요") && $0.name.hasSuffix("2") })
        XCTAssertEqual(view.paragraphStyles().current, second.id)
        view.decreaseOutlineLevel(nil)
        settle()
        XCTAssertEqual(view.paragraphStyles().current, first.id)
    }

    func testCharacterShapeColorsRoundTrip() {
        let color = CharacterShapeSheet.color("#12ab9f")
        XCTAssertEqual(color.map(CharacterShapeSheet.hex), "#12ab9f")
        XCTAssertNil(CharacterShapeSheet.color("red"))
    }

    func testSuperscriptAndSubscriptExcludeEachOther() throws {
        insert("x2")
        selectAll()
        view.toggleSuperscript(nil)
        settle()
        XCTAssertEqual(try query(.charProperties)["superscript"]?.bool, true)
        view.toggleSubscript(nil)
        settle()
        let props = try query(.charProperties)
        XCTAssertEqual(props["subscript"]?.bool, true)
        XCTAssertEqual(props["superscript"]?.bool, false)
    }

    func testCharRatioAndSpacingSteps() throws {
        insert("장평")
        selectAll()
        view.increaseCharRatio(nil)
        settle()
        view.decreaseCharSpacing(nil)
        settle()
        let props = try query(.charProperties)
        guard case let .array(ratios)? = props["ratios"], case let .array(spacings)? = props["spacings"] else {
            return XCTFail("no ratios/spacings: \(props)")
        }
        XCTAssertEqual(ratios.first?.number, 101)
        XCTAssertEqual(spacings.first?.number, -1)
        XCTAssertEqual(ratios.count, 7)
    }

    func testOutlineDistributeAndLineSpacingStep() throws {
        insert("효과")
        selectAll()
        view.toggleOutline(nil)
        view.alignDistributed(nil)
        settle()
        XCTAssertNotEqual(try query(.charProperties)["outlineType"]?.number, 0)
        XCTAssertEqual(try query(.paraProperties)["alignment"]?.string, "distribute")
        let spacing = try XCTUnwrap(query(.paraProperties)["lineSpacing"]?.number)
        view.increaseLineSpacing(nil)
        settle()
        XCTAssertEqual(try query(.paraProperties)["lineSpacing"]?.number, spacing + 10)
    }

    func testNumberingAndBulletsToggle() throws {
        insert("첫 항목")
        view.toggleNumbering(nil)
        settle()
        XCTAssertEqual(try query(.paraProperties)["headType"]?.string, "Number")
        view.toggleBullets(nil)
        settle()
        XCTAssertEqual(try query(.paraProperties)["headType"]?.string, "Bullet")
        view.toggleBullets(nil)
        settle()
        XCTAssertEqual(try query(.paraProperties)["headType"]?.string, "None")
    }

    func testPageBreakStartsNewPage() throws {
        insert("앞뒤")
        view.doCommand(by: #selector(NSResponder.moveLeft(_:)))
        settle()
        let pages = try engine.sync { try $0.session.info().pageCount }
        view.insertPageBreak(nil)
        settle()
        XCTAssertEqual(try engine.sync { try $0.session.info().pageCount }, pages + 1)
        XCTAssertEqual(try engine.sync { $0.selection?.focus.paragraph }, 1)
        let menuItem = NSMenuItem(title: "쪽 나누기", action: #selector(PagesView.insertPageBreak(_:)), keyEquivalent: "")
        XCTAssertTrue(view.validateMenuItem(menuItem))
    }

    func testPageSetupChangesOrientationAndMargins() throws {
        insert("용지")
        var page = try engine.query(.pageDef)
        guard case var .object(props) = page else { return XCTFail("no page def") }
        props["landscape"] = .bool(true)
        props["marginLeft"] = .number(5669)
        _ = engine.submit(.action(.setPageDef(props)))
        settle()
        page = try engine.query(.pageDef)
        XCTAssertEqual(page["landscape"]?.bool, true)
        XCTAssertEqual(page["marginLeft"]?.number, 5669)
    }

    func testHeaderFooterFieldTokensMapToMarkers() {
        let editable = "보고서\n- [쪽 번호] / [전체 쪽 수] -\t[파일 이름]"
        let stored = HeaderFooterSheet.stored(editable)
        XCTAssertEqual(stored, "보고서\n- \u{15} / \u{16} -\u{17}")
        XCTAssertEqual(HeaderFooterSheet.editable(stored), "보고서\n- [쪽 번호] / [전체 쪽 수] -[파일 이름]")
    }

    /// Header text with a page number field, also after a save and reopen.
    func testHeaderWithPageNumberSurvivesSaveAndReopen() throws {
        insert("본문")
        let slot = HeaderFooterSlot(isHeader: true)
        _ = engine.submit(.action(.setHeaderFooter(slot, text: "머리말 \u{15}")))
        settle()
        XCTAssertEqual(try engine.query(.headerFooter(slot))["text"]?.string, "머리말 \u{15}")
        for format in [SaveFormat.hwp, .hwpx] {
            let prepared = try engine.prepareSave(format)
            try engine.cancelSave(prepared.token)
            XCTAssertEqual(prepared.report?.losses.count ?? 0, 0, "\(format)")
            let reopened = try DocumentEngine(data: prepared.data, name: "reopened")
            defer { reopened.close() }
            _ = try reopened.sync { try $0.select(.collapsed(at: .documentStart)) }
            XCTAssertEqual(try reopened.query(.headerFooter(slot))["text"]?.string, "머리말 \u{15}", "\(format)")
        }
    }

    /// Formatting survives serialization in both formats.
    func testFormattingSurvivesSaveAndReopen() throws {
        insert("서식")
        selectAll()
        view.toggleBold(nil)
        view.alignRight(nil)
        settle()
        for format in [SaveFormat.hwp, .hwpx] {
            let prepared = try engine.prepareSave(format)
            try engine.cancelSave(prepared.token)
            XCTAssertEqual(prepared.report?.losses.count ?? 0, 0, "\(format)")
            let reopened = try DocumentEngine(data: prepared.data, name: "reopened")
            defer { reopened.close() }
            _ = try reopened.sync { try $0.select(TextSelection(anchor: .documentStart, focus: TextPosition.documentStart.offset(by: 1))) }
            XCTAssertEqual(try query(.charProperties, in: reopened)["bold"]?.bool, true, "\(format)")
            XCTAssertEqual(try query(.paraProperties, in: reopened)["alignment"]?.string, "right", "\(format)")
        }
    }
}
