import SwiftUI
import Combine

@MainActor
final class OnboardingState: ObservableObject {
    // MARK: - Persistent Flags (survive app restart)
    @AppStorage("onb_welcome") var hasSeenWelcome = false
    @AppStorage("onb_hold") var hasSeenHoldHint = false
    @AppStorage("onb_skip") var hasSeenSkipHint = false
    @AppStorage("onb_firstBlock") var hasSeenFirstBlockHint = false
    @AppStorage("onb_nlp") var hasSeenNLPHint = false
    @AppStorage("onb_drag") var hasSeenDragHint = false
    @AppStorage("onb_photo") var hasSeenPhotoHint = false
    @AppStorage("onb_week") var hasSeenWeekHint = false
    @AppStorage("onb_contextMenu") var hasSeenContextMenuHint = false
    @AppStorage("onb_sessionCount") var sessionCount = 0

    // MARK: - Transient State (current hint display)
    @Published var activeHint: HintType? = nil
    private var hintDismissTask: Task<Void, Never>? = nil

    enum HintType: String {
        case hold, skip, firstBlock, nlp, drag, photo, week, contextMenu
    }

    /// Only show one hint at a time — prevents overlap (mutex)
    func showHint(_ type: HintType, duration: TimeInterval = 4.0) {
        guard activeHint == nil else { return }
        activeHint = type
        hintDismissTask?.cancel()
        hintDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            guard !Task.isCancelled else { return }
            dismissHint()
        }
    }

    func dismissHint() {
        activeHint = nil
        hintDismissTask?.cancel()
        hintDismissTask = nil
    }
}
