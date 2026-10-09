import Foundation
import CryptoKit
import UIKit

/// **Anonymous counts of what is used** (the owner, 2026-10-08: "we can
/// understand problem areas in the app for users and features people use or
/// dont use"). Spec: `docs/superpowers/specs/2026-10-08-analytics-design.md`.
///
/// Sent to TelemetryDeck's ingest API by this file alone: no SDK, nothing else
/// in the binary. **Nothing anyone wrote, photographed or named ever leaves
/// through here**: an event carries `AnalyticsField`s, a closed set of small
/// enums, bools and buckets, so a title or a note cannot be passed by
/// accident (`AnalyticsTests.fieldsAreClosed`).
///
/// Silent until the owner's TelemetryDeck app ID is in Info.plist
/// (`SomeWinsTelemetryAppID`), and silent whenever Settings' Share Anonymous
/// Usage is off.
final class Analytics {
    static let shared = Analytics()

    /// Settings' switch. On unless turned off.
    nonisolated static let shareKey = "analytics.share"
    nonisolated static let installKey = "analytics.install"
    nonisolated static let firstDayKey = "analytics.firstDay"
    /// TelemetryDeck's SDK sends at most this many a request.
    nonisolated static let batchLimit = 100
    /// Held while offline; the oldest go first.
    nonisolated static let queueLimit = 500
    /// A return after this long away is a new session (the SDK's rule).
    nonisolated static let sessionGap: TimeInterval = 5 * 60
    /// The ordinary wait between flushes.
    nonisolated static let flushDelay: TimeInterval = 10
    /// **The longest a 429 makes us wait** (2026-10-08). TelemetryDeck stops
    /// ingesting above the plan's cap and says so with 429; retrying every
    /// ten seconds into that is a phone talking to a wall all day.
    nonisolated static let maxBackoff: TimeInterval = 10 * 60

    struct Config: Sendable {
        var appID: String
        var namespace: String?
        var testMode: Bool
        /// **The share of installs that send at all, 0 to 1** (2026-10-08).
        /// The free tier is about 50,000 events a month and stops ingesting
        /// above it, so past that the owner turns this down in Info.plist
        /// (`SomeWinsTelemetrySampleRate`) rather than losing whole days.
        /// Decided per install, never per event, so a sampled install's
        /// funnel is whole; every event carries the rate so counts scale back.
        var sampleRate: Double = 1

