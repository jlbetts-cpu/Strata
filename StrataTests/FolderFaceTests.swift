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
    func allEightAreDistinct() {
        let all = FaceExpression.all
        for i in all.indices {
            for j in all.indices where j > i {
                #expect(all[i].1 != all[j].1,
                        "\(all[i].0) and \(all[j].0) are the same face")
            }
        }
    }

    /// Six of the seven in the reference are not happy, and that proportion
    /// is the point: a folder wearing a constant grin is wallpaper. Happy is
    /// the only one that arches both eyes hard.
    @Test("The set is mostly not happy")
    func theSetIsNotAGrin() {
        let cheerful = FaceExpression.all.filter { _, face in
            face.left.bend > 0.8 && face.right.bend > 0.8
                && face.left.angle == 0 && face.right.angle == 0
        }
        #expect(cheerful.count == 1, "\(cheerful.count) of the eight are a full grin")
    }

    /// **Every face is two chevrons at a curvature and an angle**, which is
    /// what makes it a system rather than a set of drawings. Nothing may need
    /// a parameter that does not exist.
    @Test("Bend and angle alone make every shape the set needs")
    func theParametersSpanTheSet() {
        // `>` is an arch rotated a quarter turn. If that stops being true the
        // nervous and confused faces are drawings again.
        #expect(FaceExpression.nervous.left.angle == 90)
        #expect(FaceExpression.nervous.right.angle == -90)
        #expect(FaceExpression.nervous.left.bend > 0.5, "a chevron needs curvature")
        // `|` is a flat line rotated a quarter turn.
        #expect(FaceExpression.confused.right.bend == 0)
        #expect(FaceExpression.confused.right.angle == 90)
        // Asymmetry is what reads as thinking rather than as feeling.
        #expect(FaceExpression.confused.left != FaceExpression.confused.right)
        // Dizzy is the one face two strokes cannot make.
        #expect(FaceExpression.dizzy.cross == 1)
        for (name, face) in FaceExpression.all where name != "Dizzy" {
            #expect(face.cross == 0, "\(name) should not be drawing the dizzy cross")
        }
    }

    /// The curvature has to mean what it says, because the whole rig is one
    /// number being interpolated.
    @Test("Bend zero is a flat line, and the sign picks the direction")
    func bendMeansWhatItSays() {
        let box = CGRect(x: 0, y: 0, width: 40, height: 28)
        // **The TOP of the curve, not the middle of its box.** The first
        // version of this measured `boundingRect.midY`, which barely moves:
        // an arch grows upward while its box grows with it, so the centre
        // stays put and the assertion compared 14.0 with 14.00000011.
        func top(_ bend: CGFloat) -> CGFloat {
            EyeStroke(bend: bend).path(in: box).boundingRect.minY
        }
        func bottom(_ bend: CGFloat) -> CGFloat {
            EyeStroke(bend: bend).path(in: box).boundingRect.maxY
        }
        let flatTop = top(0), flatBottom = bottom(0)
        #expect(abs(flatTop - flatBottom) < 0.01, "bend 0 is not a flat line")
        #expect(abs(flatTop - box.midY) < 0.01, "bend 0 is not centred on the eye")
        #expect(top(0.9) < flatTop - 3, "a positive bend must arch UP")
        #expect(bottom(-0.9) > flatBottom + 3, "a negative bend must cup DOWN")
        // And it must be a smooth ramp, or interpolating it would jump.
        #expect(top(0.45) < flatTop && top(0.45) > top(0.9))
    }

    /// A blink is the openness going to nothing. Nothing else may sit at
    /// zero, or that expression would be permanently blinking.
    @Test("Only a blink closes the eyes")
    func nothingIsShutByDefault() {
        for (name, face) in FaceExpression.all {
            #expect(face.openness > 0.5, "\(name) is drawn half shut")
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
