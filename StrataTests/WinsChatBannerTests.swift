import Foundation
import Testing
@testable import Strata

/// **A friend's line over your Wins tower** (the owner, 2026-10-13: "chat
/// notifications not noticeable, show message above tower").
@Suite("Wins: a friend's line over the tower")
struct WinsChatBannerTests {
    private let me = UUID(), sam = UUID(), ana = UUID()
    private let crew = CrewID(rawValue: "c1")
    private let noon = Date(timeIntervalSince1970: 1_791_900_000)

    private func line(_ text: String, by who: UUID, secondsAgo: Double = 5) -> CrewMessage {
        CrewMessage(messageID: UUID(), crewID: crew, senderProfileID: who, crewDay: "2026-10-13", text: text,
                    createdAt: noon.addingTimeInterval(-secondsAgo))
    }

    @Test("what was already there is never news: the first look only remembers")
    func firstLookRemembers() {
        var watch = ChatBannerWatch()
        #expect(watch.arrived([line("morning all", by: sam)], me: me, listening: true, now: noon) == nil)
        #expect(watch.started)
    }

    @Test("a friend's new line shows; your own never does")
    func friendsOnly() {
        var watch = ChatBannerWatch()
        let old = [line("morning all", by: sam)]
        _ = watch.arrived(old, me: me, listening: true, now: noon)
        let mine = line("me! 6ish?", by: me)
        #expect(watch.arrived(old + [mine], me: me, listening: true, now: noon) == nil)
        let theirs = line("6 works", by: ana)
        #expect(watch.arrived(old + [mine, theirs], me: me, listening: true, now: noon) == theirs)
        #expect(watch.arrived(old + [mine, theirs], me: me, listening: true, now: noon) == nil, "shown once")
    }

    @Test("one at a time: several in one fetch show as the newest")
    func newestOnly() {
        var watch = ChatBannerWatch()
        _ = watch.arrived([], me: me, listening: true, now: noon)
        let first = line("lunch at 1?", by: sam, secondsAgo: 30)
        let newest = line("or 1:30", by: sam, secondsAgo: 2)
        #expect(watch.arrived([first, newest], me: me, listening: true, now: noon) == newest)
    }

    @Test("away from Wins, a line is remembered and never shown late")
    func notListening() {
        var watch = ChatBannerWatch()
        _ = watch.arrived([], me: me, listening: true, now: noon)
        let said = line("lunch at 1?", by: sam)
        #expect(watch.arrived([said], me: me, listening: false, now: noon) == nil)
        #expect(watch.arrived([said], me: me, listening: true, now: noon) == nil)
    }

    @Test("a fetch that brings an old line in does not replay it")
    func onlyJustSaid() {
        var watch = ChatBannerWatch()
        _ = watch.arrived([], me: me, listening: true, now: noon)
        let stale = line("from this morning", by: sam, secondsAgo: ChatBannerWatch.window + 60)
        #expect(watch.arrived([stale], me: me, listening: true, now: noon) == nil)
    }

    @Test("wired: under the Wins header, opening the chat, and the system banner stands down on Wins only")
    func wired() throws {
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("WinsChatBanner(isClear: ringIsClear)"))
        let banner = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/WinsChatBanner.swift"))
        #expect(banner.contains("CrewRouter.shared.openChat = true"))
        #expect(banner.contains("CrewRouter.shared.open = crew"))
        #expect(banner.contains("CrewFace(member: member"))
        #expect(banner.contains("static let holds: Duration = .seconds(4)"))
        #expect(banner.contains("reduceMotion ? .opacity :"), "Reduce Motion fades, never slides")
        #expect(!banner.contains(".shadow("), "chrome separates with glass, never elevation")
        #expect(!banner.contains("AppColors.notify"), "only the Crews tab's dot is terracotta")
        let delegate = SourceSweep.code(try SourceSweep.read("Strata/Social/StrataAppDelegate.swift"))
        #expect(delegate.contains("if isChat, await MainActor.run(body: { ChatBanner.isListening }) {"))
    }

    @Test("its words keep the voice: no long dash, no exclamation mark")
    func voice() throws {
        let banner = try SourceSweep.read("Strata/Views/Crews/WinsChatBanner.swift")
        #expect(!SourceSweep.longDash(banner))
        for literal in banner.split(separator: "\n").flatMap({ SourceSweep.literals(in: String($0)) }) {
            #expect(!literal.contains("!"), "\(literal)")
        }
    }
}