        static var fromBundle: Config {
            let info = Bundle.main.infoDictionary ?? [:]
            #if DEBUG
            let test = true
            #else
            let test = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
            #endif
            return Config(appID: (info["SomeWinsTelemetryAppID"] as? String ?? "").trimmingCharacters(in: .whitespaces),
                          namespace: (info["SomeWinsTelemetryNamespace"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                          testMode: test,
                          sampleRate: sampleRate(from: info["SomeWinsTelemetrySampleRate"]))
        }

        /// A plist number or a string of one, clamped to 0...1; anything
        /// missing or unreadable is 1, everyone.
        nonisolated static func sampleRate(from value: Any?) -> Double {
            let raw: Double?
            switch value {
            case let n as NSNumber: raw = n.doubleValue
            case let s as String: raw = Double(s.trimmingCharacters(in: .whitespaces))
            default: raw = nil
            }
            guard let raw, raw.isFinite else { return 1 }
            return min(1, max(0, raw))
        }

        var isEnabled: Bool { !appID.isEmpty }
    }

    /// Posts one request; the HTTP status, or nil when nothing came back.
    typealias Sender = @Sendable (URLRequest) async -> Int?

    private let config: Config
    private let defaults: UserDefaults
    private let send: Sender
    private let now: () -> Date
    private(set) var queue: [[String: Any]] = []
    private var sessionID = UUID()
    private var sessionStarted = false
    private var backgroundedAt: Date?
    private var flushing: Task<Void, Never>?
    private let context: [String: String]
    /// The screens already counted this session (`screen` is once each).
    private var screensSeen: Set<String> = []
    /// Zero, or how long the last 429 asked us to stay away.
    private(set) var backoff: TimeInterval = 0
    /// No send before this, after a 429.
    private var holdUntil: Date?

    init(config: Config = .fromBundle, defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init,
         send: @escaping Sender = Analytics.post) {
        self.config = config
        self.defaults = defaults
        self.now = now
        self.send = send
        context = Self.defaultContext()
        defaults.register(defaults: [Self.shareKey: true])
    }

    /// On, given an app ID, and this install inside the sample.
    var isSharing: Bool {
        config.isEnabled && defaults.bool(forKey: Self.shareKey)
            && Self.isSampled(install: installID, rate: config.sampleRate)
    }

    /// **In or out for the life of the install**, from its own random id:
    /// the first 8 bytes of its SHA-256 as a fraction of the whole range.
    /// Never per event, which would cut every funnel at random places.
    nonisolated static func isSampled(install: String, rate: Double) -> Bool {
        guard rate < 1 else { return true }
        guard rate > 0 else { return false }
        let digest = SHA256.hash(data: Data(("somewins.sample." + install).utf8))
        let top = digest.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        return Double(top) / Double(UInt64.max) < rate
    }

    // MARK: - Recording

    /// Records one event. Does nothing when the switch is off or no app ID
    /// was given.
    ///
    /// **`screen` goes once per screen per session** (2026-10-08): it fired on
    /// every tab change and was most of the volume, while "was Camera opened
    /// this session" is the whole of what it is read for.
    func signal(_ event: AnalyticsEvent, _ fields: [AnalyticsField] = []) {
        guard isSharing else { return }
        startSessionIfNeeded()
        let payload = Dictionary(fields.map(\.pair), uniquingKeysWith: { _, last in last })
        if event == .screen {
            let name = payload["screen"] ?? ""
            guard !screensSeen.contains(name) else { return }
            screensSeen.insert(name)
        }
        enqueue(type: event.rawValue, payload: payload)
    }

    /// Settings turned the switch off: nothing held is sent, and the install
    /// is forgotten, so turning it back on is a new anonymous install rather
    /// than the old one picking up where it left off.
    func stopSharing() {
        defaults.set(false, forKey: Self.shareKey)
        forgetInstall()
    }

    /// **Drops what is held and the identity it was held under** (2026-10-08):
    /// the queue, the install id, the first-day stamp and this session. Used
    /// by the switch going off and by Reset All Data, so neither leaves the
    /// old anonymous id behind to be linked to what comes after.
    func forgetInstall() {
        queue.removeAll()
        flushing?.cancel()
        flushing = nil
        Self.forgetIdentity(in: defaults)
        sessionID = UUID()
        sessionStarted = false
        screensSeen = []
        backoff = 0
        holdUntil = nil
    }

    /// The stored half of `forgetInstall`, for a caller with no instance.
    nonisolated static func forgetIdentity(in defaults: UserDefaults) {
        defaults.removeObject(forKey: installKey)
        defaults.removeObject(forKey: firstDayKey)
    }

    // MARK: - Sessions

    func didBecomeActive() {
        guard isSharing else { return }
        if let away = backgroundedAt, now().timeIntervalSince(away) > Self.sessionGap {
            sessionID = UUID()
            sessionStarted = false
            screensSeen = []
        }
        backgroundedAt = nil
        startSessionIfNeeded()
    }

    func didEnterBackground() {
        backgroundedAt = now()
        Task { await flush() }
    }

    private func startSessionIfNeeded() {
        guard !sessionStarted else { return }
        sessionStarted = true
        if defaults.string(forKey: Self.firstDayKey) == nil {
            let day = Self.day(now())
            defaults.set(day, forKey: Self.firstDayKey)
            enqueue(type: "TelemetryDeck.Acquisition.newInstallDetected",
                    payload: ["TelemetryDeck.Acquisition.firstSessionDate": day])
        }
        enqueue(type: "TelemetryDeck.Session.started", payload: [:])
    }

    // MARK: - The wire

    private func enqueue(type: String, payload: [String: String]) {
        var merged = context
        merged["sampleRate"] = String(config.sampleRate)
        for (k, v) in payload { merged[k] = v }
        queue.append([
            "appID": config.appID,
            "clientUser": clientUser,
            "sessionID": sessionID.uuidString,
            "type": type,
            "payload": merged,
            "isTestMode": config.testMode ? "true" : "false",
            "receivedAt": Self.stamp(now()),
        ])
        if queue.count > Self.queueLimit { queue.removeFirst(queue.count - Self.queueLimit) }
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard flushing == nil else { return }
        let wait = max(Self.flushDelay, backoff)
        flushing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            await self?.flush()
            self?.flushing = nil
            if self?.queue.isEmpty == false { self?.scheduleFlush() }
        }
    }

