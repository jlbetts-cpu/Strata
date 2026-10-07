import Testing
import Foundation
@testable import Strata

/// **The cue in the chat's dark bubble** (2026-10-06): one a day, a question,
/// never about what is missing.
@Suite("Win cue")
struct WinCueTests {
    var calendar: Calendar { Calendar.current }
    func at(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }

    @Test("an empty day is asked from the morning; one or two wins are asked in the afternoon")
    func lines() {
        #expect(WinCue.line(winsToday: 0, now: at(8), shownOn: nil) == nil)
        #expect(WinCue.line(winsToday: 0, now: at(10), shownOn: nil) == WinCue.emptyDay)
        #expect(WinCue.line(winsToday: 2, now: at(12), shownOn: nil) == nil)
        #expect(WinCue.line(winsToday: 1, now: at(16), shownOn: nil) == WinCue.anythingElse)
        #expect(WinCue.line(winsToday: 3, now: at(16), shownOn: nil) == nil, "a good day is left alone")
        #expect(WinCue.line(winsToday: 0, now: at(23), shownOn: nil) == nil)
    }

    @Test("once a day")
    func once() {
        let today = DateUtils.dateString(from: at(16))
        #expect(WinCue.line(winsToday: 1, now: at(16), shownOn: today) == nil)
        #expect(WinCue.line(winsToday: 1, now: at(16), shownOn: "2000-01-01") == WinCue.anythingElse)
    }

    @Test("the words ask; they never count or say what was missed")
    func words() {
        for line in [WinCue.emptyDay, WinCue.anythingElse] {
            for banned in ["forgot", "missed", "haven't", "only", "streak", "\u{2014}"] {
                #expect(!line.lowercased().contains(banned), "\(line)")
            }
            #expect(line.rangeOfCharacter(from: .decimalDigits) == nil)
        }
    }

    @Test("the bubble is the chat's own: ink, with the page's colour as its type")
    func looksLikeChat() throws {
        let cue = SourceSweep.code(try SourceSweep.read("Strata/Views/WinCue.swift"))
        #expect(cue.contains(".fill(AppColors.inkPrimary)"))
        #expect(cue.contains(".foregroundStyle(WarmBackground.top)"))
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains(".overlay { winCueLayer }"))
        #expect(main.contains("!logs.isEmpty"))
    }
}
