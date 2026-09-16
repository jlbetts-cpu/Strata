#if DEBUG
import Foundation

/// **`-strataHeadTrace`: every target a head's state is sent to, one line
/// each, so motion can be counted rather than judged.**
///
///     [strata-head-trace] t=12.345 id=made gaze 0.412 -0.080
///
/// `t` is seconds since the first line of the launch on a monotonic clock, so
/// two heads on one page share one timeline. What is logged is the TARGET a
/// spring is sent to, at the moment it is sent, not the drawn value on the way
/// there; frame-level checks are done on a recording (see the parity report).
///
/// Events: `gaze x y`, `pose yaw roll lean dip`, `lids shut squash`,
/// `face <expression> <pop|morph|swap>`, `beat <id>`, `blink <depth>`,
/// `take <id>`, `awake <bool>`.
nonisolated enum HeadTrace {
    static let isOn: Bool = ProcessInfo.processInfo.arguments.contains("-strataHeadTrace")
    private static let start = ContinuousClock.now

    static func log(_ id: String?, _ event: @autoclosure () -> String) {
        guard isOn, let id else { return }
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        NSLog("[strata-head-trace] t=%.3f id=%@ %@", seconds, id, event())
    }

    static func number(_ value: Double) -> String { String(format: "%.3f", value) }
    static func number(_ value: CGFloat) -> String { String(format: "%.3f", Double(value)) }
}
#endif
