import Testing
import UIKit
@testable import Strata

/// **The owner's drawn icons** (2026-10-06, `Doodle`, `docs/icons/slice_icons.py`):
/// his hand where you draw and on the category chips, SF Symbols where you
/// navigate, and never the two side by side in one row.
@MainActor
@Suite("Drawn icons")
struct DoodleIconTests {
    @Test("every drawing is in the app as a template, cut for its canvas")
    func assets() throws {
        for doodle in Doodle.allCases {
            let image = try #require(UIImage(named: doodle.rawValue), "\(doodle.rawValue) is missing")
            // A template, or `.foregroundStyle` cannot tint it white on a
            // chip or light on the dark page.
            #expect(image.renderingMode == .alwaysTemplate, "\(doodle.rawValue) is not a template")
            #expect(image.size == CGSize(width: doodle.canvas, height: doodle.canvas),
                    "\(doodle.rawValue) is \(image.size), cut for \(doodle.canvas)")
        }
    }

    @Test("every category you can pick has his drawing")
    func categories() {
        for category in HabitCategory.selectable {
            #expect(category.doodle?.isCategory == true, "\(category) has no drawn glyph")
        }
        #expect(HabitCategory.unlabeled.doodle == nil)
    }

    /// The ink row is all his or no glyph (the pen's dot); a symbol beside a
    /// drawing in one row reads as a mistake.
    @Test("the ink row draws his eraser, undo and sticker, and no symbol beside them")
    func inkRow() throws {
        let canvas = SourceSweep.code(try SourceSweep.read("Strata/Views/Ink/InkCanvas.swift"))
        let controls = try #require(canvas.components(separatedBy: "struct InkControls").dropFirst().first)
        let row = controls.components(separatedBy: "struct InkSurface").first ?? controls
        #expect(row.contains("GlassIconButton(drawn: controller.erasing ? .eraserOn : .eraser"))
        #expect(row.contains("GlassIconButton(drawn: .undo"))
        #expect(row.contains("GlassIconButton(drawn: .sticker"))
        // The only symbol left is the pen's dot, which is not a glyph.
        let symbols = row.components(separatedBy: "systemName: \"").dropFirst().map { $0.prefix { $0 != "\"" } }
        #expect(symbols == ["circle.fill"], "a symbol joined the drawn row: \(symbols)")
    }

    /// "the words say it": Settings and Profile rows carry no glyph.
    @Test("Settings and Profile rows have no decorative glyph")
    func noRowGlyphs() throws {
        for path in ["Strata/Views/SettingsView.swift", "Strata/Views/ProfileView.swift",
                     "Strata/Views/Ink/MonthDrawingSettings.swift"] {
            let code = SourceSweep.code(try SourceSweep.read(path))
            let uses = code.components(separatedBy: "SettingsIcon(").count - 1
            // SettingsView declares the type once; that is not a use.
            #expect(uses == 0, "\(path) puts \(uses) glyphs back on its rows")
        }
    }
}
