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
/// if it is not, the ask schedules the read. When the read lands, `version`
/// changes, every view that asked is invalidated, and they ask again — this
/// time getting the picture.
///
/// That makes it work in every context SwiftUI has, including the ones with no
/// lifecycle at all: masks, snapshots, `ImageRenderer`, and anything drawn
/// off screen.
@Observable
@MainActor
final class ThumbnailStore {
    static let shared = ThumbnailStore()

    /// Bumped whenever a photograph lands. Read by `image(for:width:)`, so
    /// asking for one is enough to be told when it arrives.
    private(set) var version = 0

    /// What is already being read, so twenty blocks asking for the same
    /// photograph make one read. Not observed: it changes during a view's own
    /// body, and observing it there is what "modifying state during view
    /// update" means.
    @ObservationIgnored private var loading: Set<Key> = []
    /// What was looked for and is not there: a file a log still points at but
    /// which no longer exists on disk.
    @ObservationIgnored private var missing: Set<Key> = []

    private struct Key: Hashable {
        let name: String
        let width: Int
    }

    /// What is known about a photograph right now: the picture if it is in
    /// memory, and whether a read has already been tried and found nothing.
    func state(for fileName: String, width: CGFloat) -> (image: UIImage?, missing: Bool) {
        let rounded = max(1, Int(width.rounded()))
        let picture = image(for: fileName, width: width)
        return (picture, picture == nil && missing.contains(Key(name: fileName, width: rounded)))
    }

    /// The photograph if it is in memory; nil, and a read scheduled, if not.
    func image(for fileName: String, width: CGFloat) -> UIImage? {
        // Observed, so a view that asks is redrawn when anything lands.
        _ = version
        let rounded = max(1, Int(width.rounded()))
        if let cached = ImageManager.shared.cachedThumbnail(fileName: fileName,
                                                            maxWidth: CGFloat(rounded)) {
            return cached
        }
        let key = Key(name: fileName, width: rounded)
        guard !loading.contains(key) else { return nil }
        loading.insert(key)
        Task { @MainActor in
            let found = await ImageManager.shared.loadThumbnail(fileName: fileName,
                                                                maxWidth: CGFloat(rounded))
            loading.remove(key)
            if found == nil { missing.insert(key) } else { missing.remove(key) }
            // Even a read that found nothing bumps this: the view asks again,
            // gets nil again, and can say so rather than waiting forever.
            version &+= 1
        }
        return nil
    }

    /// Forgets what is in flight. For a reset, where the files themselves go.
    func forgetInFlight() {
        loading.removeAll()
        missing.removeAll()
        version &+= 1
    }
}
