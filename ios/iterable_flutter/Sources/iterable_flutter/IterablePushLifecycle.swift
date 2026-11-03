import Foundation

struct IterablePushIdentity: Codable, Equatable, Hashable {
    let email: String?
    let userId: String?

    init?(email: String?, userId: String?) {
        guard email != nil || userId != nil else { return nil }
        self.email = email
        self.userId = email == nil ? userId : nil
    }
}

/// The pinned SDK cannot retry disabling a token after its user has logged out.
/// Store an explicit identity with every disable; never consult the live SDK
/// identity when replaying it. All access is confined to the main thread.
final class IterablePushLifecycle {
    struct Endpoint: Codable, Equatable, Hashable {
        let identity: IterablePushIdentity
        var token: String?
    }

    typealias Send = (URLRequest, @escaping (Bool) -> Void) -> Void
    private let defaults: UserDefaults
    private let key: String
    private let apiKey: String
    private let send: Send
    private(set) var pending: [Endpoint]
    private(set) var token: Data?
    private var lastRegistration: Endpoint?
    private var flushing = false
    private var attempted = Set<Endpoint>()
    private var completions: [() -> Void] = []

    init(apiKey: String, defaults: UserDefaults = .standard, send: Send? = nil) {
        self.apiKey = apiKey
        self.defaults = defaults
        // Stable project namespace (not an authentication or security hash).
        let scope = apiKey.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        key = "gc.iterable.push.\(scope)"
        pending = defaults.data(forKey: key + ".pending")
            .flatMap { try? JSONDecoder().decode([Endpoint].self, from: $0) } ?? []
        token = defaults.data(forKey: key + ".token")
        lastRegistration = defaults.data(forKey: key + ".registration")
            .flatMap { try? JSONDecoder().decode(Endpoint.self, from: $0) }
        self.send = send ?? { request, completion in
            URLSession.shared.dataTask(with: request) { _, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                DispatchQueue.main.async {
                    completion(error == nil && (200..<300).contains(code))
                }
            }.resume()
        }
    }

    func enqueueLogout(_ identity: IterablePushIdentity?) {
        guard let identity = identity else { return }
        enqueue(Endpoint(identity: identity, token: hexToken))
    }

    func receiveToken(_ data: Data) {
        token = data
        defaults.set(data, forKey: key + ".token")
        // A cold-start logout may precede the first APNs callback. Resolve the
        // saved outgoing identity when APNs eventually supplies the token.
        for index in pending.indices where pending[index].token == nil {
            pending[index].token = hexToken
        }
        persist()
    }

    func resume(_ identity: IterablePushIdentity) {
        // Logging back into the same account supersedes its pending logout for
        // the current token. Old rotated tokens must still be disabled.
        pending.removeAll {
            $0.identity == identity && ($0.token == nil || $0.token == hexToken)
        }
        persist()
    }

    func willRegister(_ identity: IterablePushIdentity) {
        if let previous = lastRegistration,
           previous.identity != identity || previous.token != hexToken {
            enqueue(previous)
        }
        lastRegistration = Endpoint(identity: identity, token: hexToken)
        defaults.set(try? JSONEncoder().encode(lastRegistration), forKey: key + ".registration")
    }

    func flush(completion: @escaping () -> Void = {}) {
        completions.append(completion)
        guard !flushing else { return }
        flushing = true
        attempted.removeAll()
        attempt(Array(pending.filter { $0.token != nil }))
    }

    private var hexToken: String? {
        token?.map { String(format: "%02x", $0) }.joined()
    }

    private func enqueue(_ endpoint: Endpoint) {
        guard !pending.contains(endpoint) else { return }
        pending.append(endpoint)
        persist()
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(pending), forKey: key + ".pending")
    }

    private func attempt(_ remaining: [Endpoint]) {
        guard let endpoint = remaining.first else {
            let added = pending.filter { $0.token != nil && !attempted.contains($0) }
            if !added.isEmpty {
                attempt(added)
                return
            }
            flushing = false
            let callbacks = completions
            completions.removeAll()
            callbacks.forEach { $0() }
            return
        }
        // It may have been superseded by a same-account login while another
        // request was in flight. Never send a removed logout record later.
        guard pending.contains(endpoint) else {
            attempt(Array(remaining.dropFirst()))
            return
        }
        attempted.insert(endpoint)
        var body: [String: Any] = ["token": endpoint.token!]
        if let email = endpoint.identity.email { body["email"] = email }
        else if let userId = endpoint.identity.userId { body["userId"] = userId }
        var request = URLRequest(url: URL(string: "https://api.iterable.com/api/users/disableDevice")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        send(request) { [weak self] success in
            guard let self = self else { return }
            if success {
                self.pending.removeAll { $0 == endpoint }
                self.persist()
            }
            // No tokens, email addresses, credentials or response bodies in logs.
            NSLog("[IterablePush] disable %@; pending=%d", success ? "confirmed" : "queued for retry", self.pending.count)
            self.attempt(Array(remaining.dropFirst()))
        }
    }
}
