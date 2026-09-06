import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case today = "Today"
    case plan = "Plan"
    case insights = "Insights"

    /// Outline glyphs. SwiftUI's `Tab` fills the selected one itself, so passing
    /// the outline name is both correct and native — a hand-picked `selectedIcon`
    /// used to live here and was never read (MainAppView passed literals), and it
    /// named `calendar.fill`, which is not a real SF Symbol.
    var icon: String {
        switch self {
        case .tower: return "square.stack.3d.up"
        case .today: return "calendar"
        case .plan: return "list.bullet.clipboard"
        case .insights: return "chart.bar"
        }
    }
}
