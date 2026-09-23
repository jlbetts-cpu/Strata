import SwiftUI

#if DEBUG
/// **The blades, held still at every stage, over a real photograph.**
///
/// Reached with `-strataShutterLab 1`. The shutter fires in a fifth of a
/// second and a simulator has no camera, so the only way to check the SHAPE
/// is to stop it. Two things are being looked at and neither is visible in
/// motion: whether the corners of the frame are covered at full openness (a
/// hexagon sized by its circumradius leaves dark wedges in all four), and
/// whether the sweep reads as blades rather than as a hole shrinking.
///
/// Not shipped: behind `#if DEBUG` and a launch argument.
struct ShutterLabView: View {
    private static let stages: [CGFloat] = [1.0, 0.82, 0.62, 0.42, 0.22, 0.0]
    @State private var live: CGFloat = 1
    @State private var blades = 6

    var body: some View {
        ZStack {
            Grey.g950.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text("Shutter")
                        .font(Typography.screenTitleSerif)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // One at full size, driven by the slider, over a picture.
                    frame(openness: live)
                        .frame(height: 320)

                    HStack(spacing: 12) {
                        Text("open")
                            .font(Typography.bodySmall).foregroundStyle(Grey.g400)
                        Slider(value: $live, in: 0...1)
                        Text(String(format: "%.2f", live))
                            .font(Typography.bodySmall.monospacedDigit())
                            .foregroundStyle(Grey.g400)
                    }

                    Stepper("Blades: \(blades)", value: $blades, in: 3...10)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Grey.g400)

                    Button("Fire") { fire() }
                        .font(Typography.headerSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).frame(height: 40)
                        .background(Capsule().fill(Grey.g800))

                    Divider().overlay(Grey.g800)

                    // Every stage at once, so the sweep is judged as a
                    // sequence rather than one frame at a time.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                              spacing: 12) {
                        ForEach(Self.stages, id: \.self) { stage in
                            VStack(spacing: 6) {
                                frame(openness: stage).frame(height: 150)
                                Text(String(format: "%.2f", stage))
                                    .font(Typography.caption2).foregroundStyle(Grey.g400)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func frame(openness: CGFloat) -> some View {
        ZStack {
            if let photo = UIImage(named: "LookPreview") {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Color.gray
            }
            IrisShutter(openness: openness, blades: blades)
                .fill(.black, style: FillStyle(eoFill: true))
        }
        .clipped()
    }

    private func fire() {
        withAnimation(.easeIn(duration: ShutterBlink.shutDuration)) { live = 0 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(ShutterBlink.shutDuration + ShutterBlink.darkDuration))
            withAnimation(.easeOut(duration: ShutterBlink.openDuration)) { live = 1 }
        }
    }
}
#endif
