import Foundation
import Testing
@testable import Strata

/// **A strip, picture or sticker in the chat opens full screen** (M4): the
/// photo viewer's own page, Save and Share only on your own, Heart and Report
/// on a friend's.
@MainActor
@Suite("Chat picture viewer")
struct ChatPictureViewerTests {
    @Test("the viewer reuses the photo viewer's page, and only your own picture leaves the app")
    func wired() throws {
        let viewer = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/ChatPictureViewer.swift"))
        #expect(viewer.contains("PhotoPage(photo: photo, image: image, isCurrent: true"), "a second drawing of a photograph")
        let mine = try #require(viewer.range(of: "if mine {"))
        let theirs = try #require(viewer.range(of: "} else {", range: mine.upperBound..<viewer.endIndex))
        let ownPart = String(viewer[mine.upperBound..<theirs.lowerBound])
        // Only the menu's own else: the file goes on to define `save()`,
        // and reading to its end found the definition as a call.
        let menuEnd = try #require(viewer.range(of: "GlassIconLabel(systemName: \"ellipsis\"", range: theirs.upperBound..<viewer.endIndex))
        let friendPart = String(viewer[theirs.upperBound..<menuEnd.lowerBound])
        #expect(ownPart.contains("ShareLink(") && ownPart.contains("Save to Photos"))
        #expect(!friendPart.contains("ShareLink(") && !friendPart.contains("save()"), "a friend's picture can leave the app")
        #expect(friendPart.contains("\"Report\""))
        #expect(!viewer.contains(".shadow("))

        let chat = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewChatSheet.swift"))
        #expect(chat.contains("} else if message.isStrip || message.isPicture {"))
        #expect(chat.contains(".fullScreenCover(item: $viewingPicture)"))
    }
}
