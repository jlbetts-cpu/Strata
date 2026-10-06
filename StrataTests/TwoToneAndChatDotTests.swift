import Testing
import Foundation
@testable import Strata

/// The owner's 2026-10-06 picks from Luma: "Two-tone headers", and "make sure
/// there is a notification icon also on the chat feature".
@Suite("Two-tone headers and the chat's dot")
struct TwoToneAndChatDotTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    @Test("a day reads as two tones: its name, then the rest")
    func dayTitles() {
        let locale = Locale(identifier: "en_US")
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 12))!
        #expect(DayTitle.twoTone(forKey: "2026-10-06", now: now, calendar: calendar, locale: locale) == "Today / Tuesday")
        #expect(DayTitle.twoTone(forKey: "2026-10-05", now: now, calendar: calendar, locale: locale) == "Yesterday / Monday")
        #expect(DayTitle.twoTone(forKey: "2026-10-04", now: now, calendar: calendar, locale: locale) == "Sunday / 4 October")
        #expect(DayTitle.twoTone(forKey: "2025-10-04", now: now, calendar: calendar, locale: locale) == "Saturday / 4 October 2025")
    }

    @Test("a two-tone title splits on its slash, and a plain one stays one tone")
    func parts() {
        #expect(TwoToneTitle.parts("Roommates / Today") == ("Roommates", "Today"))
        #expect(TwoToneTitle.parts("Settings").rest == nil)
    }

    @Test("the bars that name a day or a chat use two tones")
    func wired() throws {
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(sheet.contains("DayTitle.twoTone(forKey: dateString)"))
        let chat = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewChatSheet.swift"))
        #expect(chat.contains("TwoToneTitle(title:"))
        let crewDay = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewDayView.swift"))
        #expect(crewDay.contains("TwoToneTitle(title: header)"))
    }

    /// The chat's dot was only inside the crew; a message was invisible from
    /// Wins and from the list until that crew happened to be opened.
    @Test("an unread chat line lights the Crews button and the crew's row")
    func chatLightsTheDots() throws {
        let list = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewsListView.swift"))
        #expect(list.contains("let newChat = store.unreadChats.contains(crew.id)"))
        #expect(list.contains("!store.unread.isEmpty || !store.unreadChats.isEmpty"))
    }
}
