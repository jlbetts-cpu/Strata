import CoreImage.CIFilterBuiltins
import SwiftUI

/// **The invite as a code you can show** (the owner's Launch Pack,
/// 2026-10-12, item 6: "Links, codes, contacts"). For a friend sitting next
/// to you: they point their camera at it and the link opens.
///
/// **A code to show, not one to type.** An invite link is long because it
/// carries the crew's key, which is what keeps a crew sealed. A few letters
/// could not carry it, and would need the key kept where a code looks it
/// up. A square of dots carries the whole link, so nothing changes about
/// how a crew is kept.
///
/// It is the link, so it lets in whoever reads it: it is on screen only
/// while this sheet is.
struct CrewCodeSheet: View {
    let crewID: CrewID

    @Environment(\.dismiss) private var dismiss
    @State private var code: UIImage?
    @State private var problem: String?

    private static let side: CGFloat = 240

    var body: some View {
        NavigationStack {
            VStack(spacing: GridConstants.gapSection) {
                Group {
                    if let code {
                        // Ink on the page's own ground: no white tile on a
                        // dark page, and it still reads, since a camera wants
                        // contrast and not a colour.
                        Image(uiImage: code)
                            .interpolation(.none)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundStyle(AppColors.inkPrimary)
                            .accessibilityLabel("Invite code")
                    } else {
                        Color.clear
                    }
                }
                .frame(width: Self.side, height: Self.side)
                Text(problem ?? "A friend points their camera here.")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, GridConstants.horizontalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Show a Code", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("Done").sheetAction(.confirm) }
                        .buttonStyle(.pressWord)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .task {
            do {
                let url = try await SocialStore.shared.inviteURL(for: crewID)
                code = Self.image(for: url.absoluteString)
                if code == nil { problem = "The code could not be drawn. Send the link instead." }
            } catch {
                problem = CrewErrorWords.say(error, while: .inviting)
            }
        }
    }

    /// The link as a square of dots, clear where it is light, so it can be
    /// drawn in any ink. Nil for text too long to carry.
    static func image(for text: String) -> UIImage? {
        let make = CIFilter.qrCodeGenerator()
        make.message = Data(text.utf8)
        make.correctionLevel = "M"
        guard let dots = make.outputImage else { return nil }
        // Dark dots become opaque, light ones clear.
        let mask = dots.applyingFilter("CIColorInvert").applyingFilter("CIMaskToAlpha")
        guard let cg = CIContext().createCGImage(mask, from: mask.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// What a code holds, read back: for the test that it is the link.
    static func read(_ image: UIImage) -> String? {
        // Onto white, as a camera would see ink on a page.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let side = max(image.size.width, 1) * 8
        let flat = UIGraphicsImageRenderer(size: CGSize(width: side + 64, height: side + 64), format: format).image { c in
            UIColor.white.setFill()
            c.fill(CGRect(x: 0, y: 0, width: side + 64, height: side + 64))
            c.cgContext.interpolationQuality = .none
            image.withTintColor(.black).draw(in: CGRect(x: 32, y: 32, width: side, height: side))
        }
        guard let ci = CIImage(image: flat),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return nil }
        return (detector.features(in: ci).first as? CIQRCodeFeature)?.messageString
    }
}
