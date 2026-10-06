import Testing
import Foundation
@testable import Strata

/// The strip of today's photographs beside the add sheet's block (the owner,
/// 2026-10-05: "the images should just be sleekly next to the block and also
/// change depending on the size and you can easily just scroll through
/// horizontally").
@Suite("Today's photos beside the block")
struct TodaysPhotosTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func at(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test("today starts at midnight, and before 4am it is still yesterday")
    func dayStart() {
        #expect(TodaysPhotos.dayStart(for: at(5, 19), calendar: calendar) == at(5, 0))
        #expect(TodaysPhotos.dayStart(for: at(5, 4), calendar: calendar) == at(5, 0))
        #expect(TodaysPhotos.dayStart(for: at(6, 1), calendar: calendar) == at(5, 0))
    }

    @Test("every photograph is the block's exact size and corner")
    func tilesAreTheBlocksShape() throws {
        let sheet = SourceSweep.code(try MorningSource.read("Views/AddWinSheet.swift"))
        let strip = try #require(sheet.components(separatedBy: "private func photoStrip(").dropFirst().first)
        let body = strip.components(separatedBy: "private func askTile(").first ?? ""
        #expect(body.contains("let well = wellGeometry(pageWidth: pageWidth, visibleHeight: visibleHeight)"))
        #expect(body.contains("size: well.size, radius: well.radius"),
                "a photograph beside the block is not the block's shape")
        // The well and the strip share one arithmetic, so they cannot drift.
        let well = try #require(sheet.components(separatedBy: "private func photoWell(").dropFirst().first)
        #expect(well.contains("let well = wellGeometry(pageWidth: pageWidth, visibleHeight: visibleHeight)"))
        #expect(body.contains(".scrollTargetBehavior(.viewAligned)"), "the strip no longer snaps a photo at a time")
    }

    @Test("the library is asked only after a press, and the reason is plain")
    func askedOnPress() throws {
        let sheet = SourceSweep.code(try MorningSource.read("Views/AddWinSheet.swift"))
        #expect(sheet.components(separatedBy: "TodaysPhotos.requestAccess()").count - 1 == 1)
        let ask = try #require(sheet.components(separatedBy: "private func askTile(").dropFirst().first)
        #expect(ask.prefix(400).contains("Task { photoAccess = await TodaysPhotos.requestAccess() }"),
                "the photo prompt is raised somewhere other than the tile that asks for it")
        let project = try String(contentsOfFile: #filePath
            .replacingOccurrences(of: "StrataTests/TodaysPhotosTests.swift",
                                  with: "Strata.xcodeproj/project.pbxproj"), encoding: .utf8)
        let reason = "INFOPLIST_KEY_NSPhotoLibraryUsageDescription = \"So a photo you took today can go on a win.\";"
        #expect(project.components(separatedBy: reason).count - 1 == 2,
                "the reason is missing from Debug or Release, and the prompt would crash the app")
    }

    @Test("the starter words are gone: the owner called them clutter")
    func noStarters() throws {
        let sheet = SourceSweep.code(try MorningSource.read("Views/AddWinSheet.swift"))
        #expect(!sheet.contains("WinStarters"))
        #expect(!sheet.contains("startersRow"))
    }
}
