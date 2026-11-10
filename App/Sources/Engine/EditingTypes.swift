// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import Foundation

// Swift mirrors of the rhwp native host ABI v1 editing types.

struct CellPathEntry: Codable, Equatable, Sendable {
    var control: Int
    var cell: Int
    var paragraph: Int
}

/// A text position. `scalarOffset` counts Unicode scalars within the paragraph.
struct TextPosition: Codable, Equatable, Sendable {
    var section: Int
    var paragraph: Int
    var scalarOffset: Int
    var cellPath: [CellPathEntry] = []

    static let documentStart = TextPosition(section: 0, paragraph: 0, scalarOffset: 0)

    /// The paragraph within its container: the body, or the innermost table cell.
    var leafParagraph: Int { cellPath.last?.paragraph ?? paragraph }

    /// Document order for positions in the same container (a selection never
    /// crosses a table-cell boundary).
    func precedes(_ other: TextPosition) -> Bool {
        (section, paragraph, leafParagraph, scalarOffset)
            < (other.section, other.paragraph, other.leafParagraph, other.scalarOffset)
    }

    func offset(by scalars: Int) -> TextPosition {
        var moved = self
        moved.scalarOffset += scalars
        return moved
    }
}

struct TextSelection: Codable, Equatable, Sendable {
    var anchor: TextPosition
    var focus: TextPosition

    static func collapsed(at position: TextPosition) -> TextSelection {
        TextSelection(anchor: position, focus: position)
    }

    var isCollapsed: Bool { anchor == focus }
    var start: TextPosition { focus.precedes(anchor) ? focus : anchor }
}

struct EditOutcome: Decodable {
    var revision: UInt64
    var selection: TextSelection
    var documentChanged: Bool
    var historyChanged: Bool
    var compositionId: UInt64?
}

struct SessionInfo: Decodable {
    var pageCount: Int
    var revision: UInt64
    var canUndo: Bool
    var canRedo: Bool
    var compositionId: UInt64?
    var isDirty: Bool
}

/// Caret geometry in page layout pixels; `y` is the top of the caret.
struct CaretRect: Codable, Sendable {
    var page: Int
    var x: Double
    var y: Double
    var height: Double
}

struct SelectionRect: Codable, Sendable {
    struct Bounds: Codable, Sendable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    var page: Int
    var bounds: Bounds
}

/// Text around the focus within its paragraph, for input methods.
/// `absoluteStartScalar` is the paragraph offset of the first scalar of `text`.
struct ImeContext: Codable, Sendable {
    var text: String
    var cursorScalar: Int
    var absoluteStartScalar: Int
}

struct HitTestResult: Decodable {
    var position: TextPosition
    var caret: CaretRect?
}

enum EditCommand: Codable, Sendable {
    case moveLeft(extend: Bool)
    case moveRight(extend: Bool)
    case home(extend: Bool)
    case end(extend: Bool)
    case moveUp(extend: Bool)
    case moveDown(extend: Bool)
    case deleteBackward
    case deleteForward
    case splitParagraph
    case selectAll
    /// Tab and Shift-Tab in a table.
    case nextCell
    case previousCell

    var isVertical: Bool {
        switch self {
        case .moveUp, .moveDown: true
        default: false
        }
    }

    func jsonObject(preferredX: Double?) -> [String: Any] {
        switch self {
        case let .moveLeft(extend): ["command": "moveLeft", "extendSelection": extend]
        case let .moveRight(extend): ["command": "moveRight", "extendSelection": extend]
        case let .home(extend): ["command": "home", "extendSelection": extend]
        case let .end(extend): ["command": "end", "extendSelection": extend]
        case let .moveUp(extend): ["command": "moveUp", "extendSelection": extend, "preferredX": preferredX ?? NSNull()]
        case let .moveDown(extend): ["command": "moveDown", "extendSelection": extend, "preferredX": preferredX ?? NSNull()]
        case .deleteBackward: ["command": "deleteBackward"]
        case .deleteForward: ["command": "deleteForward"]
        case .splitParagraph: ["command": "splitParagraph"]
        case .selectAll: ["command": "selectAll"]
        case .nextCell: ["command": "nextCell"]
        case .previousCell: ["command": "previousCell"]
        }
    }
}

enum SaveFormat: String, Codable, Sendable {
    case hwp
    case hwpx
}

/// One item of rhwp's content-loss report for a save.
struct ContentLoss: Codable, Sendable {
    var code: String
    var subject: String
    var path: String
    var reason: String
}

struct SaveReport: Codable, Sendable {
    var count: Int
    var losses: [ContentLoss]
    var outputFormat: String
}

