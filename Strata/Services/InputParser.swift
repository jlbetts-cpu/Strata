import Foundation
import UIKit

/// Parsed output from natural language habit input.
struct ParsedInput {
    let title: String
    let scheduledTime: String?       // "HH:mm" format
    let frequency: [DayCode]?        // nil = use default (all days)
    let isTask: Bool                 // detected "today"/"tomorrow" = one-time task
    let scheduledDate: String?       // "yyyy-MM-dd" for tasks
    let suggestedCategory: HabitCategory?
}

/// Regex-based natural language parser for habit/task input.
/// Detects time ("at 8am"), frequency ("every morning"), dates ("tomorrow"),
/// days ("on mon wed fri"), and category keywords.
enum InputParser {

    // MARK: - Pre-compiled Regexes (compiled once at launch, reused forever)

    private static let timeRegex = try! NSRegularExpression(
        pattern: #"(?:\b)at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)(?:\b)"#,
        options: .caseInsensitive
    )
    private static let noonRegex = try! NSRegularExpression(
        pattern: #"(?:\b)at\s+(noon|midnight)(?:\b)"#,
        options: .caseInsensitive
    )
    private static let onDaysRegex = try! NSRegularExpression(
        pattern: #"(?:\b)on\s+((?:(?:sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?)[\s,]*)+)(?:\b)"#,
        options: .caseInsensitive
    )
    private static let todayRegex = try! NSRegularExpression(
        pattern: #"(?:\b)today(?:\b)"#,
        options: .caseInsensitive
    )
    private static let tomorrowRegex = try! NSRegularExpression(
        pattern: #"(?:\b)tomorrow(?:\b)"#,
        options: .caseInsensitive
    )

    private static let freqEntries: [(NSRegularExpression, [DayCode]?, String?)] = [
        (try! NSRegularExpression(pattern: #"(?:\b)every\s+morning(?:\b)"#, options: .caseInsensitive), DayCode.allCases, "08:00"),
        (try! NSRegularExpression(pattern: #"(?:\b)every\s+evening(?:\b)"#, options: .caseInsensitive), DayCode.allCases, "18:00"),
        (try! NSRegularExpression(pattern: #"(?:\b)every\s+night(?:\b)"#, options: .caseInsensitive), DayCode.allCases, "21:00"),
        (try! NSRegularExpression(pattern: #"(?:\b)every\s+day(?:\b)"#, options: .caseInsensitive), DayCode.allCases, nil),
        (try! NSRegularExpression(pattern: #"(?:\b)daily(?:\b)"#, options: .caseInsensitive), DayCode.allCases, nil),
        (try! NSRegularExpression(pattern: #"(?:\b)weekdays(?:\b)"#, options: .caseInsensitive), [.mo, .tu, .we, .th, .fr], nil),
        (try! NSRegularExpression(pattern: #"(?:\b)weekends(?:\b)"#, options: .caseInsensitive), [.sa, .su], nil),
    ]

    private static let dayMapRegexes: [(NSRegularExpression, DayCode)] = [
        (try! NSRegularExpression(pattern: "sunday|sun", options: .caseInsensitive), .su),
        (try! NSRegularExpression(pattern: "monday|mon", options: .caseInsensitive), .mo),
        (try! NSRegularExpression(pattern: "tuesday|tue|tues", options: .caseInsensitive), .tu),
        (try! NSRegularExpression(pattern: "wednesday|wed", options: .caseInsensitive), .we),
        (try! NSRegularExpression(pattern: "thursday|thu|thur|thurs", options: .caseInsensitive), .th),
        (try! NSRegularExpression(pattern: "friday|fri", options: .caseInsensitive), .fr),
        (try! NSRegularExpression(pattern: "saturday|sat", options: .caseInsensitive), .sa),
    ]

    private static let highlightRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"(?:\b)at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)(?:\b)"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"(?:\b)at\s+(?:noon|midnight)(?:\b)"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"(?:\b)every\s+(?:morning|evening|night|day)(?:\b)"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"(?:\b)(?:daily|weekdays|weekends)(?:\b)"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"(?:\b)on\s+(?:(?:sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?)[\s,]*)+"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"(?:\b)(?:today|tomorrow)(?:\b)"#, options: .caseInsensitive),
    ]

    // MARK: - Parse

    /// Parses raw input text into structured habit metadata.
    /// Returns the cleaned title (metadata keywords stripped) + detected fields.
    static func parse(_ input: String) -> ParsedInput {
        var text = input.trimmingCharacters(in: .whitespaces)
        var time: String? = nil
        var frequency: [DayCode]? = nil
        var isTask = false
        var scheduledDate: String? = nil

        // --- Time detection: "at 8am", "at 2:30pm", "at noon", "at midnight" ---
        if let match = timeRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let hourRange = Range(match.range(at: 1), in: text)!
            let minuteRange = match.range(at: 2).location != NSNotFound ? Range(match.range(at: 2), in: text) : nil
            let periodRange = Range(match.range(at: 3), in: text)!

            var hour = Int(text[hourRange])!
            let minute = minuteRange.map { Int(text[$0])! } ?? 0
            let period = text[periodRange].lowercased()

            if period == "pm" && hour != 12 { hour += 12 }
            if period == "am" && hour == 12 { hour = 0 }

            time = String(format: "%02d:%02d", hour, minute)
            text = timeRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // "at noon" / "at midnight"
        if let match = noonRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let wordRange = Range(match.range(at: 1), in: text)!
            let word = text[wordRange].lowercased()
            time = word == "noon" ? "12:00" : "00:00"
            text = noonRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // --- Frequency: "every morning", "every evening", "daily", "weekdays" ---
        for (regex, days, defaultTime) in freqEntries {
            if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                frequency = days
                if time == nil, let dt = defaultTime { time = dt }
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
                break
            }
        }

        // --- Day names: "on monday", "on mon wed fri" ---
        if let match = onDaysRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let daysRange = Range(match.range(at: 1), in: text)!
            let daysText = String(text[daysRange]).lowercased()
            var detectedDays: [DayCode] = []
            for (dayRegex, code) in dayMapRegexes {
                if dayRegex.firstMatch(in: daysText, range: NSRange(daysText.startIndex..., in: daysText)) != nil {
                    detectedDays.append(code)
                }
            }
            if !detectedDays.isEmpty {
                frequency = detectedDays
            }
            text = onDaysRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // --- Date: "today", "tomorrow" → makes it a task ---
        if todayRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            isTask = true
            scheduledDate = TimelineViewModel.dateString(from: Date.now)
            frequency = []
            text = todayRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        if tomorrowRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            isTask = true
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
            scheduledDate = TimelineViewModel.dateString(from: tomorrow)
            frequency = []
            text = tomorrowRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // Clean up extra whitespace
        let title = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        // Category suggestion (reuse existing engine)
        let category = CategorySuggestionEngine.suggest(for: title)

        return ParsedInput(
            title: title,
            scheduledTime: time,
            frequency: frequency,
            isTask: isTask,
            scheduledDate: scheduledDate,
            suggestedCategory: category
        )
    }

    // MARK: - Highlight (Pre-attentive Processing)

    /// Returns an NSAttributedString with detected metadata keywords highlighted
    /// in the accent color. Used by HighlightingTextField for real-time rendering.
    static func highlight(_ text: String, baseFont: UIFont, accentColor: UIColor) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.label
            ]
        )

        for regex in highlightRegexes {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: accentColor, range: match.range)
            }
        }

        return attributed
    }
}
