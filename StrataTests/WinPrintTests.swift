import Testing
import SwiftUI
@testable import Strata

/// **The print's format, held to the file.**
///
/// The numbers come from Figma `13258-6988` (342 x 452, 8pt radius, the mark
/// 66 x 22 inset 16 from both edges). They are stated as ratios in the
/// component so the print is the same drawing at any size, and a ratio is
/// exactly the kind of thing that gets "tidied" into a rounder number by
/// somebody who does not know where it came from.
@Suite("The print's format")
struct WinPrintTests {

    /// 342:452 is a hair off 3:4 and that is the file's number, not a
    /// rounding of it.
    @Test("The format is the file's, to four figures")
    func aspectMatchesTheFile() {
        #expect(abs(WinPrint.aspect - 342.0 / 452.0) < 0.0001)
        // Portrait, and close to 3:4 without being sold as it.
        #expect(WinPrint.aspect < 1)
        #expect(abs(WinPrint.aspect - 0.75) < 0.01)
    }

    /// **The mark is off by default**, which is the caution written into the
    /// component: a wordmark is a signature where the image leaves the app
    /// and a watermark where it does not. A default of `true` would put it on
    /// every photograph its own owner looks at.
    @Test("Nothing is signed unless the caller asks for it")
    func theMarkIsOptIn() {
        let plain = WinPrint(image: nil)
        #expect(plain.showsMark == false)
    }

    /// The crop is the owner's, from `HabitLog.cropPositionX/Y`. Centre is
    /// only the default for a win nobody moved, and a print that ignored it
    /// would re-frame photographs he had already framed.
    @Test("An unmoved win prints from its middle")
    func cropDefaultsToTheMiddle() {
        #expect(WinPrint(image: nil).crop == .zero)
    }

    /// A win with no photograph is still a win, and gets the same format
    /// rather than a hole. This is the branch that fires for everything
    /// somebody typed rather than shot.
    @Test("A win with no photograph still has something to print")
    func typedWinsStillPrint() {
        let win = ScatterWin(id: "w", image: nil, size: .small, title: "Ran 5k")
        let card = WinPrint(image: nil, win: win)
        #expect(card.win?.id == "w")
    }
}