/// Serialized bytes waiting for the host to write them, then acknowledge or cancel `token`.
struct PreparedSave: Codable, Sendable {
    var token: UInt64
    var revision: UInt64
    var data: Data
    var report: SaveReport?
}

/// Formatting and document-wide actions (rhwp `native_host::editor::actions`).
/// Property keys follow rhwp's web editor: `bold`, `italic`, `underline`,
/// `strikethrough`, `fontSize` (1/100 pt), `fontName`, `textColor` ("#rrggbb"),
/// `alignment` ("left"/"center"/"right"/"justify"), `lineSpacing` (%),
/// `indent`, `marginLeft` (HWPUNIT).
enum EditAction: Codable, Sendable {
    case charFormat([String: JSONValue])
    case paraFormat([String: JSONValue])
    case replaceAll(query: String, replacement: String, caseSensitive: Bool)
    /// Paragraph numbering or bullets on or off for the selected paragraphs.
    case toggleNumbering
    case toggleBullet(String?)
    /// A page or column break at the caret (body text).
    case insertPageBreak
    case insertColumnBreak
    /// 다단 of the caret's section; `spacing` in HWPUNIT.
    case setColumns(count: Int, spacing: Int)
    /// 구역 설정 and 쪽 테두리/배경 of the caret's section (rhwp's JSON keys).
    case setSectionDef([String: JSONValue])
    case setPageBorder([String: JSONValue])
    /// Page setup of the caret's section: rhwp's PageDef keys in HWPUNIT
    /// (`width`, `height`, `margin*`, `landscape`).
    case setPageDef([String: JSONValue])
    /// Header or footer of the caret's section. In `text`, U+0015, U+0016 and
    /// U+0017 are the page number, page count and file name fields.
    case setHeaderFooter(HeaderFooterSlot, text: String)
    case deleteHeaderFooter(HeaderFooterSlot)
    /// One of rhwp's header/footer templates, e.g. 2 = page number centred.
    case applyHeaderFooterTemplate(HeaderFooterSlot, template: Int)
    /// A table at a collapsed body caret; the caret moves into its first cell.
    case insertTable(rows: Int, columns: Int)
    // The table edits below apply to the (top-level) table holding the caret.
    case insertRow(below: Bool, count: Int = 1)
    case insertColumn(right: Bool, count: Int = 1)
    case deleteRow
    case deleteColumn
    case mergeRight
    case mergeDown
    case splitCell(rows: Int, columns: Int)
    case deleteTable
    /// A web link on the selected text; the address of, or removing, the link at the caret.
    case insertHyperlink(String)
    case updateHyperlink(String)
    case removeHyperlink
    /// A bookmark at a body-text caret.
    case addBookmark(String)
    /// Document style `id` on the selected paragraphs.
    case applyStyle(Int)
    /// A picture floating at the caret; sizes in HWPUNIT and pixels.
    case insertPicture(data: Data, fileExtension: String, width: Int, height: Int, pixelWidth: Int, pixelHeight: Int)
    /// rectangle, ellipse, line or textbox, floating where the caret is; HWPUNIT.
    case insertShape(kind: String, width: Int, height: Int)
    case deleteObject(ObjectAddress)
    /// Engine property names (`width`, `rotationAngle`, `borderColor`, `fillBgColor`,
    /// `hasCaption`, …) of a picture, shape or table.
    case setObjectProperties(ObjectAddress, [String: JSONValue])
    /// 개체 묶기 of pictures and shapes in one section; the result is the group's address.
    case groupObjects(section: Int, objects: [ObjectAddress])
    case ungroupObject(ObjectAddress)
    /// front, back, forward or backward.
    case objectOrder(ObjectAddress, String)
    /// Properties of the caret's cell (`fillType`, `fillColor`, `verticalAlign`, `padding*`, `border*`).
    case setCellProperties([String: JSONValue])
    /// 계산식 in the caret's cell, e.g. `=SUM(ABOVE)`; format `%g` or `%.Nf` (`,` for thousands).
    case setCellFormula(formula: String, format: String)
    /// thousands, addDecimal or removeDecimal on the number in the caret's cell.
    case formatCellNumber(String)
    /// 감추기 on the caret's body paragraph.
    case setPageHide(PageHide)
    /// 새 쪽 번호 from the caret's page.
    case newPageNumber(Int)
    /// Removes the field around the caret.
    case removeField
    /// 각주 (`footnote`) or 미주 (`endnote`) at the caret; each line of `text` is a note paragraph.
    case insertNote(kind: String, text: String)
    /// The text of the note whose marker is at the caret, and deleting that note.
    case setNoteText(String)
    case deleteNote
    /// 각주 모양 / 미주 모양 (`footnote` or `endnote`) of the caret's section.
    case setNoteShape(note: String, props: [String: JSONValue])
    /// 표 나누기 at the caret's row, and 표 붙이기 with the next table.
    case splitTable
    case attachNextTable

