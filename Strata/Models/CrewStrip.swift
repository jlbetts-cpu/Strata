import SwiftUI

/// **A crew's strip** (the owner, 2026-10-06: "add it to crew as well and make
/// it feel very fun and easy"). The crew's day as one booth strip: every
/// photograph and doodle sent to it today, in the order they came, signed
/// with the crew's name. A doodled win travels to a crew as its picture, so it
/// is here as yours is; a plain colour block never is.
///
/// It develops whenever it is opened (a crew has no goal yet), and what is on
/// it, its paper and its doodles are this phone's own, kept per crew and day
/// as yours are (`StripKeeping`, `StripDecor`).
extension PhotoStrip {
    @MainActor
    static func crew(_ crewID: CrewID, store: SocialStore = .shared) async -> PhotoStrip {
        let wins = store.today(in: crewID)
            .filter { $0.photo != nil }
            .sorted { $0.createdAt < $1.createdAt }
        let day = wins.first?.crewDay ?? store.crew(crewID).map { CrewDay.string(for: store.now(), in: $0.timeZone) }
            ?? DateUtils.dateString(from: Date())
        var frames: [Frame] = []
        for win in wins {
            guard let url = win.photo, let picture = await picture(at: url) else { continue }
            frames.append(Frame(id: win.winID, title: win.title, size: win.blockSize, picture: picture))
        }
        return PhotoStrip(owner: .crew(crewID.rawValue), day: day, candidates: frames,
                          signature: store.crew(crewID)?.name ?? "")
    }

    /// A crew picture from this phone's cache, read off the main actor.
    private static func picture(at url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
            return ImageManager.resizeIfNeeded(image, maxDimension: 1100)
        }.value
    }
}
