import SwiftUI

/// What is in the folder. The resting face is a function of this and nothing
/// else.
struct FolderContents: Equatable {
    var count: Int = 0
}

/// **Things the person did.** Every one of these is an action, present tense.
/// There is deliberately no `.neglected`, no `.notOpenedSince`, no
/// `.streakBroken`: the folder's face changes because somebody did something,
/// never because they didn't. That single rule is the whole Tamagotchi
/// decision, and keeping it as a property of this enum means it cannot be
/// quietly broken later by adding a timer somewhere else.
enum FolderEvent: Equatable {
    /// A win went in.
    case winAdded
    /// Several went in close together.
    case winRush
    /// A win is being held over the folder, not yet dropped.
    case winHovering
    /// The hover ended without a drop.
    case hoverEnded
    /// Picked up, shaken, thrown about.
    case shaken
    /// Tapped when tapping does nothing. Repeats escalate.
    case poked
    /// Opened, or closed.
    case opened
    case closed
}

/// **When the face changes, and into what.**
///
/// The owner: "there needs to be a logic system to know when they should
/// change expressions and the lines should glide effortlessly into new
/// animations."
///
/// Two layers, and they are different in kind:
///
/// **Resting** is a pure function of the folder's CONTENTS. An empty folder
/// is sleepy, because it is empty, which is a fact about the folder. A folder
/// with wins in it is awake. That is the whole resting rule, and it is
/// deliberately this short — every richer version I tried ended up saying
/// something about the person's week rather than about the folder's contents.
///
/// **Reactions** are transient and belong to an event. They play, they hold
/// for a moment, and they fall back to resting on their own. Nothing here
/// latches, so the folder cannot end up wearing a mood somebody has to clear.
///
/// The escalating poke is the one with memory: tap a folder that has nothing
/// to say and it goes confused, then annoyed, then bored, and forgets after a
/// few seconds of being left alone. It is the only counter in here, it runs
/// on YOUR taps rather than on the clock, and it is most of the character.
@MainActor
@Observable
final class FolderMood {

    /// **One curve for every change, so the whole face moves as one thing.**
    ///
    /// Springy enough to read as alive, damped enough not to wobble: a face
    /// that overshoots looks rubbery rather than animated. This is not a rung
    /// of `GridConstants` on purpose, because that ladder is tuned for layout
    /// moving and this is an expression changing, which wants a touch more
    /// bounce than a card does.
    static let glide = Animation.spring(response: 0.34, dampingFraction: 0.72)

    private(set) var expression: FaceExpression = .idle

    var contents: FolderContents {
        didSet { if contents != oldValue { settle() } }
    }

    private var pokes = 0
    private var holding = false
    private var returnTask: Task<Void, Never>?
    private var forgetPokes: Task<Void, Never>?

    init(contents: FolderContents = FolderContents()) {
        self.contents = contents
        expression = Self.resting(for: contents)
    }

    /// The face a folder wears when nothing is happening to it.
    nonisolated static func resting(for contents: FolderContents) -> FaceExpression {
        contents.count == 0 ? .sleepy : .idle
    }

    /// What an event does, and for how long. `nil` duration means it is held
    /// until something else changes it, which is only ever a hover.
    nonisolated static func reaction(to event: FolderEvent,
                                     pokes: Int) -> (FaceExpression, Duration?)? {
        switch event {
        case .winAdded:    return (.happy, .milliseconds(1500))
        case .winRush:     return (.dizzy, .milliseconds(1300))
        case .winHovering: return (.nervous, nil)
        case .hoverEnded:  return nil
        case .shaken:      return (.dizzy, .milliseconds(1100))
        case .opened:      return (.happy, .milliseconds(900))
        case .closed:      return nil
        case .poked:
            // Escalating, and it forgets. One poke is a question, two is a
            // frown, three or more and it has stopped being interested.
            switch pokes {
            case 0:  return (.confused, .milliseconds(1200))
            case 1:  return (.annoyed, .milliseconds(1400))
            default: return (.bored, .milliseconds(1800))
            }
        }
    }

    func react(to event: FolderEvent) {
        returnTask?.cancel()

        if event == .poked {
            forgetPokes?.cancel()
            forgetPokes = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                self?.pokes = 0
            }
        }

        guard let (face, hold) = Self.reaction(to: event, pokes: pokes) else {
            holding = false
            settle()
            return
        }
        if event == .poked { pokes += 1 }
        holding = (hold == nil)

        withAnimation(Self.glide) { expression = face }
        guard let hold else { return }
        returnTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: hold)
            guard !Task.isCancelled else { return }
            self?.settle()
        }
    }

    /// Back to what the contents say, unless something is being held over it.
    func settle() {
        guard !holding else { return }
        withAnimation(Self.glide) { expression = Self.resting(for: contents) }
    }
}
