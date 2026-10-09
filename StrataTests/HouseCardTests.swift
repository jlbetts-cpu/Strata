import Foundation
import Testing
@testable import Strata

/// The Memories slot's own card (2026-10-08, the owner's "House card now"):
/// rare by rule, and only with something true to offer.
@Suite("House card")
struct HouseCardTests {
    let calendar = Calendar(identifier: .gregorian)
    func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_790_000_000 + Double(n) * 86_400) }

    @Test("never in the first three days")
    func quietStart() {
        for used in 0..<HouseCard.quietDays {
            #expect(HouseCard.next(today: day(used), firstSeen: day(0), lastShown: nil, hasCrew: false,
                                   crewsUsable: true, tipsReady: true, calendar: calendar) == nil)
        }
        #expect(HouseCard.next(today: day(3), firstSeen: day(0), lastShown: nil, hasCrew: false,
                               crewsUsable: true, tipsReady: true, calendar: calendar) == .crew)
    }

    @Test("at most once a week")
    func weekly() {
        #expect(HouseCard.next(today: day(10), firstSeen: day(0), lastShown: day(5), hasCrew: false,
                               crewsUsable: true, tipsReady: true, calendar: calendar) == nil)
        #expect(HouseCard.next(today: day(12), firstSeen: day(0), lastShown: day(5), hasCrew: false,
                               crewsUsable: true, tipsReady: true, calendar: calendar) == .crew)
    }

    @Test("a crew while you have none, then a tip, then nothing")
    func whatItOffers() {
        #expect(HouseCard.next(today: day(9), firstSeen: day(0), lastShown: nil, hasCrew: true,
                               crewsUsable: true, tipsReady: true, calendar: calendar) == .tip)
        #expect(HouseCard.next(today: day(9), firstSeen: day(0), lastShown: nil, hasCrew: false,
                               crewsUsable: false, tipsReady: true, calendar: calendar) == .tip)
        #expect(HouseCard.next(today: day(9), firstSeen: day(0), lastShown: nil, hasCrew: true,
                               crewsUsable: true, tipsReady: false, calendar: calendar) == nil)
        #expect(HouseCard.next(today: day(9), firstSeen: nil, lastShown: nil, hasCrew: false,
                               crewsUsable: true, tipsReady: true, calendar: calendar) == nil)
    }

    @Test("its words say what and why, with no long dash")
    func words() {
        for card in [HouseCard.crew, .tip] {
            for line in [card.title, card.line, card.action] { #expect(!line.contains("\u{2014}")) }
        }
    }
}
