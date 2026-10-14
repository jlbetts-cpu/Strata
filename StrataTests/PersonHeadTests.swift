import Foundation
import UIKit
import Testing
@testable import Strata

/// **One identity component** (the owner, 2026-10-14: "treat the head not
/// really as an optional thing but an identity ... I want to make sure they
/// are pretty normalized throughout the app"). `docs/heads-as-identity-2026-10-14.md`.
@MainActor
@Suite("Heads as identity: PersonHead and HeadIdentity")
struct PersonHeadTests {

    @Test("a person's colour is picked by their id, so every phone agrees")
    func colourIsStable() {
        let id = UUID(uuidString: "07000000-0000-0000-0000-000000000000")!
        #expect(HeadIdentity.paletteIndex(for: id, count: 6) == 1)
        #expect(HeadIdentity.paletteIndex(for: id, count: 6) == HeadIdentity.paletteIndex(for: id, count: 6))
        // The rule `CrewFace` used, unchanged: the id's first byte.
        let other = UUID(uuidString: "0C000000-0000-0000-0000-000000000000")!
        #expect(HeadIdentity.paletteIndex(for: other, count: 6) == 0)
        #expect(HeadIdentity.paletteIndex(for: other, count: 0) == 0, "an empty palette never divides by zero")
    }

    @Test("your initial is read the way a friend's is")
    func initial() {
        #expect(HeadIdentity.initial(fromName: "jayden betts") == "J")
        #expect(HeadIdentity.initial(fromName: "  Sam ") == "S")
        #expect(HeadIdentity.initial(fromName: "") == "")
        #expect(HeadIdentity.initial(fromName: "   ") == "")
        let sam = CrewMember(profileID: UUID(), firstName: "sam lee", head: nil, joinedAt: .now)
        #expect(HeadIdentity.initial(fromName: sam.firstName) == sam.initial)
    }

    @Test("a member who is you resolves to your own head, never a copy")
    func meAsAMember() {
        let me = UUID()
        let member = CrewMember(profileID: me, firstName: "Me", head: nil, joinedAt: .now)
        let crew = CrewID(rawValue: "c")
        let asMember = HeadIdentity.rig(for: .member(member, crew: crew, me: me))
        let asMe = HeadIdentity.rig(for: .me)
        #expect((asMember == nil) == (asMe == nil))
        #expect(asMember?.faces.count == asMe?.faces.count)
    }

    @Test("one share for a head in a disc, one for a head in a ring")
    func shares() {
        #expect(PersonHead.discShare == 0.9)
        #expect(PersonHead.ringShare == 0.76)
        // The blank head stands where a head of the same side would.
        #expect(HeadPlaceholder.aspect < 1)
    }

    @Test("no screen draws a person with its own decision tree any more")
    func oneTree() throws {
        // The four that used to choose between a head, a photo, initials and
        // a glyph are thin over `PersonHead` now.
        let avatar = SourceSweep.code(try SourceSweep.read("Strata/Views/ProfileAvatar.swift"))
        #expect(!avatar.contains("store.photo"))
        #expect(!avatar.contains("person.fill"))
        #expect(avatar.contains("PersonHead(person: .me"))
        let faces = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewFaces.swift"))
        #expect(!faces.contains("member.photo"))
        #expect(faces.contains("PersonHead(person: .member(member, crew: crew, me: me), side: side)"))
        let arena = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewHeadArena.swift"))
        #expect(!arena.contains("CrewFace(member:"), "a crew tower's heads have no disc fallback of their own")
        // The injection, so this can fail.
        #expect("if let photo = member.photo".contains("member.photo"))
    }
}

/// **The switches the head no longer has** (the owner, 2026-10-14: "the heads
/// dont need to be an option in the settings for crew or settings").
@MainActor
@Suite("Heads as identity: the switches are gone")
struct HeadSwitchesGoneTests {

