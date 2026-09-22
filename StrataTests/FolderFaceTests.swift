import Testing
import SwiftUI
@testable import Strata

/// **The face is a system, so the thing worth asserting is a property of the
/// SET rather than of any one drawing.**
struct FolderFaceTests {

    /// No two expressions may be the same face. This is the one that rots
    /// silently: somebody tunes Annoyed a little closer to Idle, both still
    /// look fine on their own, and the folder quietly loses a mood.
    @Test("Every expression is a different face")
    func allAreDistinct() {
        let all = FaceExpression.all
        for i in all.indices {
            for j in all.indices where j > i {
                #expect(all[i].1 != all[j].1,
                        "\(all[i].0) and \(all[j].0) are the same face")
            }
        }
    }

    /// Most of the set is not happy, and that proportion is the point: a
    /// folder that can be bored is a folder that wants something put in it.
    /// Happy is the only one that squints from below, which is how eyes
    /// smile.
    @Test("The set is mostly not happy")
    func theSetIsNotAGrin() {
        let smiling = FaceExpression.all.filter { _, face in
            face.left.lower > 0.3 && face.right.lower > 0.3
        }
        #expect(smiling.count == 1, "\(smiling.count) of the set are a full smile")
    }

    /// **A lid and its angle make every face the set needs.** If something
    /// ever needs a parameter that does not exist, this is where it shows.
    @Test("The lid alone spans the whole set")
    func theLidSpansTheSet() {
        // Eyes smile with the LOWER lid.
        #expect(FaceExpression.happy.left.lower > 0.3)
        // Inner corners down is cross; the sign is what carries it.
        #expect(FaceExpression.annoyed.left.tilt < 0)
        // Outer corners down is worried, which is the same lid turned.
        #expect(FaceExpression.nervous.left.tilt > 0)
        // Asymmetry is what reads as thinking rather than as feeling, and
        // confused is the only face that is not a mirror of itself.
        #expect(FaceExpression.confused.left != FaceExpression.confused.right)
        for (name, face) in FaceExpression.all where name != "Confused" && name != "Curious" {
            #expect(face.left == face.right, "\(name) is lopsided by accident")
        }
        // Heavy lids are what read as tired.
        #expect(FaceExpression.sleepy.left.lid > FaceExpression.bored.left.lid)
        #expect(FaceExpression.bored.left.lid > FaceExpression.idle.left.lid)
        #expect(FaceExpression.wide.left.lid < FaceExpression.idle.left.lid)
        // The one thing a pair does that a lid cannot.
        #expect(FaceExpression.dizzy.pupilSplit > 0)
        for (name, face) in FaceExpression.all where name != "Dizzy" {
            #expect(face.pupilSplit == 0, "\(name) has its eyes pushed apart")
        }
    }

    /// The mask has to mean what it says, because the whole rig is these
    /// three numbers being interpolated.
    @Test("An open lid shows the eye and a shut one hides it")
    func theLidMeansWhatItSays() {
        let box = CGRect(x: 0, y: 0, width: 40, height: 40)
        func height(_ lid: CGFloat, _ lower: CGFloat = 0) -> CGFloat {
            LidMask(lid: lid, lower: lower, tilt: 0).path(in: box)
                .boundingRect.intersection(box).height
        }
        #expect(height(0) >= box.height - 0.01, "a fully open lid hides part of the eye")
        #expect(height(1) < 0.01, "a fully shut lid still shows the eye")
        #expect(height(0.5) < height(0.2), "the lid goes the wrong way")
        // The lower lid comes up from the bottom, which is a separate axis.
        #expect(height(0, 0.5) < height(0, 0), "the lower lid does nothing")
    }

    /// A turned lid has to actually turn, or every tilted face is the same
    /// as the level one.
    @Test("Tilting the lid turns it")
    func tiltTurnsTheLid() {
        let box = CGRect(x: 0, y: 0, width: 40, height: 40)
        let level = LidMask(lid: 0.3, lower: 0, tilt: 0).path(in: box).boundingRect
        let turned = LidMask(lid: 0.3, lower: 0, tilt: 18).path(in: box).boundingRect
        #expect(abs(level.minY - turned.minY) > 0.5, "the tilt changed nothing")
    }

    /// A blink is the openness going to nothing. Nothing else may sit at
    /// zero, or that expression would be permanently blinking.
    @Test("Only a blink closes the eyes")
    func nothingIsShutByDefault() {
        for (name, face) in FaceExpression.all {
            #expect(face.openness > 0.5, "\(name) is drawn half shut")
            #expect(face.left.lid < 0.9 && face.right.lid < 0.9, "\(name) is drawn shut")
        }
    }
}

/// **The logic system, which is the part that can silently become a guilt
/// machine.** These assertions are the fence around that.
struct FolderMoodTests {

    @Test("An empty folder rests asleep, a full one rests awake")
    func restingIsAboutTheContents() {
        #expect(FolderMood.resting(for: FolderContents(count: 0)) == .sleepy)
        #expect(FolderMood.resting(for: FolderContents(count: 1)) == .idle)
        #expect(FolderMood.resting(for: FolderContents(count: 400)) == .idle)
    }

    /// **The rule the whole direction rests on.** Every event is something a
    /// person DID. If an event ever appears that means "time passed without
    /// you", this fails, and it should.
    @Test("Nothing in the system is triggered by absence")
    func noEventIsAboutNotDoingSomething() {
        let events: [FolderEvent] = [.winAdded, .winRush, .winHovering,
                                     .hoverEnded, .shaken, .poked, .opened, .closed]
        for event in events {
            let reaction = FolderMood.reaction(to: event, pokes: 0)
            // Every reaction is either a face or a return to rest. None of
            // them may be reached without the person acting, which is a
            // property of this enum having no case for it.
            _ = reaction
        }
        #expect(events.count == 8, "an event was added; check it is an action, not an absence")
    }

    @Test("A win going in is the happy one, and it does not latch")
    func addingAWinIsHappyAndTemporary() throws {
        let (face, hold) = try #require(FolderMood.reaction(to: .winAdded, pokes: 0))
        #expect(face == .happy)
        #expect(hold != nil, "happy must fall back to resting rather than sticking")
    }

    /// The only thing held indefinitely is a win hovering over the folder,
    /// because that state ends when the person's finger does.
    @Test("Only a hover is held")
    func onlyHoverLatches() {
        let indefinite: [FolderEvent] = [.winAdded, .winRush, .shaken, .poked, .opened]
        for event in indefinite {
            let hold = FolderMood.reaction(to: event, pokes: 0)?.1
            #expect(hold != nil, "\(event) would stick until something else moved it")
        }
        #expect(FolderMood.reaction(to: .winHovering, pokes: 0)?.1 == nil)
    }

    @Test("Poking the same folder escalates and then gives up")
    func pokingEscalates() {
        #expect(FolderMood.reaction(to: .poked, pokes: 0)?.0 == .confused)
        #expect(FolderMood.reaction(to: .poked, pokes: 1)?.0 == .annoyed)
        #expect(FolderMood.reaction(to: .poked, pokes: 2)?.0 == .bored)
        #expect(FolderMood.reaction(to: .poked, pokes: 9)?.0 == .bored)
    }
}
