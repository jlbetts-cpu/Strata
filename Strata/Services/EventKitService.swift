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

    var endTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endDate)
    }

    /// Busy range in minutes from midnight (for gap-finding)
    var busyRange: (start: Int, end: Int)? {
        guard !isAllDay else { return nil }
        let calendar = Calendar.current
        let startMinutes = calendar.component(.hour, from: startDate) * 60 + calendar.component(.minute, from: startDate)
        let endMinutes = calendar.component(.hour, from: endDate) * 60 + calendar.component(.minute, from: endDate)
        guard endMinutes > startMinutes else { return nil }
        return (startMinutes, endMinutes)
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
        fetchEvents(for: Date())
    }

    // MARK: - Fetch Events for Any Date

    func fetchEvents(for date: Date) {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
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

    // MARK: - Busy Ranges (for gap-finding integration)

    /// Returns all timed events as busy ranges in minutes from midnight
    var busyRanges: [(start: Int, end: Int)] {
        todaysEvents.compactMap(\.busyRange).sorted { $0.start < $1.start }
    }

    // MARK: - All-Day Events

    var allDayEvents: [CalendarAnchor] {
        todaysEvents.filter(\.isAllDay)
    }

    /// Timed events only (non-all-day)
    var timedEvents: [CalendarAnchor] {
        todaysEvents.filter { !$0.isAllDay }
    }
}
