import Testing
import Foundation
@testable import Strata

/// The bugs the 2026-10-06 quality-of-life review found, each pinned where it
/// lived so it cannot come back quietly.
@Suite("Quality-of-life fixes, 2026-10-06")
struct QoLFixTests {
    private func code(_ path: String) throws -> String {
        SourceSweep.code(try SourceSweep.read(path))
    }

    private func body(of marker: String, until end: String, in source: String) throws -> String {
        let start = try #require(source.components(separatedBy: marker).dropFirst().first, "\(marker) is gone")
        return start.components(separatedBy: end).first ?? start
    }

    @Test("chat and reply alerts are not silenced by pings: the chat sends none")
    func chatAlertsSurvivePings() throws {
        let source = try code("Strata/Social/CrewNotifications.swift")
        let chat = try body(of: "static func announceMessages(", until: "saveChatStates(", in: source)
        #expect(!chat.contains("pingsLive"),
                "the chat's alerts wait on pings again, and the chat leaves no ping")
        let store = try code("Strata/Social/SocialStore.swift")
        #expect(store.contains("case .crew, .member, .message:\n            return"),
                "the chat leaves a ping now; the gate above can be reconsidered")
    }

    @Test("a crew's notification tapped on a cold launch opens on Wins")
    func crewColdLaunch() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        // `wantsWinsTab` (2026-10-08) is `open != nil` OR an invitation
        // waiting on the rules and the age (`CrewGate`): both land on Wins.
        #expect(main.contains(".onAppear { if CrewRouter.shared.wantsWinsTab { selectedTab = .tower } }"))
        let tower = try code("Strata/Views/Crews/CrewTowerView.swift")
        let refresh = try body(of: ".onChange(of: store.today(in: crewID)) {", until: ".onChange(of: crew?.members)", in: tower)
        #expect(refresh.contains("openWinFromNotification()"),
                "the notification's win is only tried before the refresh that brings it")
    }

    @Test("Add waits for a photo from the strip, and so does the return key")
    func addWaitsForThePhoto() throws {
        let sheet = try code("Strata/Views/AddWinSheet.swift")
        #expect(sheet.contains("private var canSave: Bool { !isSaving && photoLoading == nil }"))
        let save = try body(of: "private func save() async {", until: "let typed", in: sheet)
        #expect(save.contains("guard canSave else { return }"))
        let put = try body(of: "private func put(_ asset: PHAsset) {", until: "private var decisions", in: sheet)
        #expect(put.contains("photoAssetID = nil"), "a photo that never arrived still looks used")
    }

    @Test("ticking a line again does not log its win twice")
    func retickFindsTheWin() throws {
        let lines = try code("Strata/Views/PlanLines.swift")
        let complete = try body(of: "private func complete(_ item: PlanItem) {", until: "onComplete(item)", in: lines)
        #expect(complete.contains("$0.planItemID == item.id"))
    }

    @Test("a failed delete says so, and its confirm word does not promise another")
    func failedDelete() throws {
        #expect(AddWinFailure.deletion.message == "Couldn't delete this win. Nothing changed.")
        #expect(AddWinFailure.deletion.retry == "Save")
        #expect(AddWinFailure.deletion.winIsSaved)
        let sheet = try code("Strata/Views/AddWinSheet.swift")
        let delete = try body(of: "private func deleteIt() {", until: "for name in names", in: sheet)
        #expect(delete.contains("fail(.deletion)"))
    }

    @Test("notifications refused: the way to iOS Settings can show, and every switch asks")
    func notificationDeadEnds() throws {
        let settings = try code("Strata/Views/SettingsView.swift")
        #expect(settings.contains("if systemNotificationsDenied {"))
        #expect(!settings.contains("systemNotificationsDenied && notificationsEnabled"))
        #expect(settings.components(separatedBy: "guard await notificationsAllowed() else").count - 1 == 2,
                "Replays or Past Wins switches on without asking for notifications")
        let time = try body(of: ".onChange(of: reminderTime) {", until: "HapticsEngine.tick()", in: settings)
        #expect(time.contains("guard hour != reminderHour || minute != reminderMinute"),
                "opening Settings ticks and reschedules again")
    }

    @Test("an edit from the photo viewer reloads the page under it")
    func viewerEditsReload() throws {
        let viewer = try code("Strata/Views/PhotoViewer.swift")
        #expect(viewer.contains("onSaved: { _ in onWinChanged() }"))
        #expect(viewer.contains("onDeleted: { onWinChanged(); onClose() }"))
        for path in ["Strata/Views/MemoriesView.swift", "Strata/Views/DayAlbumDetailView.swift",
                     "Strata/Views/PhotoCollectionView.swift"] {
            #expect(try code(path).contains("onWinChanged:"), "\(path) never hears about an edit")
        }
    }

    @Test("a restore cannot be swiped away while it writes")
    func restoreHolds() throws {
        #expect(try code("Strata/Views/RestoreBackupView.swift").contains(".interactiveDismissDisabled(isRestoring)"))
    }

    @Test("glass that holds buttons is still on the page too, and glass buttons press plainly")
    func glassTakesNoTaps() throws {
        let glass = try code("Strata/Views/GlassIconButton.swift")
        #expect(glass.contains("onPage ? (interactive ? GlassRecipe.onPage : GlassRecipe.onPageStill)"),
                "`interactive: false` is ignored on the page again")
        for path in ["Strata/Views/Crews/CrewPicker.swift", "Strata/Views/Crews/CrewWithRow.swift"] {
            let source = try code(path)
            #expect(!source.contains(".buttonStyle(.pressSurface)"),
                    "\(path) puts a scaling press on interactive glass, which cancels taps on a phone")
            // Ink since the owner thinned the glass (2026-10-06).
            #expect(!source.contains(".glassCapsule("), "\(path) is a glass chip again")
        }
        let day = try code("Strata/Views/DaySheet.swift")
        let emoji = try body(of: "private var emojiButton: some View {", until: "EmojiField(", in: day)
        #expect(emoji.contains(".buttonStyle(.plain)"))
    }

    @Test("Lock Journal comes off only for whoever can open it")
    func lockNeedsUnlockToTurnOff() throws {
        let settings = try code("Strata/Views/SettingsView.swift")
        #expect(settings.contains("if !(await JournalLock.shared.mayTurnOff()) { locksJournal = true }"))
    }

    @MainActor
    @Test("turning the lock off asks, and a refusal keeps it")
    func mayTurnOffAsks() async {
        let defaults = UserDefaults(suiteName: "qol.lock.\(UUID())")!
        var asked = 0
        let refusing = JournalLock(defaults: defaults) { asked += 1; return false }
        #expect(await refusing.mayTurnOff() == false)
        #expect(asked == 1)
        let passing = JournalLock(defaults: defaults) { true }
        #expect(await passing.mayTurnOff())
        // Already open this session: no second prompt.
        #expect(await passing.mayTurnOff())
    }
}
