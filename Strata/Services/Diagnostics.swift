import Foundation
import MetricKit

/// **Crashes and hangs, seen without a crash SDK** (2026-10-08).
///
/// Before this the app had no way to learn it had crashed on somebody's phone
/// except a one-star review. A crash reporter is a third-party SDK and a new
/// thing collected; MetricKit is Apple's own, already on the phone, and hands
/// the app a day's crashes, hangs, CPU and disk-write exceptions once a day
/// (sooner in TestFlight).
///
/// Two things happen to a delivery and nothing else:
/// - **The newest payloads are kept on this phone**, in Application Support,
///   at most `keep` of them, so a person writing in about a crash can be asked
///   to send one and a build on the owner's own phone can be read in Xcode.
/// - **One `diagnostic` signal per kind** goes through `Analytics`, with
///   coarse numbers only: the kind, how many, a crash's exception type and
///   signal, and the build. Never a stack, never a payload, never anything a
///   person made, and nothing at all when Share Anonymous Usage is off.
///
/// Nonisolated because MetricKit calls in on its own queue.
nonisolated final class Diagnostics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = Diagnostics(directory: Diagnostics.defaultDirectory)

    /// Payloads kept on the phone. Enough to see a pattern, small on disk.
    static let keep = 3

    let directory: URL
    private let lock = NSLock()
    private var started = false

    init(directory: URL) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
    }

    /// At launch. Adding a subscriber twice would deliver twice.
    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
    }

    // MARK: - A delivery

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let stamp = Date()
        for (i, payload) in payloads.enumerated() {
            save(payload.jsonRepresentation(), named: Self.fileName(at: stamp, index: i))
        }
        let summaries = payloads.flatMap(Self.summaries(of:))
        guard !summaries.isEmpty else { return }
        Task { @MainActor in
            for fields in DiagnosticSignals.fields(for: summaries) {
                Analytics.shared.signal(.diagnostic, fields)
            }
        }
    }

    /// What the signal may say about each diagnostic, read off MetricKit's
    /// types and nothing else.
    static func summaries(of payload: MXDiagnosticPayload) -> [DiagnosticSummary] {
        var out: [DiagnosticSummary] = []
        for crash in payload.crashDiagnostics ?? [] {
            out.append(DiagnosticSummary(kind: .crash,
                                         exceptionType: crash.exceptionType?.intValue,
                                         signal: crash.signal?.intValue,
                                         build: Int(crash.metaData.applicationBuildVersion)))
        }
        for hang in payload.hangDiagnostics ?? [] {
            out.append(DiagnosticSummary(kind: .hang, build: Int(hang.metaData.applicationBuildVersion)))
        }
        for cpu in payload.cpuExceptionDiagnostics ?? [] {
            out.append(DiagnosticSummary(kind: .cpuException, build: Int(cpu.metaData.applicationBuildVersion)))
        }
        for disk in payload.diskWriteExceptionDiagnostics ?? [] {
            out.append(DiagnosticSummary(kind: .diskWrite, build: Int(disk.metaData.applicationBuildVersion)))
        }
        return out
    }

    // MARK: - Kept on the phone

    private func save(_ json: Data, named name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try json.write(to: directory.appending(path: name), options: .atomic)
        } catch {
            NSLog("[diagnostics] could not keep a payload: \(error)")
            return
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for old in Self.toPrune(names, keep: Self.keep) {
            try? FileManager.default.removeItem(at: directory.appending(path: old))
        }
    }

    /// `diagnostic-<ms since 1970, zero padded>-<index>.json`, so a name sorts
    /// in the order the payloads came.
    static func fileName(at date: Date, index: Int) -> String {
        let ms = Int64(max(0, date.timeIntervalSince1970) * 1000)
        return String(format: "diagnostic-%015lld-%02d.json", ms, index)
    }

    /// Every kept payload past the newest `keep`. Only this file's own names
    /// are ever considered, so nothing else in the folder can be removed.
    static func toPrune(_ names: [String], keep: Int) -> [String] {
        let ours = names.filter { $0.hasPrefix("diagnostic-") && $0.hasSuffix(".json") }.sorted(by: >)
        return Array(ours.dropFirst(max(0, keep)))
    }
}

/// One diagnostic, as much of it as may leave the phone.
nonisolated struct DiagnosticSummary: Sendable, Equatable {
    enum Kind: String, Sendable, CaseIterable {
        case crash, hang, cpuException = "cpu_exception", diskWrite = "disk_write"
    }

    var kind: Kind
    var exceptionType: Int? = nil
    var signal: Int? = nil
    /// The build it happened on; nil when that is not a plain number.
    var build: Int? = nil
}

/// **One signal per kind per delivery**, so a crash loop is one event with a
/// count rather than a thousand events against a monthly cap.
enum DiagnosticSignals {
    static func fields(for summaries: [DiagnosticSummary]) -> [[AnalyticsField]] {
        DiagnosticSummary.Kind.allCases.compactMap { kind in
            let mine = summaries.filter { $0.kind == kind }
            guard let kind = AnalyticsField.Diagnostic(rawValue: kind.rawValue),
                  let example = representative(of: mine) else { return nil }
            var fields: [AnalyticsField] = [.diagnostic(kind), .count(mine.count)]
            if let type = example.exceptionType { fields.append(.exceptionType(type)) }
            if let signal = example.signal { fields.append(.signalNumber(signal)) }
            if let build = example.build { fields.append(.appBuild(build)) }
            return fields
        }
    }

    /// The commonest exception and signal among them, the first on a tie, so
    /// one stray crash does not speak for a loop of another.
    static func representative(of summaries: [DiagnosticSummary]) -> DiagnosticSummary? {
        guard let first = summaries.first else { return nil }
        func key(_ s: DiagnosticSummary) -> String { "\(s.exceptionType ?? -1)/\(s.signal ?? -1)" }
        var counts: [String: Int] = [:]
        for s in summaries { counts[key(s), default: 0] += 1 }
        return summaries.first { counts[key($0)] == counts.values.max() } ?? first
    }
}
