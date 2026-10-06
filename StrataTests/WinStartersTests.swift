import Testing
import Foundation
@testable import Strata

/// The add sheet's starter words (`WinStarters`) and today's photo row
/// (the owner, 2026-10-05: "a lot of days I dont have a lot of wins to post").
@Suite("Finding the win")
struct WinStartersTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 19))!

    private func win(_ title: String, daysAgo: Int, _ category: HabitCategory = .health,
                     _ size: BlockSize = .small) -> WinStarters.Past {
        WinStarters.Past(title: title, category: category, size: size,
                         at: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
    }

    @Test("your most repeated wins, most repeated first, three at most")
    func mostRepeatedFirst() {
        let past = [win("Walk", daysAgo: 1), win("Walk", daysAgo: 2), win("Walk", daysAgo: 3),
                    win("Read", daysAgo: 1), win("Read", daysAgo: 4),
                    win("Cook", daysAgo: 2), win("Cook", daysAgo: 5),
                    win("Stretch", daysAgo: 6), win("Stretch", daysAgo: 8)]
        let picked = WinStarters.pick(from: past, now: now, calendar: calendar)
        #expect(picked.count == 3)
        #expect(picked.first?.title == "Walk")
        // Ties go to the most recent: Read (yesterday) before Cook (2 days).
        #expect(picked.map(\.title) == ["Walk", "Read", "Cook"])
    }

    @Test("a one-off is not a habit, and an empty history has no row")
    func needsRepeats() {
        #expect(WinStarters.pick(from: [], now: now, calendar: calendar).isEmpty)
        #expect(WinStarters.pick(from: [win("Dentist", daysAgo: 2)], now: now, calendar: calendar).isEmpty)
    }

    @Test("something already done today is left out")
    func notWhatYouDidToday() {
        let past = [win("Walk", daysAgo: 0), win("Walk", daysAgo: 1), win("Walk", daysAgo: 2),
                    win("Read", daysAgo: 1), win("Read", daysAgo: 2)]
        #expect(WinStarters.pick(from: past, now: now, calendar: calendar).map(\.title) == ["Read"])
    }

    @Test("spellings fold together, the newest spelling and colour and size are worn")
    func spellingsFold() {
        let past = [win("gym", daysAgo: 3, .health, .small),
                    win("Gym ", daysAgo: 1, .work, .medium)]
        let picked = WinStarters.pick(from: past, now: now, calendar: calendar)
        #expect(picked == [WinStarters.Starter(title: "Gym", category: .work, size: .medium)])
    }

    @Test("an unnamed block and anything past the window never become words")
    func unnamedAndOldAreOut() {
        let past = [win(QuickWinService.untitled, daysAgo: 1), win(QuickWinService.untitled, daysAgo: 2),
                    win("Swim", daysAgo: WinStarters.windowDays + 2),
                    win("Swim", daysAgo: WinStarters.windowDays + 3)]
        #expect(WinStarters.pick(from: past, now: now, calendar: calendar).isEmpty)
    }

    @Test("today's photos are an evening thing: 5pm until 4am")
    func eveningWindow() {
        func at(_ hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)!
        }
        #expect(!AddWinSheet.isEvening(at(9), calendar: calendar))
        #expect(!AddWinSheet.isEvening(at(16), calendar: calendar))
        #expect(AddWinSheet.isEvening(at(17), calendar: calendar))
        #expect(AddWinSheet.isEvening(at(23), calendar: calendar))
        #expect(AddWinSheet.isEvening(at(2), calendar: calendar))
        #expect(!AddWinSheet.isEvening(at(4), calendar: calendar))
    }

    @Test("the photo row asks for no library permission")
    func noLibraryPermission() throws {
        // The embedded picker shows the library without access; reading it
        // ourselves would need NSPhotoLibraryUsageDescription, and a prompt
        // that reads as the app looking through your photos.
        let project = try String(contentsOfFile: #filePath
            .replacingOccurrences(of: "StrataTests/WinStartersTests.swift",
                                  with: "Strata.xcodeproj/project.pbxproj"), encoding: .utf8)
        #expect(!project.contains("INFOPLIST_KEY_NSPhotoLibraryUsageDescription"))
        let sheet = SourceSweep.code(try MorningSource.read("Views/AddWinSheet.swift"))
        #expect(sheet.contains(".photosPickerStyle(.compact)"))
        #expect(!sheet.contains("PHPhotoLibrary.requestAuthorization"))
    }
}
