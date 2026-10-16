import Foundation
import Testing

/// **No all capitals, anywhere** (the owner, 2026-10-16: "I'm really not a
/// fan of the all capital look and I feel like it doesn't fit the brand, no
/// all capitals anywhere"). Section titles, dates, months and labels are
/// written as words are. Reads the app's sources; a single initial in an
/// avatar (`prefix(1).uppercased()`, `first...uppercased()`) is a letter,
/// not a shout, and is allowed.
@Suite("No all capitals")
struct NoCapitalsTests {
    @Test("nothing is set in capitals")
    func noCapitals() throws {
        let offenders = try Self.offenders()
        #expect(offenders.isEmpty, "set in capitals:\n\(offenders.joined(separator: "\n"))")
    }

    @Test("the sweep can fail")
    func sweepCatches() {
        #expect(Self.shouts("            .textCase(.uppercase)"))
        #expect(Self.shouts("        return formatter.string(from: date).uppercased()"))
        #expect(!Self.shouts("        Text(String(name.prefix(1)).uppercased())"))
        #expect(!Self.shouts("        shortName.first.map { String($0).uppercased() } ?? \"\""))
        #expect(!Self.shouts("    /// `.textCase(.uppercase)` was here"))
    }

    static func shouts(_ line: String) -> Bool {
        let code = line.trimmingCharacters(in: .whitespaces)
        guard !code.hasPrefix("//") else { return false }
        if code.contains(".textCase(.uppercase)") { return true }
        guard code.contains(".uppercased()") || code.contains(".uppercased ") || code.hasSuffix(".uppercased") else { return false }
        // One letter: an initial, or a sentence's first letter.
        return !(code.contains("prefix(1)") || code.contains(".first") || code.contains("first.uppercased"))
    }

    static func offenders() throws -> [String] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Strata")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else { return ["Strata/ not readable"] }
        var out: [String] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let text = try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
            for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() where shouts(String(line)) {
                out.append("\(rel):\(i + 1)  \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        return out
    }
}
