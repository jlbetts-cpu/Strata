import Foundation

/// **The filter on a reply's words** (App Review 1.2: an app with free text
/// between people needs "a method for filtering objectionable material", with
/// reporting and blocking beside it, which crews already have).
///
/// A short line between friends, so this is a floor, not a censor: slurs and
/// the worst abuse are refused on the sender's phone with a quiet "Try other
/// words", and the receiving phone checks again, so a record written by
/// anything else is not shown either. Everything else is between friends,
/// and Report is one tap away.
nonisolated enum CrewWords {
    /// Matched against the words of a line, letters only, case folded, with
    /// common look-alike swaps undone ("3" → "e"), whole words and the start
    /// of words, so "idiots" is found by "idiot" but "class" is not "ass".
    static let refused: [String] = [
        "nigger", "nigga", "faggot", "fag", "retard", "tranny", "kike", "spic", "chink",
        "wetback", "coon", "dyke", "cunt", "whore", "slut", "rape", "rapist", "kys",
        "killyourself", "kill yourself", "hang yourself", "go die", "neck yourself",
    ]

    static func isAcceptable(_ text: String) -> Bool {
        let folded = fold(text)
        let words = folded.split(separator: " ").map(String.init)
        let joined = words.joined()
        for term in refused {
            let t = fold(term)
            if t.contains(" ") {
                if folded.contains(t) { return false }
            } else if words.contains(where: { $0.hasPrefix(t) }) || joined == t {
                return false
            }
        }
        return true
    }

    /// Lowercased, look-alikes undone, anything not a letter a space.
    static func fold(_ text: String) -> String {
        let swaps: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"]
        let mapped = text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .map { swaps[$0] ?? $0 }
            .map { $0.isLetter ? $0 : " " }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }
}
