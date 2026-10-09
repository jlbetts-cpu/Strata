import SwiftUI

/// **A cue on the tower, in the chat's own dark bubble** (2026-10-06: testers
/// log "maybe 1 or 2 max"; the owner: "i like when you leave a message in the
/// chat that pop up dark color we dont use that anywhere else but I feel like
/// that could be designed as the queue to help the user").
///
/// A behaviour happens when the ability and a prompt meet (Fogg 2009); one
/// win a day with nothing after it is what no prompt looks like, and this
/// app's only prompt was a notification taken back as soon as a day had a
/// win. This is the prompt at the point of performance (Barkley): over the
/// slot a win is logged in, in the one dark surface the app has, your own
/// line in a crew's chat, so it reads as a message rather than a banner.
///
/// Once a day at most, a beat after the tower settles,
/// gone by itself, and never about what is missing: a question and an
/// invitation, no count and no "you forgot" (`DailyReminder`'s rule, "a cue,
/// not a register"). A tap opens the add sheet, where the ideas over the
/// keyboard take it from there (`WinIdeas`).
nonisolated enum WinCue {
    /// One line each, as a message is: the ideas over the add sheet's
    /// keyboard already say that small ones count, so the bubble only asks.
    static let emptyDay = "What have you done so far?"
    static let anythingElse = "Anything else today?"
    /// One short of the goal: the nearer the goal, the harder people push
    /// (the goal gradient), and it says what the goal is for.
    static let oneMore = "One more and your tower dances."
    /// From when each is asked, and the most wins the second is asked at.
    static let emptyFrom = 9
    static let elseFrom = 15
    static let elseUpTo = 2
    static let defaultsKey = "winCueDay"

    /// The line for now, or nil: one a day, on a day that has not had one.
    /// "Anything else" asks until the day's goal is met (`DailyGoal`), and
    /// with no goal, up to `elseUpTo`.
    static func line(winsToday: Int, now: Date, shownOn: String?, goal: Int? = nil,
                     calendar: Calendar = .current) -> String? {
        guard shownOn != DateUtils.dateString(from: now) else { return nil }
        let hour = calendar.component(.hour, from: now)
        guard hour < 23 else { return nil }
        if winsToday == 0, hour >= emptyFrom { return emptyDay }
        if winsToday >= 1, winsToday < (goal ?? elseUpTo + 1), hour >= elseFrom {
            return goal.map { winsToday == $0 - 1 } == true ? oneMore : anythingElse
        }
        return nil
    }
}

/// **One hint for a first day** (2026-10-08, the owner's pick: "Day-one
/// hints"; onboarding no longer teaches the slot's drag, so the app does, at
/// the moment it is useful). After the first win lands, in the cue's own
/// bubble: the slot can be drawn out for a bigger block. Once ever, never to
/// someone who has already drawn one, and not past the first few wins.
nonisolated enum DayOneHint {
    static let drawOut = "Hold the + and pull it out for a bigger win."
    static let shownKey = "hint.drawOut.shown"
    static let lastChance = 5

    static func line(winsEver: Int, drewBigger: Bool, shown: Bool) -> String? {
        guard !shown, !drewBigger, (1...lastChance).contains(winsEver) else { return nil }
        return drawOut
    }
}
