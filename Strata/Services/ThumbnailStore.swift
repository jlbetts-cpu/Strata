import Observation
import SwiftUI
import UIKit

/// Photographs, fetched because somebody DREW them rather than because a view
/// appeared.
///
/// **The bug this exists for.** `CachedImageView` started its load from
/// `.task(id:)`, which runs when SwiftUI decides a view has appeared. In the
/// Memories grid that fires and the photographs arrive. In the tower it does
/// not: the block's body is evaluated, the photograph's view is built with the
/// right file name, and the task never runs — so the load is never even
/// requested and the block keeps its colour. Photographed and traced from the
/// owner's phone and reproduced in the simulator: "my photos I take dont go on
/// the blocks or stay on the blocks in any screen."
///
/// So loading no longer depends on appearing. A view ASKS for a photograph
/// while drawing itself; if it is in memory it is returned there and then, and
/// if it is not, the ask schedules the read. When the read lands, that
/// photograph's `Slot` changes, the views that asked for THAT photograph are
/// invalidated, and they ask again — this time getting the picture.
///
/// That makes it work in every context SwiftUI has, including the ones with no
/// lifecycle at all: masks, snapshots, `ImageRenderer`, and anything drawn
/// off screen.
///
/// **Per photograph, not one global number** (2026-09-15). This was a single
/// observed `version` bumped by every landing, so one photograph arriving
/// re-evaluated every image view in the app. Measured with `-strataPerfProbe`
/// over a 365-day seed, the photo viewer ran about 4,000 image-view bodies a
/// second and never stopped, and the idle map tab about 1,000.
///
/// **And at most `maxInFlight` reads at once.** A fling asks for every cell it
/// passes; the extra asks wait in `deferred`, newest first, and are asked
/// AGAIN (their slot is bumped) as places free up. A view that has gone by
/// then asks for nothing, so its read never happens. The decode itself stays
/// on `ImageManager`'s concurrent queue, which was measured and is kept.
@MainActor
final class ThumbnailStore {
    static let shared = ThumbnailStore()

    /// What one photograph at one width has to say: bumped when its read
    /// lands. A view reads its own slot while drawing, so it is invalidated by
    /// its own photograph and by nothing else.
    @Observable
    final class Slot {
        fileprivate(set) var generation = 0
    }

    /// How many reads may be in flight at once. See the type's comment.
    static let maxInFlight = 48

    /// **The widths a thumbnail is decoded at, in pixels.** A request is
    /// rounded UP to the next of these, so nothing is ever softer than it was,
    /// and one decode serves nearby sizes: the filmstrip (222px) and a
    /// one-cell month block (about 255px) share one. Above the last, a width
    /// is used as asked. 384 is there for the map: without it the map's 264px
    /// would decode at 512, nearly four times the pixels, for eighty blocks.
    ///
    /// The map's own rule still holds on top of this — one `decodeWidth` for
    /// every block whatever size it draws at — and `ReplayImages` does not go
    /// through here at all: a replay's decodes are sized to its blocks and
    /// feed `ImageRenderer`, so they are exactly what they were.
    static let widthBuckets: [Int] = [128, 256, 384, 512, 768, 1024]

    static func bucket(_ pixels: CGFloat) -> Int {
        let wanted = max(1, Int(pixels.rounded(.up)))
        return widthBuckets.first { $0 >= wanted } ?? wanted
    }

    private struct Key: Hashable {
        let name: String
        let width: Int
    }

    /// None of these is observed: they change during a view's own body, and
    /// observing them there is what "modifying state during view update"
    /// means. Only a `Slot`'s generation is observed.
    private var slots: [Key: Slot] = [:]
    /// What is already being read, so twenty blocks asking for the same
    /// photograph make one read.
    private var loading: Set<Key> = []
    /// What was looked for and is not there: a file a log still points at but
    /// which no longer exists on disk.
    private var missing: Set<Key> = []
    /// Asked for while `maxInFlight` reads were running. Newest last.
    private var deferred: [Key] = []
    /// Deferred asks whose slot was just bumped, each holding a place in the
    /// flight until its view asks again or `reaskGrace` passes.
    private var reasked: [Key: ContinuousClock.Instant] = [:]
    private static let reaskGrace: Duration = .milliseconds(250)
    private var pumpPending = false
    #if DEBUG
    /// `-strataPerfProbe`: when a photograph not in memory was first asked
    /// for, so its arrival in a view that is still asking can be timed. A
    /// view that has gone never asks again and is never counted.
    private var askedAt: [Key: CFTimeInterval] = [:]
    #endif

