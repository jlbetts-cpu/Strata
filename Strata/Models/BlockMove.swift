import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// One tower block, in transit between two positions.
    ///
    /// A private type rather than plain text so nothing dragged in from
    /// another app can land on the tower.
    static let strataBlockMove = UTType(exportedAs: "co.strataapp.blockmove")
}

/// The payload of a rearrange.
///
/// Reordering goes through the system's drag and drop rather than through a
/// `DragGesture`, and this is what gets carried. The reason is measured: any
/// gesture attached to a block inside the tower's ScrollView — high priority,
/// simultaneous, or a long press sequenced before a drag — takes the touch
/// away from the scroll view, and the tower stops scrolling entirely. A UI
/// test that swipes a 44-block tower reports 0.0pt of movement with a gesture
/// attached and scrolls normally without one.
///
/// Drag and drop has no such conflict, because it is the mechanism scroll
/// views were built to coexist with: the system owns the press that lifts an
/// item, so a press that turns into a pan stays a pan. It also brings the
/// things a hand-rolled gesture would have had to reimplement badly — the lift
/// animation, a preview that follows the finger, auto-scrolling when the drag
/// reaches the edge of the tower, and a cancel that returns the item to where
/// it came from.
struct BlockMove: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .strataBlockMove)
    }
}
