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
    /// What this plan listens for. A plan a phone kept from before this
    /// has no version and no longer reads as a plan, so the phone is told
    /// this one, which adds the crew's own subscription (`crewID`,
    /// 2026-10-10).
    var version = 2

    init(winCrews: [String], reactionCrews: [String], me: String, excluding: [String]) {
        self.winCrews = winCrews.sorted()
        self.reactionCrews = reactionCrews.sorted()
        self.me = me
        self.excluding = Array(Set(excluding + [me])).sorted()
    }

    /// The two subscriptions' ids, fixed so a new plan replaces the old one.
    static let winsID = "pings-wins"
    static let reactionsID = "pings-reactions"
    /// A crew's chat lines, joins and milestones (`CrewPingRecord.crewKinds`).
    static let crewID = "pings-crew"

    var crewPredicate: NSPredicate {
        NSPredicate(format: "%K IN %@ AND %K IN %@ AND NOT (%K IN %@)",
                    CrewPingRecord.kind, CrewPingRecord.crewKinds.map(\.rawValue),
                    CrewPingRecord.crew, winCrews,
                    CrewPingRecord.sender, excluding)
    }

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
