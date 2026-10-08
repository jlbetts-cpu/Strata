import Testing
import Foundation
import SwiftUI
@testable import Strata

/// **Rough edges + accessibility** (the owner's scope, 2026-10-06): the six
/// fixes from the quality-of-life review, each pinned where it lives. Most of
/// them are UI behaviour that no unit test can drive, so most of these read
/// the source; each was checked to fail with its fix reverted.
@Suite("Rough edges and accessibility, 2026-10-06")
@MainActor
struct RoughEdgesTests {
    private func code(_ path: String) throws -> String {
        SourceSweep.code(try SourceSweep.read(path))
    }

    private func body(of marker: String, until end: String, in source: String) throws -> String {
        let start = try #require(source.components(separatedBy: marker).dropFirst().first, "\(marker) is gone")
        return start.components(separatedBy: end).first ?? start
    }

    // MARK: 1. A swipe does not throw a win away

    @Test("Add a win holds a swipe while it has unsaved edits, and Cancel asks first")
    func addSheetGuardsEdits() throws {
        let sheet = try code("Strata/Views/AddWinSheet.swift")
        #expect(sheet.contains(".interactiveDismissDisabled(hasUnsavedEdits || isSaving)"),
                "a swipe down closes the sheet over a typed name or a photo again")
        let cancel = try body(of: "private var cancelButton: some View {", until: "} label: {", in: sheet)
        #expect(cancel.contains("if hasUnsavedEdits {") && cancel.contains("confirmingDiscard = true"),
                "Cancel throws the edits away without asking")
        #expect(sheet.contains("\"Discard this win?\""))
        #expect(sheet.contains("Button(\"Discard\", role: .destructive) { dismiss() }"))
        #expect(sheet.contains("Button(\"Keep Editing\", role: .cancel)"))
        // A camera shot handed in sets `photoChanged` in `load`, so it counts.
        let dirty = try body(of: "private var hasUnsavedEdits: Bool {", until: "var body: some View", in: sheet)
        #expect(dirty.contains("photoChanged"), "a photograph from the camera no longer counts as an edit")
        #expect(dirty.contains("failure?.winIsSaved != true"), "Done after a saved win would ask about nothing")
        // The baseline is taken LAST in `load`, after the colour default, or
        // a fresh sheet would count its own default colour as an edit.
        let load = try body(of: "private func load() {", until: "private func save() async {", in: sheet)
        let baseline = try #require(load.range(of: "opening = asItStands"), "the opening baseline is gone")
        let colour = try #require(load.range(of: "QuickWinService.spontaneousCategory"))
        #expect(colour.upperBound < baseline.lowerBound, "the baseline is taken before the sheet's own defaults")
    }

    // MARK: 2. A win with no photo opens from its day

    @Test("a photo-less block on a day's page opens the add sheet in edit mode")
    func dayPageOpensEveryWin() throws {
        let day = try code("Strata/Views/DayAlbumDetailView.swift")
        #expect(!day.contains("canTapBlock: { $0.look.imageFileName != nil },"),
                "only photographed blocks take a tap again")
        #expect(day.contains("canTapBlock: { $0.look.imageFileName != nil || $0.log?.habit != nil }"))
        #expect(day.contains("editingLog = block.log"))
        let sheet = try body(of: ".sheet(item: $editingLog) { log in", until: "private struct PhotoID", in: day)
        #expect(sheet.contains("editing: log.habit"))
        #expect(sheet.contains("onSaved: { _ in reload() }"), "the page does not reload after a save")
        #expect(sheet.contains("onDeleted: { reload() }"), "the page does not reload after a delete")
    }

    // MARK: 3. Crew drafts survive until they are sent

    @Test("a chat draft is kept per crew and cleared only by the send that carried it")
    func chatDrafts() {
        let a = CrewID(rawValue: "crew-test-a-\(UUID().uuidString)")
        let b = CrewID(rawValue: "crew-test-b-\(UUID().uuidString)")
        CrewDrafts.keepChat("half a thought", for: a)
        #expect(CrewDrafts.chat(a) == "half a thought")
        #expect(CrewDrafts.chat(b) == "", "one crew's words leaked into another's")
        // Typed more while the send was in flight: the new words stay.
        CrewDrafts.keepChat("half a thought, and more", for: a)
        CrewDrafts.clearChat(a, ifStill: "half a thought")
        #expect(CrewDrafts.chat(a) == "half a thought, and more")
        CrewDrafts.clearChat(a, ifStill: "half a thought, and more")
        #expect(CrewDrafts.chat(a) == "")
    }

    @Test("a reply draft is kept per win")
    func replyDrafts() {
        let crew = CrewID(rawValue: "crew-test-r-\(UUID().uuidString)")
        let one = UUID(), two = UUID()
        CrewDrafts.keepReply("so proud", for: crew, to: one)
        #expect(CrewDrafts.reply(crew, to: one) == "so proud")
        #expect(CrewDrafts.reply(crew, to: two) == "")
        CrewDrafts.clearReply(crew, to: one, ifStill: "so proud")
        #expect(CrewDrafts.reply(crew, to: one) == "")
    }

    @Test("the chat and Reply read and write the kept draft, and clear it only on a send that went")
    func draftsAreWired() throws {
        let chat = try code("Strata/Views/Crews/CrewChatSheet.swift")
        #expect(chat.contains("_draft = State(initialValue: CrewDrafts.chat(crewID))"),
                "the chat opens on an empty field again")
        #expect(chat.contains("TextField(\"Message\", text: draftField"))
        let send = try body(of: "private func send() {", until: "// MARK: - Report and Block", in: chat)
        // A `switch` since the send throttle (2026-10-08) added `.throttled`;
        // the draft is still cleared only on `.sent`.
        #expect(send.contains("case .sent:\n                CrewDrafts.clearChat(crewID, ifStill: text)"))
        #expect(!send.contains("CrewDrafts.keepChat(\"\""), "send wipes the kept draft before it knows")
        let panel = try code("Strata/Views/Crews/CrewReactions.swift")
        #expect(!panel.contains("draft = \"\"\n                            replying = true"),
                "Reply opens on an empty field again")
        #expect(panel.contains("draft = CrewDrafts.reply(crewID, to: winID)"))
        #expect(panel.contains("if outcome == .sent { CrewDrafts.clearReply(crewID, to: winID, ifStill: text) }"))
    }

    // MARK: 4. The camera asks who sees it once

    @Test("the camera review has no crew picker; Add a win is the one place")
    func oneCrewQuestion() throws {
        let camera = try code("Strata/Views/CameraView.swift")
        #expect(!camera.contains("CrewPicker("), "the camera asks which crews again")
        #expect(!camera.contains("var crews:"))
        let sheet = try code("Strata/Views/AddWinSheet.swift")
        #expect(sheet.contains("CrewPicker(selection:"), "the sheet's own crew row is gone, so nothing asks")
        // The sticky choice the camera's row used to save is what the sheet
        // opens on for a new win, and saves with it.
        #expect(sheet.contains("?? initialCrews ?? CrewChoice.load()"))
        #expect(sheet.contains("if initialCrews == nil { CrewChoice.save(crewChoice) }"))
    }

    // MARK: 5. One success per win

    @Test("only Add plays the success: not the capture, Use Photo or a plan tick")
    func oneSuccessPerWin() throws {
        let camera = try code("Strata/Views/CameraView.swift")
        #expect(!camera.contains("HapticsEngine.success()"), "the camera plays a success before the win exists")
        let beforeUse = try #require(camera.components(separatedBy: "Text(\"Use Photo\")").first)
        let use = beforeUse.components(separatedBy: "Button {").last ?? ""
        #expect(use.contains("HapticsEngine.lightTap()") && use.contains("keep(image)"),
                "Use Photo lost its tap, or this test is reading the wrong button")
        let lines = try code("Strata/Views/PlanLines.swift")
        let complete = try body(of: "private func complete(_ item: PlanItem) {", until: "onComplete(item)", in: lines)
        #expect(!complete.contains("HapticsEngine.success()"), "a plan tick plays the success before Add does")
        let sheet = try code("Strata/Views/AddWinSheet.swift")
        let finish = try body(of: "private func finish(_ habit: Habit) {", until: "private func fail(", in: sheet)
        #expect(finish.contains("HapticsEngine.success()"), "the save lost the one success it keeps")
    }

    // MARK: 6a. Large type shrinks to the floor, never under it

    @Test("LargeTypeFit never sets a line under 15pt, and does nothing at the default size of a 15pt line")
    func largeTypeFloor() {
        #expect(LargeTypeFit.factor(reached: 15) == 1)
        #expect(abs(LargeTypeFit.factor(reached: 17) - 15.0 / 17.0) < 0.0001)
        for reached in stride(from: 15.0, through: 80.0, by: 0.5) {
            #expect(reached * LargeTypeFit.factor(reached: reached) >= 15 - 0.0001)
        }
        #expect(LargeTypeFit.factor(reached: 10) == 1, "a style already under the floor is shrunk further")
        #expect(LargeTypeFit.defaultSize(of: .subheadline) == 15)
        #expect(LargeTypeFit.defaultSize(of: .body) == 17)
    }

    @Test("the viewer's title and caption, and the crew lines, fit at large type")
    func truncatingLinesFit() throws {
        let viewer = try code("Strata/Views/PhotoViewer.swift")
        let header = try body(of: "private var header: some View {", until: "HStack {", in: viewer)
        #expect(header.contains(".fitsLargeType(.body)"), "the viewer's title truncates at large type again")
        #expect(viewer.contains(".lineLimit(1)\n            .fitsLargeType(.subheadline)"),
                "the viewer's caption truncates at large type again")
        for (path, count) in [("Strata/Views/Crews/CrewChatSheet.swift", 3),
                              ("Strata/Views/Crews/CrewReactions.swift", 2),
                              ("Strata/Views/Crews/CrewsListView.swift", 1),
                              ("Strata/Views/Crews/CrewTowerView.swift", 1)] {
            let source = try code(path)
            #expect(source.components(separatedBy: ".fitsLargeType(").count - 1 == count, "\(path)")
        }
        #expect(!(try code("Strata/Views/Crews/CrewTowerView.swift")).contains(".minimumScaleFactor(0.85)"),
                "the crew name can shrink under 15pt at the default size again")
    }

    // MARK: 6b. Icon-only buttons are named

    /// Icon-only `Button`s (a glyph and no `Text` or `Label` in what they
    /// draw) with no `accessibilityLabel` on them or in the dozen lines after.
    /// The same rule the 2026-10-06 sweep ran over the main screens, kept so
    /// the next glyph button cannot ship nameless.
    static func unnamedIconButtons(_ source: String) -> [Int] {
        let lines = source.components(separatedBy: "\n")
        var out: [Int] = []
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !SourceSweep.isComment(line),
                  line.range(of: #"\bButton\s*[\(\{]"#, options: .regularExpression) != nil else { i += 1; continue }
            var depth = 0, j = i, started = false
            var drawn: [String] = []
            while j < lines.count, j < i + 60 {
                let t = lines[j]
                if !SourceSweep.isComment(t) {
                    drawn.append(t)
                    for ch in t {
                        if ch == "{" || ch == "(" { depth += 1; started = true }
                        if ch == "}" || ch == ")" { depth -= 1 }
                    }
                    if started, depth <= 0 { break }
                }
                j += 1
            }
            let text = drawn.joined(separator: "\n")
            // A glyph: an SF Symbol or an asset. Not `InkImage` (a drawing
            // that is the content) and not `Image(uiImage:)` (a photograph).
            let glyph = text.range(of: #"(?<![A-Za-z])Image\((systemName:|")"#, options: .regularExpression) != nil
            if glyph, !text.contains("Text("), !text.contains("Label("),
               !text.contains("accessibilityLabel") {
                let after = lines[min(j, lines.count)..<min(j + 12, lines.count)].joined(separator: "\n")
                let untilNext = after.components(separatedBy: "Button").first ?? after
                if !untilNext.contains("accessibilityLabel") { out.append(i + 1) }
            }
            i += 1
        }
        return out
    }

    @Test("every icon-only button on the main screens has a name")
    func iconButtonsNamed() throws {
        let screens = ["Strata/Views/MainAppView.swift", "Strata/Views/DaySheet.swift",
                       "Strata/Views/PlanLines.swift", "Strata/Views/AddWinSheet.swift",
                       "Strata/Views/MemoriesView.swift", "Strata/Views/DayAlbumDetailView.swift",
                       "Strata/Views/PhotoViewer.swift", "Strata/Views/Crews/CrewsListView.swift",
                       "Strata/Views/Crews/CrewTowerView.swift", "Strata/Views/Crews/CrewChatSheet.swift",
                       "Strata/Views/Crews/CrewReactions.swift", "Strata/Views/Crews/FirstWinInviteCard.swift",
                       "Strata/Views/Crews/ChatReactions.swift"]
        for path in screens {
            let unnamed = Self.unnamedIconButtons(try SourceSweep.read(path))
            #expect(unnamed.isEmpty, "\(path): icon-only buttons with no accessibilityLabel at lines \(unnamed)")
        }
    }

    @Test("the icon-button sweep catches a nameless glyph")
    func iconSweepCanFail() {
        let nameless = """
            Button { close() } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.press)
            """
        #expect(Self.unnamedIconButtons(nameless) == [1])
        #expect(Self.unnamedIconButtons(nameless + "\n.accessibilityLabel(\"Close\")").isEmpty)
    }
}
