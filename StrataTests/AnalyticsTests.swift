import Testing
import Foundation
@testable import Strata

/// What leaves the phone through `Analytics`, checked without a network.
///
/// Self-test, each of which re-injects a real bug:
/// - Let `signal` run with an empty app ID and `silentWithoutAnAppID` fails:
///   every build before the owner signs up would be posting somewhere.
/// - Drop the queue clear in `stopSharing` and `theSwitchOffSendsNothing`
///   fails with events held after the person said no.
/// - Send the raw install id as `clientUser` and `theClientUserIsHashed` fails.
@Suite("Analytics")
@MainActor
struct AnalyticsTests {
    private final class Box: @unchecked Sendable { var requests: [URLRequest] = []; var status = 200 }

    private func defaults() -> UserDefaults {
        let name = "analytics-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func make(appID: String = "APP-ID", box: Box, defaults: UserDefaults) -> Analytics {
        Analytics(config: .init(appID: appID, namespace: nil, testMode: true), defaults: defaults,
                  send: { request in box.requests.append(request); return box.status })
    }

    private func signals(_ request: URLRequest) throws -> [[String: Any]] {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    @Test("nothing is recorded or sent without an app ID")
    func silentWithoutAnAppID() async {
        let box = Box()
        let a = make(appID: "", box: box, defaults: defaults())
        a.signal(.winLogged, [.size(.quick)])
        await a.flush()
        #expect(a.queue.isEmpty)
        #expect(box.requests.isEmpty)
    }

    @Test("a signal carries what TelemetryDeck needs, and the first one says a new install")
    func theWireShape() async throws {
        let box = Box()
        let a = make(box: box, defaults: defaults())
        a.signal(.winLogged, [.size(.deep), .source(.camera), .hasPhoto(true)])
        await a.flush()
        let request = try #require(box.requests.first)
        #expect(request.url?.absoluteString == "https://nom.telemetrydeck.com/v2/")
        #expect(request.httpMethod == "POST")
        let sent = try signals(request)
        #expect(sent.map { $0["type"] as? String } == ["TelemetryDeck.Acquisition.newInstallDetected",
                                                      "TelemetryDeck.Session.started", "win_logged"])
        let win = try #require(sent.last)
        #expect(win["appID"] as? String == "APP-ID")
        #expect(win["isTestMode"] as? String == "true")
        #expect((win["sessionID"] as? String)?.isEmpty == false)
        let payload = try #require(win["payload"] as? [String: String])
        #expect(payload["size"] == "deep")
        #expect(payload["source"] == "camera")
        #expect(payload["has_photo"] == "true")
        #expect(payload["TelemetryDeck.AppInfo.version"] != nil)
        #expect(a.queue.isEmpty, "a 200 takes the batch off the queue")
    }

    @Test("a new install is announced once, a session once per launch")
    func announcedOnce() async throws {
        let box = Box()
        let d = defaults()
        let a = make(box: box, defaults: d)
        a.signal(.screen, [.screen(.wins)])
        a.signal(.screen, [.screen(.camera)])
        await a.flush()
        let b = make(box: box, defaults: d)
        b.signal(.screen, [.screen(.wins)])
        await b.flush()
        let types = try box.requests.flatMap { try signals($0) }.compactMap { $0["type"] as? String }
        #expect(types.filter { $0 == "TelemetryDeck.Acquisition.newInstallDetected" }.count == 1)
        #expect(types.filter { $0 == "TelemetryDeck.Session.started" }.count == 2)
    }

    @Test("the switch off sends nothing and empties what was held")
    func theSwitchOffSendsNothing() async {
        let box = Box()
        let a = make(box: box, defaults: defaults())
        a.signal(.winLogged)
        a.stopSharing()
        #expect(a.queue.isEmpty)
        a.signal(.winLogged)
        await a.flush()
        #expect(box.requests.isEmpty)
    }

    @Test("a failure keeps the batch; a malformed-request answer drops it")
    func failuresAndDrops() async {
        let box = Box()
        let a = make(box: box, defaults: defaults())
        a.signal(.winLogged)
        box.status = 503
        await a.flush()
        #expect(!a.queue.isEmpty, "a server error keeps the batch for later")
        box.status = 400
        await a.flush()
        #expect(a.queue.isEmpty, "a 400 will never succeed, so it is dropped")
    }

    @Test("batches split at 100")
    func batching() async throws {
        let box = Box()
        let a = make(box: box, defaults: defaults())
        for _ in 0..<150 { a.signal(.screen, [.screen(.wins)]) }
        await a.flush()
        #expect(try signals(try #require(box.requests.first)).count == Analytics.batchLimit)
        #expect(a.queue.count == 152 - Analytics.batchLimit)
    }

    @Test("the client user is stable, hashed, and not the install id")
    func theClientUserIsHashed() {
        let d = defaults()
        let a = make(box: Box(), defaults: d)
        let first = a.clientUser
        #expect(first == a.clientUser)
        #expect(first.count == 64)
        #expect(first != d.string(forKey: Analytics.installKey))
    }

    @Test("fields are closed: buckets, enums and bools only")
    func fieldsAreClosed() {
        #expect(AnalyticsField.goal(3).pair == ("goal", "3"))
        #expect(AnalyticsField.goal(40).pair == ("goal", "11+"))
        #expect(AnalyticsField.step(2).pair == ("step", "2"))
        // Every event name is snake_case words, nothing a person typed.
        for event in AnalyticsEvent.allCases {
            #expect(event.rawValue.allSatisfy { $0.isLowercase || $0 == "_" })
        }
    }
}
