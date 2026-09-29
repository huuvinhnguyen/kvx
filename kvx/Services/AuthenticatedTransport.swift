import Foundation

nonisolated struct AuthenticatedTransport: Sendable {
    let authority: any SessionAuthorizing
    let generation: UInt64?
    let session: URLSession

    init(authority: any SessionAuthorizing = NoSession(), generation: UInt64? = nil, session: URLSession = AuthenticatedTransport.makeSession()) {
        self.authority = authority
        self.generation = generation
        self.session = session
    }
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let snapshot = try await authority.snapshot(expectedGeneration: generation)
        var authorized = request
        authorized.setValue("Bearer \(snapshot.token)", forHTTPHeaderField: "Authorization")
        let prepared = authorized
        let cancellation = RequestCancellation()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    Task {
                        do {
                            try await authority.dispatch(snapshot.generation) {
                                let task = session.dataTask(with: prepared) { data, response, error in
                                    if let error { continuation.resume(throwing: error) }
                                    else if let data, let response { continuation.resume(returning: (data, response)) }
                                    else { continuation.resume(throwing: DeviceAPIError.invalidResponse) }
                                }
                                cancellation.start(task)
                            }
                        } catch { continuation.resume(throwing: error) }
                    }
                }
            } onCancel: {
                cancellation.cancel()
            }
        } catch {
            guard await authority.isCurrent(snapshot.generation) else { throw SessionFailure.stale }
            throw error
        }
        guard await authority.isCurrent(snapshot.generation) else { throw SessionFailure.stale }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw DeviceAPIError.invalidResponse }
        if response.statusCode == 401 {
            guard await authority.unauthorized(snapshot.generation) else { throw SessionFailure.stale }
        }
        return (data, response)
    }
}

// URLSession callbacks and caller cancellation can arrive on different threads.
// Keeping the start/cancel decision under one lock prevents cancelled work from
// being resumed during the actor-to-transport handoff.
nonisolated private final class RequestCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var cancelled = false
    func start(_ task: URLSessionDataTask) {
        lock.lock()
        self.task = task
        if cancelled { task.cancel() } else { task.resume() }
        lock.unlock()
    }
    func cancel() {
        lock.lock()
        cancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }
}
