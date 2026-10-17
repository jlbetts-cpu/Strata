import SwiftUI

/// **A crew stays live while it is on screen** (moved out of the tower,
/// 2026-10-16, so a message thread to one person keeps up the same way):
/// this crew's changes (`refreshLive`, one small request when nothing
/// moved), since a push is only a nudge to look and may never come.
/// **Paced** (2026-10-08, `CrewLivePace`): every 3 seconds while things
/// move, every 12 once three asks found nothing, and quick again the moment
/// you post, say or react. Waited out in single seconds so a nudge is heard
/// at once, and never by cancelling a request.
struct CrewLiveSync: ViewModifier {
    let crewID: CrewID
    @Environment(\.scenePhase) private var scenePhase
    private var store: SocialStore { SocialStore.shared }

    func body(content: Content) -> some View {
        content
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                var pace = CrewLivePace()
                // **A push reads the crew at once** (2026-10-10): the loop
                // below asked every three seconds whether or not anything had
                // happened. It still asks, as the fallback, but once pushes are
                // seen to arrive it asks far less (`CrewLivePace`).
                store.liveCrew = crewID
                defer { if store.liveCrew == crewID { store.liveCrew = nil } }
                // The pushes already answered: kept across asks, so one that
                // lands while an ask is out is seen at the top of the next wait
                // rather than forgotten.
                var answered = store.livePush
                while !Task.isCancelled {
                    let nudge = store.liveNudge
                    var waited: TimeInterval = 0
                    var byPush = false
                    while waited < pace.interval, !Task.isCancelled {
                        if store.livePush != answered { answered = store.livePush; byPush = true; break }
                        try? await Task.sleep(for: .seconds(1))
                        waited += 1
                        if store.liveNudge != nudge { pace.nudged(); break }
                    }
                    guard !Task.isCancelled else { return }
                    pace.asked(changed: await store.refreshLive(crewID), byPush: byPush)
                }
            }
    }
}
