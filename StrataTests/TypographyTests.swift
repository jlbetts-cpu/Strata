import Testing
import SwiftUI
import UIKit
import Foundation
@testable import Strata

/// **The type system, stated as numbers.**
///
/// The owner, 2026-10-01: "no tiny thin font anywhere but like the settings or
/// other places", "the weight should be similar", "I like the text that is
/// there to feel like a medium weight and be consistent". Two of those are
/// arithmetic — a floor on size and a floor on weight — and this file is where
/// they stop being adjectives.
///
/// Three suites, because they can each fail for a different reason:
///
/// 1. **The tiers** — exactly three text styles, none under 15pt.
/// 2. **The tokens** — every `Font` `Typography` hands out is one of the three.
///    `SwiftUI.Font` is `Hashable`, so this is a real identity check and not a
///    description of one.
/// 3. **The call sites** — a sweep of the Swift sources, because a token system
///    proves nothing about a view that writes `.font(.system(size: 11))`. This
///    is the one that would have caught the state the app was in before the
///    pass, and it carries its exemptions by name.
@MainActor
struct TypographyTests {

    // MARK: - 1. The tiers

    /// **15 is the floor and it is measured off `UIFont`, not asserted.**
    ///
    /// A `Font` cannot be asked its size, but the text STYLE behind it can:
    /// `UIFont.preferredFont(forTextStyle:)` resolves against the content size
    /// category, and the tests run at the default (Large).
    ///
    /// This fails the moment somebody puts `.footnote` (13) or `.caption2` (11)
    /// back on `Typography.tierStyles`, which is the only way a new rung can
    /// enter the system.
    @Test func noTierIsBelowFifteenPoints() {
        for style in Typography.tierStyles {
            let points = UIFont.preferredFont(forTextStyle: style.uiKit).pointSize
            #expect(points >= 15, "\(style) resolves to \(points)pt, under the 15pt floor")
        }
    }

    /// Three tiers, and they are 34 / 17 / 15.
    ///
    /// `docs/screen-audit.md`'s check 4 is "three type tiers, no more", and it
    /// was a thing an auditor counted off a screenshot. It is a number here now.
    @Test func thereAreExactlyThreeTiers() {
        let sizes = Typography.tierStyles
            .map { UIFont.preferredFont(forTextStyle: $0.uiKit).pointSize }
            .sorted(by: >)
        #expect(sizes == [34, 17, 15], "the tiers resolve to \(sizes)")
        #expect(Set(sizes).count == 3, "two tiers resolve to the same size: \(sizes)")
    }

