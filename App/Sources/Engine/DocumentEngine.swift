// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import CoreGraphics
import Foundation
import Rhwp

/// Runs a document's `DocumentEditor` on its own `EngineThread` so the UI
/// never waits for layout.
///
/// rhwp re-paginates synchronously after every edit (its native session has
/// no deferred pagination yet), which takes about a second per keystroke in a
/// 383-page document. Operations submitted while the engine is busy are
/// coalesced into one batch: consecutive text is inserted at once and only
/// the latest composition preview or drag selection is applied.
final class DocumentEngine: DocumentEngineClient, @unchecked Sendable {
    enum Operation: Codable, Sendable {
        case click(page: Int, x: Double, y: Double, extendSelection: Bool)
        case drag(page: Int, x: Double, y: Double)
        case select(TextSelection)
        /// Selects scalar offsets within the paragraph holding the focus.
        case selectInFocusParagraph(location: Int, length: Int)
        case insert(String)
        case mark(String)
        case commitMarked
        case cancelMarked
        case command(EditCommand)
        case undo
        case redo
        case paste(String)
        /// Formatting or replace-all; the result lands in `Snapshot.lastResult`.
        case action(EditAction)
        /// Selects the next/previous match; `Snapshot.lastResult` says whether one was found.
        case find(query: String, forward: Bool, caseSensitive: Bool)
        /// Editing marks for later renders.
        case marks(EditorMarks)

        var traceName: String {
            switch self {
            case .click: "click"
            case .drag: "drag"
            case .select, .selectInFocusParagraph: "select"
            case let .insert(text): "insert(\(text.count))"
            case .mark: "mark"
            case .commitMarked: "commit"
            case .cancelMarked: "cancel"
            case .command: "command"
            case .undo: "undo"
            case .redo: "redo"
            case .paste: "paste"
            case .action: "action"
            case .find: "find"
            case .marks: "marks"
            }
        }
    }

    /// The editing state after a batch, with geometry in page layout pixels.
    struct Snapshot: Codable, Sendable {
        var revision: UInt64
        var selection: TextSelection?
        var markedSelection: TextSelection?
        var caret: CaretRect?
        var selectionRects: [SelectionRect] = []
        var markedRects: [SelectionRect] = []
        var canUndo = false
        var canRedo = false
        var isDirty = false
        /// Set only when the page count changed.
        var pageSizes: [CGSize]?
        var contentsChanged = false
        /// Why an operation in the batch was refused, if one was.
        var failure: String?
        /// The last submitted operation this snapshot includes (see `submit`).
        var appliedSequence: UInt64 = 0
        /// Whether the last batch that changed the document was slow.
        var engineIsSlow = false
        /// Result of the last action or find in the batch (`{"found":Bool}` for find).
        var lastResult: JSONValue?
        /// Formatting at the selection start, for toolbar and menu state.
        var charProperties: JSONValue?
        var paraProperties: JSONValue?
        /// The marks renders now draw; pages rendered with others are stale.
        var marks = EditorMarks()
    }

    let initialPageSizes: [CGSize]
    /// Delivered on the main thread after every batch.
    @MainActor var onSnapshot: ((Snapshot) -> Void)?

    private let thread: EngineThread
    private let lock = NSLock()
    private var pending: [Operation] = []
    private var drainScheduled = false
    private var submitted: UInt64 = 0
    private var lastEditBatchSeconds: TimeInterval = 0

    // Engine-thread state.
    private var editor: DocumentEditor!
    private var pageCount = 0
    private var dragAnchor: TextPosition?
    private var lastResult: JSONValue?
    private var marks = EditorMarks()

