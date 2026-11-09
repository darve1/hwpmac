// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// An HWP/HWPX document edited through rhwp.
///
/// Saving follows rhwp's checkpoint protocol: serialize (`prepareSave`), let
/// NSDocument write the file, then acknowledge the checkpoint only if the
/// write succeeded, or cancel it.
final class HwpDocument: NSDocument {
    private nonisolated static let hwpType = "com.hancom.hwp"
    private nonisolated static let hwpxType = "com.hancom.hwpx"

    private(set) var editor: DocumentEditor?
    private var pageSizes: [CGSize] = []
    private var pendingSave: PreparedSave?
    /// The first in-place overwrite of the opened file asks for confirmation,
    /// because saved files are not yet verified in 한글.
    private var overwriteConfirmed = false

    override init() {
        super.init()
        hasUndoManager = false  // rhwp keeps the edit history.
    }

    override class var autosavesInPlace: Bool {
        false
    }

    // Documents are read on the main thread (concurrent reading is off by
    // default), which is also where the session is used afterwards.
    override func read(from data: Data, ofType typeName: String) throws {
        try MainActor.assumeIsolated {
            let session = try RhwpSession(data: data)
            pageSizes = try (0..<session.pageCount).map { try session.pageSize($0) }
            editor = try DocumentEditor(session: session)
        }
    }

    override func makeWindowControllers() {
        guard let editor else { return }
        addWindowController(DocumentWindowController(editor: editor, pageSizes: pageSizes))
    }

    /// Mirrors rhwp's dirty flag (which undo can clear) into the edited state.
    func syncEditedState() {
        let dirty = (try? editor?.session.info().isDirty) ?? true
        if dirty != isDocumentEdited {
            updateChangeCount(dirty ? .changeDone : .changeCleared)
        }
    }

    // MARK: Saving

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [Self.hwpType, Self.hwpxType]
    }

    override func save(
        to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let session = editor?.session else {
            return completionHandler(CocoaError(.fileWriteUnknown))
        }
        for controller in windowControllers {
            (controller as? DocumentWindowController)?.commitInput()
        }

        let overwritesOriginal = saveOperation == .saveOperation && url == fileURL && !overwriteConfirmed
        confirmOverwrite(needed: overwritesOriginal) { [self] decision in
            switch decision {
            case .cancel:
                return completionHandler(CocoaError(.userCancelled))
            case .saveAs:
                completionHandler(CocoaError(.userCancelled))
                DispatchQueue.main.async { self.saveAs(nil) }
                return
            case .proceed:
                if overwritesOriginal { overwriteConfirmed = true }
            }

            let prepared: PreparedSave
            do {
                prepared = try session.prepareSave(Self.format(forType: typeName))
            } catch {
                return completionHandler(error)
            }
            confirmLosses(prepared.report) { [self] accepted in
                guard accepted else {
                    _ = try? session.cancelSave(prepared.token)
                    return completionHandler(CocoaError(.userCancelled))
                }
                pendingSave = prepared
                writeWithNSDocument(to: url, ofType: typeName, for: saveOperation) { [self] error in
                    pendingSave = nil
                    if let error {
                        _ = try? session.cancelSave(prepared.token)
                        return completionHandler(error)
                    }
                    do {
                        try session.acknowledgeSave(prepared.token)
                    } catch {
                        return completionHandler(error)
                    }
                    completionHandler(nil)
                    if saveOperation == .saveToOperation { syncEditedState() }
                }
            }
        }
    }

    /// NSDocument's own safe-save; it calls `data(ofType:)` for `pendingSave`.
    private func writeWithNSDocument(
        to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let pendingSave else { throw CocoaError(.fileWriteUnknown) }
        return pendingSave.data
    }

    private static func format(forType typeName: String) -> SaveFormat {
        typeName.lowercased().hasSuffix("hwpx") ? .hwpx : .hwp
    }

    private enum OverwriteDecision {
        case proceed, saveAs, cancel
    }

    private func confirmOverwrite(needed: Bool, then decide: @escaping (OverwriteDecision) -> Void) {
        guard needed, let window = windowForSheet else { return decide(.proceed) }
        let alert = NSAlert()
        alert.messageText = "원본 파일을 덮어쓸까요?"
        alert.informativeText = """
        이 앱이 저장한 파일은 아직 한글(한컴오피스)에서 검증되지 않았습니다. \
        원본을 남겨 두려면 다른 이름으로 저장하세요.
        """
        alert.addButton(withTitle: "덮어쓰기")
        alert.addButton(withTitle: "다른 이름으로 저장…")
        alert.addButton(withTitle: "취소")
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn: decide(.proceed)
            case .alertSecondButtonReturn: decide(.saveAs)
            default: decide(.cancel)
            }
        }
    }

    /// Shows rhwp's content-loss report, if any, before anything is written.
    private func confirmLosses(_ report: SaveReport?, then decide: @escaping (Bool) -> Void) {
        guard let report, !report.losses.isEmpty, let window = windowForSheet else { return decide(true) }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "저장하면 일부 내용이 사라집니다"
        let shown = report.losses.prefix(8).map { "• \($0.subject) — \($0.reason) (\($0.path))" }
        let more = report.losses.count > shown.count ? ["… 외 \(report.losses.count - shown.count)건"] : []
        alert.informativeText = (["\(report.outputFormat.uppercased()) 형식으로 저장할 때 다음 \(report.losses.count)건이 보존되지 않습니다."]
            + shown + more).joined(separator: "\n")
        alert.addButton(withTitle: "그래도 저장")
        alert.addButton(withTitle: "취소")
        alert.beginSheetModal(for: window) { decide($0 == .alertFirstButtonReturn) }
    }
}