    /// **Two weights, one step apart, and no third.**
    ///
    /// It was one, Medium, until the evening of 2026-10-01: "the text reads as
    /// premium not dull a nice thicker font for headers." One weight answered
    /// "no tiny thin font anywhere" and overshot "the weight should be similar",
    /// because a page whose title, headings and body share a stem has nothing to
    /// look at first. Similar is not identical.
    ///
    /// Semibold over Medium is **14.5% more stroke** at a screen title's optical
    /// size (4.21pt against 3.68). Bold would be 34.4% and is not used: that is
    /// where a header stops being a header. Both levers are one line each and
    /// this test is where moving either gets written down.
    @Test func theTwoWeights() {
        #expect(Typography.titleWeight == .semibold)
        #expect(Typography.bodyWeight == .medium)
        #expect(Typography.titleWeight != Typography.bodyWeight,
                "a scale with one weight has no order to read it in")
    }

    // MARK: - 2. The tokens

    /// **Every token is one of the three tiers.** Nothing has a size of its own.
    ///
    /// `SwiftUI.Font` is `Hashable`, so `==` here compares the real resolved
    /// fonts. The drawn tokens go through `StrataFont.relative`, which returns
    /// `.system(style, weight: .medium)` since the drawn face came off on
    /// 2026-09-30, so they land on the tiers too — and this test is what will
    /// say so out loud if a custom face is dropped into one of the two and not
    /// the other.
    @Test func everyTokenResolvesToATier() {
        let heavy = Typography.titleWeight, light = Typography.bodyWeight
        let title = Font.system(.largeTitle, design: .default, weight: heavy)
        let header = Font.system(.body, design: .default, weight: heavy)
        let body = Font.system(.body, design: .default, weight: light)
        let label = Font.system(.subheadline, design: .default, weight: heavy)
        let quiet = Font.system(.subheadline, design: .default, weight: light)

        let tokens: [(String, Font, Font)] = [
            ("screenTitle", Typography.screenTitle, title),
            ("screenTitleDrawn", Typography.screenTitleDrawn, title),
            ("tally", Typography.tally, title),
            ("headerMedium", Typography.headerMedium, header),
            ("bodyLarge", Typography.bodyLarge, body),
            ("sheetTitleDrawn", Typography.sheetTitleDrawn, header),
            ("headerSmall", Typography.headerSmall, label),
            ("screenSubtitle", Typography.screenSubtitle, quiet),
            ("sectionLabel", Typography.sectionLabel, label),
        ]
        for (name, token, tier) in tokens {
            #expect(token == tier, "Typography.\(name) is not one of the three sizes at one of the two weights")
        }
        // **Three SIZES and two WEIGHTS is five fonts, not six**: there is no
        // large title at the body weight, because there is only one title.
        #expect(Set(tokens.map(\.1)).count == 5,
                "the tokens resolve to \(Set(tokens.map(\.1)).count) distinct fonts, not 5")
    }

    /// **A heading and the prose under it are the same SIZE and differ only in
    /// weight.** Everything that is a heading is one font; everything that is
    /// read rather than scanned is the other.
    ///
    /// Not a tautology dressed as a test. It is the pair of things the owner
    /// asked for on one day and they sound contradictory until they are written
    /// as numbers: "I hate when there is like one type of font next to another"
    /// (so: one family, one size per tier, nothing with a size of its own) and
    /// "a nice thicker font for headers" (so: the heading is heavier). This
    /// fails if anybody gives one of them a SIZE of its own, and it fails the
    /// other way if the two weights collapse back into one.
    @Test func headingsAreOneFontAndProseIsTheOther() {
        #expect(Typography.headerMedium != Typography.bodyLarge,
                "a heading and a paragraph in the same weight have no order")
        #expect(Typography.headerSmall != Typography.screenSubtitle)
        #expect(Typography.headerSmall == Typography.sectionLabel,
                "a label and a small heading are the same job")
    }

    // MARK: - 3. The call sites

    /// **A token system proves nothing about a view that ignores it.**
    ///
    /// This reads the Swift sources and fails on any type set below the floor:
    /// a `.footnote`, `.caption`, `.caption2` or `.system(size: n)` with n under
    /// 15, and any `weight:` lighter than `.medium` in a `.font(` call.
    ///
    /// **Icons are not type and are not counted.** `IconStyle.iconSize` and
    /// `GridConstants.icon*` size SF Symbols, which are a separate axis on a
    /// separate kind of object — a previous pass counted the symbols into the
    /// weight ladder, decided the app had five cuts, and was wrong. So lines
    /// that are plainly a symbol (`Image(systemName:)` a line or two above, or
    /// `relativeTo:`) are excluded, and only `.font(` is read.
    ///
    /// Every exemption is listed by file and line content with its reason. If
    /// one of them moves, this test fails and the next person reads the reason
    /// rather than rediscovering it.
    @Test func noSourceSetsTypeBelowTheFloor() throws {
        let offenders = TypeSweep.offenders()
        #expect(offenders.isEmpty, "type below the floor:\n\(offenders.joined(separator: "\n"))")
    }

    /// The sweep has to be able to FAIL, so this re-injects the bug.
    ///
    /// `CLAUDE.md`'s rule for the portfolio's gates applies here too: an
    /// injection that cannot fail is worse than none. One of the strings below
    /// is exactly what `BlockContent` used to say.
    @Test func theSweepCatchesWhatItIsFor() {
        let bad = [
            "                    .font(Typography.bodySmall.weight(.medium))",
            "                .font(.system(size: 11, weight: .medium))",
            "                .font(Font.system(.caption2, design: .default))",
            "                .font(.system(.footnote, design: .default))",
            "                .font(.system(size: 17, weight: .regular))",
            "                .font(.system(size: 14.5, weight: .medium))",
            "                .font(Typography.numeral(10))",
            "                .font(StrataFont.size(12))",
        ]
        for line in bad {
            #expect(TypeSweep.faults(in: line) != nil,
                    "the sweep let this through: \(line)")
        }
        let good = [
            "                .font(Typography.headerSmall)",
            "                .font(.system(size: 21, weight: .regular))  // symbol",
            "                .font(.system(.subheadline, design: .default, weight: .medium))",
            "                .font(Typography.numeral(96))",
            "                .font(Typography.numeral(cell * 0.16))",
            "                .font(StrataFont.size(30))",
        ]
        for line in good {
            // The symbol line is only "good" because of the exemption list; the
            // raw rule does flag it, which is what `offenders()` filters.
            if line.contains("symbol") { continue }
            #expect(TypeSweep.faults(in: line) == nil,
                    "the sweep flagged something legitimate: \(line)")
        }
    }
}

