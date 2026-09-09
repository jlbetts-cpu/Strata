import SwiftUI

/// One photograph, full size.
///
/// Two screens open one now — a day, and a curated album — so it lives here
/// rather than staying private to whichever one happened to need it first.
struct PhotoViewer: View {
    let fileName: String
    let onClose: () -> Void

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
        .statusBarHidden()
    }
}