    /// Sends what is held, a batch at a time. A batch the server refuses as
    /// malformed is dropped (the SDK's list); a 429 keeps it and backs off;
    /// anything else stays for later.
    func flush() async {
        guard isSharing, !queue.isEmpty, let url = endpoint else { return }
        if let holdUntil, now() < holdUntil { return }
        let batch = Array(queue.prefix(Self.batchLimit))
        guard let body = try? JSONSerialization.data(withJSONObject: batch) else {
            queue.removeFirst(batch.count)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let status = await send(request)
        // The queue may have moved while the request was out: take off only
        // what was sent, from the front where it still is.
        let sent = min(batch.count, queue.count)
        if status == 429 {
            backoff = Self.nextBackoff(after: backoff)
            holdUntil = now().addingTimeInterval(backoff)
            return
        }
        if let status, (200..<300).contains(status) || Self.dropped.contains(status) {
            queue.removeFirst(sent)
            backoff = 0
            holdUntil = nil
        }
    }

    /// Doubles from twice the ordinary wait (20s, 40s, 80s...), never past
    /// `maxBackoff`.
    nonisolated static func nextBackoff(after current: TimeInterval) -> TimeInterval {
        min(maxBackoff, max(flushDelay, current) * 2)
    }

    nonisolated static let dropped: Set<Int> = [400, 401, 403, 404, 413, 422, 501, 505]

    var endpoint: URL? {
        let base = "https://nom.telemetrydeck.com/v2/"
        return URL(string: config.namespace.map { base + "namespace/\($0)/" } ?? base)
    }

    nonisolated static let post: Sender = { request in
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return nil }
        return (response as? HTTPURLResponse)?.statusCode
    }

    // MARK: - Who, without saying who

