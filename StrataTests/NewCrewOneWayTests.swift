import Foundation
import Testing
@testable import Strata

/// **One way to a new crew, named one way** (the owner, 2026-10-14, his
/// pick "Merge into one"). Invite a Friend in the Crews list's left corner
/// and Start a Crew in its right were two buttons for one thing, and the app
/// named making a crew two ways. Now the compose glyph, top right, opens the
/// one New Crew sheet; the empty page's button opens the same sheet.
@MainActor
struct NewCrewOneWayTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    @Test("the list has one button to a new crew, top right, and the empty page opens the same sheet")
    func oneButton() throws {
        let list = try code("Strata/Views/Crews/CrewsListView.swift")
        #expect(!list.contains("inviteAFriend"), "the one-press crew of you is back")
        // The corners are the round glass of every tab since 2026-10-14 (the
        // owner: "why are they so much bigger than the buttons on the other
        // pages"), so their names ride on `GlassIconButton`.
        #expect(list.contains("accessibilityLabel: CrewLine.newCrew"))
        #expect(list.contains("PrimaryCapsule(title: CrewLine.newCrew, action: newCrew)"))
        #expect(list.contains(".navigationTitle(CrewLine.newCrew)"))
        // One leading toolbar item: the sheet's own Cancel. Plan stands in
        // the list's own header since 2026-10-15 (`listHeader`, the corners
        // where Wins and Memories stand theirs), and is not a second way to
        // a new crew. Invite a Friend must not come back there.
        #expect(list.components(separatedBy: ".topBarLeading").count - 1 == 1, "a second corner button is here")
        #expect(list.contains(".pinnedBar { listHeader }"))
        #expect(list.contains("accessibilityLabel: \"Plan\""))
        #expect(!list.contains("person.badge.plus"), "a second way to a new crew is back in the corner")
        // Kept on the empty page (the owner's ask).
        #expect(list.contains("Text(CrewLine.linkAgain)"))
        #expect(CrewLine.linkAgain == "Got a link from a friend? Open it again to join.")
    }

    @Test("making a crew is called New Crew everywhere a person reads it")
    func oneName() throws {
        #expect(CrewLine.newCrew == "New Crew")
        #expect(HouseCard.crew.action == CrewLine.newCrew)
        #expect(try code("Strata/Views/Crews/FirstWinInviteCard.swift").contains("hasCrew ? \"Invite\" : CrewLine.newCrew"))
        for (path, text) in try SourceSweep.sources() where path.hasPrefix("Strata/") {
            let code = SourceSweep.code(text)
            #expect(!code.contains("\"Start a Crew\"") && !code.contains("\"Invite a Friend\""), "\(path)")
        }
    }
}
