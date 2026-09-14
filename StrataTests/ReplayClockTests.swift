import Foundation
import Testing
@testable import Strata

@Suite("Replay clock")
struct ReplayClockTests {

    @Test("pausing holds the frame on screen, and resuming never reads earlier than it")
    func pauseHoldsTheRenderedFrame() {
        let clock = ReplayClock()
        clock.start()
        // Frames are drawn for a date a little ahead of now, so the last
        // drawn t can be ahead of what `Date()` would read.
        let ahead = clock.time(at: Date().addingTimeInterval(0.5), duration: 30)
        clock.lastRendered = ahead
        clock.pause()
        #expect(clock.time(at: Date(), duration: 30) == ahead)
        #expect(clock.time(at: Date().addingTimeInterval(5), duration: 30) == ahead)
        clock.resume()
        // A frame dated slightly before the resume must not step back.
        #expect(clock.time(at: Date().addingTimeInterval(-0.1), duration: 30) >= ahead)
        #expect(clock.time(at: Date().addingTimeInterval(1), duration: 30) > ahead + 0.9)
    }

    @Test("a skip while paused moves the held moment forward, never back")
    func skipWhilePaused() {
        let clock = ReplayClock()
        clock.start()
        clock.lastRendered = 3
        clock.pause()
        clock.skip(to: 10)
        #expect(clock.time(at: Date(), duration: 30) == 10)
        clock.skip(to: 5)
        #expect(clock.time(at: Date(), duration: 30) == 10)
    }
}
