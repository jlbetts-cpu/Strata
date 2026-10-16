import Foundation
import Testing
import UIKit
@testable import Strata

/// The hand-over Instagram reads (Meta's Sharing to Stories keys).
@Suite("Instagram share")
struct InstagramShareTests {
    @Test("the background and the App ID, under Meta's keys")
    func items() {
        let data = Data([1, 2, 3])
        let items = InstagramShare.items(background: data, appID: "123")
        #expect(items.count == 1)
        #expect(items[0]["com.instagram.sharedSticker.backgroundImage"] as? Data == data)
        #expect(items[0]["com.instagram.sharedSticker.appID"] as? String == "123")
    }

    @MainActor @Test("not offered without an App ID")
    func offWithoutAppID() {
        #expect(InstagramShare.appID.isEmpty ? !InstagramShare.isReady : true)
    }

    @MainActor @Test("the card is a story's size")
    func cardSize() {
        let card = InstagramShare.card(picture: nil, line: "A good day")
        #expect(card.map { Int($0.size.width * $0.scale) } == 1080)
        #expect(card.map { Int($0.size.height * $0.scale) } == 1920)
    }
}
