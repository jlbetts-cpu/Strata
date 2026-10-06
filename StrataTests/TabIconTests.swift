import Testing
import UIKit
@testable import Strata

/// **The tab bar's icons are the owner's drawings** (2026-10-06, "You draw
/// them", after Luma): filled in both states, template images the bar tints.
@MainActor
@Suite("Tab icons")
struct TabIconTests {
    @Test("each tab's drawing is in the app, as a template, at the bar's size")
    func drawnIcons() throws {
        for name in ["TabWins", "TabCamera", "TabMemories"] {
            let image = try #require(UIImage(named: name), "\(name) is missing")
            // The bar tints a template; a plain image would draw his black
            // on the dark bar and never show which tab is on.
            #expect(image.renderingMode == .alwaysTemplate, "\(name) is not a template")
            #expect(image.size == CGSize(width: 28, height: 28), "\(name) is \(image.size)")
        }
    }

    /// The ring that showed round every icon (the owner: "a weird outline
    /// around them") was the drawn edge's light gap, kept as a faint band.
    /// Clean now: from the edge of the shape inward there is no dip.
    @Test("no faint ring round the edge of an icon")
    func noRing() throws {
        let cg = try #require(UIImage(named: "TabWins")?.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let context = try #require(CGContext(data: &bytes, width: cg.width, height: cg.height, bitsPerComponent: 8,
                                             bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        // Along the middle row, from the left: once the shape is reached it
        // stays solid until well inside (the smile is lower down).
        let y = cg.height / 2
        let alpha = (0..<cg.width).map { bytes[(y * cg.width + $0) * 4 + 3] }
        let first = try #require(alpha.firstIndex { $0 > 200 })
        #expect(alpha[first..<(first + cg.width / 6)].allSatisfy { $0 > 200 }, "a band runs round the edge: \(alpha)")
    }

    @Test("the tab bar asks for his drawings, not SF Symbols")
    func barUsesThem() throws {
        let source = SourceSweep.code(try SourceSweep.read("Strata/Views/TabBarView.swift"))
        #expect(source.contains("Image(\"TabWins\")"))
        #expect(!source.contains("systemName: selected ? \"house.fill\""))
    }
}
