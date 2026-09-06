import AppIntents
import CoreSpotlight
import UIKit

struct HabitEntity: AppEntity, IndexedEntity {
    static var defaultQuery = HabitEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"

    var id: UUID

    @Property(title: "Title")
    var title: String

    @Property(title: "Category")
    var category: String

    @Property(title: "Completed Today")
    var isCompletedToday: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(category.capitalized)",
            image: .init(systemName: iconName)
        )
    }

    // Rich Spotlight metadata
    var attributeSet: CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: .content)
        attrs.displayName = title
        attrs.contentDescription = "\(category.capitalized) habit in Strata"
        attrs.keywords = [title, category, "habit", "strata"]
        attrs.thumbnailData = Self.categoryThumbnail(icon: iconName, category: category)
        return attrs
    }

    var iconName: String {
        switch category {
        case "health": "heart.fill"
        case "work": "briefcase.fill"
        case "creativity": "paintbrush.fill"
        case "focus": "eye.fill"
        case "social": "person.2.fill"
        case "mindfulness": "leaf.fill"
        default: "square.fill"
        }
    }

    init(id: UUID, title: String, category: String, isCompletedToday: Bool) {
        self.id = id
        self.title = title
        self.category = category
        self.isCompletedToday = isCompletedToday
    }

    /// Renders a category-colored SF Symbol as thumbnail data for Spotlight
    private static func categoryThumbnail(icon: String, category: String) -> Data? {
        let color: UIColor = switch category {
        case "health": UIColor(red: 0.063, green: 0.718, blue: 0.498, alpha: 1)
        case "work": UIColor(red: 0.251, green: 0.663, blue: 1.0, alpha: 1)
        case "creativity": UIColor(red: 0.686, green: 0.612, blue: 0.980, alpha: 1)
        case "focus": UIColor(red: 0.992, green: 0.710, blue: 0.310, alpha: 1)
        case "social": UIColor(red: 0.976, green: 0.439, blue: 0.400, alpha: 1)
        case "mindfulness": UIColor(red: 0.925, green: 0.522, blue: 0.706, alpha: 1)
        default: .gray
        }
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
            .applying(UIImage.SymbolConfiguration(paletteColors: [.white, color]))
        let image = UIImage(systemName: icon, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        return image?.pngData()
    }
}
