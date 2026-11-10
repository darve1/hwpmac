// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import CoreGraphics
import Foundation
import Rhwp

enum RhwpSessionError: Error {
    case imageCreationFailed
}

/// An open rhwp native session.
///
/// The native ABI binds every handle to the OS thread that opened it, so each
/// call checks that thread instead of relying on actor isolation.
final class RhwpSession {
    let handle: UInt64
    let pageCount: Int
    private let ownerThread = pthread_self()

    init(data: Data) throws {
        let opened = try Rhwp.sessionOpen(data: data)
        guard let handle = (opened["handle"] as? NSNumber)?.uint64Value,
              let pageCount = (opened["pageCount"] as? NSNumber)?.intValue
        else { throw RhwpNativeHostError.invalidResponse }
        self.handle = handle
        self.pageCount = pageCount
    }

    deinit {
        checkOwnerThread()
        try? Rhwp.sessionClose(handle: handle)
    }

    /// Page size in rhwp layout pixels (96 per inch).
    func pageSize(_ page: Int) throws -> CGSize {
        let response = try request(["op": "pageSize", "page": page])
        guard let size = response["size"] as? [String: Any],
              let width = (size["width"] as? NSNumber)?.doubleValue,
              let height = (size["height"] as? NSNumber)?.doubleValue
        else { throw RhwpNativeHostError.invalidResponse }
        return CGSize(width: width, height: height)
    }

    /// Renders a whole page; `scale` multiplies layout pixels.
    func renderPage(_ page: Int, scale: Double) throws -> CGImage {
        guard let image = try renderPixels(page, scale: scale).makeImage() else {
            throw RhwpSessionError.imageCreationFailed
        }
        return image
    }

    /// Renders a whole page to premultiplied RGBA pixels.
    func renderPixels(_ page: Int, scale: Double) throws -> PixelFrame {
        let frame = try request(["op": "render", "page": page, "scale": scale])
        guard let buffer = (frame["buffer"] as? NSNumber)?.uint64Value
        else { throw RhwpNativeHostError.invalidResponse }
        // The buffer's ownership ends here even if copying fails.
        defer { try? Rhwp.sessionBufferRelease(buffer: buffer) }

        guard let width = (frame["width"] as? NSNumber)?.intValue,
              let height = (frame["height"] as? NSNumber)?.intValue,
              let stride = (frame["stride"] as? NSNumber)?.intValue,
              let byteLength = (frame["byteLength"] as? NSNumber)?.intValue,
              frame["pixelFormat"] as? String == "rgba8Premultiplied",
              byteLength == stride * height
        else { throw RhwpNativeHostError.invalidResponse }

        let pixels = try Rhwp.sessionBufferCopy(buffer: buffer, byteLength: byteLength)
        return PixelFrame(data: pixels, width: width, height: height, stride: stride)
    }

    func info() throws -> SessionInfo {
        try decode(SessionInfo.self, from: request(["op": "info"]))
    }

    // MARK: Editing

