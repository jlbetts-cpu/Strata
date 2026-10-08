import SwiftUI

/// **What the last two weeks say about a goal** (2026-10-08, the owner's pick:
/// "Goal context"). Choosing a number of wins a day was a guess; this puts the
/// person's own fourteen days beside the stepper, a hairline at the goal, and
/// one sentence, so the choice is made against what they actually do, the way
/// a price filter shows the spread of prices before you drag it.
///
/// Today is left out: it is not over, and a half day under the line reads as
/// a shortfall it is not.
nonisolated struct GoalHistory: Equatable {
    /// Oldest first, one count per day.
    let days: [Int]

    static let length = 14
    /// Fewer days with a win than this and there is nothing to read yet.
    static let minimumActiveDays = 3

    /// The fourteen days before `today`, from the day counts Your day already
    /// loads (`YourDaySheet.counts`).
    static func make(counts: [String: Int], today: Date = Date(), calendar: Calendar = DateUtils.keyCalendar(in: .current)) -> GoalHistory {
        let days = (1...length).reversed().map { back -> Int in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return 0 }
            return counts[DateUtils.dateString(from: day)] ?? 0
        }
        return GoalHistory(days: days)
    }

    var activeDays: Int { days.filter { $0 > 0 }.count }
    var isReadable: Bool { activeDays >= Self.minimumActiveDays }
    func reached(_ goal: Int) -> Int { days.filter { $0 >= goal }.count }

    /// "You reached 3 on 9 of the last 14 days."
    func sentence(goal: Int) -> String {
        let n = reached(goal)
        switch n {
        case 0: return "None of the last \(Self.length) days reached \(goal) yet."
        case Self.length: return "You reached \(goal) on every one of the last \(Self.length) days."
        default: return "You reached \(goal) on \(n) of the last \(Self.length) days."
        }
    }
}

/// Fourteen small bars and the goal as a hairline across them. Monotone, as
/// the goal crest is: a day at or over the goal is ink, a day under it is the
/// quiet grey, and nothing is red.
struct GoalHistoryChart: View {
    let history: GoalHistory
    let goal: Int

    private static let height: CGFloat = 44

    var body: some View {
        let top = max(history.days.max() ?? 0, goal, 1)
        GeometryReader { geo in
            let gap: CGFloat = 4
            let bar = (geo.size.width - gap * CGFloat(GoalHistory.length - 1)) / CGFloat(GoalHistory.length)
            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(Array(history.days.enumerated()), id: \.offset) { _, count in
                        RoundedRectangle(cornerRadius: min(3, bar * 0.3), style: .continuous)
                            .fill(count >= goal ? AppColors.inkPrimary.opacity(0.85) : AppColors.inkQuiet.opacity(0.45))
                            .frame(width: bar, height: max(3, Self.height * CGFloat(count) / CGFloat(top)))
                    }
                }
                Rectangle()
                    .fill(AppColors.inkTertiary)
                    .frame(height: 1)
                    .offset(y: -Self.height * CGFloat(goal) / CGFloat(top))
            }
            .animation(GridConstants.motionSnappy, value: goal)
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(history.sentence(goal: goal))
    }
}
