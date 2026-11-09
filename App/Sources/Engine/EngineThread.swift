// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import Foundation

enum EngineThreadError: Error {
    case timedOut
    case stopped
}

/// Written on the engine thread before a semaphore signal, read after the wait.
private final class ResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}

/// A dedicated OS thread that runs work items in FIFO order.
///
/// rhwp binds every session handle to the OS thread that opened it, so a
/// session must live on one thread for its whole life; a GCD queue does not
/// guarantee that.
final class EngineThread: @unchecked Sendable {
    private let condition = NSCondition()
    private var items: [() -> Void] = []
    private var stopping = false

    init(name: String) {
        let thread = Thread { [self] in run() }
        thread.name = name
        thread.qualityOfService = .userInitiated
        // Layout recursion in the engine can go deep; secondary threads
        // otherwise get 512 KiB of stack.
        thread.stackSize = 32 << 20
        thread.start()
    }

    func async(_ work: @escaping () -> Void) {
        condition.lock()
        defer { condition.unlock() }
        guard !stopping else { return }
        items.append(work)
        condition.signal()
    }

    /// Runs `work` after everything already queued and waits for its result.
    func sync<T>(timeout: TimeInterval = 60, _ work: @escaping () throws -> T) throws -> T {
        let box = ResultBox<T>()
        let done = DispatchSemaphore(value: 0)
        condition.lock()
        guard !stopping else {
            condition.unlock()
            throw EngineThreadError.stopped
        }
        items.append {
            box.result = Result { try work() }
            done.signal()
        }
        condition.signal()
        condition.unlock()
        guard done.wait(timeout: .now() + timeout) == .success, let result = box.result else {
            throw EngineThreadError.timedOut
        }
        return try result.get()
    }

    /// Runs `work` last, then lets the thread exit.
    func stop(after work: @escaping () -> Void) {
        condition.lock()
        defer { condition.unlock() }
        items.append(work)
        stopping = true
        condition.signal()
    }

    private func run() {
        while true {
            condition.lock()
            while items.isEmpty && !stopping {
                condition.wait()
            }
            let batch = items
            items.removeAll()
            let exit = stopping
            condition.unlock()
            for item in batch {
                autoreleasepool { item() }
            }
            if exit { return }
        }
    }
}
