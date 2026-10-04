import Foundation
import Testing
@testable import Strata

/// The 2026-10-01 copy cuts that do not live on a screen, pinned so a line
/// deleted for a reason cannot quietly come back.
///
/// `docs/copy-audit.md` cuts 8, 17, 18 and 21, the em dash in `BackupArchive`
/// and the dead `currentConsistencyLabel`. None of these is reachable from a
/// unit test through the app's own API — four are inside view bodies, one is a
/// notification body built at schedule time and one is a deleted property — so
/// this reads the working tree, the way `TypographyTests.TypeSweep` already
/// does, and for the same reason it gives.
///
/// **Every suite here holds BOTH halves**, which is `docs/screen-audit.md`'s
/// rule for its own gates: a test that only checks that a line is gone would
/// also pass if somebody deleted the line that stays, so each cut is pinned
/// beside the thing on the same screen that still carries the fact.
@Suite("Copy cuts, 2026-10-01")
struct CopyCutsTests {

    // MARK: - The em dash

    /// CLAUDE.md, "Words the app says" (the owner, 2026-09-11): **no long dash
    /// in anything a person reads.** `docs/copy-audit.md` swept U+2014 and
    /// U+2013 over the whole app and found one, in `BackupArchive`, which had
    /// survived the Restore screen's own copy pass because it lives in a
    /// service file and not in a view. That is the lesson this test is: grep
    /// the strings, do not read the screens.
    @Test("no user-facing string holds a long dash")
    func noLongDashInAnyString() throws {
        let offenders = try SourceSweep.hits(matching: SourceSweep.longDash)
        #expect(offenders.isEmpty,
                "a long dash is in user-facing copy:\n\(offenders.joined(separator: "\n"))")
    }

    /// The sweep has to be able to FAIL. `CLAUDE.md`'s rule for the portfolio's
    /// gates applies here too: an injection that cannot fail is worse than
    /// none. The first line below is exactly what `BackupArchive` used to say.
    @Test("the dash sweep catches what it is for")
    func theDashSweepCatchesWhatItIsFor() {
        let bad = [
            #"                    "This backup is incomplete — it may not have finished downloading or copying.""#,
            #"        Text("9/7 – 9/13")"#,
            #"    static let note = "One thing — and only one.""#,
        ]
        for line in bad {
            #expect(SourceSweep.literals(in: line).contains(where: SourceSweep.longDash),
                    "the sweep let this through: \(line)")
        }
        let good = [
            #"                    "This backup is incomplete: it may not have finished downloading or copying.""#,
            #"        Text("9/7-9/13")"#,
            // A comment is not copy, and these files are full of prose.
            #"    /// The owner, 2026-09-23 — "the logo is really not necessary"."#,
            // A minus sign in arithmetic is not a dash in a sentence.
            #"        let width = box.width - GridConstants.horizontalPadding * 2"#,
        ]
        for line in good {
            #expect(!SourceSweep.literals(in: line).contains(where: SourceSweep.longDash),
                    "the sweep flagged something legitimate: \(line)")
        }
    }

    // MARK: - Cut 8: the mock tab bar is icon only

    /// `docs/copy-audit.md` cut 8. `MemoriesStill` drew an 11pt medium word
    /// under each tab glyph inside the onboarding device mock-up, and the real
    /// tab bar has no words on it: `MainAppView` builds each `Tab` from a bare
    /// `Image(systemName:)` and the three names exist only as
    /// `accessibilityLabel`. So the mock was teaching a chrome the app does not
    /// have, in the smallest type in the app.
    @Test("the onboarding tab bar mock draws glyphs and no words")
    func theMockTabBarIsIconOnly() throws {
        let still = try SourceSweep.read("Strata/Views/MemoriesStill.swift")
        #expect(!SourceSweep.code(still).contains("Text(tab.rawValue)"))
        // The other half: there is still a bar, and its glyphs still come from
        // the one place in the app that decides filled against hollow. Without
        // this, deleting the whole tab bar would pass the assertion above.
        // The still draws the bar's own glyphs, from the one function that
        // decides them (renamed `image(selected:)` when two of them became
        // drawn assets, 2026-10-03).
        #expect(SourceSweep.code(still).contains("tab.image(selected: on)"))
    }

    /// And the real bar it is a picture of still has no words, which is the
    /// fact the cut rests on. If the app's own tab bar ever grows labels, the
    /// mock is wrong again and this is the test that says so.
    @Test("the real tab bar has no words either")
    func theRealTabBarIsIconOnly() throws {
        let main = try SourceSweep.code(SourceSweep.read("Strata/Views/MainAppView.swift"))
        for name in ["Wins", "Camera", "Memories"] {
            // Each `Tab`'s label is a bare `Image(systemName:)` with the word
            // on `accessibilityLabel` and nowhere else. A `Text` carrying the
            // same word would be a drawn label and the mock would be right
            // again, so this is the assertion that has to hold for cut 8 to
            // stay true.
            #expect(main.contains("accessibilityLabel(\"\(name)\")"))
            #expect(!main.contains("Text(\"\(name)\")"))
        }
    }

    // MARK: - Cut 18: the Spotlight subtitle

    /// `docs/copy-audit.md` cut 18. "A win in Strata" was a third line under a
    /// Spotlight result whose title is the win's own name and whose subtitle is
    /// already its category.
    @Test("a Spotlight result carries no description that repeats its title")
    func spotlightHasNoContentDescription() throws {
        let entity = try SourceSweep.code(SourceSweep.read("Strata/Intents/HabitEntity.swift"))
        #expect(!entity.contains("contentDescription"))
        #expect(!entity.contains("A win in Strata"))
        // The other half: the result still has a name and the word that makes
        // it findable. A result with neither would pass the lines above.
        #expect(entity.contains("attrs.displayName = title"))
        #expect(entity.contains("attrs.keywords"))
    }

    // MARK: - The dead consistency label

    /// `Habit.currentConsistencyLabel` returned "Active" / "On a roll" / "On
    /// fire" / "Unstoppable" / "Legendary" and had no callers. Five escalating
    /// words for a number is a scoreboard, which `docs/brand.md` rejects.
    @Test("no scoreboard word is anywhere in the app")
    func theConsistencyLadderIsGone() throws {
        let habit = try SourceSweep.code(SourceSweep.read("Strata/Models/Habit.swift"))
        #expect(!habit.contains("currentConsistencyLabel"))
        for word in ["On a roll", "Unstoppable", "Legendary", "On fire"] {
            let hits = try SourceSweep.hits(matching: { $0.contains(word) })
            #expect(hits.isEmpty, "a scoreboard word is back:\n\(hits.joined(separator: "\n"))")
        }
        // The other half: the streak itself is real data and still computed.
        // Cutting `Streaks` would pass every assertion above. The app's answer
        // to "how am I doing" is a number and the tower, never an adjective.
        #expect(Streaks.longest(among: ["2026-09-01", "2026-09-02", "2026-09-03"]) == 3)
    }

    // MARK: - Cut 17: the notification bodies

    /// `docs/copy-audit.md` cut 17. The bodies described the feature their own
    /// titles announce. They are trimmed rather than deleted, and the reason is
    /// on `ReplayReminder.whereToLook`: there is no notification-response
    /// handler in the app, so a tap lands on the Wins tower with nothing on it
    /// saying where to look.
    @Test("a notification body does not describe the thing its title announces")
    func replayBodiesDoNotDescribeTheFeature() throws {
        let reminder = try SourceSweep.code(SourceSweep.read("Strata/Services/ReplayReminder.swift"))
        #expect(!reminder.contains("stacked into one tower"))
        // Both halves: the titles are the news and they stay.
        #expect(reminder.contains("Your week is ready"))
        #expect(reminder.contains("is ready"))
    }

    // MARK: - Cut 21: the walkthrough's two states and its captions

    /// `docs/copy-audit.md` cut 21, decided 2026-10-01. Page 2's title no
    /// longer swaps when a block is drawn, and page 3 has no subtitle. Page 4's
    /// stays, because it is the walkthrough's only permission prime.
    @Test("the walkthrough says each thing once")
    func onboardingCopyCuts() throws {
        let onboarding = try SourceSweep.code(SourceSweep.read("Strata/Views/OnboardingView.swift"))
        #expect(!onboarding.contains("That's how every win is made"))
        #expect(!onboarding.contains("Take it here and the picture becomes the block."))
        // The other half, and it is three separate facts:
        //  - page 2 still has its title, in one state now rather than two;
        //  - page 2's SUBTITLE still swaps, because the gesture is the one
        //    thing on these six pages a picture cannot teach;
        //  - page 4 still carries the sentence that earns the location prompt.
        #expect(onboarding.contains("Quick, regular or deep"))
        #expect(onboarding.contains("Hold the slot and pull."))
        #expect(onboarding.contains("Pull nothing and it's a quick one."))
        #expect(onboarding.contains("Your wins land on the map where you took them."))
        #expect(onboarding.contains("location.requestAccess()"))
    }
}

