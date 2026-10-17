import SwiftUI
import UIKit

/// **Add a Win stands above everything** (the owner, 2026-10-18: "pressing +
/// on the Wins tower and on a crew tower sometimes opens the OLD Add a Win
/// sheet instead of the new camera-first one, and the camera doesn't open").
///
/// Why it happened: the card was an overlay on the app's root, and a sheet
/// always stands above the root, overlays and all. A crew tower keeps its
/// chat resting at its foot as a sheet, so the card opened under it, out of
/// sight ("the camera doesn't open"), and stayed open there; the next press
/// found a card already open and fell back to the old sheet.
///
/// So the card has a window of its own over the app's, above every sheet and
/// cover, wherever Add a Win is asked for. Touches on the tab bar under it go
/// through to the app; everything above the bar is the card's and its dim's.
@MainActor
final class AddWinWindow {
    static let shared = AddWinWindow()
    private var window: PassthroughWindow?

    var isShowing: Bool { window != nil }

    /// `passesBelow`: the tab bar's top, in the window; touches under it go
    /// to the app. Nil where the card stands on the screen's own foot.
    func show(_ content: some View, passesBelow: CGFloat?) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let host = UIHostingController(rootView: AnyView(content))
        host.view.backgroundColor = .clear
        let made = PassthroughWindow(windowScene: scene)
        made.windowLevel = .normal + 1
        made.backgroundColor = .clear
        made.rootViewController = host
        made.passesBelow = passesBelow
        made.isHidden = false
        window = made
    }

    func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}

/// **A window that lets the tab bar through.** By where the touch lands, not
/// by what it lands on: SwiftUI draws its buttons without views of their own,
/// so a window that passed on touches landing on its root passed on every
/// one, the card's own X included (measured, 2026-10-18).
final class PassthroughWindow: UIWindow {
    var passesBelow: CGFloat?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let floor = passesBelow, point.y >= floor { return nil }
        return super.hitTest(point, with: event)
    }
}
