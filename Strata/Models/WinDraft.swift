import UIKit

/// What the add sheet is being opened with.
///
/// A value rather than a set of flags, and passed through `.sheet(item:)`
/// rather than sitting in `@State` behind an `isPresented` toggle. That is not
/// a style preference: with a flag, the payload lived separately from the
/// presentation, and swapping the plan sheet for this one ran the incoming
/// sheet's `onDismiss` during reconciliation, which cleared it. Measured — the
/// plan line's text went in correctly and came out nil.
///
/// Carrying the payload as the presentation's identity leaves nothing for
/// anything else to null out.
struct WinDraft: Identifiable {
    let id = UUID()
    /// Pre-fills the title, when the win is written from a plan line.
    var title: String?
    /// A photograph just taken, before `ImageManager` downscales it.
    var photo: UIImage?
    /// The size drawn out of the shutter, so a block pulled wide on the camera
    /// arrives at the sheet already that shape. `.small` unless somebody drew
    /// something else, which is every other way a draft is made.
    var size: BlockSize = .small
    /// Where the photograph was taken, when the app knew. Nil is normal.
    var place: WinPlace? = nil
    /// The plan line this came from, so it can be marked done on save.
    var planItemID: UUID?
}
