import PencilKit
import SwiftUI

/// **The strip, drawn**: paper, the frames packed as the tower is
/// (`StripLayout`), the wordmark and signature at the foot, and over it all
/// the strip's own doodles and stickers (`StripDecor`). Everything is a share
/// of `width`, so the strip in the booth, in Your day and in a saved picture
/// is one picture at three sizes.
///
/// `developed` runs 0 to 1: at 0 the frames are dark and soft, as an
/// undeveloped print is (the owner's reference); the foot is printed and
/// always clear.
struct StripView: View {
    let frames: [PhotoStrip.Frame]
    let day: String
    let signature: String
    var paper: StripPaper = .black
    var width: CGFloat = 160
    var developed: Double = 1
    var decor: InkPicture? = nil

    /// **A clean booth strip** (the owner, 2026-10-07: "I would prefer if
    /// the margins of the photos were a little closer so it can be like a
    /// clean photo strip"). The paper's border stays a border; the space
    /// between pictures is a thin line of paper, as a booth prints it, where
    /// both were 4.5% of the width and the photos read as separate tiles.
    private var margin: CGFloat { width * 0.04 }
    private var gap: CGFloat { width * 0.016 }
    private var inner: CGFloat { width - 2 * margin }
    private var corner: CGFloat { width * 0.008 }

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            if frames.isEmpty {
                // A day with nothing to print yet: one empty frame, so the
                // strip is still a strip.
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(paper.type.opacity(0.08))
                    .frame(width: inner, height: inner * 0.75)
            }
            ForEach(Array(StripLayout.rows(frames.map(\.size)).enumerated()), id: \.offset) { _, row in
                switch row {
                case .pair(let a, let b):
                    HStack(spacing: gap) {
                        picture(frames[a], width: (inner - gap) / 2, height: (inner - gap) / 2)
                        picture(frames[b], width: (inner - gap) / 2, height: (inner - gap) / 2)
                    }
                case .full(let i, let aspect):
                    picture(frames[i], width: inner, height: inner / aspect)
                }
            }
            foot
                .padding(.top, margin)
        }
        .padding(margin)
        .frame(width: width, alignment: .leading)
        .background(paper.ground)
        .overlay { decoration }
        .clipShape(RoundedRectangle(cornerRadius: width * 0.02, style: .continuous))
    }

    private func picture(_ frame: PhotoStrip.Frame, width w: CGFloat, height h: CGFloat) -> some View {
        Image(uiImage: frame.picture)
            .resizable()
            .scaledToFill()
            .frame(width: w, height: h)
            .clipped()
            // Undeveloped: dark and soft, lifting as it develops.
            .blur(radius: (1 - developed) * width * 0.05, opaque: true)
            .overlay { Color.black.opacity((1 - developed) * 0.72) }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .accessibilityLabel(frame.title.isEmpty ? "A win" : frame.title)
    }

    /// The wordmark, and under it who and when: "Jayden · Oct 6".
    private var foot: some View {
        VStack(alignment: .leading, spacing: width * 0.012) {
            Wordmark(size: width * 0.085)
                .foregroundStyle(paper.type)
            Text(signatureLine)
                .font(.custom(Wordmark.fontName, fixedSize: width * 0.052))
                .foregroundStyle(paper.quiet)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.bottom, margin * 0.4)
        .accessibilityElement(children: .combine)
    }

    private var signatureLine: String {
        let date = DateUtils.date(from: day).map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? day
        return signature.isEmpty ? date : "\(signature) \u{00B7} \(date)"
    }

    /// The strip's own doodles and stickers: stickers in their colours, the
    /// ink in the paper's opposite, so it reads on black and on white.
    @ViewBuilder
    private var decoration: some View {
        if let decor {
            ZStack {
                if let stickers = decor.stickers {
                    Image(uiImage: stickers).resizable()
                }
                Image(uiImage: decor.ink).renderingMode(.template).resizable()
                    .foregroundStyle(paper.type)
            }
            .allowsHitTesting(false)
        }
    }
}

/// **The strip's doodles and stickers, kept** per owner and day: the strokes
/// and stickers to edit again, and the picture to draw, on a canvas the
/// strip's own shape at `canvasWidth`.
@MainActor
enum StripDecor {
    static let canvasWidth: CGFloat = 320

    private struct Kept: Codable {
        var strokes: Data
        var width: Double
        var height: Double
        var stickers: [InkSticker]
    }

    private static func base(_ owner: PhotoStrip.Owner, _ day: String) -> String { "strip-\(owner.key)-\(day)" }

    static func save(_ drawing: PKDrawing, stickers: [InkSticker], canvas: CGSize,
                     owner: PhotoStrip.Owner, day: String, files: InkFiles = .shared) {
        let name = base(owner, day)
        guard !drawing.strokes.isEmpty || !stickers.isEmpty,
              let png = InkExport.png(of: drawing, stickers: stickers, in: CGRect(origin: .zero, size: canvas), scale: 3),
              let kept = try? JSONEncoder().encode(Kept(strokes: drawing.dataRepresentation(),
                                                         width: canvas.width, height: canvas.height, stickers: stickers))
        else {
            files.remove(name + ".png"); files.remove(name + ".drawing")
            cache.removeObject(forKey: name as NSString)
            return
        }
        _ = try? files.write(png, named: name + ".png")
        _ = try? files.write(kept, named: name + ".drawing")
        cache.removeObject(forKey: name as NSString)
    }

    static func load(owner: PhotoStrip.Owner, day: String, files: InkFiles = .shared)
        -> (drawing: PKDrawing, canvas: CGSize, stickers: [InkSticker])? {
        guard let data = files.read(base(owner, day) + ".drawing"),
              let kept = try? JSONDecoder().decode(Kept.self, from: data),
              let drawing = try? PKDrawing(data: kept.strokes) else { return nil }
        return (drawing, CGSize(width: kept.width, height: kept.height), kept.stickers)
    }

    static func picture(owner: PhotoStrip.Owner, day: String, files: InkFiles = .shared) -> InkPicture? {
        let name = base(owner, day)
        if let hit = cache.object(forKey: name as NSString) { return hit }
        guard let data = files.read(name + ".png"), let picture = InkLayers.decode(data, scale: 1) else { return nil }
        cache.setObject(picture, forKey: name as NSString)
        return picture
    }

    private static let cache = NSCache<NSString, InkPicture>()
}
