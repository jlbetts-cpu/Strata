import SwiftUI

/// What is left of the drawer.
///
/// **The drawer itself is gone** (2026-09-30, with the owner's call that the
/// page IS the Memories screen rather than a card over the map, see
/// `MemoriesView`, which records the same removal). `MemoriesDrawer<Content>`
/// and `DrawerDetent` are deleted here with it: the view had no callers, and
/// the detent's only reader was `DebugHarness.openDrawer`, which nothing read
/// in turn. `-strataOpenDrawer` has therefore done nothing since the drawer
/// came off, and five UI tests still pass it; their launch arguments are stale,
/// not broken, and are left for whoever owns those tests.
///
/// **The two Swift rules the deleted types were the record of, kept here
/// because `DeviceFrame` and `TowerCompanionLayer` both point at this file for
/// them:**
///
/// 1. Static STORED properties are not allowed in a generic type at all, which
///    is why this enum exists beside the view instead of inside it.
/// 2. A type nested in a generic picks the generic up: `DrawerDetent` nested
///    would have been `MemoriesDrawer<Content>.Detent`, so the `@State` holding
///    it had to name a `Content`, pinning the panel to that guess (`AnyView`)
///    and rejecting the real content type.
///
/// **This enum is one alias and should not outlive its last caller.**
/// `tabBarClearance` is `GridConstants.tabBarClearance` under a second name,
/// kept only because `MemoriesMapView` reads it at two sites. Point those two
/// at `GridConstants` and this file goes.
enum DrawerMetrics {
    /// The tab bar's allowance, so the page's last row is not under it.
    ///
    /// The value lives in `GridConstants`, because three files need it and two
    /// of them were carrying the number 110 as a literal.
    static let tabBarClearance = GridConstants.tabBarClearance
}
