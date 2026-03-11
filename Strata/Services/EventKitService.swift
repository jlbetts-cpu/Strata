import Foundation
import EventKit

struct CalendarAnchor: Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let colorRed: CGFloat
    let colorGreen: CGFloat
    let colorBlue: CGFloat

    var timeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }
}

@Observable
final class EventKitService {
    private let store = EKEventStore()
    private(set) var todaysEvents: [CalendarAnchor] = []
    private(set) var isAuthorized = false

    // MARK: - Request Access

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                fetchTodaysEvents()
            }
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Fetch Today's Events

    func fetchTodaysEvents() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        todaysEvents = events.map { event in
            let cgColor = event.calendar.cgColor
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            if let components = cgColor?.components, components.count >= 3 {
                r = components[0]
                g = components[1]
                b = components[2]
            }

            return CalendarAnchor(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                colorRed: r,
                colorGreen: g,
                colorBlue: b
            )
        }
    }

    // MARK: - Find Nearest Anchor

    func nearestUpcomingEvent() -> CalendarAnchor? {
        let now = Date()
        return todaysEvents.first { $0.startDate > now }
    }
}
