// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import CoreGraphics
import Foundation

/// A document engine running in the sandboxed EngineService XPC process.
final class RemoteDocumentEngine: NSObject, DocumentEngineClient, EngineClientProtocol, @unchecked Sendable {
    static let serviceName = "local.hwpmac.HwpMac.EngineService"

    /// Set once the service has opened the document.
    private(set) var initialPageSizes: [CGSize] = []
    @MainActor var onSnapshot: ((DocumentEngine.Snapshot) -> Void)?
    /// Called on the main thread if the service exits or the connection breaks.
    @MainActor var onDisconnect: (() -> Void)?

    private let connection: NSXPCConnection
    private let lock = NSLock()
    private var submitted: UInt64 = 0
    private var lastSnapshotSlow = false
    private var closed = false

    init(data: Data) throws {
        let connection = NSXPCConnection(serviceName: Self.serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: EngineServiceProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: EngineClientProtocol.self)
        self.connection = connection
        super.init()
        connection.exportedObject = self
        connection.interruptionHandler = { [weak self] in self?.disconnected() }
        connection.invalidationHandler = { [weak self] in self?.disconnected() }
        connection.resume()

        let reply = try waitForReply { proxy, done in proxy.open(data, reply: done) }
        guard let sizes = try? JSONDecoder().decode([CGSize].self, from: reply) else {
            connection.invalidate()
            throw EngineServiceError.remote("문서 엔진이 잘못된 응답을 보냈습니다.")
        }
        initialPageSizes = sizes
    }

    var isSlow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lastSnapshotSlow
    }

    @discardableResult
    func submit(_ operation: DocumentEngine.Operation) -> UInt64 {
        lock.lock()
        submitted += 1
        let sequence = submitted
        lock.unlock()
        // The service numbers operations in arrival order, which XPC keeps.
        if let data = try? JSONEncoder().encode(operation) {
            proxy?.submit(data)
        }
        return sequence
    }

    func render(page: Int, scale: Double, completion: @escaping @MainActor @Sendable (CGImage?, UInt64) -> Void) {
        guard let proxy else {
            return DispatchQueue.main.async { completion(nil, 0) }
        }
        proxy.render(page: page, scale: scale) { data, width, height, stride, revision in
            let image = data.flatMap { PixelFrame(data: $0, width: width, height: height, stride: stride).makeImage() }
            DispatchQueue.main.async { completion(image, revision) }
        }
    }

    func copySelection() throws -> String {
        try call(.copySelection)
    }

    func surroundingText(timeout: TimeInterval) throws -> ImeContext {
        try call(.surroundingText(timeout: timeout))
    }

    func prepareSave(_ format: SaveFormat) throws -> PreparedSave {
        try call(.prepareSave(format))
    }

    func acknowledgeSave(_ token: UInt64) throws -> Bool {
        try call(.acknowledgeSave(token: token))
    }

    func cancelSave(_ token: UInt64) throws {
        let _: Bool = try call(.cancelSave(token: token))
    }

    func documentText() throws -> String {
        try call(.documentText)
    }

    func close() {
        lock.lock()
        let alreadyClosed = closed
        closed = true
        lock.unlock()
        guard !alreadyClosed else { return }
        proxy?.close()
        connection.invalidate()
    }

    var canRestart: Bool { true }

    func restart() {
        proxy?.terminate()
    }

    // MARK: EngineClientProtocol

    func deliverSnapshot(_ data: Data) {
        guard let snapshot = try? JSONDecoder().decode(DocumentEngine.Snapshot.self, from: data) else { return }
        lock.lock()
        lastSnapshotSlow = snapshot.engineIsSlow
        lock.unlock()
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated { onSnapshot?(snapshot) }
        }
    }

    // MARK: Private

    private var proxy: EngineServiceProtocol? {
        connection.remoteObjectProxyWithErrorHandler { [weak self] _ in self?.disconnected() } as? EngineServiceProtocol
    }

    private func call<T: Decodable>(_ call: EngineCall) throws -> T {
        let request = try JSONEncoder().encode(call)
        let reply = try waitForReply { proxy, done in proxy.call(request, reply: done) }
        return try JSONDecoder().decode(T.self, from: reply)
    }

    /// Sends one request through a synchronous proxy, which returns only after
    /// the reply (or the connection error) has been delivered.
    private func waitForReply(
        _ send: (EngineServiceProtocol, @escaping @Sendable (Data?, String?) -> Void) -> Void
    ) throws -> Data {
        final class Reply: @unchecked Sendable {
            var result: Result<Data, Error> = .failure(EngineServiceError.disconnected)
        }
        let reply = Reply()
        let proxy = connection.synchronousRemoteObjectProxyWithErrorHandler { error in
            reply.result = .failure(EngineServiceError.remote(error.localizedDescription))
        } as? EngineServiceProtocol
        guard let proxy else { throw EngineServiceError.disconnected }
        send(proxy) { data, message in
            reply.result = data.map { .success($0) }
                ?? .failure(EngineServiceError.remote(message ?? "알 수 없는 오류"))
        }
        return try reply.result.get()
    }

    private func disconnected() {
        lock.lock()
        let expected = closed
        lock.unlock()
        guard !expected else { return }
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated { onDisconnect?() }
        }
    }
}
