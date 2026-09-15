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
    /// Never reset: what `window(_:seconds:)` subtracts from.
    private static var totals: [String: Int] = [:]
    private static var link: CADisplayLink?
    private static var target: LinkTarget?
    private static var lastFrame: CFTimeInterval = 0
    private static var lastFlush: CFTimeInterval = 0
    private static var pendingMark: (name: String, at: CFTimeInterval)?

    /// One body evaluation of `name`.
    static func count(_ name: String) {
        guard isOn else { return }
        counts[name, default: 0] += 1
        totals[name, default: 0] += 1
        start()
    }

    /// Logs every count that moved in the next `seconds`, as one
    /// `[PERF-WINDOW] label ...` line. For "how many in the first two seconds
    /// after X", which the once-a-second flush cannot answer to better than a
    /// second either side. (Batch C, 2026-09-15.)
    static func window(_ label: String, seconds: Double) {
        guard isOn else { return }
        start()
        let before = totals
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            let line = totals.compactMap { key, value -> String? in
                let d = value - (before[key] ?? 0)
                return d == 0 ? nil : "\(key)=\(d)"
            }.sorted().joined(separator: " ")
            NSLog("[PERF-WINDOW] %@ %.1fs %@", label, seconds, line)
        }
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
                NSLog("[PERF] bodies %@ window=%.2fs at=%.3f", line, now - lastFlush, now)
                counts.removeAll()
            }
            lastFlush = now
        }
    }

    // MARK: - Culling

    private struct Inserted { let at: CFTimeInterval; let top: CGFloat; let bottom: CGFloat; var reported = false }
    private static var cullVisible: Set<UUID> = []
    private static var cullInserted: [UUID: Inserted] = [:]
    private static var cullOnScreenMidFade = 0

    /// The blocks a culling tower is drawing this evaluation, with each
    /// one's top and bottom in the grid's own top-down space. Blocks that were
    /// not drawn last time are fading in (`towerBlockFadeIn`) from now.
    static func cullRender(_ blocks: [(id: UUID, top: CGFloat, bottom: CGFloat)]) {
        guard isOn else { return }
        start()
        let now = CACurrentMediaTime()
        let ids = Set(blocks.map(\.id))
        if !cullVisible.isEmpty {
            var n = 0
            for b in blocks where !cullVisible.contains(b.id) {
                cullInserted[b.id] = Inserted(at: now, top: b.top, bottom: b.bottom)
                n += 1
            }
            if n > 0 { NSLog("[PERF-CULL] inserted %d", n) }
        }
        cullVisible = ids
    }

    /// Called every scroll frame: is any block still inside its fade-in
    /// window already on screen? `gridTop` is the grid's top edge in window
    /// coordinates, `windowHeight` the window's height.
    static func cullCheck(gridTop: CGFloat, windowHeight: CGFloat, fade: CFTimeInterval) {
        guard isOn, !cullInserted.isEmpty else { return }
        let now = CACurrentMediaTime()
        for (id, var entry) in cullInserted {
            let age = now - entry.at
            if age > fade + 0.05 { cullInserted[id] = nil; continue }
            guard !entry.reported, age < fade else { continue }
            let top = gridTop + entry.top, bottom = gridTop + entry.bottom
            if bottom > 0 && top < windowHeight {
                cullOnScreenMidFade += 1
                entry.reported = true
                cullInserted[id] = entry
                NSLog("[PERF-CULL] ON SCREEN mid-fade age=%.0fms top=%.0f bottom=%.0f total=%d",
                      age * 1000, top, bottom, cullOnScreenMidFade)
            }
        }
    }

    private final class LinkTarget: NSObject {
        @objc func tick(_ link: CADisplayLink) { PerfProbe.tick(link) }
    }
}
#endif
