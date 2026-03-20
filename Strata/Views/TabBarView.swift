import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case timeline = "Timeline"

    var icon: String {
        switch self {
        case .tower: return "square.stack.3d.up"
        case .timeline: return "calendar.day.timeline.leading"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.3d.up.fill"
        case .timeline: return "calendar.day.timeline.leading"
        }
    }
}