    /// Starts editing on the first call and moves the selection afterwards.
    func beginEdit(_ selection: TextSelection, expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "beginEdit", "selection": json(selection), "expectedRevision": expectedRevision])
    }

    func setSelection(_ selection: TextSelection, expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "setSelection", "selection": json(selection), "expectedRevision": expectedRevision])
    }

    func replaceSelection(_ text: String, expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "replaceSelection", "text": text, "expectedRevision": expectedRevision])
    }

    func execute(_ command: EditCommand, preferredX: Double?, expectedRevision: UInt64) throws -> (EditOutcome, preferredX: Double?) {
        let response = try request([
            "op": "executeCommand", "command": command.jsonObject(preferredX: preferredX), "expectedRevision": expectedRevision,
        ])
        return (try decode(EditOutcome.self, from: response["outcome"]), (response["preferredX"] as? NSNumber)?.doubleValue)
    }

    func beginComposition(expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "beginComposition", "expectedRevision": expectedRevision])
    }

    func updateComposition(_ id: UInt64, text: String, expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "updateComposition", "compositionId": id, "text": text, "expectedRevision": expectedRevision])
    }

    func commitComposition(_ id: UInt64, expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "commitComposition", "compositionId": id, "expectedRevision": expectedRevision])
    }

    func cancelComposition(_ id: UInt64, expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "cancelComposition", "compositionId": id, "expectedRevision": expectedRevision])
    }

    func undo(expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "undo", "expectedRevision": expectedRevision])
    }

    func redo(expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "redo", "expectedRevision": expectedRevision])
    }

    /// Plain text of the selection.
    func copySelection(expectedRevision: UInt64) throws -> String {
        let response = try request(["op": "copySelection", "expectedRevision": expectedRevision])
        return try plainText(fromClipboard: response)
    }

    func cutSelection(expectedRevision: UInt64) throws -> (text: String, outcome: EditOutcome) {
        let response = try request(["op": "cutSelection", "expectedRevision": expectedRevision])
        return (try plainText(fromClipboard: response), try decode(EditOutcome.self, from: response["outcome"]))
    }

    func pasteText(_ text: String, expectedRevision: UInt64) throws -> EditOutcome {
        try edit(["op": "pasteText", "text": text, "expectedRevision": expectedRevision])
    }

    func applyAction(_ action: EditAction, expectedRevision: UInt64) throws -> (EditOutcome, JSONValue) {
        let response = try request(["op": "applyAction", "action": action.jsonObject, "expectedRevision": expectedRevision])
        return (try decode(EditOutcome.self, from: response["outcome"]), JSONValue(response["result"]))
    }

    func query(_ query: EditQuery) throws -> JSONValue {
        JSONValue(try request(["op": "query", "query": query.jsonObject])["result"])
    }

    func imeContext(expectedRevision: UInt64) throws -> ImeContext {
        try decode(ImeContext.self, from: request(["op": "imeContext", "expectedRevision": expectedRevision])["context"])
    }

    // MARK: Geometry

    func hitTest(page: Int, x: Double, y: Double) throws -> HitTestResult {
        try decode(HitTestResult.self, from: request(["op": "hitTest", "page": page, "x": x, "y": y])["hit"])
    }

    func caret(at position: TextPosition) throws -> CaretRect {
        try decode(CaretRect.self, from: request(["op": "caret", "position": json(position)])["caret"])
    }

    func selectionRects(_ selection: TextSelection) throws -> [SelectionRect] {
        try decode([SelectionRect].self, from: request(["op": "selectionRects", "selection": json(selection)])["rects"])
    }

    // MARK: Saving

    /// Serializes the document. The caller must write `data` and then call
    /// `acknowledgeSave` only after the file is complete, or `cancelSave`.
    func prepareSave(_ format: SaveFormat) throws -> PreparedSave {
        let response = try request(["op": "prepareSave", "format": format.rawValue])
        guard let token = (response["token"] as? NSNumber)?.uint64Value,
              let revision = (response["revision"] as? NSNumber)?.uint64Value,
              let buffer = (response["buffer"] as? NSNumber)?.uint64Value,
              let byteLength = (response["byteLength"] as? NSNumber)?.intValue
        else { throw RhwpNativeHostError.invalidResponse }
        let data: Data
        do {
            defer { try? Rhwp.sessionBufferRelease(buffer: buffer) }
            data = try Rhwp.sessionBufferCopy(buffer: buffer, byteLength: byteLength)
        } catch {
            _ = try? cancelSave(token)
            throw error
        }
        let report = response["report"].flatMap { $0 is NSNull ? nil : try? decode(SaveReport.self, from: $0) }
        return PreparedSave(token: token, revision: revision, data: data, report: report)
    }

    /// Returns whether the document is still dirty (edited after the saved revision).
    @discardableResult
    func acknowledgeSave(_ token: UInt64) throws -> Bool {
        (try request(["op": "acknowledgeSave", "token": token])["isDirty"] as? Bool) ?? true
    }

    @discardableResult
    func cancelSave(_ token: UInt64) throws -> Bool {
        (try request(["op": "cancelSave", "token": token])["isDirty"] as? Bool) ?? true
    }

    // MARK: Plumbing

    /// Editing marks for later renders; neither the document nor its revision changes.
    func setEditorMarks(_ marks: EditorMarks) throws {
        _ = try request(["op": "setEditorMarks", "marks": [
            "paragraphMarks": marks.paragraphMarks, "controlCodes": marks.controlCodes,
            "transparentBorders": marks.transparentBorders, "clip": marks.clip, "formMode": marks.formMode,
        ]])
    }

    private func request(_ body: [String: Any]) throws -> [String: Any] {
        checkOwnerThread()
        return try Rhwp.sessionRequest(handle: handle, request: body)
    }

    private func edit(_ body: [String: Any]) throws -> EditOutcome {
        try decode(EditOutcome.self, from: request(body)["outcome"])
    }

    private func plainText(fromClipboard response: [String: Any]) throws -> String {
        guard let payload = response["payload"] as? [String: Any], let text = payload["plainText"] as? String
        else { throw RhwpNativeHostError.invalidResponse }
        return text
    }

    private func json(_ value: some Encodable) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    private func decode<T: Decodable>(_ type: T.Type, from object: Any?) throws -> T {
        guard let object, !(object is NSNull) else { throw RhwpNativeHostError.invalidResponse }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed])
        return try JSONDecoder().decode(type, from: data)
    }

    private func checkOwnerThread() {
        precondition(pthread_equal(ownerThread, pthread_self()) != 0,
                     "rhwp session used off the thread that opened it")
    }
}
