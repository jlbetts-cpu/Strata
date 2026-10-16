import Foundation

/// **Your username, @you** (the owner, 2026-10-16: his pick, "3 to 20
/// characters, change monthly", and then "they should keep their username
/// from their login"). Chosen once, kept; changed, if ever, at most once a
/// month, for a typo or a new you. Unique across everyone: claimed in the
/// public database under its own name (`CrewCloud.claimHandle`), first come.
nonisolated enum Handle {
    static let shortest = 3
    static let longest = 20
    /// How long a username is kept before it may be changed again.
    static let changeEvery: TimeInterval = 30 * 86_400
    /// Names nobody may take, so none can pass for the app.
    static let reserved: Set<String> = ["somewins", "some.wins", "some_wins", "strata", "admin", "support",
                                        "help", "official", "team", "staff", "moderator", "apple", "instagram"]

    /// As typed, made a username: no @, no spaces at the ends, lower case.
    static func normalized(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while s.hasPrefix("@") { s.removeFirst() }
        return s
    }

    /// What is wrong with it, in a few words, or nil when it can be had.
    static func problem(_ handle: String) -> String? {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.")
        if handle.count < shortest { return "At least \(shortest) characters" }
        if handle.count > longest { return "At most \(longest) characters" }
        if !handle.allSatisfy(allowed.contains) { return "Letters, numbers, _ and . only" }
        if handle.hasPrefix(".") || handle.hasSuffix(".") { return "Not starting or ending with a dot" }
        if handle.contains("..") { return "No two dots together" }
        if reserved.contains(handle) { return "That one is taken" }
        // Nothing that passes for the app (the review: exact matches let
        // "somewins_official" through).
        let bare = handle.replacingOccurrences(of: "_", with: "").replacingOccurrences(of: ".", with: "")
        if brandStems.contains(where: bare.contains) { return "That one is taken" }
        // A username is somebody's name in public (App Review 1.2).
        if !CrewWords.isAcceptableHandle(handle) { return "Try other words" }
        return nil
    }

    static let brandStems = ["somewins", "stratawins", "official"]
    /// Changed again freely this soon after choosing it: a typo in setup, a
    /// change of mind on the spot (the review: going back in setup silently
    /// kept the first name).
    static let grace: TimeInterval = 10 * 60

    /// When it may next change, or nil when it may now.
    static func nextChange(after setAt: Date?, now: Date = Date()) -> Date? {
        guard let setAt else { return nil }
        if now.timeIntervalSince(setAt) < grace { return nil }
        let next = setAt.addingTimeInterval(changeEvery)
        return next > now ? next : nil
    }

    /// The record that holds a username in the public database.
    static func recordName(_ handle: String) -> String { "handle~" + handle }
}
