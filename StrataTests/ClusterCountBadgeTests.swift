import Testing
import SwiftUI
import UIKit
@testable import Strata

/// The map's cluster badge: one line whatever the count, and small enough to
/// be a label on a photograph rather than a lid over one.
///
/// **The two constants moved on 2026-10-01, 24 x 22 to 18 x 18**, with the
/// horizontal padding going from `gapTight` to the grid's own gutter, because
/// the badge had only ever been measured against itself. Measured against the
/// 44pt cell every badged block wears, a one-digit capsule rendered 24.3 x 22:
/// half the block's height, 55% of its width, 27.6% of its area, and 36.7% with
/// two digits in it. It is 18.0 x 18 and 16.7% now.
/// `PlaceBlock.countBadge` carries the full working and the three alternatives
/// that were rejected.
///
/// Nothing here was relaxed to let that through. Every assertion below already
/// read the constants rather than a literal, so all of them hold at the new
/// numbers and would hold again if the numbers moved. What is ADDED is
/// `theCapsuleClearsItsOwnLineBox`, which is the assertion that can fail at a
/// smaller height: without it `height` could be taken under the numeral's own
/// line box, `minHeight` would quietly stop driving the frame, and
/// `clusterBadgeIsOneLine` would start failing with a message about wrapping
/// for a reason that has nothing to do with wrapping.
@MainActor
struct ClusterCountBadgeTests {

    /// 236 wrapped to "23" over "6" on the map: the badge sits in a block's
    /// overlay, which offers it less width than three digits need. Offered
    /// almost nothing, it must stay one line and grow sideways instead.
    @Test(arguments: [2, 99, 236, 999, 1000, 9999])
    func clusterBadgeIsOneLine(count: Int) {
        let host = UIHostingController(rootView: ClusterCountBadge(count: count))
        let narrow = host.sizeThatFits(in: CGSize(width: 10, height: 500))
        let roomy = host.sizeThatFits(in: CGSize(width: 500, height: 500))
        #expect(narrow.height == ClusterCountBadge.height,
                "count \(count) wrapped: \(narrow)")
        #expect(narrow.width == roomy.width)
        #expect(narrow.width >= ClusterCountBadge.minWidth)
    }

    /// And a wider count really does get a wider capsule.
    @Test func widerCountsWidenTheCapsule() {
        func width(_ n: Int) -> CGFloat {
            UIHostingController(rootView: ClusterCountBadge(count: n))
                .sizeThatFits(in: CGSize(width: 10, height: 500)).width
        }
        #expect(width(999) > width(99))
        #expect(width(1000) > width(999))
    }

    /// **The floor under `height`, so shrinking it again has to argue with a
    /// number** (2026-10-01).
    ///
    /// `height` is a `minHeight`, so it only decides the capsule while it is
    /// larger than the text it is wrapped around. The text is
    /// `Typography.numeral(13)`, which `StrataFont.size` resolves to SF at 13pt
    /// Medium through `UIFontMetrics`: cap 9.16pt, line box 15.31 at the default
    /// Dynamic Type size. Below that the constant stops being the capsule's
    /// height and starts being a number nothing reads, which is the failure
    /// mode that is invisible in a screenshot and obvious here.
    ///
    /// The font is rebuilt the way `StrataFont.size` builds it rather than
    /// hard-coded at 15.31, so a change to the face or to the scaling moves
    /// this floor with it instead of leaving a stale literal behind.
    @Test func theCapsuleClearsItsOwnLineBox() {
        let points = UIFontMetrics(forTextStyle: .body).scaledValue(for: 13)
        let lineBox = UIFont.systemFont(ofSize: points, weight: .medium).lineHeight
        #expect(ClusterCountBadge.height >= lineBox,
                "height \(ClusterCountBadge.height) is under the numeral's own line box \(lineBox)")
        // And it is the thing driving the frame, not a number the text has
        // already overtaken: measured, not declared.
        let measured = UIHostingController(rootView: ClusterCountBadge(count: 3))
            .sizeThatFits(in: CGSize(width: 10, height: 500))
        #expect(measured.height == ClusterCountBadge.height)
    }
}
