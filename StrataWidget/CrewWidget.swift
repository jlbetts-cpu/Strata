import AppIntents
import SwiftUI
import WidgetKit

/// **A crew, on the home screen** (the owner, 2026-10-14). Everyone in the
/// crew stands in a row; each person stands on the wins they have logged
/// today, so a head rises as its owner logs, and someone who has not logged
/// yet stands on the ground, faded. Seeing your people without opening
/// anything is what brings a small group back.
///
/// Draws from `CrewWidgetSnapshot`, which the app writes
/// (`CrewWidgetPublisher`). Small shows four people and medium shows everyone.
struct CrewWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StrataCrew", intent: CrewWidgetIntent.self,
                               provider: CrewProvider()) { entry in
            CrewWidgetView(crew: entry.crew)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("Crew")
        .description("Your crew's day, one head per person.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Choosing the crew

struct CrewWidgetEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Crew"
    static let defaultQuery = CrewWidgetQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct CrewWidgetQuery: EntityQuery {
    private var all: [CrewWidgetEntity] {
        CrewWidgetSnapshot.read().crews.map { CrewWidgetEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [String]) async throws -> [CrewWidgetEntity] {
        all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CrewWidgetEntity] { all }

    func defaultResult() async -> CrewWidgetEntity? { all.first }
}

struct CrewWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Crew"
    static let description = IntentDescription("Choose which crew to show.")

    @Parameter(title: "Crew")
    var crew: CrewWidgetEntity?
}

// MARK: - Timeline

struct CrewEntry: TimelineEntry {
    let date: Date
    let crew: CrewWidgetSnapshot.Crew?
}

/// One entry. The app reloads the timeline when the crew changes; the
/// `.after` date is the crew's next midnight, which empties the blocks for
/// the new day even if the app never runs (`Crew.asOf`).
struct CrewProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CrewEntry {
        CrewEntry(date: Date(), crew: CrewWidgetSnapshot.preview.crews.first)
    }

    func snapshot(for configuration: CrewWidgetIntent, in context: Context) async -> CrewEntry {
        if context.isPreview, CrewWidgetSnapshot.read().crews.isEmpty {
            return placeholder(in: context)
        }
        return entry(for: configuration, at: Date())
    }

    func timeline(for configuration: CrewWidgetIntent, in context: Context) async -> Timeline<CrewEntry> {
        let now = Date()
        let entry = entry(for: configuration, at: now)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = entry.crew.flatMap { TimeZone(identifier: $0.zone) } ?? .current
        let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1),
                                         matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        // The new day's empty stacks are handed over now, dated midnight, so
        // they show on time even when the reload after it runs late.
        let next = CrewEntry(date: midnight, crew: entry.crew?.asOf(midnight))
        return Timeline(entries: [entry, next], policy: .after(midnight))
    }

    private func entry(for configuration: CrewWidgetIntent, at date: Date) -> CrewEntry {
        CrewEntry(date: date, crew: CrewWidgetSnapshot.read().crew(configuration.crew?.id)?.asOf(date))
    }
}
