import SwiftUI

/// **The Crews page's drawing, yours to change, as the month's is** (the
/// owner, 2026-10-14, his pick "Edit like Memories"). His three friends and
/// the crew's line, with the month drawing's hold: Draw Your Own, Use
/// Original once there is a drawing of yours, and Hide Drawing.
///
/// The same pieces as Memories, not a copy of them: the system's context
/// menu (`MonthArtHold` has why a hold opens a menu rather than an edit
/// mode), the one drawing editor (`MonthDrawingEditor`, at this drawing's
/// 3:2), and the one store (`MonthDrawingStore`), under `key` beside the
/// months'. His drawing is never touched, so Use Original is a delete of
/// yours and nothing else.
///
/// **Hidden, the words and the rows stay.** The line under it is what a crew
/// is for, and the page's rows say the rest, so only the drawing goes. The
/// hold stays on the words, with Show Drawing, so the way back is where the
/// way out was.
struct CrewsArt: View {
    /// The words under the drawing, kept when it is hidden.
    let line: String
    var height: CGFloat

    /// Where a drawing of your own for the Crews page is kept, beside the
    /// months' ("2026-10") in `MonthDrawingStore`.
    static let key = "crews"
    /// Whether the drawing is hidden, on this phone.
    static let hiddenKey = "crews.drawingHidden"
    /// His drawing's shape: 720 by 480.
    static let aspect: CGFloat = 3 / 2
    /// The editor's title.
    static let title = "Crews"

    @AppStorage(Self.hiddenKey) private var hidden = false
    @State private var editing: DrawingMonth?
    /// Your own drawing is deleted by Use Original, so it asks.
    @State private var usingOriginal = false

    var body: some View {
        let own = MonthDrawingStore.shared.drawing(for: Self.key)
        drawing(own)
            .contextMenu {
                Button("Draw Your Own", systemImage: "pencil") {
                    editing = DrawingMonth(id: Self.key)
                }
                if hidden {
                    Button("Show Drawing", systemImage: "eye") {
                        HapticsEngine.lightTap()
                        withAnimation(GridConstants.crossFade) { hidden = false }
                    }
                } else {
                    if own != nil {
                        Button("Use Original", systemImage: "arrow.uturn.backward", role: .destructive) {
                            usingOriginal = true
                        }
                    }
                    Button("Hide Drawing", systemImage: "eye.slash") {
                        HapticsEngine.lightTap()
                        withAnimation(GridConstants.crossFade) { hidden = true }
                    }
                }
            }
            .confirmationDialog("Use the original drawing?", isPresented: $usingOriginal, titleVisibility: .visible) {
                Button("Delete My Drawing", role: .destructive) { MonthDrawingStore.shared.remove(Self.key) }
                Button("Keep Mine", role: .cancel) { }
            } message: {
                Text("Your drawing for Crews will be gone.")
            }
            // A drawing made while it was hidden is shown: drawing one is
            // asking to see it.
            .fullScreenCover(item: $editing, onDismiss: {
                if MonthDrawingStore.shared.hasDrawing(for: Self.key) { hidden = false }
            }) { which in
                MonthDrawingEditor(month: which.id, monthName: Self.title,
                                   canvasAspect: Self.aspect, pageHeight: height)
            }
            #if DEBUG
            // `-strataCrewsDrawing edit`: the editor, open. A hold cannot be
            // scripted. (`-crews.drawingHidden YES` shows the page without it.)
            .task {
                guard DebugHarness.argument("-strataCrewsDrawing") == "edit", editing == nil else { return }
                try? await Task.sleep(for: .seconds(1))
                editing = DrawingMonth(id: Self.key)
            }
            #endif
    }

    @ViewBuilder
    private func drawing(_ own: MonthDrawing?) -> some View {
        if hidden {
            DrawingLine(text: line)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(line)
                .transition(.opacity)
        } else if let own {
            // Yours, drawn on as the month's own drawing is; your words under
            // it, or the crew's line when you wrote none.
            VStack(spacing: GridConstants.gapItem) {
                InkReplay(drawing: own, height: height)
                    .layoutPriority(1)
                DrawingLine(text: own.line ?? line)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(own.line ?? line)
            .transition(.opacity)
        } else if let art = UIImage(named: "CrewsTogether") {
            Illustration(art: art, line: line, height: height,
                         motion: UIImage(named: "CrewsTogetherCheer").map { .cheer(marks: $0) })
                .transition(.opacity)
        }
    }
}
