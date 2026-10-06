import SwiftUI

/// **"Sam added you to a win"**: asked once, with a system alert, the first
/// time this phone sees a crew win that tags you (shared wins, spec 1).
///
/// Keep writes a copy into your own record (`SocialStore.keepTaggedWin`).
/// Not This One is silent: nothing is sent and the tagger is never told.
/// Either answer is kept by win id, so the question never comes back, and a
/// tag from someone you blocked never asks it (`SocialStore.tagToAsk`).
///
/// Hung on the crew tower, where the tagged win is: the question arrives
/// with the block it is about, a moment after it lands, and never over a
/// sheet or the viewer, where iOS would drop it.
struct KeepTaggedWinAlert: ViewModifier {
    let crewID: CrewID
    /// Something else is on screen (the carousel, Crew Info, a report): wait.
    var isBusy: Bool

    @State private var asking: SharedWin?

    private var store: SocialStore { SocialStore.shared }

    func body(content: Content) -> some View {
        content
            .task(id: "\(store.tagToAsk(in: crewID)?.winID.uuidString ?? "-")|\(isBusy)") {
                guard asking == nil, !isBusy, let next = store.tagToAsk(in: crewID) else { return }
                // After its block has landed: the question is about a block
                // you can see.
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled, !isBusy, store.tagToAsk(in: crewID)?.winID == next.winID else { return }
                asking = next
            }
            .alert(Text(asking.map(Self.title) ?? ""),
                   isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
                   presenting: asking) { win in
                Button("Keep") { Task { await store.answer(win, keep: true) } }
                Button("Not This One", role: .cancel) { Task { await store.answer(win, keep: false) } }
            } message: { win in
                Text(Self.message(win))
            }
    }

    /// "Sam added you to a win".
    @MainActor
    static func title(_ win: SharedWin) -> String {
        let name = SocialStore.shared.crew(win.crewID)?.member(win.senderProfileID)?.shortName ?? ""
        return "\(name.isEmpty ? "A friend" : name) added you to a win"
    }

    /// "Morning run. Keep it on your tower too?", or only the question for a
    /// win with no name.
    static func message(_ win: SharedWin) -> String {
        let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "Keep it on your tower too?" }
        let stop = title.last.map { ".!?".contains($0) } == true ? "" : "."
        return "\(title)\(stop) Keep it on your tower too?"
    }
}

extension View {
    /// The Keep question for a win in this crew that tags you.
    func keepTaggedWin(in crewID: CrewID, isBusy: Bool) -> some View {
        modifier(KeepTaggedWinAlert(crewID: crewID, isBusy: isBusy))
    }
}
