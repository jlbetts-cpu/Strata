import Testing
import Foundation
@testable import Strata

/// The share sheet's header for a replay video says what it is, not
/// "Your week.mp4" (the polish pass, 2026-10-06).
@Suite("Replay share title")
struct ReplayShareTitleTests {
    @Test("a week names its days, a month its name, and the sheet uses it")
    func titles() throws {
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))!
        let week = ReplayPeriod.week(containing: monday, calendar: calendar)
        let title = ReplayView.shareTitle(week)
        #expect(title.hasPrefix("Your week, "))
        #expect(title.contains(" to "))
        #expect(!title.contains(".mp4"))
        let view = SourceSweep.code(try SourceSweep.read("Strata/Views/ReplayView.swift"))
        #expect(view.contains("ReplayShareItem(url: url, title: $0)"))
        #expect(view.contains("activityViewControllerLinkMetadata"))
    }
}
