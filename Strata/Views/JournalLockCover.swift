import SwiftUI

/// **The app-switcher snapshot, covered while Lock Journal is on** (the
/// cohesion pass, 2026-10-05).
///
/// iOS photographs the app as it leaves the screen and shows that picture in
/// the app switcher, to anyone holding the phone, without asking anybody's
/// face. With the journal open, that picture was the note. So with the
/// switch on, the moment the app stops being active the whole window goes
/// under the system's own blur, and it lifts the moment the app is back.
///
/// Inactive rather than background, because the switcher's live card is
/// taken while the app is still inactive; by the time it is backgrounded the
/// card already shows whatever was there. Not while Face ID itself is
/// asking (`JournalLock.isAsking`): that makes the app inactive too, and
/// covering the page behind the prompt would read as the app breaking.
///
/// No animation in either direction: a cover that fades in can be
/// photographed half way.
struct JournalLockCover: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(JournalLock.defaultsKey) private var lockOn = false

    var body: some View {
        if lockOn, scenePhase != .active, !JournalLock.shared.isAsking {
            Rectangle()
                .fill(.ultraThickMaterial)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .transaction { $0.animation = nil }
        }
    }
}
