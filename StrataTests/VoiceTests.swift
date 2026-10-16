import Foundation
import Testing
@testable import Strata

/// The owner's voice contract (`docs/voice.md`, from his Launch Pack of
/// 2026-10-12), where a test can hold it. The judgement, whether a line
/// sounds like a friend who gets it, is not something a test can make.
@Suite("The voice")
struct VoiceTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    @Test("nothing asks a question or raises its voice from the lock screen")
    func notifications() throws {
        let lines = [EveningCheckIn.title, WinCue.oneMore, WinCue.roomLeft, CrewEvening.line,
                     Flashback.oneMonth, Flashback.sixMonths, Flashback.title(years: 1), Flashback.title(years: 3)]
        for line in lines {
            #expect(!line.contains("?") && !line.contains("!"), "\(line)")
            #expect(!line.contains("\u{2014}") && !line.contains("\u{2013}"), "\(line)")
        }
        // The in-app cue may ask; the notification is a different line.
        #expect(WinCue.anythingElse.hasSuffix("?"))
        #expect(EveningCheckIn.title != WinCue.anythingElse)
        // A recap, in his words.
        let replay = try code("Strata/Services/ReplayReminder.swift")
        #expect(replay.contains("\"Your week, put together.\""))
        #expect(!replay.contains("is ready\""))
        // A past win invites; its name waits inside.
        let past = try code("Strata/Services/PastWin.swift")
        #expect(past.contains("content.title = pick.when + \".\""))
        #expect(!past.contains("content.body = pick.title"))
    }

    @Test("the evening's crew line is true whoever posts, and names no one")
    func crewEvening() throws {
        #expect(CrewEvening.line == "Your crew's tower is open too.")
        let daily = try code("Strata/Services/DailyReminder.swift")
        #expect(!daily.contains("CrewEvening.line(crewName:"))
    }

    @Test("a crew of two is a crew: nothing advertises eight, and a pair is spoken to as a pair")
    func crewSizes() throws {
        for path in ["Strata/Views/Crews/CrewsListView.swift", "Strata/Views/Crews/CrewInfoSheet.swift",
                     "Strata/Views/WhyItWorksView.swift", "Strata/Views/HouseCard.swift"] {
            let source = try code(path)
            #expect(!source.contains("Up to 8"), "\(path)")
            #expect(!source.contains("up to eight"), "\(path)")
            #expect(!source.contains("\"Invite People\""), "\(path)")
            #expect(!source.contains("Waiting for people"), "\(path)")
        }
        // The limit is still said where it is a refusal.
        #expect(CrewErrorWords.fullCrew.contains("eight"))
        // An unnamed crew's invite does not read "Join Sam" or "Join New Crew".
        let sharing = try code("Strata/Views/Crews/CrewSharing.swift")
        // One `title(for:)` since 2026-10-16, shared by the share sheet and
        // the text to a chosen contact.
        #expect(sharing.contains("return name.isEmpty ? message : \"Join \\(name) on Some Wins\""))
        #expect(CrewStats.streakLine(people: 2, waiting: 0) == "You're both in today.")
        #expect(CrewStats.streakLine(people: 8, waiting: 0) == "Everyone's in today.")
    }

    @Test("one quiet person never ends a crew's run, at any size")
    func quietMember() {
        // Everyone but one posts: the day is kept, from two people to eight.
        for people in 2...8 {
            #expect(people - 1 >= CrewHistory.needed(of: people), "\(people)")
        }
        #expect(CrewHistory.needed(of: 1) == 1)
        #expect(CrewHistory.needed(of: 8) == 4)
    }

    @Test("the shared strip carries the wordmark and the date, and no name")
    func stripFoot() throws {
        let strip = try code("Strata/Views/Strip/StripView.swift")
        #expect(!strip.contains("\\(signature) \\u{00B7}"))
        #expect(strip.contains("Text(signatureLine)"))
    }

    @Test("the invite link's card is the app: its name, the owner's line, the logo")
    func inviteCard() throws {
        let page = try SourceSweep.read("docs/join.html")
        #expect(page.contains("<meta property=\"og:title\" content=\"Some Wins\">"))
        #expect(page.contains("<meta property=\"og:description\" content=\"A quiet place to hold the good things, with a few people you love.\">"))
        #expect(page.contains("invite/logo.png"))
        #expect(!page.contains("A few friends, one tower"))
        // A page for the app alone, for a link that is not an invitation.
        let home = try SourceSweep.read("docs/index.html")
        #expect(home.contains("<title>Some Wins</title>"))
        #expect(!home.contains("somewins://join"))
    }

    @Test("a strip to a friend is the picture, his line and the app's page, never a crew's key")
    func stripToAFriend() throws {
        #expect(StripMessageActivity.line == "Today was a good one. Some of it's in here.")
        // The link is last and alone on its line, where Messages makes a card of it.
        #expect(StripMessageActivity.body.hasSuffix("\n" + StripMessageActivity.page))
        #expect(!StripMessageActivity.page.contains("join"))
        #expect(!StripMessageActivity.page.contains("#"))
        #expect(CrewInviteLink.read(URL(string: StripMessageActivity.page)!) == nil)
        // The sheet's own items are still the picture alone, for a post.
        let story = try code("Strata/Views/Strip/StripStory.swift")
        #expect(story.contains("UIActivityViewController(activityItems: [file], applicationActivities: activities)"))
    }

    @Test("a like on one block does not swallow a like on the next")
    func reactionsArePacedPerThing() {
        var throttle = CrewSendThrottle()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(throttle.verdict(.reaction, crew: "c", day: "2026-10-12", at: now, item: "a") == .allowed)
        throttle.record(.reaction, crew: "c", day: "2026-10-12", at: now, item: "a")
        let soon = now.addingTimeInterval(0.1)
        // The same block again, at once: held. Another block: let through.
        #expect(throttle.verdict(.reaction, crew: "c", day: "2026-10-12", at: soon, item: "a") == .tooFast)
        #expect(throttle.verdict(.reaction, crew: "c", day: "2026-10-12", at: soon, item: "b") == .allowed)
        // Old gaps are not kept.
        throttle.record(.reaction, crew: "c", day: "2026-10-12", at: now.addingTimeInterval(120), item: "b")
        #expect(throttle.last.count == 1)
    }

    @Test("a replay that Photos will not take offers the way to Settings")
    func replaySave() throws {
        let replay = try code("Strata/Views/ReplayView.swift")
        #expect(replay.contains("if !saved { photosRefused += 1 }"))
        #expect(replay.contains(".photoSaveFailed($savingRefused)"))
    }

    @Test("lines that counted against you, or said a thing the app does not do")
    func inApp() throws {
        #expect(GoalHistory(days: Array(repeating: 1, count: 14)).sentence(goal: 2).isEmpty)
        let day = try code("Strata/Views/YourDaySheet.swift")
        #expect(!day.contains("dances and prints the day's strip"))
        #expect(DayOneHint.drawOut.hasPrefix("Pull "))
        let onboarding = try code("Strata/Views/OnboardingView.swift")
        #expect(!onboarding.contains("\"One More Thing\"") || onboarding.components(separatedBy: "\"One More Thing\"").count == 2)
        let backup = try code("Strata/Services/BackupArchive.swift")
        #expect(!backup.contains("wins.json inside it"))
        #expect(!backup.contains("(\\(detail))"))
    }
}
