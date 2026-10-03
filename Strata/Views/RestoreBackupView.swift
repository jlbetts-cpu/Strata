import SwiftUI
import SwiftData

/// What is in the backup, before anything happens to the phone.
///
/// **Nobody taps restore and finds out afterwards what they got.** This screen
/// exists because the failure it follows was a data loss: the app had an export
/// and no import for months, which means it had a backup nobody could restore,
/// and the person who found that out found it out by reinstalling. The answer to
/// that is not only an importer — it is an importer that states the wins, the
/// days, the photographs and the dates it is holding, and makes somebody
/// confirm against those numbers, so a wrong or an old file is caught by reading
/// rather than by regret.
///
/// **Nothing here writes until the button is pressed.** Reading the zip and
/// planning the merge touch no file and no row; the plan is a description.
struct RestoreBackupView: View {

    /// A picked backup, wrapped so the sheet can be presented on the file
    /// itself. `sheet(item:)` rather than a Bool beside an optional, which is
    /// how a screen ends up presenting an empty state for one frame; `URL` is
    /// not `Identifiable`, so it needs one identity of its own.
    struct Picked: Identifiable {
        let id = UUID()
        let url: URL
    }

    /// A copy of the picked file, inside the app's own temporary directory. The
    /// copy is made before this screen opens so nothing depends on how long the
    /// file provider keeps its security-scoped URL alive.
    let zip: URL
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    private enum Stage {
        case reading
        case ready(BackupArchive.Contents, BackupRestore.Plan)
        case restoring
        case done(BackupRestore.Report)
        /// Read failed. The message is the person-facing one off the error, so
        /// "this isn't a Strata backup" and "this file is damaged" arrive as
        /// different sentences.
        case failed(String)
    }

    @State private var stage: Stage = .reading

    var body: some View {
        NavigationStack {
            // **The stack is at least a viewport tall, so the page can have a
            // floor** (2026-10-01, check 11c). Without this the `Spacer` before
            // the confirm button in `contents(of:)` has nothing to expand into
            // and the button stays where it was, with the page's biggest break
            // under it. See that `Spacer` for the measurement; the pattern is
            // `AddWinSheet`'s and `PlanSheet.content`'s.
            GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: GridConstants.gapWide) {
                    switch stage {
                    case .reading:
                        line("Reading the backup…")
                    case .ready(_, let plan):
                        contents(of: plan)
                    case .restoring:
                        line("Putting your wins back…")
                    case .done(let report):
                        outcome(report)
                    case .failed(let message):
                        failure(message)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // **`horizontalPadding`, and it was `gapWide`.** (2026-10-01)
                //
                // This screen was on a 24pt margin. Every other screen in Strata
                // is on 16: the tower, Memories, a day, the walkthrough, the add
                // sheet. A sheet that insets its content 8pt further than the
                // page behind it reads as a different app's dialog, and the
                // audit's own line is that every system is built on the same
                // grid and the same margins. The vertical 24 stays: that one is
                // the ladder's rung for air above and below a run of content,
                // and it is not a margin.
                .padding(.horizontal, GridConstants.horizontalPadding)
                .padding(.vertical, GridConstants.gapWide)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            // Unchanged, and it is the right one WITH the `minHeight` above:
            // the content is now exactly a viewport tall whenever it would
            // otherwise be shorter, so a one-line stage still does not bounce
            // like a long page.
            .scrollBounceBehavior(.basedOnSize)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Restore", drawn: false)
            .toolbar { closeButton }
            }
        }
        .task { await read() }
    }

    // MARK: - The numbers

