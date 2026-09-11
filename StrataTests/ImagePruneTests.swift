import Foundation
import Testing
import UIKit

@testable import Strata

/// The sweep that reclaims abandoned photographs, and the guard that stops it
/// reclaiming the wrong ones.
///
/// **This is the most dangerous code in the app.** Everything else here reads
/// user photographs; this deletes them. The interesting tests are not the ones
/// where it works — they are the ones where a caller gets it wrong.
@MainActor
struct ImagePruneTests {

    /// Real files in the real image directory, cleaned up afterwards. There is
    /// no way to test a function about the file system without one.
    private func makeFile(_ name: String) throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let url = ImageManager.shared.imageDirectoryForTesting
            .appendingPathComponent(name)
        try image.pngData()!.write(to: url)
        return name
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(
            atPath: ImageManager.shared.imageDirectoryForTesting
                .appendingPathComponent(name).path)
    }

    private func cleanUp(_ names: [String]) {
        for name in names {
            try? FileManager.default.removeItem(
                at: ImageManager.shared.imageDirectoryForTesting
                    .appendingPathComponent(name))
        }
    }

    @Test("an unreferenced file is removed and a referenced one is not")
    func pruneRemovesOnlyOrphans() throws {
        let keep = try makeFile("prune-test-keep-\(UUID().uuidString).png")
        let drop = try makeFile("prune-test-drop-\(UUID().uuidString).png")
        defer { cleanUp([keep, drop]) }

        // Everything else already on disk stays referenced, so a real store's
        // photographs are not collateral in this test.
        var referenced = Set(ImageManager.shared.allStoredFileNamesForBenchmark())
        referenced.remove(drop)

        _ = ImageManager.shared.pruneOrphans(referenced: referenced)
        #expect(exists(keep), "a referenced photograph was deleted")
        #expect(!exists(drop), "an orphan survived")
    }

    /// **The failure that would erase somebody's life.**
    ///
    /// If a caller ever hands over an empty set — which is what `try?` on a
    /// failed fetch produces — every photograph on disk is unreferenced by
    /// definition. This test does not assert that the function refuses; it
    /// cannot know the difference. It asserts that it deletes EVERYTHING, so
    /// the contract is written down in a test rather than only in a comment,
    /// and anyone tempted to call it with `try?` has to delete this first.
    @Test("an empty set deletes everything — which is why the caller must not guess")
    func emptySetIsTotal() throws {
        let doomed = try makeFile("prune-test-doomed-\(UUID().uuidString).png")
        defer { cleanUp([doomed]) }

        let before = ImageManager.shared.allStoredFileNamesForBenchmark().count
        let removed = ImageManager.shared.pruneOrphans(referenced: [])
        #expect(removed == before,
                "an empty set must be understood as 'nothing is referenced'")
        #expect(!exists(doomed))
    }
}
