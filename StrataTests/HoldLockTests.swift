import CoreGraphics
import Foundation
import Testing
@testable import Strata

/// The rest that chooses a drawn size (`HoldLock`), on the slot and the
/// shutter alike (the owner, 2026-10-16: "It only commits after I've held
/// still in the new size or spot for a short moment").
@MainActor
@Suite("Hold lock")
struct HoldLockTests {
    private func wait(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    @Test("a rest locks, and only once it has lasted")
    func restLocks() async {
        let lock = HoldLock()
        lock.begin(at: .zero)
        await wait(HoldLock.rest * 0.5)
        #expect(!lock.locked, "locked before the rest was over")
        await wait(HoldLock.rest * 0.5 + 0.25)
        #expect(lock.locked, "a full rest did not lock")
        #expect(lock.end(), "letting go after the lock did not report it")
        #expect(!lock.locked)
    }

    @Test("a new size starts the rest over")
    func sizeRestarts() async {
        let lock = HoldLock()
        lock.begin(at: .zero)
        await wait(HoldLock.rest * 0.7)
        lock.moved(to: CGPoint(x: 50, y: 0), sizeChanged: true)
        await wait(HoldLock.rest * 0.7)
        #expect(!lock.locked, "the rest carried over a change of size")
        #expect(!lock.end(), "let go before the new rest, and it still committed")
    }

    @Test("a tremble is still a rest; a wander is not")
    func slack() async {
        let lock = HoldLock()
        lock.begin(at: .zero)
        lock.moved(to: CGPoint(x: HoldLock.slack - 2, y: 0), sizeChanged: false)
        await wait(HoldLock.rest + 0.25)
        #expect(lock.locked, "a few points of tremble reset the rest")
        lock.moved(to: CGPoint(x: HoldLock.slack * 3, y: 0), sizeChanged: false)
        #expect(!lock.locked, "a finger that wandered off kept its lock")
        lock.end()
    }

    @Test("a lock never arrives after the finger is up")
    func noLateLock() async {
        let lock = HoldLock()
        lock.begin(at: .zero)
        await wait(HoldLock.rest * 0.5)
        #expect(!lock.end())
        await wait(HoldLock.rest)
        #expect(!lock.locked, "the fill finished after it was let go")
    }
}