    private func slot(_ key: Key) -> Slot {
        if let slot = slots[key] { return slot }
        let slot = Slot()
        slots[key] = slot
        return slot
    }

    /// What is known about a photograph right now: the picture if it is in
    /// memory, and whether a read has already been tried and found nothing.
    func state(for fileName: String, width: CGFloat) -> (image: UIImage?, missing: Bool) {
        let picture = image(for: fileName, width: width)
        let key = Key(name: fileName, width: Self.bucket(width))
        return (picture, picture == nil && missing.contains(key))
    }

    /// The photograph if it is in memory; nil, and a read scheduled, if not.
    /// `width` is in pixels.
    func image(for fileName: String, width: CGFloat) -> UIImage? {
        let key = Key(name: fileName, width: Self.bucket(width))
        // Observed, so a view that asks is redrawn when THIS photograph lands.
        _ = slot(key).generation
        if let cached = ImageManager.shared.cachedThumbnail(fileName: fileName,
                                                            maxWidth: CGFloat(key.width)) {
            #if DEBUG
            if PerfProbe.isOn, let asked = askedAt.removeValue(forKey: key) {
                PerfProbe.sample("ThumbAskToShown", ms: (CACurrentMediaTime() - asked) * 1000)
            }
            #endif
            return cached
        }
        #if DEBUG
        if PerfProbe.isOn, askedAt[key] == nil { askedAt[key] = CACurrentMediaTime() }
        #endif
        guard !loading.contains(key) else { return nil }
        let heldPlace = reasked.removeValue(forKey: key) != nil
        if let queued = deferred.firstIndex(of: key) { deferred.remove(at: queued) }
        guard heldPlace || loading.count + reasked.count < Self.maxInFlight else {
            deferred.append(key)
            return nil
        }
        schedule(key)
        return nil
    }

    private func schedule(_ key: Key) {
        loading.insert(key)
        #if DEBUG
        PerfProbe.count("ThumbScheduled")
        #endif
        Task { @MainActor in
            let found = await ImageManager.shared.loadThumbnail(fileName: key.name,
                                                                maxWidth: CGFloat(key.width))
            loading.remove(key)
            if found == nil { missing.insert(key) } else { missing.remove(key) }
            // Even a read that found nothing bumps this: the view asks again,
            // gets nil again, and can say so rather than waiting forever.
            slot(key).generation &+= 1
            #if DEBUG
            PerfProbe.count("ThumbLanded")
            #endif
            pump()
        }
    }

    /// Hands free places in the flight to the newest deferred asks, by
    /// bumping their slots so their views ask again. A place is held for
    /// `reaskGrace`; a view that has gone never asks, and its place frees.
    private func pump() {
        let now = ContinuousClock.now
        reasked = reasked.filter { now - $0.value < Self.reaskGrace }
        while loading.count + reasked.count < Self.maxInFlight, let key = deferred.popLast() {
            reasked[key] = now
            slot(key).generation &+= 1
        }
        guard !reasked.isEmpty, !pumpPending else { return }
        pumpPending = true
        Task { @MainActor in
            try? await Task.sleep(for: Self.reaskGrace)
            pumpPending = false
            pump()
        }
    }

    /// Forgets what is in flight. For a reset, where the files themselves go.
    func forgetInFlight() {
        loading.removeAll()
        missing.removeAll()
        deferred.removeAll()
        reasked.removeAll()
        for slot in slots.values { slot.generation &+= 1 }
    }

    #if DEBUG
    /// For the tests: a slot's generation, read WITHOUT observing it.
    func generationForTesting(_ fileName: String, width: CGFloat) -> Int {
        slots[Key(name: fileName, width: Self.bucket(width))]?.generation ?? 0
    }
    var inFlightForTesting: Int { loading.count }
    var deferredForTesting: Int { deferred.count }
    #endif
}