    var jsonObject: [String: Any] {
        switch self {
        case let .charFormat(props): ["action": "charFormat", "props": JSONValue.object(props).object]
        case let .paraFormat(props): ["action": "paraFormat", "props": JSONValue.object(props).object]
        case let .replaceAll(query, replacement, caseSensitive):
            ["action": "replaceAll", "query": query, "replacement": replacement, "caseSensitive": caseSensitive]
        case .toggleNumbering: ["action": "toggleNumbering"]
        case .insertPageBreak: ["action": "insertPageBreak"]
        case let .setSectionDef(props): ["action": "setSectionDef", "props": JSONValue.object(props).object]
        case let .setPageBorder(props): ["action": "setPageBorder", "props": JSONValue.object(props).object]
        case let .setColumns(count, spacing): ["action": "setColumns", "count": count, "spacing": spacing]
        case .insertColumnBreak: ["action": "insertColumnBreak"]
        case let .setPageDef(props): ["action": "setPageDef", "props": JSONValue.object(props).object]
        case let .setHeaderFooter(slot, text):
            ["action": "setHeaderFooter", "isHeader": slot.isHeader, "applyTo": slot.applyTo.rawValue, "text": text]
        case let .deleteHeaderFooter(slot):
            ["action": "deleteHeaderFooter", "isHeader": slot.isHeader, "applyTo": slot.applyTo.rawValue]
        case let .applyHeaderFooterTemplate(slot, template):
            ["action": "applyHeaderFooterTemplate", "isHeader": slot.isHeader, "applyTo": slot.applyTo.rawValue,
             "template": template]
        case let .toggleBullet(bullet): ["action": "toggleBullet", "bullet": bullet ?? NSNull()]
        case let .insertTable(rows, columns): ["action": "insertTable", "rows": rows, "cols": columns]
        case let .insertRow(below, count): ["action": "insertRow", "below": below, "count": count]
        case let .insertColumn(right, count): ["action": "insertColumn", "right": right, "count": count]
        case .deleteRow: ["action": "deleteRow"]
        case .deleteColumn: ["action": "deleteColumn"]
        case .mergeRight: ["action": "mergeRight"]
        case .mergeDown: ["action": "mergeDown"]
        case let .splitCell(rows, columns): ["action": "splitCell", "rows": rows, "cols": columns]
        case .deleteTable: ["action": "deleteTable"]
        case let .insertHyperlink(uri): ["action": "insertHyperlink", "uri": uri]
        case let .updateHyperlink(uri): ["action": "updateHyperlink", "uri": uri]
        case .removeHyperlink: ["action": "removeHyperlink"]
        case let .addBookmark(name): ["action": "addBookmark", "name": name]
        case let .applyStyle(id): ["action": "applyStyle", "id": id]
        case let .insertPicture(data, fileExtension, width, height, pixelWidth, pixelHeight):
            ["action": "insertPicture", "data": data.base64EncodedString(), "extension": fileExtension,
             "width": width, "height": height, "naturalWidth": pixelWidth, "naturalHeight": pixelHeight]
        case let .insertShape(kind, width, height): ["action": "insertShape", "kind": kind, "width": width, "height": height]
        case let .deleteObject(object): ["action": "deleteObject"].merging(object.json) { $1 }
        case let .setObjectProperties(object, props):
            ["action": "setObjectProperties", "props": JSONValue.object(props).object].merging(object.json) { $1 }
        case let .groupObjects(section, objects):
            ["action": "groupObjects", "section": section,
             "objects": objects.map { ["paragraph": $0.paragraph, "control": $0.control] }]
        case let .ungroupObject(object): ["action": "ungroupObject"].merging(object.json) { $1 }
        case let .objectOrder(object, operation):
            ["action": "objectOrder", "operation": operation].merging(object.json) { $1 }
        case let .setCellProperties(props): ["action": "setCellProperties", "props": JSONValue.object(props).object]
        case let .setPageHide(hide):
            ["action": "setPageHide", "header": hide.header, "footer": hide.footer, "masterPage": hide.masterPage,
             "border": hide.border, "fill": hide.fill, "pageNumber": hide.pageNumber]
        case let .newPageNumber(start): ["action": "newPageNumber", "start": start]
        case let .setCellFormula(formula, format): ["action": "setCellFormula", "formula": formula, "format": format]
        case let .formatCellNumber(operation): ["action": "formatCellNumber", "operation": operation]
        case .removeField: ["action": "removeField"]
        case let .insertNote(kind, text): ["action": "insertNote", "kind": kind, "text": text]
        case let .setNoteText(text): ["action": "setNoteText", "text": text]
        case .deleteNote: ["action": "deleteNote"]
        case let .setNoteShape(note, props): ["action": "setNoteShape", "note": note, "props": JSONValue.object(props).object]
        case .splitTable: ["action": "splitTable"]
        case .attachNextTable: ["action": "attachNextTable"]
        }
    }
}

