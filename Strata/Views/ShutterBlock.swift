import SwiftUI

/// **The shutter, drawn once.**
///
/// There were two of it. `CameraView.shutter` and `HeadMakerView.shutter` each
/// drew a rim rounded rect and a block rounded rect from the same
/// `shutterBounds` and the same 14.7% corner, in two files, sharing only those
/// two numbers. For a while that cost nothing because nobody touched either.
/// Then the screen audit went through both on the same day and they came out
/// disagreeing: the maker's unlit shutter became an empty rim, measured, and
/// the camera's stayed a dimmed fill. Two copies of one control is a check 3
/// failure the moment anybody improves one of them, which is to say always,
/// eventually.
///
/// **`rim` is 14 and `cornerFraction` is 0.147**, and both were already
/// duplicated as literals. `shutterBounds` adds the rim to the block's cells,
/// so the control takes the shape of the block being drawn: a 2x1 draw makes
/// the whole thing a rectangle and a 2x2 a bigger square. An inner square
/// growing inside a fixed circle said the size in a language you had to learn;
/// the button BECOMING the block says it in the app's own.
///
/// **Unlit is an empty rim, not a dimmed fill**, which is the decision the
/// head maker arrived at by measurement and the one this view carries for
/// both. The old `.white.opacity(0.3)` was dimmed a second time by the
/// disabled-button environment and came out rgb(38, 38, 38) over 3,983 square
/// points: 1.33:1 against the viewfinder, under the 3:1 a shape has to clear,
/// and still the second largest piece of grey on the page. Raising the 0.3 to
/// a token was the obvious move and the wrong one, because `onDarkQuiet` puts
/// rgb(140) across 4,356 square points and makes the one control you cannot
/// use the brightest object on the screen. That is word for word the fault
/// written up against the camera's refused state. So the fill goes instead of
/// changing weight, and the rim carries the control at rgb(128), 5.1:1.
///
/// It also reads as this app's own sentence: an empty slot that fills with a
/// block the moment it is ready, which is exactly what the tower's slot does.
///
/// **No `Legibility` here.** The camera needs it, because its shutter is white
/// inside a white rim with the scene showing through the gap, and on a white
/// wall every part of that goes to one value. The head maker's ground is its
/// own dimmed outline and never white. The caller applies it, so a screen that
/// does not need the treatment does not pay for it.
struct ShutterBlock: View {
    /// The block being drawn. The control takes its shape.
    var size: BlockSize = .small
    /// Filled when a press will take a photograph; an empty rim when it will not.
    var lit: Bool = true
    /// The press squash, 1 at rest.
    var scale: CGFloat = 1

    static let rim: CGFloat = 14
    static let cornerFraction: CGFloat = 0.147

    private var bounds: CGSize { CameraView.shutterBounds(size) }
    private var inner: CGSize {
        CGSize(width: bounds.width - Self.rim, height: bounds.height - Self.rim)
    }
    private var outerRadius: CGFloat {
        min(bounds.width, bounds.height) * Self.cornerFraction
    }

    /// The hit shape, so a caller can hand it to `contentShape` and to its own
    /// gesture without rebuilding the corner a third time.
    var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            shape
                .strokeBorder(.white, lineWidth: 1)
                .frame(width: bounds.width, height: bounds.height)

            // ONE block, in the shape you are drawing.
            //
            // It was a grid of cells, two squares for a 2x1 and four for a
            // 2x2, which was wrong twice over: it read as a keypad, and a 2x1
            // in this app is not two blocks, it is one block two cells wide.
            //
            // `.opacity` rather than a clear fill for the unlit state, because
            // opacity is what animates cleanly on the snappy rung.
            RoundedRectangle(cornerRadius: min(inner.width, inner.height) * Self.cornerFraction,
                             style: .continuous)
                .fill(.white)
                .frame(width: inner.width, height: inner.height)
                .scaleEffect(scale)
                .opacity(lit ? 1 : 0)
        }
    }
}
