import SwiftUI
import SwiftData

/// The button page: press it, a block lands on the tower.
///
/// This exists because recording something you already did had to go through
/// the add sheet, and every question in that sheet is about the future —
/// recurring or one-time, which weekdays, what time. A win has no future to
/// describe. The mismatch is the friction.
///
/// So the page asks nothing. One button, one tap, a counter that goes up. The
/// block is neutral grey because the colour system is for categories you chose,
/// and this one has not been chosen yet — naming a win later moves it into a
/// real category. Naming is available but never required, and never in the way.
///
/// The button is drawn with BlockSurface rather than a button style: it is
/// literally the same material as the thing it creates, so pressing it reads as
/// placing a block rather than submitting a form.
struct WinsView: View {
    /// The tower a win belongs to.
    let tower: Tower?
    /// Hands the new habit to the tower's drop cascade, so a win lands exactly
    /// as a normal completion does.
    let onWin: (Habit) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allHabits: [Habit]
    @Query private var allLogs: [HabitLog]

    @State private var pressed = false
    @State private var saveFailed = false
    @State private var renaming: Habit?
    @State private var draftName = ""

    private var today: String { DateUtils.dateString(from: Date()) }

    /// Wins logged today, newest first.
    private var todaysWins: [Habit] {
        let completedToday = Set(
            allLogs.filter { $0.dateString == today && $0.completed }
                .compactMap { $0.habit?.id }
        )
        return allHabits
            .filter { QuickWinService.isWin($0) && completedToday.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var count: Int { todaysWins.count }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            counter

            button
                .padding(.top, 28)

            Spacer(minLength: 0)

            if !todaysWins.isEmpty {
                winList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, GridConstants.horizontalPadding)
        .alert("Couldn't save that win", isPresented: $saveFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Nothing was added. Try again.")
        }
        .alert("Name this win", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("What was it?", text: $draftName)
            Button("Save") { commitRename() }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    // MARK: - Counter

    private var counter: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 72, weight: .medium, design: .rounded))
                .foregroundStyle(Color.primary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : GridConstants.motionSmooth, value: count)

            Text(count == 1 ? "win today" : "wins today")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.primary.opacity(0.45))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(count == 1 ? "win" : "wins") today")
    }

    // MARK: - The button

    private var button: some View {
        Button(action: logWin) {
            BlockSurface(cornerRadius: 28) {
                HabitCategory.unlabeled.style.baseColor
            }
            .frame(width: 180, height: 180)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.white)
            )
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log a win")
        .accessibilityHint("Adds a block to your tower. Name it afterwards if you want to.")
    }

    // MARK: - Today's wins

    private var winList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(todaysWins) { win in
                    Button {
                        draftName = win.title == QuickWinService.untitled ? "" : win.title
                        renaming = win
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(win.category.style.baseColor)
                                .frame(width: 8, height: 8)
                            Text(win.title)
                                .font(Typography.bodySmall)
                                .foregroundStyle(Color.primary.opacity(0.7))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(win.title)
                    .accessibilityHint("Rename this win")
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Actions

    private func logWin() {
        HapticsEngine.snap()
        if !reduceMotion {
            withAnimation(GridConstants.tapSquashSpring) { pressed = true }
            withAnimation(GridConstants.tapPopSpring.delay(0.06)) { pressed = false }
        }
        do {
            let habit = try QuickWinService.logWin(
                context: modelContext,
                tower: tower
            )
            onWin(habit)
        } catch {
            // Never leave a counter that counted something which was not written.
            saveFailed = true
        }
    }

    private func commitRename() {
        guard let habit = renaming else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            habit.title = trimmed
            try? modelContext.save()
        }
        renaming = nil
        draftName = ""
    }
}
