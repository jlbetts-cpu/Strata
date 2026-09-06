import AppIntents

enum CategoryAppEnum: String, AppEnum {
    case health, work, creativity, focus, social, mindfulness

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static var caseDisplayRepresentations: [CategoryAppEnum: DisplayRepresentation] = [
        .health: .init(title: "Health", image: .init(systemName: "heart.fill")),
        .work: .init(title: "Work", image: .init(systemName: "briefcase.fill")),
        .creativity: .init(title: "Creativity", image: .init(systemName: "paintbrush.fill")),
        .focus: .init(title: "Focus", image: .init(systemName: "eye.fill")),
        .social: .init(title: "Social", image: .init(systemName: "person.2.fill")),
        .mindfulness: .init(title: "Mindfulness", image: .init(systemName: "leaf.fill")),
    ]
}