    /// Opens `data` (empty data creates a blank document) on a new engine thread.
    init(data: Data, name: String = "rhwp engine") throws {
        let thread = EngineThread(name: name)
        let opened: (editor: DocumentEditor, sizes: [CGSize])
        do {
            opened = try thread.sync {
                let session = try RhwpSession(data: data)
                let sizes = try (0..<session.pageCount).map { try session.pageSize($0) }
                return (try DocumentEditor(session: session), sizes)
            }
        } catch {
            thread.stop {}
            throw error
        }
        self.thread = thread
        editor = opened.editor
        pageCount = opened.sizes.count
        initialPageSizes = opened.sizes
    }

    /// Closes the session on its thread and ends the thread.
    func close() {
        thread.stop { [self] in editor = nil }
    }

    /// Queues an operation and returns its sequence number; snapshots report
    /// the last sequence number they include.
    @discardableResult
    func submit(_ operation: Operation) -> UInt64 {
        lock.lock()
        pending.append(operation)
        submitted += 1
        let sequence = submitted
        let schedule = !drainScheduled
        drainScheduled = true
        lock.unlock()
        if schedule {
            thread.async { [self] in drain() }
        }
        return sequence
    }

    /// Whether the last batch that changed the document took long enough that
    /// the UI should not wait for the engine to show typing.
    var isSlow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lastEditBatchSeconds > Self.slowBatchSeconds
    }

    private static let slowBatchSeconds: TimeInterval = 0.15

    /// Runs `body` with the editor after all submitted operations.
    func sync<T>(timeout: TimeInterval = 60, _ body: @escaping (DocumentEditor) throws -> T) throws -> T {
        try thread.sync(timeout: timeout) { [self] in try body(editor) }
    }

    /// Renders a page on the engine thread; `completion` runs on the main thread.
    func render(page: Int, scale: Double, completion: @escaping @MainActor @Sendable (CGImage?, UInt64) -> Void) {
        renderPixels(page: page, scale: scale) { frame, revision in
            let image = frame?.makeImage()
            DispatchQueue.main.async { completion(image, revision) }
        }
    }

    /// Renders a page on the engine thread; `completion` runs on the engine thread.
    func renderPixels(page: Int, scale: Double, completion: @escaping @Sendable (PixelFrame?, UInt64) -> Void) {
        thread.async { [self] in
            let revision = editor.revision
            completion(try? editor.session.renderPixels(page, scale: scale), revision)
        }
    }

    func copySelection() throws -> String {
        try sync(timeout: 10) { try $0.copy() }
    }

    func surroundingText(timeout: TimeInterval) throws -> ImeContext {
        try sync(timeout: timeout) { try $0.surroundingText() }
    }

    func prepareSave(_ format: SaveFormat) throws -> PreparedSave {
        try sync { try $0.session.prepareSave(format) }
    }

    func acknowledgeSave(_ token: UInt64) throws -> Bool {
        try sync { try $0.session.acknowledgeSave(token) }
    }

    func cancelSave(_ token: UInt64) throws {
        _ = try sync { try $0.session.cancelSave(token) }
    }

    /// The current document as a vector PDF through rhwp's print profile
    /// (at most 256 pages). rhwp exports from a file, so the current state is
    /// serialized to a temporary file first; in the XPC service that is the
    /// service's own container.
    func exportPDF() throws -> Data {
        let bytes = try sync(timeout: 300) { editor -> Data in
            let prepared = try editor.session.prepareSave(.hwp)
            try editor.session.cancelSave(prepared.token)
            return prepared.data
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("document.hwp")
        let output = directory.appendingPathComponent("document.pdf")
        try bytes.write(to: input)
        let result = try Rhwp.exportPDFDirect(inputFile: input, outputFile: output)
        guard result.ok else { throw EngineServiceError.remote(result.error ?? "PDF를 만들지 못했습니다.") }
        return try Data(contentsOf: output)
    }

    func query(_ query: EditQuery) throws -> JSONValue {
        try sync { try $0.query(query) }
    }

    func documentText() throws -> String {
        try sync { editor in
            let selection = editor.selection
            if selection == nil { try editor.select(.collapsed(at: .documentStart)) }
            try editor.execute(.selectAll)
            defer { if let selection { _ = try? editor.select(selection) } }
            return try editor.copy()
        }
    }

    // MARK: Engine thread

    private func drain() {
        lock.lock()
        let batch = Self.coalesce(pending)
        pending.removeAll()
        drainScheduled = false
        let appliedSequence = submitted
        lock.unlock()

        let revision = editor.revision
        var failure: String?
        let started = Date()
        var steps: [String] = []
        for operation in batch {
            let stepStarted = Date()
            do {
                try apply(operation)
            } catch let RhwpNativeHostError.failed(code: "unsupported", message) {
                failure = Self.unsupportedMessage(message)
            } catch let RhwpNativeHostError.failed(_, message) {
                failure = "편집하지 못했습니다: \(Self.argumentMessage(message))"
            } catch {
                failure = "편집하지 못했습니다: \(error)"
            }
            steps.append("\(operation.traceName) \(Self.millis(since: stepStarted))")
        }
        let snapshotStarted = Date()
        var snapshot = makeSnapshot(contentsChanged: editor.revision != revision, failure: failure)
        snapshot.appliedSequence = appliedSequence
        snapshot.lastResult = lastResult
        snapshot.marks = marks
        lastResult = nil
        lock.lock()
        if snapshot.contentsChanged {
            lastEditBatchSeconds = snapshotStarted.timeIntervalSince(started)
        }
        snapshot.engineIsSlow = lastEditBatchSeconds > Self.slowBatchSeconds
        lock.unlock()
        if Self.tracing {
            let line = "[engine] batch \(Self.millis(since: started)) ms: \(steps.joined(separator: ", ")), "
                + "snapshot \(Self.millis(since: snapshotStarted))\n"
            FileHandle.standardError.write(Data(line.utf8))
        }
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated { onSnapshot?(snapshot) }
        }
    }

    private func apply(_ operation: Operation) throws {
        switch operation {
        case let .click(page, x, y, extend):
            let hit = try editor.session.hitTest(page: page, x: x, y: y).position
            let anchor = extend ? (editor.selection?.anchor ?? hit) : hit
            dragAnchor = anchor
            try editor.select(TextSelection(anchor: anchor, focus: hit))
        case let .drag(page, x, y):
            guard let anchor = dragAnchor else { return }
            let hit = try editor.session.hitTest(page: page, x: x, y: y).position
            if hit != editor.selection?.focus {
                try editor.select(TextSelection(anchor: anchor, focus: hit))
            }
        case let .select(selection):
            try editor.select(selection)
        case let .selectInFocusParagraph(location, length):
            guard var anchor = editor.selection?.focus else { return }
            anchor.scalarOffset = location
            try editor.select(TextSelection(anchor: anchor, focus: anchor.offset(by: length)))
        case let .insert(text):
            try editor.insertText(text)
        case let .mark(text):
            try editor.setMarkedText(text)
        case .commitMarked:
            try editor.commitMarkedText()
        case .cancelMarked:
            try editor.cancelMarkedText()
        case let .command(command):
            try editor.execute(command)
        case .undo:
            try editor.undo()
        case .redo:
            try editor.redo()
        case let .paste(text):
            try editor.paste(text)
        case let .action(action):
            lastResult = try editor.apply(action)
        case let .marks(newMarks):
            try editor.session.setEditorMarks(newMarks)
            marks = newMarks
        case let .find(query, forward, caseSensitive):
            lastResult = .object(["found": .bool(try editor.find(query, forward: forward, caseSensitive: caseSensitive))])
        }
    }

    /// The engine's reasons for refusing an edit, in Korean.
    static func unsupportedMessage(_ message: String) -> String {
        let reasons: [(String, String)] = [
            ("holds an object", "그림·표 같은 개체가 든 범위는 글자 편집으로 지울 수 없습니다."),
            ("table-cell boundary", "선택 범위가 표 셀 경계를 넘을 수 없습니다."),
            ("inline-object", "글자처럼 취급하는 개체(표·그림 등)가 있는 문단은 아직 편집할 수 없습니다."),
            ("top-level tables only", "표 안에 든 표는 줄·칸을 편집할 수 없습니다."),
            ("breaks go into body text", "쪽·단 나누기는 본문에서만 됩니다."),
            ("HTML paste into table cells", "표 셀에는 서식 없는 글자만 붙일 수 있습니다."),
            ("stacking order applies to shapes", "순서는 도형에만 바꿀 수 있습니다."),
            ("pictures are inserted in body text", "그림은 본문에만 넣을 수 있습니다."),
        ]
        return reasons.first { message.contains($0.0) }?.1
            ?? "이 위치는 아직 편집할 수 없습니다 (글상자, 머리말 안 등)"
    }

    /// Messages of refused arguments; the core's own are often Korean already.
    static func argumentMessage(_ message: String) -> String {
        let reasons: [(String, String)] = [
            ("non-empty selection", "글자를 먼저 고르세요."),
            ("a link needs selected text", "링크를 붙일 글자를 한 문단 안에서 고르세요."),
            ("no link at the caret", "캐럿 자리에 링크가 없습니다."),
            ("not in a table", "캐럿이 표 안에 있지 않습니다."),
            ("no cell at that grid position", "그 방향에 셀이 없습니다."),
        ]
        return reasons.first { message.contains($0.0) }?.1 ?? message
    }

    private func makeSnapshot(contentsChanged: Bool, failure: String?) -> Snapshot {
        let session = editor.session
        var snapshot = Snapshot(
            revision: editor.revision, selection: editor.selection, markedSelection: editor.markedSelection,
            contentsChanged: contentsChanged, failure: failure
        )
        if let info = try? session.info() {
            snapshot.canUndo = info.canUndo
            snapshot.canRedo = info.canRedo
            snapshot.isDirty = info.isDirty
            if info.pageCount != pageCount {
                pageCount = info.pageCount
                snapshot.pageSizes = try? (0..<info.pageCount).map { try session.pageSize($0) }
            }
        }
        if let selection = editor.selection {
            if selection.isCollapsed {
                snapshot.caret = try? session.caret(at: selection.focus)
            } else {
                snapshot.selectionRects = (try? session.selectionRects(selection)) ?? []
            }
        }
        if let marked = editor.markedSelection {
            snapshot.markedRects = (try? session.selectionRects(marked)) ?? []
        }
        if editor.isEditing {
            snapshot.charProperties = try? editor.query(.charProperties)
            snapshot.paraProperties = try? editor.query(.paraProperties)
        }
        return snapshot
    }

    /// Set HWPMAC_ENGINE_TRACE=1 to log per-batch timings to stderr.
    private static let tracing = ProcessInfo.processInfo.environment["HWPMAC_ENGINE_TRACE"] == "1"

    private static func millis(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    /// Merges operations that only the last of a run matters for, or that
    /// can be applied at once, without changing the resulting document.
    static func coalesce(_ operations: [Operation]) -> [Operation] {
        var result: [Operation] = []
        for operation in operations {
            switch (result.last, operation) {
            // Inserting while composing replaces the preview with the text, so
            // a preview immediately followed by an insert is never seen.
            case (.mark?, .mark), (.drag?, .drag):
                result[result.count - 1] = operation
            case (.mark?, .insert):
                result.removeLast()
                append(operation, to: &result)
            default:
                append(operation, to: &result)
            }
        }
        return result
    }

    private static func append(_ operation: Operation, to result: inout [Operation]) {
        if case let .insert(text) = operation, case let .insert(previous)? = result.last {
            result[result.count - 1] = .insert(previous + text)
        } else {
            result.append(operation)
        }
    }
}
