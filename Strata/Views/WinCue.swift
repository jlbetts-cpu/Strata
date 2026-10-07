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
    /// From when each is asked, and the most wins the second is asked at.
    static let emptyFrom = 9
    static let elseFrom = 15
    static let elseUpTo = 2
    static let defaultsKey = "winCueDay"

    /// The line for now, or nil: one a day, on a day that has not had one.
    static func line(winsToday: Int, now: Date, shownOn: String?, calendar: Calendar = .current) -> String? {
        guard shownOn != DateUtils.dateString(from: now) else { return nil }
        let hour = calendar.component(.hour, from: now)
        guard hour < 23 else { return nil }
        if winsToday == 0, hour >= emptyFrom { return emptyDay }
        if (1...elseUpTo).contains(winsToday), hour >= elseFrom { return anythingElse }
        return nil
    }
}

/// The bubble: the crew chat's own line, ink with the page's colour as its
/// type (`CrewChatSheet.bubbleFace`), so the app speaks the way you do there.
struct WinCueBubble: View {
    let text: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(Typography.bodyLarge)
                .foregroundStyle(WarmBackground.top)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, GridConstants.gapLabel)
                .padding(.vertical, GridConstants.gapItem)
                .background {
                    RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                        .fill(AppColors.inkPrimary)
                }
                .contentShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
        }
        .buttonStyle(.press)
        // Its own width, so its edge is the slot's edge: a wider frame left
        // the pill centred inside it, short of the slot (measured, 25pt).
        .fixedSize()
        .accessibilityHint("Adds a win")
    }
}
