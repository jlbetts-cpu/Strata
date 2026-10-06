import Testing
import Foundation
@testable import Strata

/// **A line under a drawing** (the owner, 2026-10-06: "should there be like a
/// nice quote under the scarecrow drawing and when you are drawing your own
/// you can add you own quote").
@MainActor
@Suite("A line under a drawing", .serialized)
struct DrawingLineTests {
    private let canvas = CGSize(width: 300, height: 450)

    @Test("your line is kept with your drawing, and reads back")
    func keptWithTheDrawing() throws {
        let store = MonthDrawingStore(files: InkTests.folder())
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true,
                   line: "  Out by noon ", for: "2026-10")
        #expect(store.drawing(for: "2026-10")?.line == "Out by noon")
        // A fresh store reads it from the file, not the cache.
        let again = MonthDrawingStore(files: store.files)
        #expect(again.drawing(for: "2026-10")?.line == "Out by noon")
        // Cleared, there is no line, not an empty one.
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true, line: "   ", for: "2026-10")
        #expect(store.drawing(for: "2026-10")?.line == nil)
    }

    @Test("a drawing saved before there were lines still reads")
    func oldRecordsRead() throws {
        let old = #"{"strokes":"","canvasWidth":300,"canvasHeight":450,"bringsToLife":true,"picture":"p.png"}"#
        let drawing = try JSONDecoder().decode(MonthDrawing.self, from: Data(old.utf8))
        #expect(drawing.line == nil)
    }

    @Test("a line is one line, trimmed, and no longer than one breath")
    func keptShape() {
        #expect(DrawingLine.kept(nil) == nil)
        #expect(DrawingLine.kept(" \n ") == nil)
        #expect(DrawingLine.kept("Out\nby noon") == "Out by noon")
        let long = String(repeating: "a", count: 80)
        #expect(DrawingLine.kept(long)?.count == DrawingLine.maxLength)
    }

    @Test("October's scarecrow has its quote, and the crews' drawing keeps its own")
    func octoberHasAQuote() throws {
        #expect(MemoriesView.monthLine["October"] == "Small wins still count")
        let crews = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewsListView.swift"))
        #expect(crews.contains("line: \"Winning is better together\""))
    }

    @Test("your own drawing shows its line, in the one style lines have")
    func ownLineShown() throws {
        let memories = SourceSweep.code(try SourceSweep.read("Strata/Views/MemoriesView.swift"))
        #expect(memories.contains("if let line = own.line { DrawingLine(text: line) }"))
        let illustration = SourceSweep.code(try SourceSweep.read("Strata/Views/Illustration.swift"))
        #expect(illustration.contains("if let line { DrawingLine(text: line) }"))
        let editor = SourceSweep.code(try SourceSweep.read("Strata/Views/Ink/MonthDrawingEditor.swift"))
        #expect(editor.contains("TextField(\"Add a line\", text: $line)"))
        #expect(editor.contains("line: line, for: month)"))
        // A line changed on its own is a change: Done saves it.
        #expect(editor.contains("$0.line == DrawingLine.kept(line)"))
    }

    /// "maybe it can be changed for those that want to keep the scarecrow
    /// but change the quote" (the owner, 2026-10-06).
    @Test("the original drawing's line can be changed per month, and put back")
    func changeTheLine() throws {
        let lines = MonthLines(defaults: UserDefaults(suiteName: "lines.\(UUID())")!)
        #expect(lines.line(for: "2026-10") == nil)
        lines.set("  Keep going  ", for: "2026-10")
        #expect(lines.line(for: "2026-10") == "Keep going")
        #expect(lines.line(for: "2026-11") == nil, "a line is the month's own")
        lines.set("", for: "2026-10")
        #expect(lines.line(for: "2026-10") == nil, "an empty line is the original again")
        let memories = SourceSweep.code(try SourceSweep.read("Strata/Views/MemoriesView.swift"))
        #expect(memories.contains("MonthLines.shared.line(for: key) ?? Self.monthLine[month]"))
        #expect(memories.contains("Button(\"Change Line\""))
    }

    /// "can we also turn the scarecrows frown into a smile when the bird
    /// lands on him" (the owner, 2026-10-06).
    @Test("the scarecrow frowns until the crow lands, then smiles while it stays")
    func smileWhenTheCrowLands() {
        typealias Face = IllustrationMotion.Face
        typealias Crow = IllustrationMotion.Crow
        // The first play: a frown in the air, a smile once it has its feet.
        #expect(Face.smile(at: 0, play: 1) == 0)
        #expect(Face.smile(at: Crow.fly * 0.9, play: 1) == 0, "it smiled before the crow landed")
        #expect(Face.smile(at: Crow.fly + 1, play: 1) == 1)
        // At rest, with the crow on him: the frown gone, the smile shown,
        // turned over. Before it comes, the frown alone.
        #expect(Face.mouth(at: .infinity, play: 1).opacity == 0)
        #expect(Face.grin(at: .infinity, play: 1).opacity == 1)
        #expect(Face.grin(at: .infinity, play: 1).scaleY < 0, "the smile is the mouth turned over")
        #expect(Face.mouth(at: 0, play: 1).opacity == 1)
        #expect(Face.grin(at: 0, play: 1).opacity == 0)
        // Clean: only ever one mouth shows, and never a thin bar or a speck.
        var t = Crow.fly
        while t < Crow.fly + 1.5 {
            let frown = Face.mouth(at: t, play: 1), grin = Face.grin(at: t, play: 1)
            #expect(frown.opacity + grin.opacity == 1, "two mouths at once at \(t)s")
            let shown = frown.opacity == 1 ? frown : grin
            #expect(abs(shown.scaleY) >= Face.smallest - 0.001, "the mouth shrank to \(shown.scaleY) at \(t)s")
            t += 1.0 / 120
        }
        // A tap sends it off: the frown comes back while it is away.
        #expect(Face.smile(at: 0, play: 2) == 1)
        #expect(Face.smile(at: Crow.away, play: 2) == 0, "still smiling with the crow gone")
        #expect(Face.smile(at: Crow.away + Crow.fly + 1, play: 2) == 1)
    }

    /// "the smile is still not right why is it turned so side ways" (the
    /// owner, 2026-10-06), then "look at 3... if you angled it a little
    /// better": turned over and set at 20 degrees, both ends rising.
    @Test("the smile is the mouth turned over at 20 degrees, lifted off the jaw")
    func smileAngle() {
        let grin = IllustrationMotion.Face.grin(at: .infinity, play: 1)
        #expect(grin.scaleY < 0)
        #expect(grin.rotation == 20)
        #expect(grin.y < 0)
    }
}
