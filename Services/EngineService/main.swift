// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
//
// The engine XPC service: parses, lays out, edits and serializes documents in
// a sandboxed process with no file, network or device access. It receives
// document bytes and returns snapshots, pixels and serialized bytes, so a
// malicious document that subverts the parser reaches nothing but this process.

import Foundation

/// One connection, one open document.
final class EngineServiceSession: NSObject, EngineServiceProtocol, @unchecked Sendable {
    private weak var connection: NSXPCConnection?
    private let lock = NSLock()
    private var engine: DocumentEngine?

    init(connection: NSXPCConnection) {
        self.connection = connection
    }

    private var currentEngine: DocumentEngine? {
        lock.lock()
        defer { lock.unlock() }
        return engine
    }

    func open(_ document: Data, reply: @escaping @Sendable (Data?, String?) -> Void) {
        do {
            let engine = try DocumentEngine(data: document, name: "rhwp engine (service)")
            // Snapshots arrive on the main queue; forward each to the app.
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    engine.onSnapshot = { [weak self] snapshot in self?.forward(snapshot) }
                }
            }
            lock.lock()
            self.engine = engine
            lock.unlock()
            reply(try JSONEncoder().encode(engine.initialPageSizes), nil)
        } catch {
            reply(nil, String(describing: error))
        }
    }

    func submit(_ operation: Data) {
        guard let engine = currentEngine,
              let operation = try? JSONDecoder().decode(DocumentEngine.Operation.self, from: operation)
        else { return }
        engine.submit(operation)
    }

    func render(page: Int, scale: Double, reply: @escaping @Sendable (Data?, Int, Int, Int, UInt64) -> Void) {
        guard let engine = currentEngine else { return reply(nil, 0, 0, 0, 0) }
        engine.renderPixels(page: page, scale: scale) { frame, revision in
            reply(frame?.data, frame?.width ?? 0, frame?.height ?? 0, frame?.stride ?? 0, revision)
        }
    }

    func call(_ request: Data, reply: @escaping @Sendable (Data?, String?) -> Void) {
        do {
            guard let engine = currentEngine else { throw EngineServiceError.remote("문서가 열려 있지 않습니다.") }
            reply(try JSONDecoder().decode(EngineCall.self, from: request).perform(on: engine), nil)
        } catch {
            reply(nil, String(describing: error))
        }
    }

    func close() {
        lock.lock()
        let engine = self.engine
        self.engine = nil
        lock.unlock()
        engine?.close()
    }

    private func forward(_ snapshot: DocumentEngine.Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        (connection?.remoteObjectProxy as? EngineClientProtocol)?.deliverSnapshot(data)
    }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let session = EngineServiceSession(connection: connection)
        connection.exportedInterface = NSXPCInterface(with: EngineServiceProtocol.self)
        connection.remoteObjectInterface = NSXPCInterface(with: EngineClientProtocol.self)
        connection.exportedObject = session
        connection.invalidationHandler = { session.close() }
        connection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
