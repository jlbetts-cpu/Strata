import Foundation
import Testing
@testable import Strata

/// **Earlier heads, the screens** (the owner, 2026-10-14: "I took a head
/// already but I deleted it to try the new feature I feel like the app
/// should save your previous three heads to go off of"). The roster's rules
/// are in `HeadRosterTests`; these hold what the screens do with them.
@MainActor
struct EarlierHeadsTests {
    private func entry(_ name: String, created: Date = Date()) -> HeadStore.Entry {
        let id = UUID()
        return HeadStore.Entry(id: id, name: name, created: created, folder: "Heads/\(id.uuidString)")
    }

    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    @Test("Undo after bringing a head back puts the one in use back, and loses no head")
    func undoPutsBackWhatWas() {
        var roster = HeadStore.Roster()
        let old = entry("Old"), now = entry("Now")
        roster.add(old)
        roster.replaceWith(now)
        // Brought back: Old in use, Now waiting.
        let before = roster.activeID
        roster.bringBack(old.id)
        #expect(roster.activeID == old.id && roster.earlier.map(\.id) == [now.id])
        // Undo, as `EarlierHeads.bringBack` does it.
        if let before { roster.bringBack(before) }
        #expect(roster.activeID == now.id && roster.earlier.map(\.id) == [old.id])
    }

    @Test("Undo with no head before leaves you with none again, and the head still waiting")
    func undoToNoHead() {
        var roster = HeadStore.Roster()
        let gone = entry("Gone")
        roster.add(gone)
        roster.retire(gone.id)
        roster.bringBack(gone.id)
        #expect(roster.activeID == gone.id && roster.earlier.isEmpty)
        // `store.delete(id)` retires it.
        roster.retire(gone.id)
        #expect(roster.activeID == nil && roster.earlier.map(\.id) == [gone.id])
    }

    @Test("with three waiting, bringing one back and undoing it keeps all four heads")
    func fullListLosesNothing() {
        var roster = HeadStore.Roster()
        let heads = (0..<4).map { entry("Head \($0)") }
        for head in heads { roster.replaceWith(head) }
        #expect(roster.earlier.count == 3)
        let before = roster.activeID
        #expect(roster.bringBack(heads[0].id).isEmpty, "a head's files went")
        #expect(roster.bringBack(before!).isEmpty, "a head's files went on Undo")
        #expect(Set(roster.earlier.map(\.id) + roster.heads.map(\.id)) == Set(heads.map(\.id)))
    }

    @Test("a head is named for VoiceOver by a name somebody chose, or by when it was made")
    func spokenName() {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 12))!
        #expect(EarlierHeadsRow.name(of: entry("Sam", created: day), person: "Jayden") == "Sam")
        let generated = EarlierHeadsRow.name(of: entry("Head 2", created: day), person: "Jayden")
        #expect(generated.hasPrefix("Head from ") && generated != "Head 2")
        #expect(EarlierHeadsRow.name(of: entry("Jayden", created: day), person: "Jayden").hasPrefix("Head from "))
    }

    @Test("the words are the app's: no long dash, no exclamation mark, and delete says where it goes")
    func words() throws {
        for line in [EarlierHeads.title, EarlierHeads.broughtBack, EarlierHeads.footer, EarlierHeads.instead] {
            #expect(!SourceSweep.longDash(line) && !line.contains("!"), "\(line)")
        }
        let profile = try code("Strata/Views/ProfileView.swift")
        #expect(profile.contains("moves to Earlier Heads on this phone, kept with your last three"))
        #expect(!profile.contains("A head can't be brought back"), "the delete hint says it is gone for good again")
        #expect(profile.contains("EarlierHeadsRow(entries: heads.earlierEntries) { EarlierHeads.bringBack($0) }"))
        #expect(profile.contains(".undoLine()"), "Head brought back is said under the sheet, out of sight")
        let row = try code("Strata/Views/EarlierHeads.swift")
        #expect(row.contains("Button(\"Delete for Good\", systemImage: \"trash\", role: .destructive) { forgetting = entry }"))
        #expect(row.contains("HeadStore.shared.forget(entry.id)"))
    }

    @Test("the pages that ask for a head offer an earlier one when there is one")
    func offeredWhereAHeadIsAskedFor() throws {
        let ask = try code("Strata/Views/HeadAsk.swift")
        #expect(ask.contains("EarlierHeadsRow(entries: HeadStore.shared.earlierEntries, alignment: .center)"))
        #expect(ask.contains("cover = HeadStore.shared.earlierEntries.isEmpty ? .maker : .catchUp"))
        let onboarding = try code("Strata/Views/OnboardingView.swift")
        #expect(onboarding.contains("if offersHead && !heads.earlierEntries.isEmpty {"))
    }

    @Test("the policy says a deleted head stays on this phone, unsent, until it is deleted for good")
    func policy() {
        let head = PrivacyPolicyText.sections.first { $0.title == "Your head" }?.paragraphs.joined(separator: " ") ?? ""
        #expect(!head.contains("Delete Head removes it."))
        #expect(head.contains("stays on this device with your last three heads, and is never sent"))
        #expect(head.contains("Delete for Good") && head.contains("reset all data"))
    }
}
