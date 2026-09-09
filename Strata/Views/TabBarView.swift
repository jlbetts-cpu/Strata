import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Wins"
    case camera = "Camera"
    case memories = "Memories"

    var icon: String {
        switch self {
        case .tower: return "square.stack"
        case .camera: return "camera"
        case .memories: return "photo.stack"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.fill"
        case .camera: return "camera.fill"
        case .memories: return "photo.stack.fill"
        }
    }
}
