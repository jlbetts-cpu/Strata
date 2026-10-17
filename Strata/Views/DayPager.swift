import SwiftUI

/// **Inside a day, swipe through the month** (the owner's launch pass, 1:
/// "open a day, then swipe left and right to move to the next and previous
/// day without backing out. Same spring and follow-the-finger feel as
/// swiping between photos in Photos"). The day pages of its month, up to
/// today, in a paged view that follows the finger as Photos' does; the back
/// button still goes to Memories in one step.
struct DayPager: View {
    let start: String
    @State private var shown: String

    init(start: String) {
        self.start = start
        _shown = State(initialValue: start)
    }

    /// The month's days, first to last, never past today.
    private var days: [String] {
        guard let date = DateUtils.date(from: start) else { return [start] }
        let calendar = DateUtils.keyCalendar(in: NSTimeZone.default)
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [start] }
        let today = DateUtils.dateString(from: Date())
        return range.compactMap { offset -> String? in
            guard let day = calendar.date(byAdding: .day, value: offset - 1, to: first) else { return nil }
            let key = DateUtils.dateString(from: day)
            return key <= today ? key : nil
        }
    }

    var body: some View {
        TabView(selection: $shown) {
            ForEach(days, id: \.self) { day in
                DayAlbumDetailView(route: DayRoute(dateString: day), hostsBar: day == shown)
                    .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sensoryFeedback(.selection, trigger: shown)
        .background { WarmBackground().ignoresSafeArea() }
    }
}
