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
        #expect(MemoriesView.monthLine["October"] == "Even scarecrows have friends")
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
}
