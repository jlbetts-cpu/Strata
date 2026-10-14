import Foundation

/// **What the chat reads off a line** (2026-10-14): a win said in it, words
/// that can be copied, when a time stands above it, whether the thread
/// follows a new one down. Pure, so the tests can hold each rule.
extension CrewMessage {
    /// What a win's line says: its title, or "A win" for one with no name,
    /// as a quote of an unnamed win already reads (`CrewChatSheet.quoted`).
    nonisolated static func winLineText(_ title: String) -> String {
        let words = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(textLimit))
        return words.isEmpty ? "A win" : words
    }

    /// **A win said in the chat** (`SocialStore.sendWinLine`): a line that
    /// quotes its own sender's win and says that win's title and nothing
    /// else. Told apart by its shape, not by a marker, so an older build
    /// still reads it as a plain reply ("↪ Gym / Gym") and no field is new.
    nonisolated static func isWinLine(text: String, sender: UUID, sketch: Bool, quoting win: SharedWin?) -> Bool {
        guard let win, !sketch, win.senderProfileID == sender else { return false }
        return text == winLineText(win.title)
    }

    /// Words a person can copy: a line of text, not a picture, a strip, a
    /// plan's card or a doodle alone.
    nonisolated var hasWordsToCopy: Bool {
        !text.isEmpty && !isStrip && !isPicture && groupPlan == nil && !isToss
    }

    /// How long a line of yours may sit in the outbox before it says it did
    /// not go (M1).
    nonisolated static let unsentAfter: TimeInterval = 10
}

/// **Times, quietly** (M5, `docs/qol-research-2026-10-13.md`): one centred
/// time above the day's first line and above any line that comes an hour or
/// more after the one before. No time under every line, no swipe.
nonisolated enum ChatTimes {
    static let gap: TimeInterval = 3600

    static func showsTime(_ message: CrewMessage, after previous: CrewMessage?) -> Bool {
        guard let previous else { return true }
        return message.createdAt.timeIntervalSince(previous.createdAt) >= gap
    }

    /// "9:41 AM", in the phone's own shape.
    static func words(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

/// **No jump while reading** (M7): a new line takes the thread down only
/// when it is yours or you are already near the newest. Otherwise the
/// thread stays where you are and Newest offers the way down.
nonisolated enum ChatFollow {
    /// Within this much of the foot counts as at the newest: one screen,
    /// as the spec puts it.
    static func follows(newLineIsMine: Bool, distanceFromFoot: CGFloat, screen: CGFloat) -> Bool {
        newLineIsMine || distanceFromFoot <= screen
    }
}

/// **Say the chat is today's** (M6): one quiet line at the top of the
/// thread. When the crew's midnight is not this phone's, it gives the time
/// it falls here.
nonisolated enum ChatClears {
    static let midnight = "Today's chat clears at midnight."

    /// The line for a crew in `crewZone`, read on a phone in `here`.
    static func line(crewZone: TimeZone, here: TimeZone, now: Date) -> String {
        guard crewZone.secondsFromGMT(for: now) != here.secondsFromGMT(for: now) else { return midnight }
        var crewCalendar = Calendar(identifier: .gregorian)
        crewCalendar.timeZone = crewZone
        guard let next = crewCalendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                               matchingPolicy: .nextTime) else { return midnight }
        let style = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: here)
        return "Today's chat clears at \(next.formatted(style))."
    }
}
