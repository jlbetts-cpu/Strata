import Foundation
import Testing
@testable import Strata

/// A chat's photo is for the moment (the owner, 2026-10-17: "They disappear
/// after 24 hours").
struct ChatPhotoDayTests {
    let sam = UUID()

    func line(_ text: String, sketch: URL?, ago hours: Double) -> CrewMessage {
        CrewMessage(messageID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sam, crewDay: "2026-10-14",
                    text: text, sketch: sketch, createdAt: Date().addingTimeInterval(-hours * 3600))
    }

    @Test("a photo goes after a day; words, stickers and strips do not")
    func aDay() {
        let file = URL(fileURLWithPath: "/tmp/x.jpg")
        let photo = line(CrewMessage.pictureMarker, sketch: file, ago: 25)
        let fresh = line(CrewMessage.pictureMarker, sketch: file, ago: 23)
        let sticker = line(CrewMessage.pictureMarker + CrewMessage.stickerWord, sketch: file, ago: 30)
        let words = line("See you at six", sketch: nil, ago: 30)
        #expect(SocialStore.photoHasGone(photo, at: .now))
        #expect(!SocialStore.photoHasGone(fresh, at: .now))
        #expect(!SocialStore.photoHasGone(sticker, at: .now), "a sticker is not a photo for the moment")
        #expect(!SocialStore.photoHasGone(words, at: .now))
    }
}
