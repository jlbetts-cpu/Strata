import Foundation
import SwiftData

/// **A plan a crew can see** (the owner's Launch Pack, 2026-10-12: "a
/// shared commitment where completion surfaces as living proof, like 'Rildy
/// just did the workout'. Not a challenge, not competitive"). The design he
/// approved is `docs/crew-plus-design.md`.
///
/// **It travels as a line in the crew's chat**, marked the way a photo strip
/// is (`CrewMessage.stripMarker`): two characters nobody types, and then
/// words a person can read, "Plan: Workout (tomorrow)". So it is no new kind
/// of record: it is sealed, paced, checked and cleared exactly as every chat
/// line is, and a friend on a build from before this sees those words as a
/// plain line.
///
/// **The proposal is one day long, the commitment is yours.** The card with
/// its button is in the chat on the day it was sent. Tapping I'm In puts the
/// line in your own plan (`GroupPlanBook`), where it lives as any line of
/// yours does. On the plan's day the chat draws the card again, on your
/// phone, from your own plan; the heads on it are the crew's wins of that
/// name that day. Nothing says who is in and who is not.
nonisolated struct GroupPlan: Equatable, Identifiable, Sendable {
    enum When: Equatable, Sendable {
        /// One day, `yyyy-MM-dd`.
        case day(String)
        /// The days of the week it comes back on, 1 = Sunday, as `PlanItem`
        /// numbers them.
        case weekdays([Int])
    }

    /// The chat line that proposed it.
    let id: UUID
    let crewID: CrewID
    let sender: UUID
    let title: String
    let when: When

    /// A plan is a few words: longer than this is a sentence, and it has to
    /// fit a card and a block.
    static let titleLimit = 60
    private static let lead = "Plan: "
    private static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: The line

    /// The chat line for a plan, as it is sent. Nil for a title with nothing
    /// in it. `sentOn` is the crew's day: "today" and "tomorrow" are written
    /// as those words, so the line reads well where nothing draws a card.
    static func line(title: String, when: When, sentOn: String) -> String? {
        let words = tidy(title)
        guard !words.isEmpty else { return nil }
        let spec: String
        switch when {
        case .day(let day):
            if day == sentOn { spec = "today" }
            else if day == next(after: sentOn) { spec = "tomorrow" }
            else { spec = day }
        case .weekdays(let days):
            let known = Set(days).filter { (1...7).contains($0) }.sorted()
            guard !known.isEmpty else { return nil }
            spec = known.map { weekdayNames[$0 - 1] }.joined(separator: " ")
        }
        return CrewMessage.planMarker + lead + words + " (" + spec + ")"
    }

    init?(message: CrewMessage) {
        guard message.sketch == nil, let rest = CrewMessage.words(after: CrewMessage.planMarker, in: message.text),
              rest.hasPrefix(Self.lead), rest.hasSuffix(")"),
              let open = rest.range(of: " (", options: .backwards) else { return nil }
        let title = Self.tidy(String(rest[rest.index(rest.startIndex, offsetBy: Self.lead.count)..<open.lowerBound]))
        let spec = String(rest[open.upperBound..<rest.index(before: rest.endIndex)])
        guard !title.isEmpty else { return nil }
        let when: When
        if spec == "today" {
            when = .day(message.crewDay)
        } else if spec == "tomorrow" {
            guard let day = Self.next(after: message.crewDay) else { return nil }
            when = .day(day)
        } else if DateUtils.date(from: spec) != nil, spec.count == 10 {
            when = .day(spec)
        } else {
            let days = spec.split(separator: " ").compactMap { name in
                Self.weekdayNames.firstIndex(of: String(name)).map { $0 + 1 }
            }
            guard !days.isEmpty, days.count == spec.split(separator: " ").count else { return nil }
            when = .weekdays(days.sorted())
        }
        self.init(id: message.messageID, crewID: message.crewID, sender: message.senderProfileID, title: title, when: when)
    }

    init(id: UUID, crewID: CrewID, sender: UUID, title: String, when: When) {
        self.id = id
        self.crewID = crewID
        self.sender = sender
        self.title = title
        self.when = when
    }

    // MARK: When

    /// Whether the plan is for `day`.
    func isFor(_ day: String) -> Bool {
        switch when {
        case .day(let its): return its == day
        case .weekdays(let days):
            guard let date = DateUtils.date(from: day) else { return false }
            return days.contains(DateUtils.keyCalendar().component(.weekday, from: date))
        }
    }

    /// When it is, as the card says it: "today", "tomorrow", "Tue 13 Oct",
    /// or "Mon, Wed, Fri".
    func whenWords(today: String) -> String {
        switch when {
        case .day(let day):
            if day == today { return "today" }
            if day == Self.next(after: today) { return "tomorrow" }
            guard let date = DateUtils.date(from: day) else { return day }
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .weekdays(let days):
            if days.count == 7 { return "every day" }
            return days.map { Self.weekdayNames[$0 - 1] }.joined(separator: ", ")
        }
    }

    /// The title as two plans, or a plan and a win, are told to be the same
    /// one: letters and numbers, lowercased, one space between words.
    static func key(_ title: String) -> String {
        tidy(title).lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    /// Which book entry this is: the crew, the title and when.
    var bookKey: String {
        let spec: String = switch when {
        case .day(let day): "d:\(day)"
        case .weekdays(let days): "w:\(days.map(String.init).joined(separator: ","))"
        }
        return "\(crewID.rawValue)|\(Self.key(title))|\(spec)"
    }

    private static func tidy(_ title: String) -> String {
        let words = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(words.prefix(titleLimit)).trimmingCharacters(in: .whitespaces)
    }

    private static func next(after day: String) -> String? {
        guard let date = DateUtils.date(from: day),
              let next = DateUtils.keyCalendar().date(byAdding: .day, value: 1, to: date) else { return nil }
        return DateUtils.dateString(from: next)
    }
}

extension CrewMessage {
    /// A plan (`GroupPlan`): the marker, then words anyone can read.
    nonisolated static let planMarker = "\u{2063}\u{2062}"
    /// A picture that is shown as it is, with a line under it if there is
    /// one: a sticker, or a photograph brought back (`CrewLookBack`). A
    /// doodle is ink and is tinted; a strip is its own marker.
    nonisolated static let pictureMarker = "\u{2063}\u{2061}"

    /// What follows `marker` at the start of `text`, or nil when it does not
    /// start with it. By scalar: these characters join nothing and are
    /// counted one by one.
    nonisolated static func words(after marker: String, in text: String) -> String? {
        let scalars = Array(text.unicodeScalars), mark = Array(marker.unicodeScalars)
        guard scalars.count >= mark.count, Array(scalars.prefix(mark.count)) == mark else { return nil }
        var rest = String.UnicodeScalarView()
        rest.append(contentsOf: scalars.dropFirst(mark.count))
        return String(rest)
    }

    nonisolated var groupPlan: GroupPlan? { GroupPlan(message: self) }
    nonisolated var isPicture: Bool { sketch != nil && Self.words(after: Self.pictureMarker, in: text) != nil }
    /// The line under a picture, or nothing.
    nonisolated var caption: String { Self.words(after: Self.pictureMarker, in: text) ?? "" }
    /// The words a person wrote, for a line that is only words.
    nonisolated var isPlainWords: Bool {
        sketch == nil && Self.words(after: Self.planMarker, in: text) == nil
    }
}

/// **The group plans you are in**, on this phone. Beside the model, as
/// `PlanSkips` and `RemovedAlbums` are: a new field on a plan line would
/// need the iCloud schema deployed by hand. An entry says which line of your
/// own plan is which crew's plan; nothing here is sent anywhere.
nonisolated enum GroupPlanBook {
    static let key = "crews.groupPlans"

    struct Entry: Codable, Equatable, Sendable {
        var crew: String
        var title: String
        /// One day, or nil for a plan that repeats.
        var day: String?
        var weekdays: [Int]
        /// The line in your own plan.
        var planItem: UUID
        var joinedOn: String
    }

    static func all(defaults: UserDefaults = .standard) -> [String: Entry] {
        guard let data = defaults.data(forKey: key),
              let table = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return table
    }

    private static func write(_ table: [String: Entry], defaults: UserDefaults) {
        if table.isEmpty { defaults.removeObject(forKey: key) }
        else if let data = try? JSONEncoder().encode(table) { defaults.set(data, forKey: key) }
    }

    static func isIn(_ plan: GroupPlan, defaults: UserDefaults = .standard) -> Bool {
        all(defaults: defaults)[plan.bookKey] != nil
    }

    static func keep(_ plan: GroupPlan, planItem: UUID, today: String, defaults: UserDefaults = .standard) {
        var table = all(defaults: defaults)
        var entry = Entry(crew: plan.crewID.rawValue, title: plan.title, day: nil, weekdays: [], planItem: planItem, joinedOn: today)
        switch plan.when {
        case .day(let day): entry.day = day
        case .weekdays(let days): entry.weekdays = days
        }
        table[plan.bookKey] = entry
        // A one-off whose day went by more than a week ago is not read again.
        if let old = DateUtils.date(from: today).flatMap({ DateUtils.keyCalendar().date(byAdding: .day, value: -7, to: $0) }) {
            let cutoff = DateUtils.dateString(from: old)
            table = table.filter { $0.value.day.map { $0 >= cutoff } ?? true }
        }
        write(table, defaults: defaults)
    }

    static func leave(_ bookKey: String, defaults: UserDefaults = .standard) {
        var table = all(defaults: defaults)
        table[bookKey] = nil
        write(table, defaults: defaults)
    }

    /// The crew a line of your plan belongs to, if it is a group plan.
    static func crew(forPlanItem id: UUID, defaults: UserDefaults = .standard) -> CrewID? {
        all(defaults: defaults).values.first { $0.planItem == id }.map { CrewID(rawValue: $0.crew) }
    }

    /// Your plans with `crew` that are for `day`, as the chat draws them on
    /// the day: from your own plan, since the proposal's line is a day long.
    static func plans(in crew: CrewID, on day: String, me: UUID, defaults: UserDefaults = .standard) -> [GroupPlan] {
        all(defaults: defaults).values
            .filter { $0.crew == crew.rawValue }
            .map { entry in
                GroupPlan(id: entry.planItem, crewID: crew, sender: me, title: entry.title,
                          when: entry.day.map { .day($0) } ?? .weekdays(entry.weekdays))
            }
            .filter { $0.isFor(day) }
            .sorted { $0.title < $1.title }
    }
}

extension GroupPlan {
    /// **I'm In**: the plan, as a line of your own plan. The same words
    /// already waiting for that day are used rather than written twice.
    @MainActor
    @discardableResult
    func join(context: ModelContext, today: String = DateUtils.dateString(from: Date()),
              defaults: UserDefaults = .standard) -> PlanItem? {
        let all = (try? context.fetch(FetchDescriptor<PlanItem>())) ?? []
        if let entry = GroupPlanBook.all(defaults: defaults)[bookKey], let held = all.first(where: { $0.id == entry.planItem }) {
            return held
        }
        let line: PlanItem
        switch when {
        case .day(let day):
            line = PlanItem(text: title, order: (all.map(\.order).max() ?? -1) + 1,
                            category: HabitCategory.selectable.randomElement() ?? .health, day: day)
        case .weekdays(let days):
            line = PlanItem(text: title, order: (all.map(\.order).max() ?? -1) + 1,
                            category: HabitCategory.selectable.randomElement() ?? .health)
            line.repeatDaysRaw = days.sorted().map(String.init).joined(separator: ",")
        }
        context.insert(line)
        try? context.save()
        GroupPlanBook.keep(self, planItem: line.id, today: today, defaults: defaults)
        return line
    }
}