/// A picture, shape or table control in body text, as page object layouts list it.
struct ObjectAddress: Codable, Equatable, Hashable, Sendable {
    var section: Int
    var paragraph: Int
    var control: Int

    var json: [String: Any] { ["section": section, "paragraph": paragraph, "control": control] }
}

/// 감추기: what a paragraph hides from its page on.
struct PageHide: Codable, Equatable, Sendable {
    var header = false
    var footer = false
    var masterPage = false
    var border = false
    var fill = false
    var pageNumber = false

    init() {}

    init(_ json: JSONValue) {
        header = json["hideHeader"]?.bool ?? false
        footer = json["hideFooter"]?.bool ?? false
        masterPage = json["hideMasterPage"]?.bool ?? false
        border = json["hideBorder"]?.bool ?? false
        fill = json["hideFill"]?.bool ?? false
        pageNumber = json["hidePageNum"]?.bool ?? false
    }
}

/// Editing marks on screen renders: 문단 부호, 조판 부호, 투명 선. View state only.
struct EditorMarks: Codable, Equatable, Sendable {
    var paragraphMarks = false
    var controlCodes = false
    var transparentBorders = false
    /// Clip drawing to the page; off shows what spills over.
    var clip = true
}

/// A header or footer of a section, by the pages it applies to.
struct HeaderFooterSlot: Codable, Equatable, Sendable {
    enum Pages: Int, Codable, Sendable {
        case both = 0, even = 1, odd = 2
    }

    var isHeader: Bool
    var applyTo: Pages = .both
}

/// Read-only queries at the current selection.
enum EditQuery: Codable, Sendable {
    case charProperties
    case paraProperties
    /// Page setup of the caret's section.
    case pageDef
    case sectionDef
    case pageBorder
    /// `{"count","spacing",…}`: columns of the caret's section.
    case columns
    /// `{"sections":[html…]}`: each section as an HTML fragment, for export.
    case documentHtml
    /// `{"found":false}` or the note whose marker is at the caret: `kind`, `number`, `text`.
    case noteAtCaret
    /// `numberFormat`, `prefixChar`, `suffixChar`, `startNumber`, `numbering`, `placement`, …
    case noteShape(String)
    /// `{"controls":[{"type","x","y","w","h","secIdx","paraIdx","controlIdx",…}]}` on a page.
    case pageObjects(page: Int)
    /// A picture's, shape's or table's properties, with `kind` picture, shape or table.
    case objectProperties(ObjectAddress)
    case cellProperties
    /// `{"exists","hideHeader",…}` of the caret's paragraph.
    case pageHide
    /// `{"inField":Bool,…}` at the caret.
    case fieldInfo
    /// The link at the caret, `{"text","uri",…}`, or null.
    case hyperlink
    /// `{"styles":[{"id","name","type"}],"current":id}`.
    case styles
    /// `{"exists":…,"text":…}` for a header or footer of the caret's section.
    case headerFooter(HeaderFooterSlot)
    case find(query: String, forward: Bool, caseSensitive: Bool)

    var jsonObject: [String: Any] {
        switch self {
        case .charProperties: ["kind": "charProperties"]
        case .paraProperties: ["kind": "paraProperties"]
        case .pageDef: ["kind": "pageDef"]
        case .sectionDef: ["kind": "sectionDef"]
        case .pageBorder: ["kind": "pageBorder"]
        case .columns: ["kind": "columns"]
        case .documentHtml: ["kind": "documentHtml"]
        case .noteAtCaret: ["kind": "noteAtCaret"]
        case let .noteShape(note): ["kind": "noteShape", "note": note]
        case let .pageObjects(page): ["kind": "pageObjects", "page": page]
        case let .objectProperties(object): ["kind": "objectProperties"].merging(object.json) { $1 }
        case .cellProperties: ["kind": "cellProperties"]
        case .pageHide: ["kind": "pageHide"]
        case .fieldInfo: ["kind": "fieldInfo"]
        case .hyperlink: ["kind": "hyperlink"]
        case .styles: ["kind": "styles"]
        case let .headerFooter(slot): ["kind": "headerFooter", "isHeader": slot.isHeader, "applyTo": slot.applyTo.rawValue]
        case let .find(query, forward, caseSensitive):
            ["kind": "find", "query": query, "forward": forward, "caseSensitive": caseSensitive]
        }
    }
}
