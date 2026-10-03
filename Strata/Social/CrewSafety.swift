import CloudKit
import Foundation
import os

/// What App Store guideline 1.2 asks of an app where people share words and
/// photographs, in one place: report, block, and the photo check.
@MainActor
enum CrewSafety {
    private static let log = Logger(subsystem: "Strata", category: "crews.safety")

    enum Reason: String, CaseIterable, Identifiable {
        case inappropriate, harassment, spam, other
        var id: String { rawValue }
        var words: String {
            switch self {
            case .inappropriate: "It's inappropriate"
            case .harassment: "It's harassment or bullying"
            case .spam: "It's spam"
            case .other: "Something else"
            }
        }
    }

    /// A report goes to Sturdy, never to the crew: a `Report` record in the
    /// app's PUBLIC database, which only the developer can read (the record
    /// type's permissions are set that way in the CloudKit dashboard). It
    /// names the crew, the win and the reason. It carries no photograph.
    static func report(win: SharedWin, in crew: CrewID, reason: Reason) async {
        guard let cloud = SocialStore.shared.cloud as? CloudKitCrewCloud else {
            log.notice("report (no cloud): \(reason.rawValue, privacy: .public)")
            return
        }
        let record = CKRecord(recordType: "Report")
        record["crew"] = crew.rawValue as NSString
        record["winID"] = win.winID.uuidString as NSString
        record["sender"] = win.senderProfileID.uuidString as NSString
        record["reporter"] = SocialStore.shared.me.uuidString as NSString
        record["reason"] = reason.rawValue as NSString
        record["title"] = win.title as NSString
        do {
            _ = try await cloud.container.publicCloudDatabase.save(record)
        } catch {
            log.error("report not sent: \(error)")
        }
    }

    /// Blocks someone everywhere. If you started this crew they are also
    /// removed from it; either way they are not told.
    static func block(_ profileID: UUID, from crew: CrewID) async {
        let store = SocialStore.shared
        store.block(profileID)
        if store.crew(crew)?.isOwner(store.me) == true {
            do { try await store.remove(member: profileID, from: crew) } catch {
                log.error("blocked member not removed: \(error)")
            }
        }
    }
}
