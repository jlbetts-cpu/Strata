#if DEBUG
import QuartzCore
import Foundation

/// Counts and frame gaps for smoothness work, from `-strataPerfProbe`.
///
/// Off unless the flag is on: every call returns at the first line. With it
/// on, three kinds of line go to the unified log, and nothing else changes:
///
/// - `[PERF] bodies AnimatedBlockView=N ...` once a second while anything
///   counted: body evaluations in that second, per view.
/// - `[PERF-HITCH] gap=Nms` for any display-link gap over 50ms.
/// - `[PERF-MARK] name → next frame Nms` for a marked moment (a landing), the
///   time from the mark to the next frame the display link saw, which is how
///   long the main thread held that frame.
///
/// Read with `xcrun simctl spawn <dev> log stream --predicate
/// 'eventMessage CONTAINS "[PERF"'`. Written for the 2026-09-14 tower pass
/// (batch B): the body counts are the before/after for removing the scroll
/// offset from the block view, and the mark is the first-landing stall.
enum PerfProbe {
    nonisolated static let isOn = ProcessInfo.processInfo.arguments.contains("-strataPerfProbe")

    private static var counts: [String: Int] = [:]
    private static var link: CADisplayLink?
    private static var target: LinkTarget?
    private static var lastFrame: CFTimeInterval = 0
    private static var lastFlush: CFTimeInterval = 0
    private static var pendingMark: (name: String, at: CFTimeInterval)?

    /// One body evaluation of `name`.
    static func count(_ name: String) {
        guard isOn else { return }
        counts[name, default: 0] += 1
        start()
    }

    /// Something happened that the next frame should be timed against.
    static func mark(_ name: String) {
        guard isOn else { return }
        start()
        let now = CACurrentMediaTime()
        NSLog("[PERF-MARK] %@ at=%.3f", name, now)
        pendingMark = (name, now)
    }

    /// A duration measured by the caller, logged as is.
    nonisolated static func duration(_ name: String, since start: CFTimeInterval) {
        guard isOn else { return }
        NSLog("[PERF-SPAN] %@ %.1fms", name, (CACurrentMediaTime() - start) * 1000)
    }

    static func start() {
        guard isOn, link == nil else { return }
        let t = LinkTarget()
        let l = CADisplayLink(target: t, selector: #selector(LinkTarget.tick(_:)))
        l.add(to: .main, forMode: .common)
        target = t
        link = l
        lastFlush = CACurrentMediaTime()
    }

    fileprivate static func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        if lastFrame > 0, now - lastFrame > 0.050 {
            NSLog("[PERF-HITCH] gap=%.0fms at=%.3f", (now - lastFrame) * 1000, now)
        }
        lastFrame = now
        if let mark = pendingMark {
            NSLog("[PERF-MARK] %@ → next frame %.1fms", mark.name, (now - mark.at) * 1000)
            pendingMark = nil
        }
        if now - lastFlush >= 1 {
            if !counts.isEmpty {
                let line = counts.sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: " ")
                NSLog("[PERF] bodies %@ window=%.2fs", line, now - lastFlush)
                counts.removeAll()
            }
            lastFlush = now
        }
    }

    private final class LinkTarget: NSObject {
        @objc func tick(_ link: CADisplayLink) { PerfProbe.tick(link) }
    }
}
#endif
