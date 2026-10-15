import SwiftUI
import UIKit

/// **The crew chat as a native sheet** (the owner, 2026-10-15: "right now
/// its custom but it is not feeling responsive and clean i think we should
/// use a native pull up since that will have the amazing polish").
///
/// One persistent sheet for as long as the crew is on screen, the shape of
/// Maps' and Find My's: never dismissed by a drag, the tower alive under it
/// up to the reading height, and three heights. The research and its
/// pitfalls are `docs/research/2026-10-15-native-chat-sheet.md`.
///
/// `-strataDrawerChat 1` brings back the custom drawer (`ChatDrawer`) for a
/// side by side.
enum NativeChat {
    static var isOn: Bool {
        #if DEBUG
        if DebugHarness.argument("-strataDrawerChat") == "1" { return false }
        #endif
        return true
    }

    /// At rest: the newest line over the composer, and the grabber.
    static let rest = PresentationDetent.custom(ChatRestDetent.self)
    /// Part way: the thread, the tower still showing above (the owner,
    /// 2026-10-14: "popping up enough to see the chat").
    static let reading = CrewChatSheet.drawerHeight
    static let detents: Set<PresentationDetent> = [rest, reading, .large]

    /// The resting card's height, and the room the tower keeps for it.
    static let restHeight: CGFloat = 128
}

/// The resting height as its own type, so its identity never changes while
/// its number can: a detent built from a measured value is a new detent
/// whenever the value moves, and a selected detent dropping out of the set
/// switches with no animation (FB19252983).
struct ChatRestDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        min(NativeChat.restHeight, context.maxDetentValue * 0.3)
    }
}

/// **The chat steps aside for what the app itself presents.** Add a Win and
/// a planned box's camera come from the app's root, which cannot present
/// while this sheet is up (one presentation at a time). The sheet goes down,
/// the thing opens, and once nothing is presented any more the sheet comes
/// back.
@MainActor
@Observable
final class ChatAside {
    private(set) var away = false
    @ObservationIgnored private var watch: Task<Void, Never>?

    func run(_ action: @escaping () -> Void) {
        away = true
        watch?.cancel()
        watch = Task { @MainActor in
            // The sheet's own fall, then the thing it made room for.
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            action()
            try? await Task.sleep(for: .milliseconds(900))
            while !Task.isCancelled, Self.rootIsPresenting() {
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled else { return }
            away = false
        }
    }

    func cancel() {
        watch?.cancel()
        away = false
    }

    static func rootIsPresenting() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?.presentedViewController != nil
    }
}

extension View {
    /// `transform` applied, or not, by a condition fixed for the view's life.
    @ViewBuilder
    func applying<Changed: View>(_ condition: Bool, _ transform: (Self) -> Changed) -> some View {
        if condition { transform(self) } else { self }
    }
}

/// **Something on the crew screen opening over it** (the review, 2026-10-15):
/// while the native chat is up, nothing under it can present, so a crew plan
/// box's menu, the plan card's strip and your blank head's maker did nothing.
/// They ask through this: on the crew screen the chat steps aside, the thing
/// opens, and the chat comes back when it closes; everywhere else, and inside
/// the chat itself, it simply runs.
struct PresentAside {
    let run: (@escaping () -> Void) -> Void
    func callAsFunction(_ action: @escaping () -> Void) { run(action) }
    static let direct = PresentAside { $0() }
}

private struct PresentAsideKey: EnvironmentKey {
    static let defaultValue = PresentAside.direct
}

extension EnvironmentValues {
    var presentAside: PresentAside {
        get { self[PresentAsideKey.self] }
        set { self[PresentAsideKey.self] = newValue }
    }
}

/// **Whether the native chat's sheet is up**, for the Crews list's own
/// alerts (the review, 2026-10-15): the list cannot present while the chat
/// is up, so its alerts stand down and the crew screen shows the same ones
/// from the chat (`CrewTowerView.presenting`). The moment the chat goes, the
/// list's alerts are its own again, which is how "This crew has ended."
/// reaches you after the crew closes.
@MainActor
@Observable
final class NativeChatPresence {
    static let shared = NativeChatPresence()
    var up = false
}
