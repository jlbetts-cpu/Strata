import Foundation
import Testing
@testable import Strata

/// The stories standard, rule 4 (`docs/stories-standard.md`): words get time
/// to be read, a photograph keeps its five seconds.
@Suite("How long a story page stands, 2026-10-17")
struct StoryTimingTests {
    @Test("a photograph stands five seconds")
    func photo() {
        #expect(StoryTiming.photo == 5)
    }

    @Test("a short words page stands no less than a photograph")
    func short() {
        #expect(StoryTiming.words(["Ran", nil, nil]) == 5)
        #expect(StoryTiming.words([nil, nil, nil]) == 5)
    }

    @Test("three ordinary lines get time to be read")
    func three() {
        // 18 words: two seconds to find the first line, a third of a second a word.
        let lines = ["Ran the whole loop without stopping", "Rained the whole walk home", "Honey never goes off"]
        let count = lines.reduce(0) { $0 + $1.split(separator: " ").count }
        #expect(StoryTiming.words(lines) == 2 + Double(count) / 3)
        #expect(StoryTiming.words(lines) > StoryTiming.photo)
    }

    @Test("a long page never stands more than twelve seconds")
    func longest() {
        let long = String(repeating: "word ", count: 80)
        #expect(StoryTiming.words([long, long, long]) == StoryTiming.longest)
    }

    @Test("a missing photograph waits a moment, never the night")
    func photoWait() {
        #expect(StoryTiming.photoWait > 0 && StoryTiming.photoWait < StoryTiming.photo)
    }
}
