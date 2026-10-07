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

    /// **Tools are Apple's, what is yours is drawn** (the owner, 2026-10-07:
    /// custom icons "make sense for the category and emoji picker, doesn't
    /// make as much sense for the eraser"). In the ink row the eraser and undo
    /// are symbols and the sticker button is his drawing. This first asserted
    /// all three were drawn; turned round with his rule, not deleted.
    @Test("the ink row: Apple's eraser and undo, his sticker")
    func inkRow() throws {
        let canvas = SourceSweep.code(try SourceSweep.read("Strata/Views/Ink/InkCanvas.swift"))
        let controls = try #require(canvas.components(separatedBy: "struct InkControls").dropFirst().first)
        let row = controls.components(separatedBy: "struct InkSurface").first ?? controls
        #expect(row.contains("GlassIconButton(systemName: controller.erasing ? \"eraser.fill\" : \"eraser\""))
        #expect(row.contains("GlassIconButton(systemName: \"arrow.uturn.backward\""))
        #expect(row.contains("GlassIconButton(drawn: .sticker"))
        #expect(!row.contains("drawn: .eraser") && !row.contains("drawn: .undo"))
    }

    /// **Settings and Profile rows keep their glyphs** (the owner,
    /// 2026-10-07: "the settings should have icons, idk where they went").
    /// They came off for a night under "less is so much more"; he wants them.
    /// This used to assert the opposite, and is turned round rather than
    /// deleted, so taking them off again has to be a decision, not a sweep.
    @Test("Settings and Profile rows have their glyphs")
    func rowGlyphs() throws {
        for (path, least) in [("Strata/Views/SettingsView.swift", 15), ("Strata/Views/ProfileView.swift", 5),
                              ("Strata/Views/Ink/MonthDrawingSettings.swift", 1)] {
            let code = SourceSweep.code(try SourceSweep.read(path))
            let uses = code.components(separatedBy: "SettingsIcon(").count - 1
            #expect(uses >= least, "\(path) has \(uses) row glyphs, expected at least \(least)")
        }
    }
}