/// Reads the app's own source and reports lines, for the copy rules that cannot
/// be reached through an API.
///
/// **It fails loudly rather than finding nothing.** A sweep that silently reads
/// zero files passes every assertion written against it, which is the failure
/// mode `CLAUDE.md` names about instruments pointed at the wrong thing, so
/// every entry point here throws if the checkout does not look like one.
enum SourceSweep {

    /// The four source trees `docs/copy-audit.md` swept.
    static let trees = ["Strata", "Shared", "StrataWidget", "WidgetSupport"]

    /// **One file is exempt, and it is written down rather than assumed**
    /// (`docs/screen-audit.md`: an exemption is only an exemption when it is
    /// written down). `DebugHarness.swift` opens with `#if DEBUG` on line 1 and
    /// closes with `#endif` on its last, so not one byte of it is in a build
    /// anybody installs, and every string in it is a launch argument or an
    /// `NSLog` line read off a console. `docs/copy-audit.md` found the same
    /// thing and said so: sweeping U+2014 and U+2013 over the whole app
    /// returned the `BackupArchive` sentence, which is fixed, and this file's
    /// `[strata-bench]` log line, which is "not user-facing, no action".
    ///
    /// It is a FILE and not a pattern on purpose. Exempting "any line that
    /// looks like a log call" would quietly cover `os.Logger` calls in shipping
    /// code, and the rule this test is for is about what a person reads, not
    /// about where the dash is typed.
    static let exempt = ["Strata/Services/DebugHarness.swift"]

