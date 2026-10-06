import Foundation

/// **Suggest, after you have started writing** (2026-10-05).
///
/// Suggest used to work only on an empty note, because its question lived in
/// the placeholder and a written note has no placeholder. Now, under written
/// words, the question shows as a faded line, and tapping it writes the
/// question into the note as a heading line: the question, then a new line,
/// with the caret after it, so you keep writing. The goal is that journaling
/// is as easy as it can be.
///
/// **It never writes an answer.** Only the question goes in, cut at its
/// question mark, so nothing the model said after it can reach the note.
nonisolated enum JournalSuggestInsert {
    static func inserting(_ question: String, into note: String) -> (text: String, caret: String.Index) {
        var asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if let mark = asked.firstIndex(of: "?") { asked = String(asked[...mark]) }
        // Trailing blank lines and spaces fold away, so the heading lands one
        // blank line under the last words rather than wherever the caret
        // happened to wander.
        var base = note
        while let last = base.last, last.isWhitespace { base.removeLast() }
        let text = base.isEmpty ? asked + "\n" : base + "\n\n" + asked + "\n"
        return (text, text.endIndex)
    }
}
