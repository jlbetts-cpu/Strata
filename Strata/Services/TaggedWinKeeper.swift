import Foundation
import SwiftData
import UIKit
import os

/// **Keep, on "Sam added you to a win".** A friend's win becomes one of
/// yours: a copy written through the app's normal logging path
/// (`QuickWinService.logWin`), with the same title, colour and size, the
/// win's own date, and its photograph if this phone has it (shared wins,
/// spec 1).
///
/// It is a NEW win with an id of its own, never the crew's copy re-labelled.
/// The tagger editing or withdrawing theirs later must not touch it, and a
/// `HabitLog` carrying the crew win's id would look to the save observer like a win
/// of yours already in that crew, so its next save would overwrite Sam's
/// record with yours. It is not sent anywhere either: the copy is yours, and
/// only the two places a person logs a win ever post one.
///
/// Here, in the app layer, because `SocialStore` takes no `ModelContext`
/// (CLAUDE.md, Crews). It reaches this through `SocialStore.keepTaggedWin`.
@MainActor
enum TaggedWinKeeper {
    private static let log = Logger(subsystem: "Strata", category: "crews.keep")

    /// The phone's own Keep: into the store the app has open, on the tower
    /// it has open, so the copy lands where your wins do.
    static func keepFromCrew(_ win: SharedWin) async {
        let context = SharedModelContainer.shared.mainContext
        var win = win
        // A friend's photo the check has not cleared stays out of your
        // record, as it stays out of your sight.
        if let photo = win.photo, !SocialStore.shared.photoIsShown(photo) { win.photo = nil }
        do {
            let kept = try await keep(win, context: context, tower: LogWinIntent.activeTower(in: context))
            // Who it was with, for the journal's Suggest (`KeptWith`): the
            // friend who tagged you and anyone else on it, never you.
            let me = SocialStore.shared.me
            let crew = SocialStore.shared.crew(win.crewID)
            let names = ([win.senderProfileID] + win.withPeople).filter { $0 != me }
                .compactMap { crew?.member($0)?.shortName }
            KeptWith.record(names, for: kept.id)
            WidgetReloader.reload()
        } catch {
            log.error("could not keep a tagged win: \(error)")
        }
    }

    /// Writes the copy and returns its log.
    @discardableResult
    static func keep(_ win: SharedWin, context: ModelContext, tower: Tower?) async throws -> HabitLog {
        // `icon` is the category somebody chose; `colour` is what the block
        // wears. Two facts, kept as two (`QuickWinService.labels`).
        let spontaneous: HabitCategory? = win.icon == .unlabeled && win.colour != .unlabeled ? win.colour : nil
        let made = try QuickWinService.logWin(
            title: win.title.isEmpty ? QuickWinService.untitled : win.title,
            category: win.icon,
            size: win.blockSize,
            spontaneous: spontaneous,
            on: win.createdAt,
            context: context,
            tower: tower
        )
        guard let entry = (made.habit.logs ?? []).first(where: { $0.id == made.logID }) else {
            throw KeepError.noLog
        }
        // The photograph, copied into your own images: the crew's file is a
        // cache that leaves with the crew day, yours stays with the win.
        // A photo that does not copy leaves the win kept without it.
        if let file = win.photo, let image = UIImage(contentsOfFile: file.path) {
            do {
                entry.imageFileName = try await ImageManager.shared.save(image: image, for: entry.id)
                entry.cropPositionX = win.cropX
                entry.cropPositionY = win.cropY
                try context.save()
            } catch {
                log.error("kept the win, not its photo: \(error)")
            }
        }
        return entry
    }

    enum KeepError: Error { case noLog }
}
