import Testing
import Foundation
import SwiftData
@testable import Strata

/// **What a win you log becomes in a crew, and what a friend's never becomes.**
@MainActor
@Suite("Crew sync", .serialized)
struct CrewSyncTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema,
                                               isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test func aLoggedWinCarriesItsLookAndNothingPrivate() throws {
        let context = try context()
        let win = try QuickWinService.logWin(title: "Gym", category: .health, size: .medium,
                                             context: context, tower: nil)
        let log = try #require((win.habit.logs ?? []).first)
        log.note = "felt awful"
        log.caption = "private caption"
        log.latitude = 38.5
        log.longitude = -121.7
        let own = try #require(CrewSync.ownWin(log))
        #expect(own.title == "Gym")
        #expect(own.colour == .health && own.blockSize == .medium)
        #expect(own.winID == log.id)
        // OwnWin has no field for any of them; the record keys test pins the
        // rest. This proves the mapping cannot have grown one.
        let labels = Mirror(reflecting: own).children.compactMap(\.label)
        for forbidden in ["note", "caption", "latitude", "longitude", "place"] {
            #expect(!labels.contains(forbidden))
        }
    }

    @Test func thePlaceholderNameIsNotAName() throws {
        let context = try context()
        let win = try QuickWinService.logWin(context: context, tower: nil)
        let log = try #require((win.habit.logs ?? []).first)
        #expect(CrewSync.ownWin(log)?.title == "")
    }

    @Test func aFriendsWinNeverBecomesYours() async throws {
        let context = try context()
        let world = FakeCrewWorld()
        let store = SocialStore(cloud: FakeCrewCloud(world: world), defaults: UserDefaults(suiteName: "sync-\(UUID())")!,
                                directory: FileManager.default.temporaryDirectory.appending(path: "sync-\(UUID())"))
        store.isEnabled = { true }
        let (crew, _) = try await store.createCrew(name: "One")
        store.receive(SharedWin(winID: UUID(), crewID: crew.id, senderProfileID: UUID(),
                                crewDay: CrewDay.string(for: .now, in: crew.timeZone), title: "Their run",
                                colour: .health, icon: .health, blockSize: .hard, photo: nil, cropX: nil, cropY: nil,
                                createdAt: .now, updatedAt: .now))
        #expect(store.today(in: crew.id).count == 1)
        #expect(try context.fetch(FetchDescriptor<HabitLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Habit>()).isEmpty)
    }

    @Test func aBlockedPersonsWinsDisappear() async throws {
        let store = SocialStore(cloud: FakeCrewCloud(), defaults: UserDefaults(suiteName: "block-\(UUID())")!,
                                directory: FileManager.default.temporaryDirectory.appending(path: "block-\(UUID())"))
        store.isEnabled = { true }
        let (crew, _) = try await store.createCrew(name: "One")
        let sam = UUID()
        store.receive(SharedWin(winID: UUID(), crewID: crew.id, senderProfileID: sam,
                                crewDay: CrewDay.string(for: .now, in: crew.timeZone), title: "Run",
                                colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                                createdAt: .now, updatedAt: .now))
        #expect(store.unread == [crew.id])
        store.block(sam)
        #expect(store.today(in: crew.id).isEmpty)
        #expect(store.unread.isEmpty)
    }

    @Test func ageDecidesPhotos() {
        #expect(CrewAge.from(lowerBound: 18) == .adult)
        #expect(CrewAge.from(lowerBound: 13) == .teen)
        #expect(CrewAge.from(lowerBound: 9) == .under13)
        #expect(CrewAge.from(lowerBound: nil) == .teen, "declining to say is treated as 13 to 15")
        #expect(!CrewAge.under13.opensCrews)
        #expect(!CrewAge.teen.sendsPhotos && CrewAge.adult.sendsPhotos)
        #expect(!CrewAge.unknown.sendsPhotos)
    }
}

extension CrewSyncTests {
    @Test func aNotificationReadsLikeMessages() {
        let me = UUID(), sam = UUID()
        let crew = Crew(id: CrewID(rawValue: "crew-n"), name: "Roommates", ownerProfileID: me, timeZoneIdentifier: "UTC",
                        createdAt: .now, photo: nil,
                        members: [CrewMember(profileID: me, firstName: "Jayden", head: nil, joinedAt: .distantPast),
                                  CrewMember(profileID: sam, firstName: "Sam Lee", head: nil, joinedAt: .now)])
        func win(_ title: String, photo: URL? = nil) -> SharedWin {
            SharedWin(winID: UUID(), crewID: crew.id, senderProfileID: sam, crewDay: "2026-10-02", title: title,
                      colour: .health, icon: .health, blockSize: .small, photo: photo, cropX: nil, cropY: nil,
                      createdAt: .now, updatedAt: .now)
        }
        #expect(CrewNotifications.Text.of(win("Gym"), in: crew, me: me) == ("Roommates", "Sam: Gym"))
        #expect(CrewNotifications.Text.of(win("", photo: URL(fileURLWithPath: "/tmp/x.jpg")), in: crew, me: me).body
                == "Sam added a photo")
        #expect(CrewNotifications.Text.of(win(""), in: crew, me: me).body == "Sam added a win")
    }

    @Test func noCrewWordUsesALongDashOrSoundsLikeWatching() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Strata")
        let files = ["Views/Crews/CrewsListView.swift", "Views/Crews/CrewTowerView.swift", "Views/Crews/CrewInfoSheet.swift",
                     // The win sheet went for a menu over the block (2026-10-02);
                     // its words live in CrewReactions now.
                     "Views/Crews/CrewReactions.swift", "Views/Crews/CrewPicker.swift", "Views/Crews/CrewSharing.swift",
                     "Views/Crews/CrewStatsSections.swift", "Views/Crews/MakeYourHead.swift",
                     "Social/CrewNotifications.swift", "Social/StrataAppDelegate.swift", "Social/CrewSafety.swift"]
        for file in files {
            let text = try String(contentsOf: folder.appending(path: file), encoding: .utf8)
            // Only what a person reads: string literals.
            let literals = text.split(separator: "\"").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
            for literal in literals {
                #expect(!literal.contains("\u{2014}") && !literal.contains("\u{2013}"), "\(file): \(literal)")
                for word in ["watching", "tracking", "active now", "see what your friends"] {
                    #expect(!literal.lowercased().contains(word), "\(file): \(literal)")
                }
            }
        }
    }
}
