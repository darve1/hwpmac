// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import Foundation

/// XPC boundary between the app and the engine service. Payloads are JSON
/// (`DocumentEngine.Operation`, `Snapshot`, `EngineCall`) or raw bytes, so the
/// service only ever receives document bytes, never file paths.
@objc protocol EngineServiceProtocol {
    /// Opens `document` (empty creates a blank document); replies JSON `[CGSize]` page sizes or an error.
    func open(_ document: Data, reply: @escaping @Sendable (Data?, String?) -> Void)
    /// JSON-encoded `DocumentEngine.Operation`. Delivered in order on the connection.
    func submit(_ operation: Data)
    /// Replies RGBA pixels, width, height, stride and the revision rendered, or nil pixels.
    func render(page: Int, scale: Double, reply: @escaping @Sendable (Data?, Int, Int, Int, UInt64) -> Void)
    /// JSON-encoded `EngineCall`; replies JSON result or an error.
    func call(_ request: Data, reply: @escaping @Sendable (Data?, String?) -> Void)
    func close()
    /// Ends the service process even while its engine is stuck in a long edit;
    /// the app sees the connection drop and reopens its documents.
    func terminate()
}

/// Exported by the app so the service can push snapshots.
@objc protocol EngineClientProtocol {
    /// JSON-encoded `DocumentEngine.Snapshot`.
    func deliverSnapshot(_ snapshot: Data)
}

/// Calls that wait for queued operations and return a value.
enum EngineCall: Codable {
    case copySelection
    case surroundingText(timeout: TimeInterval)
    case prepareSave(SaveFormat)
    case acknowledgeSave(token: UInt64)
    case cancelSave(token: UInt64)
    case documentText
    case exportPDF
    case query(EditQuery)

    /// Runs the call against an in-process engine and encodes its result.
    func perform(on engine: DocumentEngine) throws -> Data {
        let encoder = JSONEncoder()
        switch self {
        case .copySelection: return try encoder.encode(engine.copySelection())
        case let .surroundingText(timeout): return try encoder.encode(engine.surroundingText(timeout: timeout))
        case let .prepareSave(format): return try encoder.encode(engine.prepareSave(format))
        case let .acknowledgeSave(token): return try encoder.encode(engine.acknowledgeSave(token))
        case let .cancelSave(token):
            try engine.cancelSave(token)
            return try encoder.encode(true)
        case .documentText: return try encoder.encode(engine.documentText())
        case .exportPDF: return try encoder.encode(engine.exportPDF())
        case let .query(query): return try encoder.encode(engine.query(query))
        }
    }
}

enum EngineServiceError: LocalizedError {
    case remote(String)
    case disconnected

    var errorDescription: String? {
        switch self {
        case let .remote(message): message
        case .disconnected: "문서 엔진과의 연결이 끊어졌습니다."
        }
    }
}
