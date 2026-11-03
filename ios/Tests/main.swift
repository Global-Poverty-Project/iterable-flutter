import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

func storage() -> UserDefaults {
    UserDefaults(suiteName: "IterablePushLifecycleTests." + UUID().uuidString)!
}

func payload(_ request: URLRequest) -> [String: String] {
    try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
}

let a = IterablePushIdentity(email: "a@example.com", userId: nil)!
let b = IterablePushIdentity(email: "b@example.com", userId: nil)!
let userId = IterablePushIdentity(email: nil, userId: "42")!
let token = Data([0x01, 0xab])

// Request identity is the outgoing account even after another account resumes.
do {
    let defaults = storage()
    var requests: [URLRequest] = []
    let lifecycle = IterablePushLifecycle(apiKey: "test-key", defaults: defaults) { request, done in
        requests.append(request)
        done(true)
    }
    lifecycle.receiveToken(token)
    lifecycle.enqueueLogout(a)
    lifecycle.resume(b)
    lifecycle.flush()
    check(requests.count == 1, "one scoped disable")
    check(payload(requests[0]) == ["token": "01ab", "email": "a@example.com"], "disable targets A only")
    check(lifecycle.pending.isEmpty, "confirmed disables are removed")
}

// A failed request persists across process restarts and retries with userId.
do {
    let defaults = storage()
    let first = IterablePushLifecycle(apiKey: "test-key", defaults: defaults) { _, done in done(false) }
    first.receiveToken(token)
    first.enqueueLogout(userId)
    first.flush()
    check(first.pending.count == 1, "offline cleanup retained")
    var request: URLRequest?
    let restarted = IterablePushLifecycle(apiKey: "test-key", defaults: defaults) { value, done in
        request = value
        done(true)
    }
    check(restarted.token == token, "APNs token cached across starts")
    restarted.flush()
    check(payload(request!) == ["token": "01ab", "userId": "42"], "userId snapshot survives restart")
    check(restarted.pending.isEmpty, "retry removed on confirmation")
}

// Early cold-start logout retains its identity until APNs supplies the token.
do {
    let defaults = storage()
    let first = IterablePushLifecycle(apiKey: "test-key", defaults: defaults) { _, _ in fatalError("no token yet") }
    first.enqueueLogout(a)
    first.flush()
    check(first.pending.count == 1, "logout without token retained")
    var requested = false
    let restarted = IterablePushLifecycle(apiKey: "test-key", defaults: defaults) { request, done in
        requested = true
        check(payload(request)["email"] == "a@example.com", "late token still targets A")
        done(true)
    }
    restarted.receiveToken(token)
    restarted.flush()
    check(requested && restarted.pending.isEmpty, "cold-start logout eventually disabled")
}

// A same-account login supersedes its logout for the current token.
do {
    let lifecycle = IterablePushLifecycle(apiKey: "test-key", defaults: storage()) { _, _ in fatalError("superseded disable sent") }
    lifecycle.receiveToken(token)
    lifecycle.enqueueLogout(a)
    lifecycle.resume(a)
    lifecycle.flush()
    check(lifecycle.pending.isEmpty, "same-account resume keeps current token enabled")
    lifecycle.enqueueLogout(nil)
    check(lifecycle.pending.isEmpty, "signed-out state never creates a global disable")
}

// Rotation disables the previous token, not the newly registered token.
do {
    var requests: [URLRequest] = []
    let lifecycle = IterablePushLifecycle(apiKey: "test-key", defaults: storage()) { request, done in
        requests.append(request)
        done(true)
    }
    lifecycle.receiveToken(token)
    lifecycle.willRegister(a)
    lifecycle.receiveToken(Data([0x02]))
    lifecycle.resume(a)
    lifecycle.willRegister(a)
    lifecycle.flush()
    check(requests.count == 1 && payload(requests[0])["token"] == "01ab", "only rotated token disabled")
}

// A login waiting on an in-flight disable proceeds only after that attempt ends.
do {
    var finish: ((Bool) -> Void)?
    let lifecycle = IterablePushLifecycle(apiKey: "test-key", defaults: storage()) { _, done in finish = done }
    lifecycle.receiveToken(token)
    lifecycle.enqueueLogout(a)
    lifecycle.flush()
    lifecycle.resume(a)
    var completed = false
    lifecycle.flush { completed = true }
    check(!completed, "login waits for already-sent disable")
    finish!(true)
    check(completed && lifecycle.pending.isEmpty, "login can safely register again")
}

// Newly enqueued logout work joins an in-flight batch and is attempted once.
do {
    var sends = 0
    var finish: ((Bool) -> Void)?
    let lifecycle = IterablePushLifecycle(apiKey: "test-key", defaults: storage()) { _, done in
        sends += 1
        if sends == 1 { finish = done } else { done(false) }
    }
    lifecycle.receiveToken(token)
    lifecycle.enqueueLogout(a)
    lifecycle.flush()
    lifecycle.enqueueLogout(b)
    var completed = false
    lifecycle.flush { completed = true }
    finish!(false)
    check(completed && sends == 2, "joined work attempted without an infinite offline retry")
    check(lifecycle.pending.count == 2, "both failures retained")
}

// QA and production projects cannot replay one another's cleanup.
do {
    let defaults = storage()
    let qa = IterablePushLifecycle(apiKey: "qa", defaults: defaults) { _, done in done(false) }
    qa.receiveToken(token)
    qa.enqueueLogout(a)
    let production = IterablePushLifecycle(apiKey: "production", defaults: defaults) { _, _ in fatalError("wrong project") }
    check(production.pending.isEmpty && production.token == nil, "project isolation")
}

print("8 Iterable push lifecycle scenarios passed")