    @Test("the retired switches are forgotten, and nothing else is")
    func retiredKeysCleared() throws {
        let defaults = try #require(UserDefaults(suiteName: "retired-head-switches"))
        defer { defaults.removePersistentDomain(forName: "retired-head-switches") }
        for key in RetiredHeadSwitches.keys { defaults.set(true, forKey: key) }
        defaults.set(["c1"], forKey: "crews.headsHidden")
        defaults.set(true, forKey: "headOnTower")
        RetiredHeadSwitches.clear(defaults)
        for key in RetiredHeadSwitches.keys { #expect(defaults.object(forKey: key) == nil, "\(key) is still on disk") }
        #expect(defaults.bool(forKey: "headOnTower"), "the tower switch is the one that stays")
        // Twice is the same as once.
        RetiredHeadSwitches.clear(defaults)
        #expect(defaults.bool(forKey: "headOnTower"))
    }

    @Test("your crews see your head whenever you have one")
    func crewsSeeTheHead() throws {
        let store = SourceSweep.code(try SourceSweep.read("Strata/Models/HeadStore.swift"))
        #expect(store.contains("var headForCrews: HeadRig? { head }"))
        #expect(store.contains("var crewHeadDirectory: URL? { activeDirectory }"))
        #expect(!store.contains("isSomewhere"))
        #expect(!store.contains("headForPicture") && !store.contains("headForMap") && !store.contains("headForSticker"))
        #expect(HeadStore.shared.headForCrews == nil || HeadStore.shared.head != nil)
    }

    @Test("Profile offers no photograph and no placement switches")
    func profileHasNoPhoto() throws {
        let profile = SourceSweep.code(try SourceSweep.read("Strata/Views/ProfileView.swift"))
        for gone in ["Choose Photo", "Remove Photo", "Use Photo or Initials", "Use as Profile Picture",
                     "Show My Head on the Map", "Add My Head to Photos", ".photosPicker("] {
            #expect(!profile.contains(gone), "\(gone) is back in Profile")
        }
        // The one switch he had kept went later the same day (the owner,
        // 2026-10-14: "no need to have the option of letting head on tower").
        #expect(!profile.contains("Let My Head Onto the Tower"), "the tower switch is back in Profile")
        let crew = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewInfoSheet.swift"))
        #expect(!crew.contains("setShowsHeads"), "the per-crew Heads switch is back")
        let social = SourceSweep.code(try SourceSweep.read("Strata/Social/SocialStore.swift"))
        #expect(!social.contains("myPhoto"), "a profile photo is being sent to crews again")
    }
}

/// **Making a head is a must, with a way through** (the owner, 2026-10-14:
/// "make the head making a must"). `HeadAsk`, plan §4.4.
@MainActor
@Suite("Heads as identity: the head is asked for")
struct HeadAskTests {

    @Test("the page over Wins shows once, and only with no head")
    func catchUpOnce() {
        #expect(HeadAsk.showsCatchUp(alreadyShown: false, hasHead: false))
        #expect(!HeadAsk.showsCatchUp(alreadyShown: true, hasHead: false), "once only")
        #expect(!HeadAsk.showsCatchUp(alreadyShown: false, hasHead: true))
        let defaults = UserDefaults(suiteName: "head-catch-up")!
        defer { defaults.removePersistentDomain(forName: "head-catch-up") }
        #expect(!defaults.bool(forKey: HeadAsk.catchUpShownKey))
        HeadAsk.markCatchUpShown(defaults)
        #expect(defaults.bool(forKey: HeadAsk.catchUpShownKey))
    }

    @Test("Later appears after trouble, never on first sight with a working camera")
    func laterOnlyAfterTrouble() throws {
        let page = SourceSweep.code(try SourceSweep.read("Strata/Views/OnboardingView.swift"))
        #expect(!page.contains("decline(\"Not Now\")"), "the head is skippable on first sight again")
        #expect(page.contains("if offersHead && HeadAsk.shared.offersLater { decline(HeadAsk.Copy.later) }"))
        let ask = SourceSweep.code(try SourceSweep.read("Strata/Views/HeadAsk.swift"))
        #expect(ask.contains("var offersLater: Bool { hadTrouble || Self.cameraBlocked }"))
        let maker = SourceSweep.code(try SourceSweep.read("Strata/Views/HeadMakerView.swift"))
        #expect(maker.contains("HeadAsk.shared.noteTrouble()"), "a refused camera never offers Later")
    }

    @Test("Try Again after a photo with no camera goes back to the choice, not the outline")
    func retakeWithoutCamera() {
        let model = HeadMakerModel()
        model.retake()
        #expect(model.step == .unavailable)
    }

    @Test("a photo with no face in it makes no head")
    func photoWithNoFace() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let data = renderer.jpegData(withCompressionQuality: 0.9) { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let upright = try #require(HeadCaptureEngine.upright(data, longEdge: 200))
        #expect(max(upright.width, upright.height) <= 200, "read no larger than asked")
        #expect(upright.bitsPerComponent == 8)
        #expect(HeadCaptureEngine.take(fromPhoto: data) == nil)
        #expect(HeadCaptureEngine.upright(Data([1, 2, 3]), longEdge: 200) == nil)
    }

    @Test("the words hold to the voice")
    func voice() {
        let lines = [HeadAsk.Copy.pageLine, HeadAsk.Copy.pageMade, HeadAsk.Copy.usePhoto, HeadAsk.Copy.later,
                     HeadAsk.Copy.cameraOff, HeadAsk.Copy.noCamera, HeadAsk.Copy.photoFailed,
                     HeadAsk.Copy.catchUpTitle, HeadAsk.Copy.catchUpLine, HeadAsk.Copy.makeMyHead,
                     HeadAsk.Copy.profileFooter]
        let banned = ["scan", "detect", "recognis", "recogniz", "track", "analys", "analyz", "watch",
                      "face data", "find your face", "see you", "look at you"]
        for line in lines {
            #expect(!line.contains("!"), "\(line)")
            #expect(!line.contains("\u{2014}") && !line.contains("\u{2013}"), "\(line)")
            for word in banned { #expect(!line.lowercased().contains(word), "\(line) says \(word)") }
        }
        // The injection, so this can fail.
        #expect("We detect your face".lowercased().contains("detect"))
    }
}
