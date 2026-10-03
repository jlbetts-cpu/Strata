import Foundation
import Testing
@testable import Strata

/// **The 2026-10-02 design review of the Memories side, pinned.**
///
/// `docs/design-review/` is the report (memories, map, viewer, profile,
/// settings, restore, head maker, head picker, onboarding, store); this is the
/// part of it that can come back. Each check carries an injection proving the
/// matcher would have caught the thing it is for.
@Suite("Design review, Memories side, 2026-10-02")
struct DesignReviewMemoriesSideTests {

    /// Every file of the Memories side that sets words a person reads.
    static let screens = [
        "Strata/Views/MemoriesView.swift",
        "Strata/Views/MemoriesMapView.swift",
        "Strata/Views/MonthCalendarView.swift",
        "Strata/Views/DayAlbumDetailView.swift",
        "Strata/Views/PhotoCollectionView.swift",
        "Strata/Views/PhotoViewer.swift",
        "Strata/Views/ProfileView.swift",
        "Strata/Views/SettingsView.swift",
        "Strata/Views/RestoreBackupView.swift",
        "Strata/Views/PrivacyPolicyView.swift",
        "Strata/Views/HeadMakerView.swift",
        "Strata/Views/HeadPickerRow.swift",
        "Strata/Views/OnboardingView.swift",
        "Strata/Views/StoreUnavailableView.swift",
    ]

    // MARK: - The app is called Sturdy

    /// `docs/brand.md`, "The name is Sturdy" (2026-09-30). The home screen,
    /// the Settings app and every permission prompt say Sturdy; twenty-one
    /// sentences on these screens said Strata, including two instructions that
    /// send somebody to the Settings app to find an entry under a name that is
    /// not there. A word inside a string literal, so `StrataFont`, an asset
    /// name or a launch argument cannot trip it.
    static func oldName(in code: String) -> [String] {
        code.split(separator: "\n").map(String.init)
            .filter { !SourceSweep.isComment($0) }
            .flatMap { SourceSweep.literals(in: $0) }
            .filter { $0.range(of: #"\bStrata\b"#, options: .regularExpression) != nil }
    }

    @Test("no sentence on the Memories side calls the app Strata")
    func noOldName() throws {
        for path in Self.screens {
            let found = Self.oldName(in: SourceSweep.code(try SourceSweep.read(path)))
            #expect(found.isEmpty, "\(path) still says Strata: \(found)")
        }
    }

    @Test("the old-name sweep catches what it is for")
    func oldNameSweepCatches() {
        let sentence = #"                    Text("Location is off for Strata in the Settings app.")"#
        let asset = #"            Image("StrataSMark")"#
        let flag = #"        argument("-strataOpenPhoto")"#
        #expect(Self.oldName(in: sentence).count == 1)
        #expect(Self.oldName(in: asset).isEmpty, "an asset name is not a sentence")
        #expect(Self.oldName(in: flag).isEmpty, "a launch argument is not a sentence")
    }

    // MARK: - Text is never written in the glyph ink

    /// The same systemic finding the Wins side made: `inkQuiet` is for glyphs
    /// and measured **3.32 to 3.35:1** as text here (Settings' version plate,
    /// Profile's name placeholder, the head maker's suggested name, the
    /// privacy policy's date). Uses the Wins side's matcher, so the two halves
    /// of the app are held to one definition.
    @Test("no text on the Memories side is set in inkQuiet")
    func noTextInQuietInk() throws {
        for path in Self.screens {
            let found = DesignReviewWinsSideTests.textInQuietInk(
                SourceSweep.code(try SourceSweep.read(path)))
            #expect(found.isEmpty, "\(path) writes text in inkQuiet: \(found)")
        }
    }

    // MARK: - Form footers are on the ladder

    /// A bare `Text` in a grouped Form's footer is `.footnote` in `.secondary`:
    /// 13pt at 3.36:1 measured. Every footer `Text` on Settings and Profile goes
    /// through `.formFooter()`. Counted, not parsed: the number of footer
    /// sentences that do not wear it must be zero.
    static func bareFooters(in code: String) -> Int {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var bare = 0
        var inFooter = false
        var depth = 0
        for (i, line) in lines.enumerated() {
            // The opening line is `} footer: {`: its braces cancel, so the
            // block's own depth starts at one.
            if line.contains("footer: {") { inFooter = true; depth = 1; continue }
            guard inFooter else { continue }
            depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            if line.contains("Text(") && !line.contains("Button") {
                let next = lines[(i + 1)..<min(lines.count, i + 3)]
                if !next.contains(where: { $0.contains(".formFooter()") }) { bare += 1 }
            }
            if depth <= 0 { inFooter = false }
        }
        return bare
    }

    @Test("every Form footer on Settings and Profile is on the type ladder")
    func footersOnTheLadder() throws {
        for path in ["Strata/Views/SettingsView.swift", "Strata/Views/ProfileView.swift"] {
            let code = SourceSweep.code(try SourceSweep.read(path))
            #expect(Self.bareFooters(in: code) == 0, "\(path) has a footer at the system's 13pt")
        }
    }

    @Test("the footer sweep catches what it is for")
    func footerSweepCatches() {
        let bare = """
                    } footer: {
                        Text("Log a win to start one.")
                    }
        """
        let styled = """
                    } footer: {
                        Text("Log a win to start one.")
                            .formFooter()
                    }
        """
        #expect(Self.bareFooters(in: bare) == 1)
        #expect(Self.bareFooters(in: styled) == 0)
    }

    // MARK: - A blank poster is asked for again

    /// The replay row settled as an empty well because a nil render was left
    /// "for the next reload", and this page has none. The pass now asks again.
    @Test("an empty poster render is retried inside the pass")
    func emptyPosterIsRetried() throws {
        #expect(ReplayShelfModel.emptyRenderRetries > 0)
        let page = SourceSweep.code(try SourceSweep.read("Strata/Views/MemoriesView.swift"))
        // The recap ROW is gone (2026-10-03: a play button in the top row
        // replaced it), so there is no row poster to check; what still holds
        // is that nothing reads the poster dictionary inside a closure.
        #expect(!page.contains("poster: replays.cards["))
    }

    /// The blank row the review actually found: the thumbnail cropped the
    /// poster's middle, and a short period's tower stands below it. Anchored
    /// to the base line, any tower shows.
    @Test("the replay thumbnail is cropped from the tower's base")
    func thumbnailCropsFromTheBase() throws {
        let row = SourceSweep.code(try SourceSweep.read("Strata/Views/ReplayRow.swift"))
        #expect(row.contains(".frame(width: width, height: Self.height, alignment: .bottom)"))
    }
}
