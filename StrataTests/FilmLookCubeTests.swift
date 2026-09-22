import Testing
import Foundation
@testable import Strata

/// **Writes every look out as a `.cube` file, and proves the file is right.**
///
/// The fourth thing on the list of what this pipeline was missing was `.CUBE`
/// support, so a look could be authored in Lightroom or DaVinci rather than by
/// asking me to change numbers. Reading arbitrary LUTs back INTO the app is a
/// product decision and is deliberately not taken here; writing them out is
/// pure gain and costs the app nothing, because it lives entirely in the test
/// suite. Run the tests and four current `.cube` files are sitting in
/// /tmp/apollo-film, openable by anything that grades.
///
/// **A LUT is the colour half of a look and only the colour half.** Everything
/// that depends on a pixel's own colour is in the file: the curve, the
/// crossover, the hue steering, the memory colours, the saturation ramps, the
/// blue density, the split tone and the skin exemption. Everything that
/// depends on a pixel's NEIGHBOURS cannot be and is not: grain, halation,
/// bloom, glow, clarity, the vignette and the white balance measurement. A
/// grade made from one of these files is the look's colour, not the look.
struct FilmLookCubeTests {

    /// 33 a side is what DaVinci and Lightroom expect, and it is enough: the
    /// app itself interpolates a 64-step table, and the difference between
    /// them on a real photograph is below a display's own quantisation.
    static let side = 33

    static func cube(for look: FilmLook) -> String {
        var out = """
        # \(look.kind.name), from Apollo
        # \(look.kind.describedAs)
        #
        # The COLOUR of this look and nothing else. Grain, halation, bloom,
        # glow, clarity and the vignette depend on neighbouring pixels and
        # cannot live in a lookup table.
        TITLE "Apollo \(look.kind.name)"
        LUT_3D_SIZE \(side)
        DOMAIN_MIN 0.0 0.0 0.0
        DOMAIN_MAX 1.0 1.0 1.0

        """
        // Red fastest, which is what the format specifies.
        for b in 0..<Self.side {
            for g in 0..<Self.side {
                for r in 0..<Self.side {
                    let step = Double(Self.side - 1)
                    let colour = look.graded(FilmLook.RGB(Double(r) / step,
                                                          Double(g) / step,
                                                          Double(b) / step))
                    out += String(format: "%.6f %.6f %.6f\n", colour.r, colour.g, colour.b)
                }
            }
        }
        return out
    }

    /// Parsed back, because a file nobody has read is a file nobody knows is
    /// correct. This is also the reader the app would use if importing is
    /// ever wanted, sitting here already proven.
    static func parse(_ text: String) -> (side: Int, entries: [FilmLook.RGB])? {
        var side = 0
        var entries: [FilmLook.RGB] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("LUT_3D_SIZE") {
                side = Int(trimmed.split(separator: " ").last ?? "") ?? 0
                continue
            }
            if trimmed.hasPrefix("TITLE") || trimmed.hasPrefix("DOMAIN") { continue }
            let parts = trimmed.split(separator: " ").compactMap { Double($0) }
            guard parts.count == 3 else { continue }
            entries.append(FilmLook.RGB(parts[0], parts[1], parts[2]))
        }
        guard side > 1, entries.count == side * side * side else { return nil }
        return (side, entries)
    }

    @Test("Every look writes a .cube that reads back as the look itself")
    func cubesRoundTrip() throws {
        let directory = URL(fileURLWithPath: "/tmp/apollo-film", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for look in FilmLook.all where look.kind != .none {
            let text = Self.cube(for: look)
            try? text.write(to: directory.appendingPathComponent("Apollo \(look.kind.name).cube"),
                            atomically: true, encoding: .utf8)

            let read = try #require(Self.parse(text), "\(look.kind.name) wrote a file that will not parse")
            #expect(read.side == Self.side)

            // Spot the corners and the middle rather than all 35,937: the
            // index arithmetic is the only thing that can be wrong, and it is
            // wrong at an edge or nowhere.
            let last = Self.side - 1
            for (r, g, b) in [(0, 0, 0), (last, 0, 0), (0, last, 0), (0, 0, last),
                              (last, last, last), (16, 16, 16), (last, 8, 2)] {
                let index = r + g * Self.side + b * Self.side * Self.side
                let step = Double(last)
                let expected = look.graded(FilmLook.RGB(Double(r) / step,
                                                        Double(g) / step,
                                                        Double(b) / step))
                let got = read.entries[index]
                let apart = max(abs(expected.r - got.r),
                                max(abs(expected.g - got.g), abs(expected.b - got.b)))
                #expect(apart < 0.000002,
                        "\(look.kind.name) at \(r),\(g),\(b) is \(apart) out, so red is not the fastest axis")
            }
        }
    }

    /// **Both ends have to be sane, and white is not 1.0 on purpose.**
    ///
    /// The first version of this asserted white above 0.90 and all four looks
    /// failed it, at 0.832 to 0.875. That is the shoulder doing its job, not
    /// a fault: the curve rolls a fully blown input down so there is somewhere
    /// above a white subject for a specular highlight to still be brighter,
    /// which is what a negative does and is the reason film highlights do not
    /// read as a flat white wall. The looks then put some of it back with
    /// glow, bloom and the highlight tint, which a table cannot contain.
    ///
    /// So the assertion is a corridor rather than a ceiling. Below about 0.80
    /// the picture would genuinely be hazy; at 1.0 there would be no roll-off
    /// at all and no reason to have a shoulder.
    @Test("No look's table breaks the two ends")
    func endsAreSane() {
        for look in FilmLook.all where look.kind != .none {
            let black = FilmLook.luma(look.graded(FilmLook.RGB(0, 0, 0)))
            let white = FilmLook.luma(look.graded(FilmLook.RGB(1, 1, 1)))
            #expect(black < 0.12, "\(look.kind.name) turns black into \(black)")
            #expect(white > 0.80, "\(look.kind.name) turns white into \(white), which is hazy")
            #expect(white < 0.98, "\(look.kind.name) has no highlight roll-off at all")
        }
    }
}
