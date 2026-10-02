import Testing
@testable import Strata

/// The 2026-10-01 copy cuts on the head maker and the head picker, pinned so
/// that a line deleted for a reason cannot quietly come back.
///
/// **Every one of these has to be able to fail**, which is the rule
/// `docs/screen-audit.md` applies to its own gates: a test that asserts a bug,
/// or that could never go red, is worse than none. So each suite holds BOTH
/// halves — the thing that was cut and the thing that was kept — because a
/// test that only checks the cut would also pass if somebody deleted the line
/// that stays.
@Suite("Settings and Profile copy, 2026-10-01")
struct SettingsAndProfileCopyTests {

    // MARK: - Cut 14: a name the app made up is not drawn

    /// `HeadStore` writes exactly three shapes of name without anybody typing
    /// one: `firstHeadName` ("Me"), the person's own name off Profile, and
    /// "Head <n>" for every head after the first. All three are a caption
    /// repeating a picture of a face, and none of them is drawn.
    @Test("every name HeadStore generates is recognised as generated")
    func generatedNamesAreRecognised() {
        #expect(HeadPickerRow.isGenerated(HeadStore.firstHeadName))
        #expect(HeadPickerRow.isGenerated("Me"))
        for index in 1...12 {
            #expect(HeadPickerRow.isGenerated(HeadStore.defaultName(index: index, person: "")))
        }
        // The first head's default when Profile carries a name.
        #expect(HeadPickerRow.isGenerated(HeadStore.defaultName(index: 0, person: "Jayden"),
                                          person: "Jayden"))
        // Whitespace around a stored name must not make a generated one look
        // chosen.
        #expect(HeadPickerRow.isGenerated("  Me  "))
        #expect(HeadPickerRow.isGenerated("Head 2 "))
    }

    /// The other half, and the half that makes this able to fail: a name
    /// somebody typed is a Fact, it is the only thing that tells two friends'
    /// heads apart, and it is still drawn.
    @Test("a name somebody chose is still drawn")
    func chosenNamesSurvive() {
        #expect(!HeadPickerRow.isGenerated("Sam"))
        #expect(!HeadPickerRow.isGenerated("Mum"))
        #expect(!HeadPickerRow.isGenerated("Head"))
        #expect(!HeadPickerRow.isGenerated("Head two"))
        #expect(!HeadPickerRow.isGenerated("My Head 2"))
        // Somebody else's head, on a phone whose owner is called Jayden.
        #expect(!HeadPickerRow.isGenerated("Sam", person: "Jayden"))
        // And the person's name must only be privileged when there IS one, or
        // every head would be nameless on a phone with an empty Profile.
        #expect(!HeadPickerRow.isGenerated("Sam", person: "   "))
    }

    /// The predicate must not depend on where a head sits in the row.
    /// `HeadStore.defaultName` numbers off the roster count at the moment a
    /// head is made, and deleting a head renumbers nothing, so "Head 3" can be
    /// standing at index 0. An index-based implementation passes every
    /// assertion above and fails this one, which is why it is a test of its
    /// own.
    @Test("a generated name is recognised wherever it ends up in the row")
    func positionDoesNotDecideIt() {
        for name in ["Head 3", "Me", "Head 5"] {
            #expect(HeadPickerRow.isGenerated(name))
        }
    }

    // MARK: - Cut 7: the head maker says only what the head cannot do

    /// A head with every face says nothing under its name. The page is a
    /// portrait, its name, and two words to press.
    @Test("a complete head gets no caption")
    func aCompleteHeadHasNothingToSay() {
        #expect(HeadMakerView.previewCaption(blinks: true, smiles: true, raisesBrows: true,
                                             isSurprised: true, winks: true) == nil)
    }

    /// The honest branch survives, and it is the half that can fail: it names
    /// a thing no picture shows.
    @Test("a head that cannot blink still says so")
    func anIncompleteHeadStillWarns() {
        let line = HeadMakerView.previewCaption(blinks: false, smiles: true, raisesBrows: true,
                                                isSurprised: true, winks: true)
        #expect(line?.contains("won't blink") == true)
        // And the cut sentence is in neither branch.
        #expect(line?.contains("It only shows up where you turn it on") == false)
    }

    /// Several missing faces are still one sentence, not five.
    @Test("a head missing several faces lists them in one sentence")
    func severalMissingFacesReadAsOneLine() {
        let line = HeadMakerView.previewCaption(blinks: false, smiles: false, raisesBrows: true,
                                                isSurprised: true, winks: false)
        #expect(line?.contains("blink or smile or wink") == true)
    }
}
