import SwiftUI

/// **"Win deleted · Undo", for a few seconds** (the owner, 2026-10-06).
///
/// One line at a time, app-wide. A delete shows it instead of asking first,
/// and a block drawn out of the tower's slot shows it, because a held press
/// or a stray drag is how a win gets logged by accident. It goes by itself
/// after `seconds`, and that is when a deleted win's photographs go.
@MainActor
@Observable
final class UndoLine {
    static let shared = UndoLine()

    struct Line: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    /// Long enough to read four words and reach the button, short enough
    /// that it is gone before it is furniture (Material's snackbar is 4 to
    /// 10 seconds; this is the low end, because it says almost nothing).
    static let seconds: Double = 5

    private(set) var line: Line?
    @ObservationIgnored private var undoAction: (() -> Void)?
    @ObservationIgnored private var expireAction: (() -> Void)?

    /// Shows `text` with Undo. A line already showing is finished first, so
    /// its expiry still runs.
    func show(_ text: String, undo: @escaping () -> Void, expire: @escaping () -> Void = {}) {
        finish()
        let shown = Line(text: text)
        line = shown
        undoAction = undo
        expireAction = expire
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.seconds))
            if line?.id == shown.id { finish() }
        }
    }

    func undo() {
        let action = undoAction
        undoAction = nil
        expireAction = nil
        line = nil
        action?()
    }

    /// The chance has passed: run what waited for it.
    func finish() {
        let expire = expireAction
        undoAction = nil
        expireAction = nil
        line = nil
        expire?()
    }
}

/// The line, at the foot of a tab, over the content and above the tab bar.
struct UndoLineOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var undo: UndoLine { UndoLine.shared }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let line = undo.line {
                    UndoLineView(text: line.text) { undo.undo() }
                        .padding(.bottom, GridConstants.gapWide)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .id(line.id)
                }
            }
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: undo.line)
            // Leaving the app ends the chance, so nothing waits on a clock
            // that is not running.
            .onChange(of: scenePhase) { _, phase in if phase == .background { undo.finish() } }
    }
}

extension View {
    func undoLine() -> some View { modifier(UndoLineOverlay()) }
}

/// The words and Undo on one capsule of the page's glass. The capsule holds a
/// button, so its glass does not answer the finger itself
/// (`glassCapsule(interactive:)`); the word does.
private struct UndoLineView: View {
    let text: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: GridConstants.gapWide) {
            Text(text)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkPrimary)
            Button {
                HapticsEngine.lightTap()
                undo()
            } label: {
                Text("Undo")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            // The word presses as every word button does. The capsule's
            // glass is still, so this is not the scaling-press-on-interactive-
            // glass pairing that cancelled taps on a phone.
            .buttonStyle(.pressWord)
        }
        .padding(.leading, GridConstants.gapWide)
        .padding(.trailing, GridConstants.gapLabel)
        .glassCapsule(onPage: true, interactive: false)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Undo", undo)
    }
}
