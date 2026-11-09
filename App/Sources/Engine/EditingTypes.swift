// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import Foundation

// Swift mirrors of the rhwp native host ABI v1 editing types.

struct CellPathEntry: Codable, Equatable {
    var control: Int
    var cell: Int
    var paragraph: Int
}

/// A text position. `scalarOffset` counts Unicode scalars within the paragraph.
struct TextPosition: Codable, Equatable {
    var section: Int
    var paragraph: Int
    var scalarOffset: Int
    var cellPath: [CellPathEntry] = []

    static let documentStart = TextPosition(section: 0, paragraph: 0, scalarOffset: 0)

    /// Document order for positions in the same text flow.
    func precedes(_ other: TextPosition) -> Bool {
        (section, paragraph, scalarOffset) < (other.section, other.paragraph, other.scalarOffset)
    }

    func offset(by scalars: Int) -> TextPosition {
        var moved = self
        moved.scalarOffset += scalars
        return moved
    }
}

struct TextSelection: Codable, Equatable {
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
struct CaretRect: Decodable {
    var page: Int
    var x: Double
    var y: Double
    var height: Double
}

struct SelectionRect: Decodable {
    struct Bounds: Decodable {
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
struct ImeContext: Decodable {
    var text: String
    var cursorScalar: Int
    var absoluteStartScalar: Int
}

struct HitTestResult: Decodable {
    var position: TextPosition
    var caret: CaretRect?
}

enum EditCommand {
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
        }
    }
}

enum SaveFormat: String {
    case hwp
    case hwpx
}

/// One item of rhwp's content-loss report for a save.
struct ContentLoss: Decodable {
    var code: String
    var subject: String
    var path: String
    var reason: String
}

struct SaveReport: Decodable {
    var count: Int
    var losses: [ContentLoss]
    var outputFormat: String
}

/// Serialized bytes waiting for the host to write them, then acknowledge or cancel `token`.
struct PreparedSave {
    var token: UInt64
    var revision: UInt64
    var data: Data
    var report: SaveReport?
}