    /// U+2014 EM DASH and U+2013 EN DASH, the two the owner's rule names.
    static func longDash(_ text: String) -> Bool {
        text.contains("\u{2014}") || text.contains("\u{2013}")
    }

    /// Every file in the sweep, as `(path, text)`.
    static func sources() throws -> [(String, String)] {
        let root = repoRoot()
        var out: [(String, String)] = []
        for tree in trees {
            let dir = root.appendingPathComponent(tree)
            guard let walk = FileManager.default.enumerator(atPath: dir.path) else { continue }
            for case let name as String in walk where name.hasSuffix(".swift") {
                let path = "\(tree)/\(name)"
                guard !exempt.contains(path) else { continue }
                let url = dir.appendingPathComponent(name)
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    out.append((path, text))
                }
            }
        }
        // The guard. Measured on 2026-10-01 the four trees hold well over two
        // hundred Swift files; a handful means the layout moved.
        guard out.count > 100 else {
            throw SweepError.notACheckout("read \(out.count) files under \(root.path)")
        }
        return out
    }

    /// One file, by its path from the checkout root.
    static func read(_ path: String) throws -> String {
        let url = repoRoot().appendingPathComponent(path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw SweepError.notACheckout("could not read \(path)")
        }
        return text
    }

    /// The file with its comment lines taken out, so prose about a decision is
    /// never mistaken for the decision. These files carry long arguments in
    /// `///` and `//`, and several of them quote the owner.
    static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !isComment(String($0)) }
            .joined(separator: "\n")
    }

    static func isComment(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("//") || t.hasPrefix("*") || t.hasPrefix("/*")
    }

    /// The double-quoted runs on one line of code. Deliberately simple: it is
    /// looking for words a person reads, and an escaped quote inside a sentence
    /// only ever splits one literal into two, which cannot hide a dash.
    static func literals(in line: String) -> [String] {
        guard !isComment(line) else { return [] }
        var out: [String] = []
        var current: String?
        for ch in line {
            if ch == "\"" {
                if let open = current { out.append(open); current = nil } else { current = "" }
            } else if current != nil {
                current?.append(ch)
            }
        }
        return out
    }

    /// Every line of real code whose string literals match.
    static func hits(matching predicate: (String) -> Bool) throws -> [String] {
        var out: [String] = []
        for (path, text) in try sources() {
            for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(raw)
                if literals(in: line).contains(where: predicate) {
                    out.append("\(path):\(i + 1)  \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        return out
    }

    enum SweepError: Error { case notACheckout(String) }

    /// The checkout, from this file's own path, the way `TypeSweep` does it.
    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)   // .../StrataTests/CopyCutsTests.swift
            .deletingLastPathComponent()  // .../StrataTests
            .deletingLastPathComponent()  // the checkout
    }
}
