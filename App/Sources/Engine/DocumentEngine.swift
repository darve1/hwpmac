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
final class DocumentEngine: @unchecked Sendable {
    enum Operation: Sendable {
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
            }
        }
    }

    /// The editing state after a batch, with geometry in page layout pixels.
    struct Snapshot: Sendable {
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
        return lastEditBatchSeconds > 0.15
    }

    /// Runs `body` with the editor after all submitted operations.
    func sync<T>(timeout: TimeInterval = 60, _ body: @escaping (DocumentEditor) throws -> T) throws -> T {
        try thread.sync(timeout: timeout) { [self] in try body(editor) }
    }

    /// Renders a page on the engine thread; `completion` runs on the main thread.
    func render(page: Int, scale: Double, completion: @escaping @MainActor @Sendable (CGImage?, UInt64) -> Void) {
        thread.async { [self] in
            let revision = editor.revision
            let image = try? editor.session.renderPage(page, scale: scale)
            DispatchQueue.main.async { completion(image, revision) }
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
            } catch RhwpNativeHostError.failed(code: "unsupported", _) {
                failure = "이 위치는 아직 편집할 수 없습니다 (표, 개체 등이 있는 문단)"
            } catch {
                failure = "편집하지 못했습니다: \(error)"
            }
            steps.append("\(operation.traceName) \(Self.millis(since: stepStarted))")
        }
        let snapshotStarted = Date()
        var snapshot = makeSnapshot(contentsChanged: editor.revision != revision, failure: failure)
        snapshot.appliedSequence = appliedSequence
        if snapshot.contentsChanged {
            lock.lock()
            lastEditBatchSeconds = snapshotStarted.timeIntervalSince(started)
            lock.unlock()
        }
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
        }
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