    @ViewBuilder
    private func contents(of plan: BackupRestore.Plan) -> some View {
        let summary = plan.summary

        // The count as a numeral and the word as a caption under it, which is
        // the tower header's own arrangement: the number is the fact and the
        // word tells you which fact it is.
        //
        // **The caption is `bodyLarge`, and it was `screenSubtitle`.**
        // (2026-10-01) The audit allows a screen three type tiers: the screen's
        // title, an object's name, and body. This screen was setting four sizes
        // (34 for the tally, 15 for this line, 17 for the facts under it and 13
        // for the plan beneath those), and 15 is the one of them that belongs to
        // no tier here: `screenSubtitle` is the line under a SCREEN title, and
        // the screen's title here is "Restore", up in the toolbar. This is a
        // word naming a number, which is body.
        //
        // **Two sizes now, 34 and 17** (2026-10-01, the type pass). The four
        // 13pt lines left on this screen — the two sub-facts under the merge
        // plan, the "Restoring only adds" promise and the warning note — are
        // all `bodyLarge` as well. They are consequences of a button you are
        // about to press, and the promise in particular is the sentence that
        // makes the press safe; none of them is a caption.
        VStack(alignment: .leading, spacing: GridConstants.spacing) {
            // `StrataFont.digits`, never `Text("\(n)")`: interpolation groups a
            // thousand as "1,000" and the owner's face has no comma.
            Text(verbatim: StrataFont.digits(summary.wins))
                .font(Typography.tally)
                .foregroundStyle(AppColors.inkPrimary)
            Text(summary.wins == 1 ? "win in this backup" : "wins in this backup")
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
        }
        .accessibilityElement(children: .combine)

        VStack(spacing: 0) {
            if summary.otherEntries > 0 {
                fact("Not marked done", value: "\(summary.otherEntries)")
            }
            fact("Days", value: "\(summary.days)")
            fact("Photographs", value: photographLine(summary))
            // **"None", not a dash.** These were a long dash, which is the one
            // punctuation mark this app's copy is not allowed anywhere, and a
            // dash is not a word: a person reading "From, long dash" learns
            // nothing. The row right above it already says "None" for no
            // photographs, so this is the word the screen already uses.
            fact("From", value: summary.firstDay.map(Self.day) ?? "None")
            fact("To", value: summary.lastDay.map(Self.day) ?? "None")
            fact("Backed up", value: Self.day(summary.exportDate))
            fact("Made by Some Wins", value: summary.appVersion, isLast: true)
        }

        // What the merge will actually do, in the same place as the numbers it
        // is derived from.
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            Text(plan.winsToAdd == 1
                 ? "1 win will be added."
                 : "\(plan.winsToAdd) wins will be added.")
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkPrimary)
            if plan.winsAlreadyHere > 0 {
                Text(plan.winsAlreadyHere == 1
                     ? "1 is already on this phone and will be left as it is."
                     : "\(plan.winsAlreadyHere) are already on this phone and will be left as they are.")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            if !plan.photographsForExistingWins.isEmpty {
                Text(plan.photographsForExistingWins.count == 1
                     ? "1 win already here will get its photograph back."
                     : "\(plan.photographsForExistingWins.count) wins already here will get their photographs back.")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            // **The promise is NOT restated here** (cut 9,
            // `docs/copy-audit.md`, 2026-10-01). This slot carried "Restoring
            // only adds. Nothing already on this phone is deleted or changed."
            // and it was the THIRD statement of one fact inside a single flow:
            //
            //   1. `SettingsView`'s Data footer, on the row that opens this
            //      sheet: "Restoring only adds what the file holds; nothing
            //      already on this phone is deleted."
            //   2. the lines a few points above, per category: "N are already
            //      on this phone and will be left as they are."
            //   3. this one.
            //
            // The Settings footer is the one read BEFORE the decision, which is
            // where a promise about safety does its work; by the time somebody
            // is on this screen reading a count they have already been told.
            // Nothing about the screen's honesty moves: the per-category lines
            // still say in numbers that what is here is left alone, and
            // `BackupRestore` still contains no delete.
        }

        ForEach(plan.warnings, id: \.self) { warning in
            note(warning)
        }

        if plan.isEmptyOfWork {
            Text("Everything in this backup is already on this phone.")
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkPrimary)
        } else {
            // **The action stands on the bottom margin, not under the last
            // sentence** (2026-10-01, check 11c). Measured before: the button
            // sat at y641 to 691 with **148.7pt of nothing under it**, which is
            // the page's biggest break and it was AFTER the last band — the
            // clause's definition of a page that stopped rather than ended, and
            // `docs/space.md`'s P7. The flexible `Spacer` turns that tail into
            // the break, between the plan and the one irreversible control on
            // the screen, which is also where a break belongs on a page that
            // asks you to read before you press.
            //
            // The pattern is `AddWinSheet`'s and `PlanSheet.content`'s, not a
            // new one: the stack is held to at least the viewport's height by
            // the `GeometryReader` in `body` and the `Spacer` is the only
            // flexible thing in it. With a backup that carries warnings the
            // content is taller than the viewport, the `Spacer` collapses to
            // the stack's own `gapWide` at each end, and nothing is pushed off.
            //
            // It lands at y766 to 816, which is where the walkthrough's pill
            // and Store unavailable's pill already stand — the app's settled
            // position for the one action on a page.
            Spacer(minLength: 0)
            primaryButton(plan.winsToAdd == 1 ? "Add 1 win" : "Add \(plan.winsToAdd) wins") {
                await restore(plan)
            }
        }
    }

    private func photographLine(_ summary: BackupRestore.Summary) -> String {
        guard summary.photographs > 0 else { return "None" }
        // The two numbers differ for an old backup, and that difference is the
        // whole story of it, so it is stated rather than averaged into one.
        if summary.attachablePhotographs == summary.photographs {
            return "\(summary.photographs)"
        }
        return "\(summary.photographs), \(summary.attachablePhotographs) restorable"
    }

    // MARK: - After

    @ViewBuilder
    private func outcome(_ report: BackupRestore.Report) -> some View {
        if let failure = report.failure {
            Text("Nothing was restored")
                .font(Typography.screenTitle)
                .foregroundStyle(AppColors.inkPrimary)
            Text(failure)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
        } else {
            VStack(alignment: .leading, spacing: GridConstants.spacing) {
                Text(verbatim: StrataFont.digits(report.winsAdded))
                    .font(Typography.tally)
                    .foregroundStyle(AppColors.inkPrimary)
                // `bodyLarge`, for the reason the same pair in `contents(of:)`
                // gives: 15 is the one size on this screen that belongs to none
                // of the three tiers.
                Text(report.winsAdded == 1 ? "win restored" : "wins restored")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                fact("Days", value: "\(report.daysAdded)")
                fact("Photographs", value: "\(report.photographsRestored)")
                if report.photographsAlreadyHere > 0 {
                    fact("Already on this phone", value: "\(report.photographsAlreadyHere)")
                }
                if report.photographsReattached > 0 {
                    fact("Put back on older wins", value: "\(report.photographsReattached)")
                }
                fact("Wins untouched", value: "everything you already had", isLast: true)
            }
        }

        ForEach(report.problems, id: \.self) { problem in
            note(problem)
        }

        primaryButton("Done") { onClose() }
    }

    @ViewBuilder
    private func failure(_ message: String) -> some View {
        Text("This backup can't be read")
            .font(Typography.screenTitle)
            .foregroundStyle(AppColors.inkPrimary)
        Text(message)
            .font(Typography.bodyLarge)
            .foregroundStyle(AppColors.inkSecondary)
        primaryButton("Close") { onClose() }
    }

    // MARK: - Pieces

    private func line(_ text: String) -> some View {
        HStack(spacing: GridConstants.gapItem) {
            ProgressView()
            Text(text)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One labelled fact, with the app's one hairline under it.
    ///
    /// No card, no rim, no elevation: a hairline is how this app separates
    /// (CLAUDE.md — chrome separates with hairlines and translucency, never
    /// shadow, and a card with a white rim makes a claim only a block gets to
    /// make).
    private func fact(_ label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
                Spacer(minLength: GridConstants.gapItem)
                Text(value)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, GridConstants.gapItem)
            if !isLast {
                Rectangle()
                    .fill(GridConstants.fillHairline)
                    // One hairline, one token: `1 / displayScale`, not a flat
                    // 0.5, which is 50% too heavy on a 3x phone.
                    .frame(height: 1 / displayScale)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Something the person needs to know before they decide. Ink, not red:
    /// colour in this app means something, and none of these is a destruction.
    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: GridConstants.gapItem) {
            Image(systemName: "info.circle")
                .iconSize(GridConstants.iconMedium, relativeTo: .footnote, weight: .medium)
                .foregroundStyle(AppColors.inkQuiet)
            Text(text)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The app's filled primary capsule, shared with `StoreUnavailableView`.
    ///
    /// **This comment used to say "the same filled capsule the onboarding's
    /// primary action uses" and had been wrong for a commit.** Onboarding's pill
    /// became a lit `AppColors.accent` capsule with the block's rim on
    /// 2026-09-30 and this stayed a flat `inkPrimary` one, so the app had three
    /// primary actions in three places and a comment asserting it had one. That
    /// is the drift `GlassIconButton.swift` and `SectionHeading.swift` each
    /// record in their own words: a treatment redefined per screen drifts per
    /// screen.
    ///
    /// **It stays ink rather than becoming the accent, and that is measured.**
    /// Sampled off the 2026-10-01 walkthrough shots, the accent pill's white
    /// label is 2.03:1 where the guideline asks 4.5 of a 17pt word; this one is
    /// 14.0:1. Adopting the accent today would spread a failure rather than end
    /// a drift. See `OnboardingView.pillLabel` for the three measured ways out:
    /// once one is picked, these two and onboarding's belong in one component.
    /// **`PrimaryCapsule` now, and the comment above this was right.** It said
    /// these two and onboarding's belong in one component "once one is picked",
    /// meaning the colour. It is picked: `accentPrimary`, flat, measured at
    /// 4.69:1 for a white word across the whole pill. This screen's confirm was
    /// `inkPrimary`, a near black, which is the same thing that made Cancel
    /// three lines up read as a label rather than as a control.
    private func primaryButton(_ title: String, action: @escaping () async -> Void) -> some View {
        PrimaryCapsule(title: title) { Task { await action() } }
    }

    /// **Gone once the restore has settled.** Done and failed each end in a
    /// `PrimaryCapsule` that closes the sheet, so the toolbar word was a second
    /// exit beside it: "Done" over "Done", and on a failure "Cancel" over
    /// "Close", two words for one way out and a Cancel with nothing left to
    /// cancel (2026-10-02, first capture of these stages). Before then it is
    /// the only way out and stays.
    @ToolbarContentBuilder
    private var closeButton: some ToolbarContent {
        // Bare glyph, like every other toolbar in the app: iOS 26 puts a glass
        // capsule behind a toolbar item and the app strips it deliberately.
        if isSettled {
            ToolbarItem(placement: .cancellationAction) { EmptyView() }
        } else if #available(iOS 26.0, *) {
            ToolbarItem(placement: .cancellationAction) { cancelLabel }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .cancellationAction) { cancelLabel }
        }
    }

    /// **`inkPrimary`, through the shared `sheetAction()`.**
    ///
    /// **The comment that stood here was headed "`accentPrimary`, and it was
    /// `accentWarm`", ran eight lines on why this word is blue, and the code had
    /// drawn `inkPrimary` the whole time** (corrected 2026-10-01,
    /// `docs/consistency-audit.md` §2.1 — the third instance of this exact fault
    /// in three files, and `accentPrimary` is now deleted from the palette with
    /// zero call sites). The owner retired the blue: "lets just do the basic."
    ///
    /// What was true in it and is kept: `accentWarm` in light mode is
    /// (28, 26, 24), so this word was drawn at the same weight of black as the
    /// title beside it and read as a label rather than as the thing you press to
    /// walk away from a restore. The retired token's own measurement, kept because
    /// it is the number anybody reopening this needs: 4.38:1 on the light page,
    /// 3.62:1 on the dark one.
    ///
    /// **`accentWarm` is NOT a fixed black and this comment said it was for
    /// about an hour.** It carries a `userInterfaceStyle` branch and goes to a
    /// warm near-white (0.98, 0.97, 0.96) in dark mode, so every piece of ink in
    /// the app inverts together. The reason to prefer `inkPrimary` here is not
    /// adaptivity, it is that `accentWarm`'s job is a ground and a brand
    /// near-black rather than the ink on a control, and `inkPrimary` is the token
    /// for ink. `SheetAction` carries the same correction.
    ///
    /// **It is only ever Cancel now.** It used to turn into "Done" once the
    /// restore had happened, which put it beside the stage's own Done capsule;
    /// the toolbar word leaves at that point instead (see `closeButton`).
    ///
    /// **And the 44pt box arrives with the modifier.** This was a bare `Text`,
    /// so it measured the 68x36 the audit measured on four of six sheets, on the
    /// one screen in the app whose leading word is the only way out.
    private var cancelLabel: some View {
        Button {
            HapticsEngine.lightTap()
            onClose()
        } label: {
            Text("Cancel")
                .sheetAction(.cancel)
        }
        .buttonStyle(.pressWord)
        .disabled(isRestoring)
    }

    private var isSettled: Bool {
        switch stage {
        case .done, .failed: return true
        default: return false
        }
    }

    private var isRestoring: Bool {
        if case .restoring = stage { return true }
        return false
    }

    private static func day(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Work

    /// Reads the archive off the main thread, then plans on it.
    ///
    /// The read inflates and checksums `wins.json` and walks the index of
    /// hundreds of photographs; the plan fetches the store, which belongs to the
    /// main actor.
    private func read() async {
        guard case .reading = stage else { return }
        let url = zip
        let outcome = await Task.detached(priority: .userInitiated) { () -> Result<BackupArchive.Contents, Error> in
            do { return .success(try BackupArchive.read(zipAt: url)) }
            catch { return .failure(error) }
        }.value
        #if DEBUG
        if let held = Self.heldStage() { stage = held; return }
        #endif
        switch outcome {
        case .failure(let error):
            stage = .failed(Self.message(for: error))
        case .success(let contents):
            do {
                stage = .ready(contents, try BackupRestore.plan(contents, context: modelContext))
            } catch {
                stage = .failed("Some Wins could not read what is already on this phone, so it cannot say what this backup would add (\(error.localizedDescription)). Nothing has been changed.")
            }
        }
    }

    private func restore(_ plan: BackupRestore.Plan) async {
        guard case .ready(let contents, _) = stage else { return }
        stage = .restoring
        // The photographs first, off the main thread: each one is inflated,
        // decoded and written, and a year of them would freeze the screen at the
        // one moment this app cannot afford to look broken.
        let photographs = await Task.detached(priority: .userInitiated) {
            BackupRestore.takePhotographs(for: plan, from: contents)
        }.value
        let report = BackupRestore.apply(plan, contents: contents,
                                         context: modelContext, photographs: photographs)
        if report.succeeded { HapticsEngine.success() } else { HapticsEngine.warning() }
        stage = .done(report)
    }

    #if DEBUG
    /// A stage past the decision, for `-strataRestoreStage`. The numbers are a
    /// believable restore of the seeded backup, and the failure is the real
    /// copy for a backup from a newer version, so what is photographed is what
    /// a person would read.
    private static func heldStage() -> Stage? {
        switch DebugHarness.restoreStage {
        case "restoring":
            return .restoring
        case "done":
            var report = BackupRestore.Report()
            report.winsAdded = 40
            report.daysAdded = 18
            report.photographsRestored = 12
            return .done(report)
        case "failed":
            return .failed(BackupArchive.ReadFailure.fromTheFuture(fileVersion: BackupArchive.currentFormatVersion + 7).message)
        default:
            return nil
        }
    }
    #endif

    private static func message(for error: Error) -> String {
        if let failure = error as? BackupArchive.ReadFailure { return failure.message }
        if let failure = error as? ZipArchiveReader.Failure {
            return BackupArchive.ReadFailure.archive(failure).message
        }
        return "Some Wins could not open this file (\(error.localizedDescription))."
    }
}
