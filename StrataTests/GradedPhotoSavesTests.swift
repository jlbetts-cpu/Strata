import Testing
import UIKit
import CoreImage
@testable import Strata

/// **A graded photograph has to survive the trip to disk.**
///
/// The owner: "the filtered photo never loaded on the block", and the block
/// showed "just the colour, no photo" — so the win was saved WITHOUT its
/// image. The ungraded path skips `render` entirely, which means the fault
/// is somewhere between the grade and the file, and that whole stretch is
/// testable on a machine with no camera.
///
/// It is worth being blunt about why this test did not exist: `render` was
/// changed from writing 16 bit float to writing 8 bit in the memory pass,
/// and nothing anywhere asserted that what it produces can be encoded. A
/// pipeline that returns a beautiful `UIImage` nobody can save is a pipeline
/// that passes every test it has.
struct GradedPhotoSavesTests {

    private func photo() -> UIImage? { UIImage(named: "LookPreview") }

    @Test("Every look produces a photograph that still has pixels")
    func gradingKeepsAnImage() throws {
        let source = try #require(photo(), "LookPreview must be in the app bundle")
        for look in FilmLook.all where look.kind != .none {
            let graded = FilmLookRenderer.shared.render(source, look: look,
                                                        pulledStops: look.pullStops)
            let cg = try #require(graded.cgImage,
                                  "\(look.kind.name) produced a UIImage with no CGImage")
            #expect(cg.width > 0 && cg.height > 0,
                    "\(look.kind.name) produced an empty image")
            #expect(graded.size.width > 0, "\(look.kind.name) has no size")
        }
    }

    /// **The one that matters: it has to ENCODE.** A CGImage that cannot be
    /// turned into HEIC or JPEG is a win with no photograph on it, which is
    /// exactly what he saw.
    @Test("Every look produces a photograph that encodes to a file")
    func gradedPhotosEncode() throws {
        let source = try #require(photo())
        for look in FilmLook.all where look.kind != .none {
            let graded = FilmLookRenderer.shared.render(source, look: look,
                                                        pulledStops: look.pullStops)
            let heic = ImageManager.encodeHEICForSeeding(image: graded, quality: 0.85)
            let jpeg = graded.jpegData(compressionQuality: 0.85)
            #expect(heic != nil || jpeg != nil,
                    "\(look.kind.name) cannot be written to a file at all")
            if let heic {
                #expect(heic.count > 1000, "\(look.kind.name) encoded to \(heic.count) bytes")
            }
            if let jpeg {
                #expect(jpeg.count > 1000, "\(look.kind.name) encoded to \(jpeg.count) bytes")
            }
        }
    }

    /// **The whole trip, at the size a real photograph is.**
    ///
    /// The first two tests used the 640px bundled picture and passed, which
    /// proved nothing about the case that broke: a RAW developed frame is
    /// about 4000px, in Display P3, and it goes through `resizeIfNeeded` and
    /// an encoder before anything writes it. `AddWinSheet` swallows a failure
    /// here with `try?`, and the comment beside that line already records
    /// what it looks like when it goes wrong — "blocks kept their colour and
    /// the gallery stayed empty", which is word for word what he saw.
    @Test("A full size graded photograph saves to disk and comes back with a name")
    func fullSizeGradedPhotosSave() async throws {
        let small = try #require(photo())
        // Up to the size a phone actually takes, so the resize path runs.
        let bigSide: CGFloat = 4032
        let scale = bigSide / max(small.size.width, small.size.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let big = UIGraphicsImageRenderer(
            size: CGSize(width: small.size.width * scale, height: small.size.height * scale),
            format: format
        ).image { _ in
            small.draw(in: CGRect(origin: .zero,
                                  size: CGSize(width: small.size.width * scale,
                                               height: small.size.height * scale)))
        }

        for look in FilmLook.all where look.kind != .none {
            let graded = FilmLookRenderer.shared.render(big, look: look,
                                                        pulledStops: look.pullStops)
            let id = UUID()
            let name = try? await ImageManager.shared.save(image: graded, for: id)
            #expect(name != nil,
                    "\(look.kind.name) at \(Int(graded.size.width))x\(Int(graded.size.height)) would not save, so its win keeps its colour and loses the photograph")
            if let name { ImageManager.shared.deleteImage(fileName: name) }
        }
    }

    /// The head sticker path composites before grading, so the graded result
    /// may carry alpha. An image with an alpha channel is the classic thing
    /// that encodes to nothing in a format that does not take one.
    @Test("A graded photograph is opaque, whatever went in")
    func gradedPhotosAreOpaque() throws {
        let source = try #require(photo())
        for look in FilmLook.all where look.kind != .none {
            let graded = FilmLookRenderer.shared.render(source, look: look)
            let info = try #require(graded.cgImage?.alphaInfo)
            #expect(info != .first && info != .last,
                    "\(look.kind.name) carries straight alpha, which encoders reject")
        }
    }
}
