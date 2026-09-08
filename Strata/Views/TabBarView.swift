import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Wins"
    case camera = "Camera"
    case history = "History"

    var icon: String {
        switch self {
        case .tower: return "square.stack"
        case .camera: return "camera"
        case .history: return "clock.arrow.circlepath"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.fill"
        case .camera: return "camera.fill"
        case .history: return "clock.arrow.circlepath"
        }
    }
}
