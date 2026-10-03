import Foundation

/// **What this phone wants to hear about**, as iCloud is asked to filter it
/// (`CrewPingRecord`): wins in these crews, reactions in these crews to your
/// own wins, and from nobody in `excluding` (you, and everyone you blocked).
///
/// A muted crew is simply not on the list, and reactions follow each crew's
/// own switch. Kept sorted, so two plans that mean the same thing are equal
/// and an unchanged plan is never sent twice.
nonisolated struct CrewPingPlan: Codable, Equatable, Sendable {
    var winCrews: [String]
    var reactionCrews: [String]
    var me: String
    var excluding: [String]

    init(winCrews: [String], reactionCrews: [String], me: String, excluding: [String]) {
        self.winCrews = winCrews.sorted()
        self.reactionCrews = reactionCrews.sorted()
        self.me = me
        self.excluding = Array(Set(excluding + [me])).sorted()
    }

    /// The two subscriptions' ids, fixed so a new plan replaces the old one.
    static let winsID = "pings-wins"
    static let reactionsID = "pings-reactions"

    var winsPredicate: NSPredicate {
        NSPredicate(format: "%K == %@ AND %K IN %@ AND NOT (%K IN %@)",
                    CrewPingRecord.kind, CrewPingRecord.Kind.win.rawValue,
                    CrewPingRecord.crew, winCrews,
                    CrewPingRecord.sender, excluding)
    }

    var reactionsPredicate: NSPredicate {
        NSPredicate(format: "%K == %@ AND %K == %@ AND %K IN %@ AND NOT (%K IN %@)",
                    CrewPingRecord.kind, CrewPingRecord.Kind.reaction.rawValue,
                    CrewPingRecord.recipient, me,
                    CrewPingRecord.crew, reactionCrews,
                    CrewPingRecord.sender, excluding)
    }
}
