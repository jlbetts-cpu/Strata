import Foundation
import Testing
@testable import Strata

/// The crew's evening check-in lands at one moment on every phone
/// (`CrewEvening`, `tasks/unification-log.md` §5a).
@Suite("Crew evening")
struct CrewEveningTests {
    let zone = TimeZone(identifier: "America/Los_Angeles")!

    @Test("the same crew and day give the same minute, inside 7 to 9pm")
    func sameMinute() {
        let a = CrewEvening.minuteOfDay(crew: "crew-1", day: "2026-10-09")
        #expect(a == CrewEvening.minuteOfDay(crew: "crew-1", day: "2026-10-09"))
        for day in 1...28 {
            let m = CrewEvening.minuteOfDay(crew: "crew-1", day: String(format: "2026-10-%02d", day))
            #expect(m >= 19 * 60 && m <= 20 * 60 + 55 && m % 5 == 0)
        }
        let days = Set((1...28).map { CrewEvening.minuteOfDay(crew: "crew-1", day: String(format: "2026-10-%02d", $0)) })
        #expect(days.count > 5, "a different moment most evenings")
    }

    @Test("two phones in different zones get the same instant, or keep their own evening")
    func zones() throws {
        var la = Calendar(identifier: .gregorian); la.timeZone = zone
        var ny = Calendar(identifier: .gregorian); ny.timeZone = TimeZone(identifier: "America/New_York")!
        var tokyo = Calendar(identifier: .gregorian); tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let noon = try #require(la.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12)))
        let here = try #require(CrewEvening.time(crew: "crew-1", zone: zone, now: noon, calendar: la))
        // New York is three hours on: 10pm to midnight there, outside its 5 to 10pm.
        #expect(here > noon)
        #expect(CrewEvening.time(crew: "crew-1", zone: zone, now: noon, calendar: ny) == nil)
        #expect(CrewEvening.time(crew: "crew-1", zone: zone, now: noon, calendar: tokyo) == nil)
        #expect(!CrewEvening.line(crewName: "Roommates").contains("waiting"))
    }
}
