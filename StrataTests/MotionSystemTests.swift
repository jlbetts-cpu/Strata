import Foundation
import SwiftUI
import Testing
@testable import Strata

/// **The motion pass, 2026-10-02, pinned.** One vocabulary, Reduce Motion
/// decided once, and the controls that gave no answer to a finger.
/// `tools/motion-inventory.py` counts the same things from the outside.
@Suite("Motion system, 2026-10-02", .serialized)
struct MotionSystemTests {

    @Test("with Reduce Motion on, every UI spring is the fade")
    func calmUnderReduceMotion() {
        let before = GridConstants.reducedMotion
        defer { GridConstants.reducedMotion = before }
        GridConstants.reducedMotion = true
        for token in [GridConstants.motionSnappy, GridConstants.slotSnap, GridConstants.layoutReflow,
                      GridConstants.elasticPop, GridConstants.shutterRelease, GridConstants.danceRise,
                      GridConstants.danceSettle, GridConstants.microBounceUpSpring,
                      GridConstants.slotRelease(velocity: 2)] {
            #expect(token == GridConstants.crossFade)
        }
        GridConstants.reducedMotion = false
        #expect(GridConstants.motionSnappy != GridConstants.crossFade, "the injection: off, the spring is back")
        #expect(GridConstants.slotSnap != GridConstants.crossFade)
    }

    @Test("the cluster stays collapsed: four near-copies of motionSnappy are gone")
    func clusterCollapsed() {
        let names = ["gentleReveal", "naturalSettle", "motionSmooth", "dropSettleSpring"]
        let hits = MemoriesConsistencyTests.codeLines().filter { line in
            names.contains { line.text.contains("GridConstants.\($0)") || line.text.contains("static let \($0)") }
        }
        #expect(hits.isEmpty, "\(hits.map { "\($0.file):\($0.line)" })")
    }

    @Test("no animation is typed inline outside the token file")
    func noInlineAnimations() {
        let inline = try! NSRegularExpression(pattern: #"withAnimation\(\s*\.(spring|easeInOut|easeOut|easeIn|interpolatingSpring|smooth|snappy|bouncy)\b"#)
        let hits = MemoriesConsistencyTests.codeLines().filter { line in
            !line.file.hasSuffix("GridConstants.swift")
                && inline.firstMatch(in: line.text, range: NSRange(line.text.startIndex..., in: line.text)) != nil
        }
        #expect(hits.isEmpty, "\(hits.map { "\($0.file):\($0.line): \($0.text)" })")
        // The injection, so this can fail.
        let bad = "        withAnimation(.interpolatingSpring(duration: 0.34, bounce: 0.18)) {"
        #expect(inline.firstMatch(in: bad, range: NSRange(bad.startIndex..., in: bad)) != nil)
    }

    @Test("the profile picture answers a press when it is not on glass")
    func avatarPresses() throws {
        let text = try MorningSource.read("Views/ProfileAvatar.swift")
        #expect(text.contains(".buttonStyle(isGlass ? PressResponse(scale: 1, dim: 1) : .pressSurface)"))
        #expect(!text.contains("        .buttonStyle(.plain)\n        .accessibilityLabel(\"Profile\")"))
    }

    @Test("Reduce Motion is read at launch and kept current")
    func reduceMotionWired() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(contentsOf: root.appendingPathComponent("Strata/StrataApp.swift"), encoding: .utf8)
        #expect(app.contains("GridConstants.reducedMotion = UIAccessibility.isReduceMotionEnabled"))
        #expect(app.contains(".modifier(ReduceMotionSync())"))
    }

    @Test("Spotlight draws each category's picture once, and waits for the first taps")
    func spotlightIsCheap() throws {
        let entity = try MorningSource.read("Intents/HabitEntity.swift")
        #expect(entity.contains("if let hit = thumbnails.withLock({ $0[key] }) { return hit }"))
        let indexer = try MorningSource.read("Services/SpotlightIndexer.swift")
        #expect(indexer.contains("Task.detached(priority: .background)"))
        #expect(indexer.contains("try? await Task.sleep(for: .seconds(2))"))
    }
}
