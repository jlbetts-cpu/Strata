import Foundation

struct DayProgressData: Identifiable {
    let id = UUID()
    let date: Date
    let dayLabel: String
    let dayNumber: Int
    let completionRate: Double
    let isToday: Bool
    let isFuture: Bool
}
