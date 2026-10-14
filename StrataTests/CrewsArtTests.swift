import Foundation
import PencilKit
import Testing
@testable import Strata

/// **The Crews page's drawing, editable like the month's** (the owner,
/// 2026-10-14, his pick "Edit like Memories"): the same hold, the same
/// editor and the same store, keyed for the Crews page, plus a way to hide
/// it that leaves the words and keeps the way back on the same hold.
@MainActor
@Suite("Crews drawing", .serialized)
struct CrewsArtTests {
    private let canvas = CGSize(width: 300, height: 200)

    @Test("a drawing for Crews is kept beside the months' and Use Original takes only it")
    func keptBesideTheMonths() {
        let store = MonthDrawingStore(files: InkTests.folder())
        store.save(InkTests.drawing(strokes: [60]), canvas: canvas, bringsToLife: true, line: "Us", for: CrewsArt.key)
        store.save(InkTests.drawing(strokes: [60]), canvas: CGSize(width: 300, height: 450), bringsToLife: true, for: "2026-10")
        #expect(store.drawing(for: CrewsArt.key)?.line == "Us")
        #expect(store.drawing(for: CrewsArt.key)?.canvasSize == canvas)
        store.remove(CrewsArt.key)
        #expect(store.drawing(for: CrewsArt.key) == nil)
        #expect(store.drawing(for: "2026-10") != nil, "Use Original on Crews took a month's drawing")
        let left = Set(store.files.all().map(\.lastPathComponent))
        #expect(!left.contains { $0.hasPrefix("month-\(CrewsArt.key)") })
    }

    @Test("the key never reads as a month, so no month's art or title is taken for it")
    func notAMonth() {
        #expect(MonthName.of(CrewsArt.key) == "")
        #expect(CrewsArt.aspect == 3 / 2)
    }

    @Test("both places the drawing stands use the one view, with the month's hold and a way to hide it")
    func oneViewWithTheHold() throws {
        let list = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewsListView.swift"))
        #expect(list.components(separatedBy: "CrewsArt(line: CrewLine.forWho").count - 1 == 2)
        #expect(!list.contains("Illustration(art:"), "a drawing on the Crews page that cannot be held")
        let art = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewsArt.swift"))
        for item in ["Button(\"Draw Your Own\", systemImage: \"pencil\")",
                     "Button(\"Use Original\", systemImage: \"arrow.uturn.backward\", role: .destructive)",
                     "Button(\"Hide Drawing\", systemImage: \"eye.slash\")",
                     "Button(\"Show Drawing\", systemImage: \"eye\")"] {
            #expect(art.contains(item), "\(item)")
        }
        // The one editor and the one store, not copies.
        #expect(art.contains("MonthDrawingEditor(month: which.id, monthName: Self.title,"))
        #expect(art.contains("MonthDrawingStore.shared.remove(Self.key)"))
        // Hidden, the words stay, and the hold is on them.
        #expect(art.contains("if hidden {\n            DrawingLine(text: line)"))
    }
}
