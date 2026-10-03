import Testing
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import UIKit
@testable import Strata

/// **What crosses to a friend, exactly.** The record keys are the contract
/// with every other phone, so these fail the day a field is added "just for
/// the tooltip".
@Suite("Crew records")
struct CrewRecordTests {
    static let crew = CrewID(rawValue: "crew-test")

    static func win(photo: URL? = URL(fileURLWithPath: "/tmp/p.jpg")) -> SharedWin {
        SharedWin(winID: UUID(), crewID: crew, senderProfileID: UUID(), crewDay: "2026-10-02",
                  title: "Gym", colour: .health, icon: .health, blockSize: .medium,
                  photo: photo, cropX: 0.1, cropY: -0.2,
                  createdAt: Date(timeIntervalSince1970: 1_790_000_000),
                  updatedAt: Date(timeIntervalSince1970: 1_790_000_100))
    }

    @Test func theSharedWinKeysAreExactlyTheTable() {
        #expect(CrewRecords.sharedWinKeys == [
            "winID", "senderProfileID", "crewDay", "title", "colour", "icon",
            "blockSize", "photo", "cropX", "cropY", "createdAt", "updatedAt",
        ])
        #expect(Set(CrewRecords.fields(Self.win()).keys) == CrewRecords.sharedWinKeys)
    }

    @Test func nothingPrivateCanReachARecord() {
        let forbidden = ["note", "caption", "latitude", "longitude", "locationAccuracy", "place",
                         "habit", "habitID", "planItem", "mood", "dateString", "subtasks"]
        for type in CrewRecordType.allCases {
            for key in forbidden { #expect(!CrewRecords.keys(of: type).contains(key), "\(type) has \(key)") }
        }
        // `photo` since 2026-10-02: a profile photo, for someone with no head.
        #expect(CrewRecords.memberKeys == ["profileID", "firstName", "head", "photo", "joinedAt"])
        #expect(CrewRecords.crewKeys == ["name", "ownerProfileID", "timeZoneIdentifier", "createdAt", "photo"])
    }

    @Test func aWinRoundTrips() {
        let win = Self.win()
        #expect(CrewRecords.sharedWin(CrewRecords.fields(win), crew: Self.crew) == win)
        let bare = Self.win(photo: nil)
        #expect(CrewRecords.fields(bare)["photo"] == nil)
        #expect(CrewRecords.sharedWin(CrewRecords.fields(bare), crew: Self.crew) == bare)
    }

    @Test func theCrewDayIsTheCrewsZone() throws {
        let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let ny = try #require(TimeZone(identifier: "America/New_York"))
        // 2026-10-02 23:30 in Los Angeles is 2026-10-03 02:30 in New York.
        let late = try #require(ISO8601DateFormatter().date(from: "2026-10-03T06:30:00Z"))
        #expect(CrewDay.string(for: late, in: la) == "2026-10-02")
        #expect(CrewDay.string(for: late, in: ny) == "2026-10-03")
        let afterMidnight = late.addingTimeInterval(3600)
        #expect(CrewDay.string(for: afterMidnight, in: la) == "2026-10-03")
    }

    @Test func theCrewDaySurvivesTheClocksGoingBack() throws {
        let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
        // 2026-11-01 01:30 happens twice in Los Angeles: PDT, then PST.
        let first = try #require(ISO8601DateFormatter().date(from: "2026-11-01T08:30:00Z"))
        let second = try #require(ISO8601DateFormatter().date(from: "2026-11-01T09:30:00Z"))
        #expect(CrewDay.string(for: first, in: la) == "2026-11-01")
        #expect(CrewDay.string(for: second, in: la) == "2026-11-01")
        #expect(CrewDay.day("2026-11-01", offsetBy: -1, in: la) == "2026-10-31")
        #expect(CrewDay.day("2026-03-08", offsetBy: 1, in: la) == "2026-03-09")
    }

    @Test func anUnnamedCrewIsCalledByItsPeople() {
        let me = UUID()
        func person(_ name: String, _ t: Double) -> CrewMember {
            CrewMember(profileID: UUID(), firstName: name, head: nil, joinedAt: Date(timeIntervalSince1970: t))
        }
        var crew = Crew(id: Self.crew, name: "", ownerProfileID: me, timeZoneIdentifier: "UTC", createdAt: .now,
                        photo: nil, members: [CrewMember(profileID: me, firstName: "Jayden", head: nil, joinedAt: .distantPast)])
        #expect(crew.displayName(excluding: me) == "New Crew")
        crew.members.append(person("Sam Lee", 1))
        #expect(crew.displayName(excluding: me) == "Sam")
        crew.members.append(person("Ana", 2))
        #expect(crew.displayName(excluding: me) == "Sam & Ana")
        crew.members.append(person("Leo", 3))
        #expect(crew.displayName(excluding: me) == "Sam, Ana & Leo")
        crew.members.append(person("Kai", 4))
        #expect(crew.displayName(excluding: me) == "Sam, Ana & 2 more")
        crew.name = " Roommates "
        #expect(crew.displayName(excluding: me) == "Roommates")
    }
}

