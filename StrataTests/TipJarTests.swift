import Testing
import Foundation
@testable import Strata

/// The tip jar's rules, without StoreKit.
///
/// Self-test, each of which re-injects a real bug:
/// - Drop `!asked` from `TipJar.shouldAsk` and `askedOnceEver` fails: the ask
///   would come back after every strip.
/// - Drop the `inviteDay` check and `neverOnAnInviteDay` fails with two asks on
///   one moment.
@Suite("TipJar")
@MainActor
struct TipJarTests {
    private func defaults() -> UserDefaults {
        let name = "tipjar-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test("not before the third developed strip")
    func waitsForTheThirdStrip() {
        #expect(!TipJar.shouldAsk(strips: 2, asked: false, tipped: false, inviteDay: nil, today: "2026-10-08"))
        #expect(TipJar.shouldAsk(strips: 3, asked: false, tipped: false, inviteDay: nil, today: "2026-10-08"))
    }

    @Test("asked once, ever, and never after a tip")
    func askedOnceEver() {
        #expect(!TipJar.shouldAsk(strips: 9, asked: true, tipped: false, inviteDay: nil, today: "2026-10-08"))
        #expect(!TipJar.shouldAsk(strips: 9, asked: false, tipped: true, inviteDay: nil, today: "2026-10-08"))
    }

    @Test("never on a day a crew invite was asked for")
    func neverOnAnInviteDay() {
        #expect(!TipJar.shouldAsk(strips: 5, asked: false, tipped: false, inviteDay: "2026-10-08", today: "2026-10-08"))
        #expect(TipJar.shouldAsk(strips: 5, asked: false, tipped: false, inviteDay: "2026-10-07", today: "2026-10-08"))
    }

    @Test("the ask follows only a strip just developed, and only once")
    func followsAStripJustDeveloped() {
        let jar = TipJar(defaults: defaults())
        let today = "2026-10-08"
        jar.noteStripDeveloped(); jar.noteStripDeveloped()
        #expect(!jar.takeAsk(today: today), "two strips is too soon")
        #expect(!jar.takeAsk(today: today), "closing the booth again without a new strip asks nothing")
        jar.noteStripDeveloped()
        #expect(jar.takeAsk(today: today))
        jar.markAsked()
        jar.noteStripDeveloped()
        #expect(!jar.takeAsk(today: today), "asked once, never again")
    }

    @Test("the words: no long dash, never a donation")
    func theWords() {
        let all = [TipJar.Copy.section, TipJar.Copy.line, TipJar.Copy.thanks, TipJar.Copy.askTitle,
                   TipJar.Copy.askLine, TipJar.Copy.notNow] + TipJar.ProductID.all.map(TipJar.name(of:))
        for line in all {
            #expect(!line.contains("\u{2014}") && !line.contains("\u{2013}"), "\(line)")
            #expect(!line.lowercased().contains("donat"), "\(line)")
        }
    }

    @Test("tiers name the three products")
    func tiers() {
        #expect(TipJar.tier(of: TipJar.ProductID.small) == .small)
        #expect(TipJar.tier(of: TipJar.ProductID.medium) == .medium)
        #expect(TipJar.tier(of: TipJar.ProductID.large) == .large)
    }
}
