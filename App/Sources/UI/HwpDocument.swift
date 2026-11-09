// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit
import PDFKit

/// An HWP/HWPX document edited through rhwp on its own engine thread.
///
/// Saving follows rhwp's checkpoint protocol: serialize (`prepareSave`), let
/// NSDocument write the file, then acknowledge the checkpoint only if the
/// write succeeded, or cancel it.
final class HwpDocument: NSDocument {
    private nonisolated static let hwpType = "com.hancom.hwp"
    private nonisolated static let hwpxType = "com.hancom.hwpx"

    private(set) var engine: (any DocumentEngineClient)?
    private var pendingSave: PreparedSave?
    /// The first in-place overwrite of the opened file asks for confirmation,
    /// because saved files are not yet verified in 한글.
    private var overwriteConfirmed = false
    private var restartRequested = false
    /// The opened file is HWP 3.0. Hancom's viewer reported rhwp's HWP 5 save of
    /// an HWP 3.0 sample as corrupt while the HWPX save opened (see
    /// verification/hancom-viewer-2026-11-09), so saving it as HWP asks first.
    private var openedAsHWP3 = false

    override init() {
        super.init()
        hasUndoManager = false  // rhwp keeps the edit history.
    }

    /// A new, blank document (File > New). rhwp creates it from empty bytes.
    convenience init(type typeName: String) throws {
        self.init()
        fileType = typeName
        try MainActor.assumeIsolated { try openEngine(with: Data()) }
    }

    override class var autosavesInPlace: Bool {
        false
    }

    // Documents are read on the main thread (concurrent reading is off by default).
    // The engine runs in the sandboxed EngineService XPC process unless
    // HWPMAC_IN_PROCESS_ENGINE=1 (for debugging the engine in the app).
    override func read(from data: Data, ofType typeName: String) throws {
        try MainActor.assumeIsolated {
            openedAsHWP3 = Self.isHWP3(data)
            try openEngine(with: data)
        }
    }

    /// HWP 3.0 files start with this ASCII signature (HWP 5 files are CFB).
    nonisolated static func isHWP3(_ data: Data) -> Bool {
        data.starts(with: Data("HWP Document File V3".utf8))
    }

    private func openEngine(with data: Data) throws {
        if ProcessInfo.processInfo.environment["HWPMAC_IN_PROCESS_ENGINE"] == "1" {
            engine = try DocumentEngine(data: data, name: "rhwp engine")
        } else {
            let remote = try RemoteDocumentEngine(data: data)
            remote.onDisconnect = { [weak self] in self?.engineStopped() }
            engine = remote
        }
    }

    /// Stops a stuck engine. The service hosts every open document, so all of
    /// them are reopened from disk.
    func restartEngine() {
        restartRequested = true
        engine?.restart()
    }

    /// The engine process exited (a crash, a kill or a restart): its unsaved
    /// edits are gone, so say so and reopen the document from disk.
    private func engineStopped() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = restartRequested ? "문서 엔진을 다시 시작했습니다" : "문서 엔진이 멈췄습니다"
        alert.informativeText = "마지막으로 저장한 뒤의 편집은 사라졌을 수 있습니다. 문서를 디스크에서 다시 엽니다."
        let reopen = { [self] in
            let url = fileURL
            close()
            if let url {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            }
        }
        if let window = windowForSheet {
            alert.beginSheetModal(for: window) { _ in reopen() }
        } else {
            alert.runModal()
            reopen()
        }
    }

    override func makeWindowControllers() {
        guard let engine else { return }
        addWindowController(DocumentWindowController(engine: engine))
    }

    override func close() {
        super.close()
        engine?.close()
        engine = nil
    }

    /// Mirrors rhwp's dirty flag (which undo can clear) into the edited state.
    func syncEditedState(isDirty: Bool) {
        if isDirty != isDocumentEdited {
            updateChangeCount(isDirty ? .changeDone : .changeCleared)
        }
    }

    // MARK: Printing and PDF

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        guard let document = PDFDocument(data: try currentPDF()),
              let operation = document.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: true)
        else { throw CocoaError(.fileWriteUnknown) }
        return operation
    }

    @objc func exportPDF(_ sender: Any?) {
        guard let window = windowForSheet else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (displayName as NSString).deletingPathExtension + ".pdf"
        panel.beginSheetModal(for: window) { [self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try currentPDF().write(to: url)
            } catch {
                presentError(error)
            }
        }
    }

    private func currentPDF() throws -> Data {
        guard let engine else { throw CocoaError(.fileReadUnknown) }
        for controller in windowControllers {
            (controller as? DocumentWindowController)?.commitInput()
        }
        return try engine.exportPDF()
    }

    // MARK: Saving

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [Self.hwpType, Self.hwpxType]
    }

    override func save(
        to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let engine else {
            return completionHandler(CocoaError(.fileWriteUnknown))
        }
        for controller in windowControllers {
            (controller as? DocumentWindowController)?.commitInput()
        }

        let overwritesOriginal = saveOperation == .saveOperation && url == fileURL && !overwriteConfirmed
        let hwp3AsHWP = openedAsHWP3 && Self.format(forType: typeName) == .hwp
        confirmOverwrite(needed: overwritesOriginal, hwp3AsHWP: hwp3AsHWP) { [self] decision in
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

            let format = Self.format(forType: typeName)
            let prepared: PreparedSave
            do {
                // Runs after every edit already submitted.
                prepared = try engine.prepareSave(format)
            } catch {
                return completionHandler(error)
            }
            confirmLosses(prepared.report) { [self] accepted in
                guard accepted else {
                    try? engine.cancelSave(prepared.token)
                    return completionHandler(CocoaError(.userCancelled))
                }
                pendingSave = prepared
                writeWithNSDocument(to: url, ofType: typeName, for: saveOperation) { [self] error in
                    pendingSave = nil
                    if let error {
                        try? engine.cancelSave(prepared.token)
                        return completionHandler(error)
                    }
                    let stillDirty: Bool
                    do {
                        stillDirty = try engine.acknowledgeSave(prepared.token)
                    } catch {
                        return completionHandler(error)
                    }
                    completionHandler(nil)
                    if saveOperation == .saveToOperation || stillDirty { syncEditedState(isDirty: stillDirty) }
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

    private func confirmOverwrite(needed: Bool, hwp3AsHWP: Bool, then decide: @escaping (OverwriteDecision) -> Void) {
        guard needed || hwp3AsHWP, let window = windowForSheet else { return decide(.proceed) }
        let alert = NSAlert()
        if hwp3AsHWP {
            alert.alertStyle = .warning
            alert.messageText = "HWP 3.0 문서를 HWP로 저장할까요?"
            alert.informativeText = """
            이 문서는 HWP 3.0 형식입니다. 이 앱이 HWP 3.0 문서를 HWP로 저장한 파일을 한글 Viewer가 \
            손상된 파일로 판정한 사례가 있습니다. 다른 이름으로 저장에서 HWPX를 고르는 것을 권합니다.
            """
            alert.addButton(withTitle: "그래도 HWP로 저장")
        } else {
            alert.messageText = "원본 파일을 덮어쓸까요?"
            alert.informativeText = """
            이 앱의 저장본은 한글 Viewer 검사에서 99.8%가 정상으로 열렸지만, 모든 문서가 검증된 것은 아닙니다. \
            원본을 남겨 두려면 다른 이름으로 저장하세요.
            """
            alert.addButton(withTitle: "덮어쓰기")
        }
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