/// **What leaves the phone with a photograph.**
@Suite("Crew payloads")
struct CrewPayloadTests {
    /// A 3000 x 2000 JPEG carrying a camera's EXIF and a GPS fix.
    static func taggedJPEG(width: Int = 3000, height: Int = 2000) throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: space,
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let out = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 38.54, kCGImagePropertyGPSLongitude: 121.74,
                                            kCGImagePropertyGPSLatitudeRef: "N", kCGImagePropertyGPSLongitudeRef: "W"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "iPhone back camera",
                                             kCGImagePropertyExifDateTimeOriginal: "2026:10:02 16:20:00"],
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return out as Data
    }

    static func properties(_ data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    @Test func theFixtureReallyCarriesAPlace() throws {
        let props = try Self.properties(try Self.taggedJPEG())
        #expect(props[kCGImagePropertyGPSDictionary] != nil)
    }

    @Test func aSharedPhotoCarriesNoPlaceAndNoCamera() throws {
        let shared = try #require(ShareDerivative.jpeg(from: try Self.taggedJPEG()))
        let props = try Self.properties(shared)
        #expect(props[kCGImagePropertyGPSDictionary] == nil)
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifLensModel] == nil)
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect(props[kCGImagePropertyPixelWidth] as? Int == 1080)
        #expect(props[kCGImagePropertyPixelHeight] as? Int == 720)
    }

    @Test func aSmallPhotoIsNeverBlownUp() throws {
        let shared = try #require(ShareDerivative.jpeg(from: try Self.taggedJPEG(width: 600, height: 400)))
        #expect(try Self.properties(shared)[kCGImagePropertyPixelWidth] as? Int == 600)
    }
}

/// **A head, small enough to send.**
@MainActor
@Suite("Crew head pack")
struct CrewHeadPackTests {
    @Test func aHeadPacksSmallAndUnpacksWhole() throws {
        let made = FileManager.default.temporaryDirectory.appending(path: "head-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        HeadStore.writeVersion2Fixture(to: made)
        let original = try #require(HeadStore.load(at: made)?.rig)
        let pack = try #require(CrewHeadPack.make(from: made))
        #expect(pack.count < 250_000, "a head travels in under 250 KB, was \(pack.count)")
        let received = made.deletingLastPathComponent().appending(path: "got-\(UUID().uuidString)", directoryHint: .isDirectory)
        let rig = try #require(try CrewHeadPack.unpack(pack, into: received))
        #expect(Set(rig.expressions) == Set(original.expressions))
        let face = try #require(rig.faces[.neutral]?.image)
        #expect(max(face.size.width * face.scale, face.size.height * face.scale) <= CrewHeadPack.side)
    }

    @Test func aPackCannotNameAPath() {
        #expect(CrewHeadPack.isSafe("neutral.png"))
        #expect(CrewHeadPack.isSafe("head.json"))
        #expect(!CrewHeadPack.isSafe("../photo.jpg"))
        #expect(!CrewHeadPack.isSafe("a/neutral.png"))
        #expect(!CrewHeadPack.isSafe("notes.txt"))
    }
}
