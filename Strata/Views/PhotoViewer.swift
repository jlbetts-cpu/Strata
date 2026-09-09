import SwiftUI

/// One photograph, full size.
///
/// Three screens open one — a day, an album and the gallery — so it lives
/// here rather than staying private to whichever one happened to need it
/// first.
struct PhotoViewer: View {
    let fileName: String
    /// What the photograph is of, shown under it. Nil for a win that was
    /// never named.
    var title: String?
    let onClose: () -> Void

    @State private var saving = false
    @State private var saved: Bool?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CachedImageView(fileName: fileName, width: UIScreen.main.bounds.width,
                            height: UIScreen.main.bounds.height, cornerRadius: 0,
                            fullResolution: true)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            GlassIconButton(
                systemName: "xmark",
                tint: .white,
                glyphSize: 16,
                accessibilityLabel: "Close photo",
                action: onClose
            )
            // Clear of the status bar and the Dynamic Island — a close button
            // at y=34 in screen coordinates is not pressable, which this app
            // has already learned once.
            .padding(.top, 58)
            .padding(.trailing, 16)
        }
        .overlay(alignment: .bottom) { footer }
        .statusBarHidden()
    }

    /// The title, and the one thing anybody wants to do with a photograph they
    /// are looking at.
    ///
    /// A visible button rather than a long press or a share sheet: "save this
    /// picture" is the whole action, it is one tap, and it says what it does
    /// before you touch it. Anything hidden behind a gesture is a thing your
    /// grandmother will never find.
    private var footer: some View {
        VStack(spacing: 14) {
            if let title {
                Text(title)
                    .font(Typography.headerMedium)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 8)
            }

            Button {
                save()
            } label: {
                Label(label, systemImage: icon)
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassCapsule()
            .disabled(saving || saved == true)
            .accessibilityLabel(label)
        }
        .padding(.bottom, 44)
        .padding(.horizontal, 24)
        .animation(GridConstants.motionSnappy, value: saved)
    }

    private var label: String {
        if saved == true { return "Saved to Photos" }
        if saved == false { return "Could not save" }
        return saving ? "Saving…" : "Save to Photos"
    }

    private var icon: String {
        if saved == true { return "checkmark" }
        if saved == false { return "exclamationmark.triangle" }
        return "square.and.arrow.down"
    }

    private func save() {
        guard !saving, saved != true else { return }
        saving = true
        Task { @MainActor in
            let image = await ImageManager.shared.loadFullImage(fileName: fileName)
            guard let image else { saving = false; saved = false; return }
            let ok = await PhotoLibrarySaver.save(image, respectingPreference: false)
            saving = false
            saved = ok
            if ok { HapticsEngine.success() }
        }
    }
}

private extension View {
    /// The system's own floating-control material, where it exists.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
