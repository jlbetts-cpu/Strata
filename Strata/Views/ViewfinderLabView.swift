import SwiftUI
import CoreImage
import MetalKit

#if DEBUG
/// **The graded viewfinder's own draw path, on screen, with a picture whose
/// top and bottom cannot be confused.**
///
/// Reached with `-strataViewfinderLab 1`.
///
/// The owner has now reported the live viewfinder upside down three times,
/// and I have been wrong about why twice — once by changing the connection
/// angle and the flip in the same commit so they cancelled, and once by
/// reasoning about Core Image's handedness from a probe that rendered into a
/// bare `MTLTexture` rather than into an `MTKView`'s drawable.
///
/// Reasoning about it again would be the third guess. This puts the REAL
/// `GradedPreviewView` on screen, hands it a photograph with sky at the top
/// and rocks at the bottom, and shows the same photograph beside it the
/// ordinary way. If the two disagree, the draw path flips; if they agree, it
/// does not, and the fault is upstream in the capture connection.
///
/// The simulator has a Metal device, so this exercises exactly the code that
/// runs on the phone.
struct ViewfinderLabView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("left: SwiftUI   right: GradedPreviewView")
                .font(.caption)
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                if let reference = UIImage(named: "DemoPhoto1") {
                    Image(uiImage: reference)
                        .resizable()
                        .scaledToFit()
                }
                GradedSurfaceProbe()
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

/// Wraps the real drawing surface and feeds it one frame.
private struct GradedSurfaceProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .darkGray
        guard let view = GradedPreviewView.make(cost: { _ in }) else {
            let label = UILabel()
            label.text = "no Metal device"
            label.textColor = .white
            label.frame = host.bounds
            host.addSubview(label)
            return host
        }
        view.isHidden = false
        view.frame = host.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(view)

        if let photo = UIImage(named: "DemoPhoto1"), let cg = photo.cgImage {
            // Exactly what the camera hands over: a CIImage, drawn by `show`.
            let image = CIImage(cgImage: cg)
            // A moment, so the view has a drawable size before it draws.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                view.show(image)
            }
        }
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
