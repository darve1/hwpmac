// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import Foundation
import Rhwp

/// Body-text editing on top of an `RhwpSession`: tracks the revision, the
/// selection and the active input-method composition.
///
/// It speaks in input-method terms (marked text, insert, commands) so the
/// AppKit view and the command-line edit check drive the same code path.
final class DocumentEditor {
    let session: RhwpSession
    private(set) var revision: UInt64
    /// `nil` until the first click or `begin(at:)`; the session is view-only until then.
    private(set) var selection: TextSelection?
    private(set) var markedText = ""
    private(set) var markedStart: TextPosition?
    private var compositionId: UInt64?
    private var preferredX: Double?

    init(session: RhwpSession) throws {
        self.session = session
        revision = try session.info().revision
    }

    var isEditing: Bool { selection != nil }
    var hasMarkedText: Bool { compositionId != nil }

    /// Marked (uncommitted) text as a selection, for underlining.
    var markedSelection: TextSelection? {
        guard let markedStart, !markedText.isEmpty else { return nil }
        return TextSelection(anchor: markedStart, focus: markedStart.offset(by: markedText.unicodeScalars.count))
    }

    // MARK: Selection

    @discardableResult
    func select(_ newSelection: TextSelection) throws -> EditOutcome {
        try commitMarkedText()
        let outcome = selection == nil
            ? try session.beginEdit(newSelection, expectedRevision: revision)
            : try session.setSelection(newSelection, expectedRevision: revision)
        preferredX = nil
        return apply(outcome)
    }

    // MARK: Text input

    /// Inserts committed text. While composing, this finishes the composition
    /// with `text`, which is how input methods deliver a completed syllable.
    @discardableResult
    func insertText(_ text: String) throws -> EditOutcome {
        preferredX = nil
        if let id = compositionId {
            apply(try session.updateComposition(id, text: text, expectedRevision: revision))
            return try finishComposition { try self.session.commitComposition(id, expectedRevision: self.revision) }
        }
        return apply(try session.replaceSelection(text, expectedRevision: revision))
    }

    /// Shows uncommitted input-method text; empty text cancels the composition.
    @discardableResult
    func setMarkedText(_ text: String) throws -> EditOutcome? {
        if text.isEmpty {
            return try cancelMarkedText()
        }
        if compositionId == nil {
            let outcome = apply(try session.beginComposition(expectedRevision: revision))
            markedStart = outcome.selection.start
        }
        guard let id = compositionId else { throw RhwpNativeHostError.invalidResponse }
        let outcome = apply(try session.updateComposition(id, text: text, expectedRevision: revision))
        markedText = text
        return outcome
    }

    @discardableResult
    func commitMarkedText() throws -> EditOutcome? {
        guard let id = compositionId else { return nil }
        return try finishComposition { try self.session.commitComposition(id, expectedRevision: self.revision) }
    }

    @discardableResult
    func cancelMarkedText() throws -> EditOutcome? {
        guard let id = compositionId else { return nil }
        return try finishComposition { try self.session.cancelComposition(id, expectedRevision: self.revision) }
    }

    // MARK: Commands

    @discardableResult
    func execute(_ command: EditCommand) throws -> EditOutcome {
        try commitMarkedText()
        let (outcome, nextPreferredX) = try session.execute(
            command, preferredX: command.isVertical ? preferredX : nil, expectedRevision: revision
        )
        preferredX = command.isVertical ? nextPreferredX : nil
        return apply(outcome)
    }

    @discardableResult
    func undo() throws -> EditOutcome {
        try commitMarkedText()
        return apply(try session.undo(expectedRevision: revision))
    }

    @discardableResult
    func redo() throws -> EditOutcome {
        try commitMarkedText()
        return apply(try session.redo(expectedRevision: revision))
    }

    /// Applies a formatting or document-wide action as one undo entry.
    @discardableResult
    func apply(_ action: EditAction) throws -> JSONValue {
        try commitMarkedText()
        let (outcome, result) = try session.applyAction(action, expectedRevision: revision)
        apply(outcome)
        return result
    }

    func query(_ query: EditQuery) throws -> JSONValue {
        try session.query(query)
    }

    /// Selects the next (or previous) match of `text` from the caret. Returns
    /// false when there is none.
    @discardableResult
    func find(_ text: String, forward: Bool, caseSensitive: Bool) throws -> Bool {
        try commitMarkedText()
        let hit = try session.query(.find(query: text, forward: forward, caseSensitive: caseSensitive))
        guard hit["found"]?.bool == true, let position = hit["position"], let length = hit["length"]?.number
        else { return false }
        // The match may be inside a table cell; `position` carries its cell path.
        let start = try JSONDecoder().decode(TextPosition.self, from: JSONEncoder().encode(position))
        try select(forward ? TextSelection(anchor: start, focus: start.offset(by: Int(length)))
                           : TextSelection(anchor: start.offset(by: Int(length)), focus: start))
        return true
    }

    /// Paragraph text around the focus; does not change the selection.
    func surroundingText() throws -> ImeContext {
        try session.imeContext(expectedRevision: revision)
    }

    func copy() throws -> String {
        try session.copySelection(expectedRevision: revision)
    }

    func cut() throws -> String {
        try commitMarkedText()
        let (text, outcome) = try session.cutSelection(expectedRevision: revision)
        apply(outcome)
        return text
    }

    @discardableResult
    func paste(_ text: String) throws -> EditOutcome {
        try commitMarkedText()
        return apply(try session.pasteText(text, expectedRevision: revision))
    }

    // MARK: Private

    private func finishComposition(_ finish: () throws -> EditOutcome) throws -> EditOutcome {
        defer {
            markedText = ""
            markedStart = nil
        }
        return apply(try finish())
    }

    @discardableResult
    private func apply(_ outcome: EditOutcome) -> EditOutcome {
        revision = outcome.revision
        selection = outcome.selection
        compositionId = outcome.compositionId
        return outcome
    }
}