// MARK: - The sweep

/// Reads the app's own Swift sources. Kept out of the suite so the rule and
/// its exemptions are one readable thing.
enum TypeSweep {

    /// Everything below 15 at the default content size category.
    private static let smallStyles = ["caption2", "caption", "footnote"]

    /// Lines that are allowed to break the rule, each with the reason, matched
    /// on a distinctive substring of the line itself so that moving the code
    /// does not silently widen the exemption.
    ///
    /// - `BlockContent`: a block's title is sized to the BLOCK. Measured at the
    ///   86.5pt cell: 4 of 14 ordinary titles truncate at 13 and 8 at 15.
    /// - `MemoriesMapView`: the map's cluster badge. A DIGIT on an 18pt
    ///   capsule, solved against the 44pt block it sits on and deliberately
    ///   measured down to 16.7% of it on 2026-10-01. At 15 a two-digit badge
    ///   goes 24.3 to 27.1pt wide, 55% to 62% of the cell.
    /// - `MemoriesStill`: a drawing of the phone inside the onboarding device
    ///   frame, at UIKit's tab-bar metrics times a scale factor.
    /// - `CameraView` / `HeadMakerView` / `MonthReplayRow` / `CachedImageView` /
    ///   `GlassIconButton` / `PlanBullet` / `ProfileAvatar` / `IconStyle`: an SF
    ///   Symbol's point size, which is not type.
    private static let exempt: [(file: String, needle: String)] = [
        ("BlockContent.swift", ".font(.system(.footnote, design: .default, weight: .medium))"),
        ("MemoriesMapView.swift", ".font(Typography.numeral(13))"),
        ("MemoriesStill.swift", ".font(.system(size: 20 * s, weight: .regular))"),
        ("MemoriesStill.swift", ".font(.system(size: 11 * s, weight: .medium))"),
        ("CameraView.swift", ".font(.system(size: 21, weight: .regular))"),
        ("HeadMakerView.swift", ".font(.system(size: 21, weight: .regular))"),
        ("ReplayRow.swift", ".font(.system(size: 30))"),
        ("CachedImageView.swift", ".font(.system(size: min(width, height) * 0.25, weight: .medium))"),
        ("GlassIconButton.swift", ".font(.system(size: glyphSize, weight: .medium))"),
        ("PlanBullet.swift", ".font(.system(size: side * 0.52, weight: .medium))"),
        ("ProfileAvatar.swift", ".font(.system(size: side * 0.42, weight: .medium))"),
        ("IconStyle.swift", "content.font(.system(size: size, weight: weight, design: design))"),
        ("StrataMark.swift", ".font(.system(size: points, weight: Typography.titleWeight, design: .default))"),
    ]

