import SwiftUI
import UIKit

/// **The crew chat as a native sheet** (the owner, 2026-10-15: "right now
/// its custom but it is not feeling responsive and clean i think we should
/// use a native pull up since that will have the amazing polish").
///
/// **A sheet only while the chat is open** (the owner, later the same day:
/// the persistent sheet's resting card "looks like a glitch on the bottom
/// doesnt look sleek", and the chat was "super laggy"; his pick "Bar, then
/// sheet"). An iOS 26 sheet below full height always floats as an inset
/// card, so at rest the crew stands on `ChatRestBar`, flush with the foot of
/// the screen, and the sheet rises from it to read or to write and goes back
/// into it on a drag down. Nothing is presented over the tower while the
/// chat is shut. The research and its pitfalls are
/// `docs/research/2026-10-15-native-chat-sheet.md`.
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

    /// Part way: the thread, the tower still showing above (the owner,
    /// 2026-10-14: "popping up enough to see the chat").
    static let reading = CrewChatSheet.drawerHeight
    /// Open only: at rest the crew stands on `ChatRestBar`, not on a
    /// floating card (2026-10-15).
    static let detents: Set<PresentationDetent> = [reading, .large]
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
            // Clear twice, half a second apart: a menu that closes and then
            // opens the camera leaves a moment with nothing up between them,
            // and the chat must not rise into it (the second review).
            var clear = 0
            while !Task.isCancelled, clear < 2 {
                try? await Task.sleep(for: .milliseconds(250))
                clear = Self.rootIsPresenting() ? 0 : clear + 1
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
