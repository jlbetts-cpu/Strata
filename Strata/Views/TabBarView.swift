import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case journal = "Journal"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .tower: return "square.stack.3d.up"
        case .journal: return "book"
        case .profile: return "person"
        }
    }
}
