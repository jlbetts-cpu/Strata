import Testing
import SwiftUI
import UIKit
@testable import Strata

/// The map's cluster badge: one line whatever the count.
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
}
