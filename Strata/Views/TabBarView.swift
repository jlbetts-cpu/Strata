import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Wins"
    case camera = "Camera"
    case insights = "Insights"

    var icon: String {
        switch self {
        case .tower: return "square.stack"
        case .camera: return "camera"
        case .insights: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.fill"
        case .camera: return "camera.fill"
        case .insights: return "chart.bar.fill"
        }
    }
}
