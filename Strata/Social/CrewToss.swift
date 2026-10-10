import Foundation

// MARK: - A drawing thrown onto a crew's tower (taken out 2026-10-10)

/// **Drawings thrown onto a crew's tower are gone** (the owner, 2026-10-10,
/// after using them: "there is no way to delete drawings or move them and
/// honestly dont understand the point of the feature"). Draw was a tab in
/// the crew's sheet; one drawing a person a day fell onto the tower and
/// cleared at midnight. Doodles on your own wins and in the chat stay.
///
/// What stays here is the mark such a drawing travelled under: a chat doodle
/// whose `text` is two invisible format characters (U+2063, U+2064) and
/// nothing else. A phone on a build from before this can still send one, so
/// the chat goes on leaving them out (`SocialStore.messages(in:)`), nothing
/// alerts for one (`SocialStore.pingMessage`, the notification extension),
/// and it ends with the crew's day like every line.
extension CrewMessage {
    nonisolated static let tossMarker = "\u{2063}\u{2064}"

    /// A drawing an older build threw onto the tower: never shown. By the
    /// mark alone: one whose picture has not arrived, or never does, is
    /// still not a line of invisible words in the chat.
    nonisolated var isToss: Bool { text == Self.tossMarker }
}
