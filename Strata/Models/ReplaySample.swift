import CoreGraphics
import Foundation

/// Sample wins for the Settings preview.
///
/// The preview has to play EXACTLY as the real thing, so it is the real
/// replay fed made-up wins: the onboarding's bundled photographs, plausible
/// names, every block size, one empty day and one clearly busiest day, so every
/// part of the choreography shows. Deterministic, so what you preview today is
/// what you previewed yesterday.
enum ReplaySample {

    private static let titles = ["Morning run", "Read 20 pages", "Called Mum", "Deep work", "Stretch",
                                 "Cooked dinner", "Guitar", "Inbox zero", "Walk", "Sketch",
                                 "Meditate", "Gym", "Tidied the flat", "Journal", "Swim"]

    static func replay(_ kind: ReplayKind, now: Date, calendar: Calendar = .current) -> Replay {
        let period = kind == .week ? ReplayPeriod.week(containing: now, calendar: calendar)
                                   : ReplayPeriod.month(containing: now, calendar: calendar)
        var rng = SplitMix(seed: kind == .week ? 7 : 31)
        let categories = HabitCategory.selectable
        let emptyDay = kind == .week ? 2 : 9
        let busiestDay = kind == .week ? 3 : 17

        var wins: [ReplayWin] = []
        for day in period.days.indices where day != emptyDay {
            let count: Int
            if day == busiestDay { count = kind == .week ? 6 : 8 }
            else { count = kind == .week ? 2 + Int(rng.next() % 3) : 2 + Int(rng.next() % 4) }
            for n in 0..<count {
                let roll = rng.next() % 10
                let size: BlockSize = roll < 5 ? .small : (roll < 8 ? .medium : .hard)
                let hasPhoto = rng.next() % 3 == 0
                wins.append(ReplayWin(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-%04lX-%012lX", day, n))!,
                    dateString: period.days[day],
                    completedAt: period.date(ofDay: day).addingTimeInterval(Double(7 * 3600 + n * 2400)),
                    title: titles[Int(rng.next() % UInt64(titles.count))],
                    category: categories[Int(rng.next() % UInt64(categories.count))],
                    size: size,
                    photo: hasPhoto ? .bundled("DemoPhoto\(1 + Int(rng.next() % 12))") : nil,
                    crop: .zero))
            }
        }
        return Replay(period: period, wins: wins)
    }

    /// A tiny deterministic generator; `SystemRandomNumberGenerator` cannot be seeded.
    private struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}
