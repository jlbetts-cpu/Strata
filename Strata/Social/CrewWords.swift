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

    /// Ordinary words that begin with a refused one. **"Spicy noodles" was
    /// refused** (found by review, 2026-10-12): a win of that name never
    /// reached a crew, and a chat line with it would not send.
    static let innocent: Set<String> = [
        "spice", "spices", "spiced", "spicy", "spicier", "spiciest", "spicing",
        "rapeseed",
    ]

    /// **What a phone shows of a name or a title it received** (the
    /// compliance audit, 2026-10-15, §3.3): the chat's lines were checked
    /// on the way in, and crew names, first names and win titles were not;
    /// a crew name now leaves the app on the home screen too. A refused one
    /// is shown as nothing, as an unnamed one already is.
    static func kept(_ text: String) -> String {
        isAcceptableName(text) ? text : ""
    }

    /// **For a name or a title: whole words only** (the review, 2026-10-15).
    /// The chat's check matches the start of a word and runs phrases across
    /// words, which is right for a sentence and wrong for a name: it blanked
    /// "Kyson" and refused "Mango diet". A refused term here has to be a
    /// word of the name, or a phrase of whole words in it.
    static func isAcceptableName(_ text: String) -> Bool {
        let words = fold(text).split(separator: " ").map(String.init).filter { !innocent.contains($0) }
        let padded = " " + words.joined(separator: " ") + " "
        let joined = words.joined()
        for term in refused {
            let t = fold(term)
            if padded.contains(" " + t + " ") || joined == t.replacingOccurrences(of: " ", with: "") { return false }
            // A refused word with an ending is the same word (the second
            // review: "sluts" and "retarded" passed as names).
            if !t.contains(" "), words.contains(where: { $0 == t + "s" || $0 == t + "es" || $0 == t + "ed" || $0 == t + "ing" }) {
                return false
            }
        }
        return true
    }

    static func isAcceptable(_ text: String) -> Bool {
        let folded = fold(text)
        let words = folded.split(separator: " ").map(String.init).filter { !innocent.contains($0) }
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
