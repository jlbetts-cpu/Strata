import Testing
import Foundation
@testable import Strata

/// **The judgement, without a photograph.**
///
/// `DayStickerService` is half Vision and half opinion. The Vision half needs
/// a GPU and a picture; the opinion half is a pure function over six numbers,
/// and it is the half that can be wrong in a way somebody notices — a sticker
/// on the wrong photograph says "this is what that day was" about a blurry
/// shot of a table.
///
/// Every test here can fail: each one names a specific bad pick and asserts
/// the scorer refuses it.
@Suite("What is worth a sticker")
struct DayStickerTests {

    private func features(faces: Int = 0, salience: Double = 0, area: Double = 0.30,
                          named: Bool = false, weight: Int = 1,
                          located: Bool = false) -> DayStickerService.Features {
        DayStickerService.Features(faces: faces, salience: salience, subjectArea: area,
                                   named: named, weight: weight, located: located)
    }

    // MARK: - The gate

    /// A subject that is 2% of the frame is a sticker the size of a full stop
    /// at 50pt. No amount of significance rescues it.
    @Test("A subject too small to see scores nothing, however good the rest is")
    func specksScoreZero() {
        let perfect = features(faces: 2, salience: 1, area: 0.02,
                               named: true, weight: 3, located: true)
        #expect(DayStickerService.score(perfect) == 0)
    }

    /// If the "subject" is nearly the whole picture then the cut-out is the
    /// picture with its corners nibbled, which is not a sticker.
    @Test("A subject that fills the frame is not a cut-out")
    func wholeFrameScoresZero() {
        let perfect = features(faces: 2, salience: 1, area: 0.94,
                               named: true, weight: 3, located: true)
        #expect(DayStickerService.score(perfect) == 0)
    }

    @Test("The gate opens inside the band and not outside it")
    func gateEdges() {
        #expect(DayStickerService.score(features(area: 0.059)) == 0)
        #expect(DayStickerService.score(features(salience: 1, area: 0.061)) > 0)
        #expect(DayStickerService.score(features(salience: 1, area: 0.749)) > 0)
        #expect(DayStickerService.score(features(area: 0.751)) == 0)
    }

    /// **The numbers real photographs actually produce**, measured by running
    /// this pipeline on the app's own demo pictures on a Mac — the model
    /// cannot run in a simulator. Every photograph of people landed between
    /// 0.22 and 0.56 coverage, and a close portrait of two reached 0.71.
    ///
    /// This is the test that would have caught the bug that shipped for an
    /// hour: coverage was being measured as the subject's BOUNDING BOX
    /// against the frame, which put those same three photographs at 0.66,
    /// 0.95 and 0.95 — every one of them past the ceiling, so the feature
    /// would have produced nothing at all on a phone and there would have
    /// been no way to tell that from "no day was good enough".
    @Test("The coverage real photographs of people produce is inside the band")
    func realPhotographsPass() {
        for coverage in [0.22, 0.28, 0.31, 0.34, 0.54, 0.56, 0.71] {
            let person = features(faces: 1, salience: 1, area: coverage)
            #expect(DayStickerService.score(person) > 0,
                    "coverage \(coverage) was gated out, and a person at that size is a sticker")
        }
        // And the two that should be refused: a speck, and a mask that is
        // nearly the whole picture.
        #expect(DayStickerService.score(features(faces: 1, salience: 1, area: 0.05)) == 0)
        #expect(DayStickerService.score(features(faces: 1, salience: 1, area: 0.95)) == 0)
    }

    // MARK: - The bar

    /// The claim the service's own comment makes, checked rather than
    /// asserted in prose: a nicely composed photograph of nothing in
    /// particular, on a win nobody named, does not get to speak for the day.
    @Test("A well-composed photograph of nobody, unnamed, stays off the folder")
    func aPrettyNothingIsNotAMemory() {
        let pretty = features(faces: 0, salience: 1.0, area: 0.32,
                              named: false, weight: 1, located: false)
        #expect(DayStickerService.score(pretty) < DayStickerService.bar,
                "a photograph with nobody and nothing said about it cleared the bar")
    }

    @Test("Somebody in the frame clears it")
    func aPersonIsAMemory() {
        let person = features(faces: 1, salience: 0.6, area: 0.30)
        #expect(DayStickerService.score(person) >= DayStickerService.bar)
    }

    /// The term the phone cannot see: a win somebody named, sized up and
    /// recorded a place for is one they thought about.
    @Test("What the app knows can carry a photograph over on its own")
    func deliberatenessCounts() {
        let plain = features(salience: 0.7, area: 0.30)
        let meant = features(salience: 0.7, area: 0.30, named: true, weight: 3, located: true)
        #expect(DayStickerService.score(plain) < DayStickerService.bar)
        #expect(DayStickerService.score(meant) >= DayStickerService.bar)
        #expect(DayStickerService.score(meant) > DayStickerService.score(plain))
    }

    @Test("A fourth face is worth no more than a second")
    func crowdsAreCapped() {
        let two = features(faces: 2, salience: 0.5)
        let six = features(faces: 6, salience: 0.5)
        #expect(DayStickerService.score(two) == DayStickerService.score(six))
    }

    @Test("A subject near a third of the frame beats one at the edges of the band")
    func sizeHasASweetSpot() {
        let ideal = DayStickerService.score(features(salience: 0.5, area: 0.32))
        let tight = DayStickerService.score(features(salience: 0.5, area: 0.08))
        let loose = DayStickerService.score(features(salience: 0.5, area: 0.60))
        #expect(ideal > tight)
        #expect(ideal > loose)
    }

    /// Nothing here may exceed 1, or the bar stops meaning a fraction of the
    /// best possible photograph and starts meaning an arbitrary number.
    @Test("The best possible photograph still scores at most 1")
    func scoreIsBounded() {
        let best = features(faces: 9, salience: 1, area: 0.32,
                            named: true, weight: 3, located: true)
        let worst = features(faces: 0, salience: 0, area: 0.32)
        #expect(DayStickerService.score(best) <= 1.0)
        #expect(DayStickerService.score(worst) >= 0)
    }

    // MARK: - The cache key

    @Test("The key changes when the day's wins change, and not otherwise")
    func keyFollowsTheDay() {
        let a = DayStickerService.key(day: "2026-09-22", winIDs: ["one.heic", "two.heic"])
        let sameSetReordered = DayStickerService.key(day: "2026-09-22", winIDs: ["two.heic", "one.heic"])
        let winAdded = DayStickerService.key(day: "2026-09-22", winIDs: ["one.heic", "two.heic", "three.heic"])
        let otherDay = DayStickerService.key(day: "2026-09-21", winIDs: ["one.heic", "two.heic"])
        #expect(a == sameSetReordered, "the order wins were loaded in changed the key")
        #expect(a != winAdded, "adding a win did not invalidate the day's sticker")
        #expect(a != otherDay)
        #expect(a.hasPrefix("2026-09-22-"), "the key has to name its day so pruning can read it")
    }

    @Test("Pruning keeps what is asked for and drops the rest")
    func pruneDropsTheUnreachable() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sticker-prune-\(UUID().uuidString)")
        let folder = root.appendingPathComponent("stickers", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for key in ["keep-1", "drop-1", "drop-2"] {
            try Data([0x1]).write(to: folder.appendingPathComponent("\(key).png"))
        }
        let removed = DayStickerService.prune(keeping: ["keep-1"], in: root)
        #expect(removed == 2)
        let left = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        #expect(left.map { $0.lastPathComponent } == ["keep-1.png"])
    }
}
