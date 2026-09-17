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
/// passes; the extra asks wait in `deferredSeq`, newest first, and are asked
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
    /// and sizes a few pixels apart share one decode instead of one each.
    ///
    /// **Steps of about 18%, so no decode holds more than 1.4 times the pixels
    /// it was asked for.** The first set was 128/256/384/512/768/1024, which
    /// put the gallery's 389px cells on 512 (1.73x the pixels) and anything
    /// just over 512 on 768 (2.25x). Above the last, a width is used as asked.
    ///
    /// A caller that already passes one stable `decodeWidth` — the map, whose
    /// rule is one width for every block — is not bucketed at all (`exact`).
    /// `ReplayImages` does not come through here: a replay's decodes are sized
    /// to its blocks and feed `ImageRenderer`, and are exactly what they were.
    static let widthBuckets: [Int] = [128, 144, 168, 192, 224, 264, 312, 368, 432, 504,
                                      592, 696, 816, 960, 1024]

    static func bucket(_ pixels: CGFloat, exact: Bool = false) -> Int {
        let wanted = max(1, Int(pixels.rounded(.up)))
        if exact { return wanted }
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
    /// What was looked for and is not there — a file a log still points at
    /// but which no longer exists on disk — and when that was found out.
    ///
    /// **Not read again while it is recent.** A read that found nothing bumps
    /// the slot so the view can say "missing", and the view asking again used
    /// to schedule the read again: a read and a body for every missing file on
    /// every frame, for ever, each holding a place in the flight. Asked again
    /// after `missingRetry`, it is read again, in case the file has arrived.
    private var missing: [Key: ContinuousClock.Instant] = [:]
    private static let missingRetry: Duration = .seconds(10)
    /// Asked for while `maxInFlight` reads were running, as an ordered set:
    /// `deferredOrder` holds each ask with its sequence number, newest last,
    /// and an entry counts only while `deferredSeq` still gives its key that
    /// number. Removing a key is a dictionary write, not a scan; stale entries
    /// are skipped when popped and compacted away.
    private var deferredSeq: [Key: Int] = [:]
    private var deferredOrder: [(key: Key, seq: Int)] = []
    private var deferredHead = 0
    private var nextSeq = 0
    /// At most this many asks wait. Past it the OLDEST is let go — after a
    /// fling those are the cells that scrolled away first — and its slot is
    /// bumped, so a view still showing it asks again and queues as the newest.
    static let maxDeferred = maxInFlight * 2
    /// Deferred asks whose slot was just bumped, each holding a place in the
    /// flight until its view asks again or `reaskGrace` passes. About three
    /// frames: a view that is still there asks again on its next body pass,
    /// and one that has gone should not keep a visible cell waiting. It was
    /// 250ms.
    private var reasked: [Key: ContinuousClock.Instant] = [:]
    private static let reaskGrace: Duration = .milliseconds(50)
    private var pumpPending = false

    // MARK: Prefetch lane

    /// **At most this many prefetch reads at once** (2026-09-16), on
    /// `ImageManager`'s utility-QoS lane. Small on purpose: prefetch is a
    /// guess about what comes next, and a guess must never crowd out what is
    /// on screen now. Visible reads keep their own `maxInFlight`.
    static let maxPrefetchInFlight = 8
    /// Prefetch asks not yet started, oldest first. A visible ask for the same
    /// key takes it over; `cancelPrefetch` drops it.
    private var prefetchPending: [Key] = []
    private var prefetchQueued: Set<Key> = []
    /// Prefetch reads running, each with the flag that drops it if it has not
    /// started by the time its cell has gone.
    private var prefetchFlags: [Key: ImageManager.CancelFlag] = [:]
    #if DEBUG
    /// Keys a prefetch put in memory that no view has shown yet. A view that
    /// then finds its picture already there is a prefetch that was AHEAD,
    /// counted as `PrefetchUsed`; the measure the spec asks for.
    private var prefetched: Set<Key> = []
    #endif
    private var trimPending = false
    #if DEBUG
    /// `-strataPerfProbe`: when a photograph not in memory was first asked
    /// for, so its arrival in a view that is still asking can be timed. A
    /// view that has gone never asks again and is never counted.
    private var askedAt: [Key: CFTimeInterval] = [:]
    private var askedFresh: [Key: CFTimeInterval] = [:]
    #endif

    private func slot(_ key: Key) -> Slot {
        if let slot = slots[key] { return slot }
        let slot = Slot()
        slots[key] = slot
        return slot
    }

    /// What is known about a photograph right now: the picture if it is in
    /// memory, and whether a read has already been tried and found nothing.
    func state(for fileName: String, width: CGFloat, exact: Bool = false) -> (image: UIImage?, missing: Bool) {
        let picture = image(for: fileName, width: width, exact: exact)
        let key = Key(name: fileName, width: Self.bucket(width, exact: exact))
        return (picture, picture == nil && missing[key] != nil)
    }

    /// The photograph if it is in memory; nil, and a read scheduled, if not.
    /// `width` is in pixels; `exact` skips the bucket (see `widthBuckets`).
    func image(for fileName: String, width: CGFloat, exact: Bool = false) -> UIImage? {
        let key = Key(name: fileName, width: Self.bucket(width, exact: exact))
        // Observed, so a view that asks is redrawn when THIS photograph lands.
        _ = slot(key).generation
        #if DEBUG
        let lookupStart = PerfProbe.isOn ? CACurrentMediaTime() : 0
        #endif
        if let cached = ImageManager.shared.cachedThumbnail(fileName: fileName,
                                                            maxWidth: CGFloat(key.width)) {
            #if DEBUG
            if PerfProbe.isOn {
                if prefetched.remove(key) != nil { PerfProbe.count("PrefetchUsed") }
                if let asked = askedAt.removeValue(forKey: key) {
                    let ms = (CACurrentMediaTime() - asked) * 1000
                    PerfProbe.sample("ThumbAskToShown", ms: ms)
                    // `ThumbAskToShown` keeps the first ask for as long as the
                    // picture is not shown, so a cell that scrolled away and
                    // came back a minute later reports a minute. Kept as it was
                    // so the before and after compare like for like; this one
                    // is forgotten when the asking view leaves the screen
                    // (`debugViewLeft`), so it is the wait a person sat through.
                    if let fresh = askedFresh.removeValue(forKey: key) {
                        PerfProbe.sample("ThumbFreshAskToShown", ms: (CACurrentMediaTime() - fresh) * 1000)
                    }
                } else {
                    // **The warm number, measured rather than asserted.** A
                    // picture already in memory is handed back inside the
                    // asking view's own body, so its cost is this lookup and
                    // nothing else. Sampling it is the only way to say "warm
                    // is same-frame" with a figure behind it.
                    PerfProbe.sample("ThumbWarm", ms: (CACurrentMediaTime() - lookupStart) * 1000)
                }
            }
            #endif
            return cached
        }
        #if DEBUG
        if PerfProbe.isOn {
            let now = CACurrentMediaTime()
            if askedAt[key] == nil { askedAt[key] = now }
            if askedFresh[key] == nil { askedFresh[key] = now }
        }
        #endif
        guard !loading.contains(key) else { return nil }
        // On the prefetch lane already. **Decoding: wait for it** — its
        // landing bumps this slot like any other. **Not yet decoding: take it
        // over** (fix round 1): a prefetch queued behind every visible read on
        // an unmigrated library used to hold an on-screen cell blank until it
        // reached the front at utility priority. Cancelled here, its slot is
        // freed at once and this ask is scheduled on the visible lane.
        if let flag = prefetchFlags[key] {
            if flag.cancelIfNotStarted() {
                prefetchFlags[key] = nil
                #if DEBUG
                PerfProbe.count("PrefetchTakenOver")
                #endif
                pumpPrefetch()
            } else if !flag.isSet {
                return nil
            }
        }
        if prefetchQueued.remove(key) != nil {
            prefetchPending.removeAll { $0 == key }
        }
        if let found = missing[key] {
            guard ContinuousClock.now - found >= Self.missingRetry else { return nil }
            missing[key] = nil
        }
        let heldPlace = reasked.removeValue(forKey: key) != nil
        deferredSeq[key] = nil
        guard heldPlace || loading.count + reasked.count < Self.maxInFlight else {
            queueDeferred(key)
            return nil
        }
        schedule(key)
        return nil
    }

    private func queueDeferred(_ key: Key) {
        nextSeq &+= 1
        deferredSeq[key] = nextSeq
        deferredOrder.append((key, nextSeq))
        // **Letting one go tells its view, so it happens after the pass, not
        // during it.** Trimming inline bumped another key's slot while a body
        // was running: a pass asking for more than `maxInFlight + maxDeferred`
        // keys (a cold map comes close) made every extra ask invalidate an
        // older view, and those views asked again on the next pass. Coalesced
        // to the next turn, one trim covers the whole pass, and only asks made
        // before it was scheduled can be let go.
        if deferredSeq.count > Self.maxDeferred, !trimPending {
            trimPending = true
            let madeBeforeThisTurn = nextSeq
            Task { @MainActor in
                trimPending = false
                trim(keeping: madeBeforeThisTurn)
            }
        }
        if deferredHead > 256, deferredHead * 2 > deferredOrder.count {
            deferredOrder.removeFirst(deferredHead)
            deferredHead = 0
        }
    }

    /// Lets the oldest waiting asks go, down to `maxDeferred`, and tells each
    /// one's views so anything still showing it asks again. Never touches an
    /// ask made after `seq`, which is this pass's own.
    private func trim(keeping seq: Int) {
        while deferredSeq.count > Self.maxDeferred {
            guard let entry = nextOldestDeferred(), entry.seq <= seq else { break }
            _ = popOldestDeferred()
            slot(entry.key).generation &+= 1
        }
    }

    /// The oldest ask still waiting, without removing it.
    private func nextOldestDeferred() -> (key: Key, seq: Int)? {
        while deferredHead < deferredOrder.count {
            let entry = deferredOrder[deferredHead]
            if isCurrent(entry) { return entry }
            deferredHead += 1
        }
        return nil
    }

    private func isCurrent(_ entry: (key: Key, seq: Int)) -> Bool {
        deferredSeq[entry.key] == entry.seq
    }

    private func popNewestDeferred() -> Key? {
        while deferredOrder.count > deferredHead, let entry = deferredOrder.popLast() {
            if isCurrent(entry) { deferredSeq[entry.key] = nil; return entry.key }
        }
        return nil
    }

    private func popOldestDeferred() -> Key? {
        while deferredHead < deferredOrder.count {
            let entry = deferredOrder[deferredHead]
            deferredHead += 1
            if isCurrent(entry) { deferredSeq[entry.key] = nil; return entry.key }
        }
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
            missing[key] = found == nil ? ContinuousClock.now : nil
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
        while loading.count + reasked.count < Self.maxInFlight, let key = popNewestDeferred() {
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

    /// Reads these photographs ahead of anybody drawing them, on the prefetch
    /// lane. **An extra ask, never a replacement**: a view still asks while
    /// drawing (CLAUDE.md), and this only means the answer is usually already
    /// there. Nothing is observed here, so a prefetch invalidates no view
    /// until its picture lands, and then only the views that asked for it.
    func prefetch(_ fileNames: [String], width: CGFloat, exact: Bool = false) {
        for name in fileNames where !name.isEmpty {
            let key = Key(name: name, width: Self.bucket(width, exact: exact))
            guard !loading.contains(key), prefetchFlags[key] == nil, !prefetchQueued.contains(key),
                  missing[key] == nil, deferredSeq[key] == nil,
                  ImageManager.shared.cachedThumbnail(fileName: name, maxWidth: CGFloat(key.width)) == nil
            else { continue }
            prefetchQueued.insert(key)
            prefetchPending.append(key)
        }
        pumpPrefetch()
    }

    /// Drops prefetch asks for photographs that are no longer coming: not
    /// started, they never start; started, they are dropped if their decode
    /// has not begun. A decode already running finishes — it cannot be
    /// interrupted, and from a 320px derivative it is a few milliseconds.
    func cancelPrefetch(_ fileNames: [String], width: CGFloat, exact: Bool = false) {
        let keys = Set(fileNames.map { Key(name: $0, width: Self.bucket(width, exact: exact)) })
        guard !keys.isEmpty else { return }
        let before = prefetchPending.count
        prefetchPending.removeAll { keys.contains($0) }
        prefetchQueued.subtract(keys)
        var dropped = before - prefetchPending.count
        for key in keys {
            guard let flag = prefetchFlags[key], flag.cancelIfNotStarted() else { continue }
            // **Its place is free now, and anyone waiting on it is told**
            // (fix round 1). A view that asked while this was queued got nil
            // and is waiting on this slot; without the bump it waited until
            // the dropped read limped through the queue and exited.
            prefetchFlags[key] = nil
            slot(key).generation &+= 1
            dropped += 1
        }
        #if DEBUG
        if dropped > 0 { PerfProbe.count("PrefetchCancelled") }
        #endif
        if dropped > 0 { pumpPrefetch() }
    }

    private func pumpPrefetch() {
        while prefetchFlags.count < Self.maxPrefetchInFlight, !prefetchPending.isEmpty {
            let key = prefetchPending.removeFirst()
            prefetchQueued.remove(key)
            let flag = ImageManager.CancelFlag()
            prefetchFlags[key] = flag
            Task { @MainActor in
                let found = await ImageManager.shared.loadThumbnail(
                    fileName: key.name, maxWidth: CGFloat(key.width), lane: .prefetch, cancelled: flag)
                // Only this read's own entry: a cancelled one may already have
                // been replaced by a new prefetch of the same key.
                if prefetchFlags[key] === flag { prefetchFlags[key] = nil }
                if found != nil {
                    #if DEBUG
                    PerfProbe.count("PrefetchLanded")
                    if PerfProbe.isOn { prefetched.insert(key) }
                    #endif
                }
                // Landed or dropped, a view waiting on it asks again: it gets
                // the picture, or schedules its own visible read. A dropped
                // or failed prefetch is never recorded as missing — only a
                // visible read decides that.
                slot(key).generation &+= 1
                pumpPrefetch()
            }
        }
    }

    /// Whether anything a person is looking at is being read or waiting to
    /// be, on any lane: what the drawer's off-screen build waits out. (The
    /// migration checks `ImageManager.hasForegroundReads` directly, off the
    /// main actor.)
    var hasVisibleWork: Bool {
        !loading.isEmpty || !deferredSeq.isEmpty || !prefetchFlags.isEmpty || ImageManager.shared.hasForegroundReads
    }

    /// A photograph has just been written to disk under this name: anything
    /// that looked for it and found nothing may now find it.
    ///
    /// Without this, a file that arrives after its log — a restore, or a save
    /// landing late — stayed "missing" for up to `missingRetry`, and even then
    /// only if some unrelated redraw made a view ask again.
    func fileArrived(_ fileName: String) {
        let waiting = missing.keys.filter { $0.name == fileName }
        guard !waiting.isEmpty else { return }
        for key in waiting {
            missing[key] = nil
            slot(key).generation &+= 1
        }
    }

    /// Forgets what is in flight. For a reset, where the files themselves go.
    func forgetInFlight() {
        loading.removeAll()
        missing.removeAll()
        deferredSeq.removeAll()
        deferredOrder.removeAll()
        deferredHead = 0
        reasked.removeAll()
        for flag in prefetchFlags.values { flag.set() }
        prefetchFlags.removeAll()
        prefetchPending.removeAll()
        prefetchQueued.removeAll()
        for slot in slots.values { slot.generation &+= 1 }
    }

    #if DEBUG
    /// A view showing this photograph has left the screen: its wait, if it
    /// was still waiting, did not end in a picture anybody saw.
    func debugViewLeft(_ fileName: String, width: CGFloat, exact: Bool) {
        guard PerfProbe.isOn else { return }
        askedFresh[Key(name: fileName, width: Self.bucket(width, exact: exact))] = nil
    }

    /// For the tests: a slot's generation, read WITHOUT observing it.
    func generationForTesting(_ fileName: String, width: CGFloat) -> Int {
        slots[Key(name: fileName, width: Self.bucket(width))]?.generation ?? 0
    }
    var inFlightForTesting: Int { loading.count }
    var prefetchInFlightForTesting: Int { prefetchFlags.count }
    var prefetchPendingForTesting: Int { prefetchPending.count }
    var deferredForTesting: Int { deferredSeq.count }
    /// The file names still waiting for a place.
    var waitingNamesForTesting: Set<String> { Set(deferredSeq.keys.map(\.name)) }
    #endif
}