    /// A random id made on first use, never the device's, hashed with a fixed
    /// salt; TelemetryDeck hashes it again on its server. Deleting the app
    /// forgets it.
    var clientUser: String {
        let install = installID
        let salt = "somewins.analytics.v1.4f6c1d2e9b8a7c3d5e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2"
        return SHA256.hash(data: Data((install + salt).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The random install id, made on first use.
    var installID: String {
        if let kept = defaults.string(forKey: Self.installKey) { return kept }
        let made = UUID().uuidString
        defaults.set(made, forKey: Self.installKey)
        return made
    }

    // MARK: - Context every event carries

    /// The keys TelemetryDeck's own views read, so versions, devices and
    /// retention fill in without its SDK.
    nonisolated static func defaultContext() -> [String: String] {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let system = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        var machine = utsname()
        uname(&machine)
        let model = withUnsafeBytes(of: &machine.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        #if DEBUG
        let debug = "true"
        #else
        let debug = "false"
        #endif
        let simulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        let testFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        return [
            "TelemetryDeck.AppInfo.version": version,
            "TelemetryDeck.AppInfo.buildNumber": build,
            "TelemetryDeck.AppInfo.versionAndBuildNumber": "\(version) (build \(build))",
            "TelemetryDeck.Device.platform": "iOS",
            "TelemetryDeck.Device.operatingSystem": "iOS",
            "TelemetryDeck.Device.systemVersion": "iOS \(system)",
            "TelemetryDeck.Device.systemMajorVersion": "iOS \(os.majorVersion)",
            "TelemetryDeck.Device.modelName": model,
            "TelemetryDeck.RunContext.locale": Locale.current.identifier,
            "TelemetryDeck.RunContext.isDebug": debug,
            "TelemetryDeck.RunContext.isSimulator": simulator ? "true" : "false",
            "TelemetryDeck.RunContext.isTestFlight": testFlight ? "true" : "false",
            "appVersion": version,
            "buildNumber": build,
            "systemVersion": system,
            "modelName": model,
        ]
    }

    nonisolated static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    nonisolated static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f.string(from: date)
    }
}

// MARK: - What may be said

/// Every event the app sends. The table in the spec, section 2.
enum AnalyticsEvent: String, Sendable, CaseIterable {
    case winLogged = "win_logged"
    case goalReached = "goal_reached"
    case stripPrinted = "strip_printed"
    case stripDeveloped = "strip_developed"
    case stripShared = "strip_shared"
    case journalWritten = "journal_written"
    case doodleDrawn = "doodle_drawn"
    case crewCreated = "crew_created"
    case crewInviteSent = "crew_invite_sent"
    case crewJoined = "crew_joined"
    case crewMessageSent = "crew_message_sent"
    case crewReaction = "crew_reaction"
    case onboardingStep = "onboarding_step"
    case trailer
    case headMade = "head_made"
    case replaySaved = "replay_saved"
    case tipJarShown = "tip_jar_shown"
    case tipPurchased = "tip_purchased"
    case tipAsk = "tip_ask"
    case screen
    /// MetricKit reported a crash, hang, CPU or disk-write exception
    /// (`Diagnostics`, 2026-10-08). One per kind per delivery, coarse fields
    /// only: never a stack, never anything a person made.
    case diagnostic
}

/// **Closed on purpose.** Each case carries an enum, a bool or a bucket, never
/// a String, so nothing a person typed can ride along.
enum AnalyticsField: Sendable, Equatable {
    enum Size: String, Sendable { case quick, regular, deep }
    enum Source: String, Sendable { case slot, camera, widget, siri, lockScreen = "lock_screen", crew, onboarding }
    enum Destination: String, Sendable { case instagram, messages, saved, crew, other }
    enum Action: String, Sendable { case shown, done, skipped, played, finished, soundOn = "sound_on", tipped, dismissed }
    enum Tier: String, Sendable { case small, medium, large }
    enum Screen: String, Sendable { case wins, camera, memories, settings, crews, chat, profile, journal }
    enum Diagnostic: String, Sendable, CaseIterable {
        case crash, hang, cpuException = "cpu_exception", diskWrite = "disk_write"
    }

    case size(Size)
    case source(Source)
    case hasPhoto(Bool)
    case hasDoodle(Bool)
    /// Bucketed: 1 to 10 as itself, then "11+".
    case goal(Int)
    case destination(Destination)
    /// An onboarding page by its index, never its words.
    case step(Int)
    case action(Action)
    case tier(Tier)
    case screen(Screen)
    case diagnostic(Diagnostic)
    /// How many of one kind arrived together. Bucketed as `goal` is.
    case count(Int)
    /// A Mach exception type, a small number by definition; outside 0...64
    /// it is "other", so nothing larger can ride along.
    case exceptionType(Int)
    /// A POSIX signal number, bucketed the same way.
    case signalNumber(Int)
    /// The build a diagnostic came from, which may not be the running one.
    case appBuild(Int)

    var pair: (String, String) {
        switch self {
        case .size(let v): ("size", v.rawValue)
        case .source(let v): ("source", v.rawValue)
        case .hasPhoto(let v): ("has_photo", v ? "true" : "false")
        case .hasDoodle(let v): ("has_doodle", v ? "true" : "false")
        case .goal(let v): ("goal", v > 10 ? "11+" : String(max(0, v)))
        case .destination(let v): ("destination", v.rawValue)
        case .step(let v): ("step", String(v))
        case .action(let v): ("action", v.rawValue)
        case .tier(let v): ("tier", v.rawValue)
        case .screen(let v): ("screen", v.rawValue)
        case .diagnostic(let v): ("diagnostic", v.rawValue)
        case .count(let v): ("count", v > 10 ? "11+" : String(max(0, v)))
        case .exceptionType(let v): ("exception_type", Self.small(v))
        case .signalNumber(let v): ("signal", Self.small(v))
        case .appBuild(let v): ("diagnostic_build", String(max(0, v)))
        }
    }

    private static func small(_ v: Int) -> String { (0...64).contains(v) ? String(v) : "other" }
}
