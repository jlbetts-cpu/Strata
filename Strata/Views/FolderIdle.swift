import SwiftUI

/// **The illusion of life, on real numbers rather than chosen ones.**
///
/// A face that holds perfectly still between events is a graphic. What makes
/// it read as alive is what it does when nothing is happening, and the
/// literature on eyes is specific enough to build from rather than guess at:
///
/// - **Spontaneous blinking runs 15 to 20 times a minute**, so one every
///   three to four seconds. A suggested two-to-six was close but wide at the
///   top: six seconds apart reads as staring.
/// - **A blink lasts 100 to 200ms**, with full closure only 10 to 50ms of it.
///   So it is a snap, not a gesture. 120ms total here.
/// - **Saccades last 30 to 120ms.** Eyes do not pan, they jump, and this is
///   the single detail that separates alive from animated. 90ms.
/// - **A fixation is 200 to 600ms while reading**, longer when idle, with a
///   200ms refractory period before another jump is possible. Idle holds are
///   1.4 to 3.4 seconds here.
///
/// The occasional **double blink** is not from the literature; it is an
/// animator's trick, and it is worth having because a perfectly regular blink
/// is its own kind of dead. One in six.
///
/// Nothing in here reacts to time passing in the user's life. It is a loop
/// that runs while the folder is on screen and stops when it is not.
@MainActor
@Observable
final class FolderIdle {

    /// Multiplied into the expression's openness, so a blink composes with a
    /// squint rather than fighting it.
    private(set) var blink: CGFloat = 1
    /// **How much of a blink is happening, 0 to 1.** Separate from `blink`
    /// because a blink is two things at once, and doing only the first is
    /// what made the first version read as a shrink rather than a blink.
    ///
    /// The owner: "blinking should really feel like blinking."
    ///
    /// A lid comes DOWN. On a two-stroke face that means the stroke
    /// FLATTENS as it closes — an arched eye passes through a straight line
    /// on its way shut, because a closed eye IS a line. Squashing an arch
    /// vertically just makes a smaller arch, which reads as the eye shrinking
    /// away from you. So the bend is pulled toward zero by this amount at the
    /// same time as the height goes.
    private(set) var flatten: CGFloat = 0
    /// Added to the expression's gaze.
    private(set) var gaze: CGSize = .zero
    /// The slow vertical drift. Two points over two and a half seconds, which
    /// is under the threshold of noticing and over the threshold of feeling.
    private(set) var breath: CGFloat = 0

    private var loop: Task<Void, Never>?

    /// How far the eyes wander. A fraction of an eye's width, so it scales
    /// with the face rather than being a fixed number of points.
    var reach: CGFloat = 5

    func start() {
        guard loop == nil else { return }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            breath = 2
        }
        loop = Task { @MainActor [weak self] in
            // Two independent rhythms, because eyes do not blink and look in
            // step and the moment they do it reads as a machine.
            async let blinking: Void = self?.blinkForever() ?? ()
            async let looking: Void = self?.lookAroundForever() ?? ()
            _ = await (blinking, looking)
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        blink = 1
        flatten = 0
        gaze = .zero
    }

    private func blinkForever() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2900...4100)))
            guard !Task.isCancelled else { return }
            await blinkOnce()
            if Int.random(in: 0..<6) == 0 {
                try? await Task.sleep(for: .milliseconds(140))
                await blinkOnce()
            }
        }
    }

    /// **Closing is faster than opening, and that asymmetry is most of what
    /// sells it.** A lid snaps shut and rolls back up; a symmetric blink
    /// reads as a pulse. Measured blinks run 100 to 200ms in total with the
    /// closure the shorter half, so: 55ms down, a 25ms hold at the bottom,
    /// 95ms back up. 175ms, inside the range, weighted the way a real one is.
    private func blinkOnce() async {
        withAnimation(.easeIn(duration: 0.055)) {
            blink = 0.04
            flatten = 1
        }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.easeOut(duration: 0.095)) {
            blink = 1
            flatten = 0
        }
        try? await Task.sleep(for: .milliseconds(95))
    }

    private func lookAroundForever() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1400...3400)))
            guard !Task.isCancelled else { return }
            // Back to centre about half the time: eyes return to rest rather
            // than wandering further and further from it.
            let next: CGSize = Bool.random()
                ? .zero
                : CGSize(width: CGFloat.random(in: -reach...reach),
                         height: CGFloat.random(in: -reach * 0.5...reach * 0.45))
            // A jump, not a pan.
            withAnimation(.easeOut(duration: 0.09)) { gaze = next }
        }
    }
}
