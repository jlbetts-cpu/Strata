import UserNotifications

/// **How loudly a crew notification arrives** (the owner, 2026-10-06, picked
/// from the quality-of-life research). Compiled into the app and the
/// notification extension, so a ping and the app's own alert agree.
///
/// A friend's win is news, not a call: it arrives quietly, into Notification
/// Center and the lock screen with no sound and no lighting up, because a
/// sound for every friend's win adds up, and alerts measurably raise
/// inattention (Kushlev, Proulx and Dunn, CHI 2016). Something addressed to
/// YOU still alerts: a reaction or a reply to your own win, and a win that
/// names you as being there.
enum CrewAlertLevel {
    static func apply(to content: UNMutableNotificationContent, kind: CrewPingRecord.Kind, tagsMe: Bool) {
        if kind == .win && !tagsMe {
            content.interruptionLevel = .passive
            content.sound = nil
            content.relevanceScore = 0.2
        } else {
            content.interruptionLevel = .active
            content.sound = .default
            content.relevanceScore = 1
        }
    }
}
