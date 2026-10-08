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
/// - Drop the `screensSeen` guard in `signal` and `aScreenOncePerSession` fails.
/// - Treat 429 like any other failure and `aTooManyBacksOff` fails: the
///   second flush sends again at once.
/// - Keep the install id in `stopSharing` and `offForgetsTheInstall` fails.
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

    private final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 1_800_000_000) }

    private func make(appID: String = "APP-ID", box: Box, defaults: UserDefaults,
                      sampleRate: Double = 1, clock: Clock? = nil) -> Analytics {
        Analytics(config: .init(appID: appID, namespace: nil, testMode: true, sampleRate: sampleRate),
                  defaults: defaults,
                  now: { clock?.now ?? Date() },
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
        #expect(payload["sampleRate"] == "1.0", "every event says the rate, so counts can be scaled back")
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
        // `win_logged`, not `screen`: since 2026-10-08 a screen is counted
        // once a session, so 150 of them would be one.
        for _ in 0..<150 { a.signal(.winLogged) }
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

    @Test("a screen is counted once a session, and again after a new session")
    func aScreenOncePerSession() async throws {
        let box = Box()
        let clock = Clock()
        let a = make(box: box, defaults: defaults(), clock: clock)
        for _ in 0..<5 { a.signal(.screen, [.screen(.wins)]) }
        a.signal(.screen, [.screen(.camera)])
        a.signal(.screen, [.screen(.wins)])
        // Sent or still held: `didEnterBackground` may flush.
        func screens() throws -> [String] {
            (try box.requests.flatMap { try signals($0) } + a.queue)
                .filter { $0["type"] as? String == "screen" }
                .compactMap { ($0["payload"] as? [String: String])?["screen"] }
        }
        #expect(try screens() == ["wins", "camera"])
        a.didEnterBackground()
        clock.now += Analytics.sessionGap + 1
        a.didBecomeActive()
        a.signal(.screen, [.screen(.wins)])
        #expect(try screens() == ["wins", "camera", "wins"], "a new session counts the screen again")
    }

    @Test("sampling is decided per install, deterministically, and reaches about the rate")
    func samplingIsPerInstall() {
        #expect(Analytics.isSampled(install: "any", rate: 1))
        #expect(!Analytics.isSampled(install: "any", rate: 0))
        let id = "8C1F4D2E-0000-4000-8000-000000000001"
        let first = Analytics.isSampled(install: id, rate: 0.5)
        for _ in 0..<10 { #expect(Analytics.isSampled(install: id, rate: 0.5) == first) }
        let ids = (0..<2_000).map { "install-\($0)" }
        let inside = ids.filter { Analytics.isSampled(install: $0, rate: 0.25) }.count
        #expect((400...600).contains(inside), "\(inside) of 2000 at 0.25")
        // Raising the rate keeps everyone who was already in.
        let quarter = Set(ids.filter { Analytics.isSampled(install: $0, rate: 0.25) })
        let half = Set(ids.filter { Analytics.isSampled(install: $0, rate: 0.5) })
        #expect(quarter.isSubset(of: half))
    }

    @Test("the plist rate reads numbers and strings, clamps, and is 1 when absent")
    func sampleRateFromThePlist() {
        #expect(Analytics.Config.sampleRate(from: nil) == 1)
        #expect(Analytics.Config.sampleRate(from: NSNumber(value: 0.2)) == 0.2)
        #expect(Analytics.Config.sampleRate(from: "0.5") == 0.5)
        #expect(Analytics.Config.sampleRate(from: "nonsense") == 1)
        #expect(Analytics.Config.sampleRate(from: NSNumber(value: 7)) == 1)
        #expect(Analytics.Config.sampleRate(from: NSNumber(value: -1)) == 0)
    }

    @Test("an install outside the sample records nothing")
    func outsideTheSampleIsSilent() async {
        let box = Box()
        let a = make(box: box, defaults: defaults(), sampleRate: 0)
        a.signal(.winLogged)
        await a.flush()
        #expect(a.queue.isEmpty)
        #expect(box.requests.isEmpty)
    }

    @Test("a 429 keeps the batch and backs off, doubling to a cap")
    func aTooManyBacksOff() async {
        let box = Box()
        let clock = Clock()
        let a = make(box: box, defaults: defaults(), clock: clock)
        a.signal(.winLogged)
        box.status = 429
        await a.flush()
        #expect(box.requests.count == 1)
        #expect(!a.queue.isEmpty, "a 429 is not a refusal of the batch")
        #expect(a.backoff == 20)
        await a.flush()
        #expect(box.requests.count == 1, "nothing is sent while backing off")
        clock.now += 21
        await a.flush()
        #expect(box.requests.count == 2)
        #expect(a.backoff == 40)
        box.status = 200
        clock.now += 41
        await a.flush()
        #expect(a.queue.isEmpty)
        #expect(a.backoff == 0, "a success clears the back-off")
        var b: TimeInterval = 0
        for _ in 0..<20 { b = Analytics.nextBackoff(after: b) }
        #expect(b == Analytics.maxBackoff)
    }

    @Test("turning sharing off forgets the install, so on again is a new one")
    func offForgetsTheInstall() async throws {
        let box = Box()
        let d = defaults()
        let a = make(box: box, defaults: d)
        a.signal(.winLogged)
        let before = a.clientUser
        #expect(d.string(forKey: Analytics.firstDayKey) != nil)
        a.stopSharing()
        #expect(a.queue.isEmpty)
        #expect(d.string(forKey: Analytics.installKey) == nil)
        #expect(d.string(forKey: Analytics.firstDayKey) == nil)
        d.set(true, forKey: Analytics.shareKey)
        a.signal(.winLogged)
        #expect(a.clientUser != before)
        #expect(a.queue.first?["type"] as? String == "TelemetryDeck.Acquisition.newInstallDetected")
    }

    @Test("a diagnostic delivery is one signal per kind, coarse fields only")
    func diagnosticsAreOnePerKind() throws {
        let summaries = [
            DiagnosticSummary(kind: .crash, exceptionType: 1, signal: 11, build: 108),
            DiagnosticSummary(kind: .crash, exceptionType: 10, signal: 6, build: 108),
            DiagnosticSummary(kind: .crash, exceptionType: 1, signal: 11, build: 107),
            DiagnosticSummary(kind: .hang, build: 108),
        ]
        let sent = DiagnosticSignals.fields(for: summaries)
        try #require(sent.count == 2)
        #expect(sent[0] == [.diagnostic(.crash), .count(3), .exceptionType(1), .signalNumber(11), .appBuild(108)])
        #expect(sent[1] == [.diagnostic(.hang), .count(1), .appBuild(108)])
        #expect(DiagnosticSignals.fields(for: []).isEmpty)
        #expect(AnalyticsField.exceptionType(9_999).pair == ("exception_type", "other"))
        #expect(AnalyticsField.count(500).pair == ("count", "11+"))
        // Every MetricKit kind has an analytics name.
        for kind in DiagnosticSummary.Kind.allCases {
            #expect(AnalyticsField.Diagnostic(rawValue: kind.rawValue) != nil)
        }
    }

    @Test("only the newest three payloads are kept, and nothing else is touched")
    func diagnosticFilesArePruned() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let names = (0..<5).map { Diagnostics.fileName(at: base.addingTimeInterval(Double($0)), index: 0) }
            + ["index.json", "notes.txt"]
        let pruned = Diagnostics.toPrune(names, keep: 3)
        #expect(Set(pruned) == Set(names.prefix(2)))
        #expect(Diagnostics.fileName(at: base, index: 1) > Diagnostics.fileName(at: base, index: 0))
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