    /// Why this line breaks the rule, or nil.
    static func faults(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(".font(") || trimmed.contains(".font(") else { return nil }
        guard !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///") else { return nil }

        for style in smallStyles where line.contains(".\(style),") || line.contains(".\(style))") {
            return "text style .\(style) is under 15pt"
        }
        if line.contains("Typography.bodySmall") || line.contains("Typography.caption2") {
            return "a deleted 13/11pt token"
        }
        for weight in [".regular", ".light", ".thin", ".ultraLight"] where line.contains("weight: \(weight)") {
            return "weight \(weight) is lighter than .medium"
        }
        // `.system(size: 12` and friends. A literal only — an expression is
        // geometry, which is exempt by nature and listed above anyway.
        //
        // The capture GROUP, not the whole match: reading the digits out of the
        // match with a `filter` picks up the dot in ".system" too, so "size: 15"
        // came back as 0.15 and every legitimate 15 failed the sweep while
        // "size: 14.5" parsed as nothing and passed it. Caught by the injection
        // test below, which is what it is for.
        if let n = literalSize(in: line), n < 15 {
            return "a literal \(n)pt"
        }
        // `Typography.numeral(13)` and `StrataFont.size(13)` are fixed sizes
        // too. They are geometry by design, but a LITERAL under the floor is
        // still a decision somebody made and it belongs in the exemption list
        // rather than outside the sweep.
        if let n = literalNumeral(in: line), n < 15 {
            return "a literal \(n)pt numeral"
        }
        return nil
    }

    private static let sizePattern = try? NSRegularExpression(
        pattern: #"\.system\(size:\s*([0-9]+(?:\.[0-9]+)?)\s*[,)]"#)

    private static let numeralPattern = try? NSRegularExpression(
        pattern: #"(?:Typography\.numeral|StrataFont\.size)\(\s*([0-9]+(?:\.[0-9]+)?)\s*\)"#)

    private static func literalNumeral(in line: String) -> Double? {
        guard let re = numeralPattern else { return nil }
        let ns = line as NSString
        guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        return Double(ns.substring(with: m.range(at: 1)))
    }

    private static func literalSize(in line: String) -> Double? {
        guard let re = sizePattern else { return nil }
        let ns = line as NSString
        guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        return Double(ns.substring(with: m.range(at: 1)))
    }

    /// Every offending line in the app's sources, as "file:line  reason".
    static func offenders() -> [String] {
        let root = repoRoot()
        var out: [String] = []
        for dir in ["Strata", "Shared", "StrataWidget"] {
            let base = root.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(atPath: base.path) else {
                out.append("\(dir): not readable at \(base.path) — the sweep found nothing to read")
                continue
            }
            for case let rel as String in walker where rel.hasSuffix(".swift") {
                let path = base.appendingPathComponent(rel)
                guard let text = try? String(contentsOf: path, encoding: .utf8) else { continue }
                let name = path.lastPathComponent
                for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    let line = String(line)
                    guard let reason = faults(in: line) else { continue }
                    if exempt.contains(where: { $0.file == name && line.contains($0.needle) }) { continue }
                    out.append("\(name):\(i + 1)  \(reason)  \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        return out
    }

    /// The checkout, from this file's own path. If the layout ever changes this
    /// resolves to a directory that does not exist, and `offenders()` reports
    /// that it could not read rather than returning an empty list — a sweep
    /// that silently finds nothing is the failure mode `CLAUDE.md` names.
    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)        // .../StrataTests/TypographyTests.swift
            .deletingLastPathComponent()       // .../StrataTests
            .deletingLastPathComponent()       // the checkout
    }
}

private extension Font.TextStyle {
    /// The UIKit twin, so a point size can be read off `UIFont`.
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}
