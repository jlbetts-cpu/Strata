import SwiftUI

/// One tap logs a win. Long-press picks the category.
///
/// The friction being removed: the existing path to record something you did is
/// the full add sheet — recurring-vs-one-time, title, category, size, weekday
/// set, time — which is a scheduling form. Everything in it is a question about
/// the FUTURE, and a win has no future to describe; it already happened.
///
/// So the common path is one tap and no questions: the category defaults to the
/// last one used, the title stays "Win" until you care, and the block lands in
/// the tower immediately. `Menu(primaryAction:)` keeps the category available on
/// long-press without putting it in the way — tap is the whole interaction
/// unless you want more.
struct QuickWinButton: View {
    /// Last category used, so the common case needs no choice at all.
    @AppStorage("quickWinCategory") private var lastCategoryRaw: String = HabitCategory.health.rawValue

    let onLog: (HabitCategory) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    private var lastCategory: HabitCategory {
        HabitCategory(rawValue: lastCategoryRaw) ?? .health
    }

    var body: some View {
        Menu {
            Section("Log a win as") {
                ForEach(HabitCategory.allCases, id: \.self) { category in
                    Button {
                        lastCategoryRaw = category.rawValue
                        log(category)
                    } label: {
                        Label(category.rawValue.capitalized, systemImage: category.iconName)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .iconSize(GridConstants.iconAction, relativeTo: .body, weight: .semibold)
                Text("Log a win")
                    .font(Typography.headerSmall)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(lastCategory.style.baseColor, in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: GridConstants.blockRimWidth))
            .shadow(
                color: .black.opacity(GridConstants.blockShadowOpacity),
                radius: GridConstants.blockShadowRadius,
                x: 0,
                y: GridConstants.blockShadowY
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
        } primaryAction: {
            log(lastCategory)
        }
        .accessibilityLabel("Log a win")
        .accessibilityHint("Adds a completed block. Long press to choose a category.")
    }

    private func log(_ category: HabitCategory) {
        HapticsEngine.snap()
        if reduceMotion {
            onLog(category)
        } else {
            withAnimation(GridConstants.microResponse) { pressed = true }
            withAnimation(GridConstants.snapBack.delay(0.06)) { pressed = false }
            onLog(category)
        }
    }
}
