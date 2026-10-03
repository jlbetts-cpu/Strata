import CloudKit
import Foundation
import SensitiveContentAnalysis
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

    /// A report goes to Some Wins, never to the crew: a `Report` record in the
    /// app's PUBLIC database, readable only by its writer and the Moderator
    /// role (the developer). It names the crew, the win, the reason, the
    /// sender's iCloud ACCOUNT (as CloudKit recorded it, not as the app says),
    /// and carries the photograph's sent copy, so the report can be judged
    /// and the sender banned (the 2026-10-03 audit: a report has to be
    /// something someone can act on).
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
        if let account = cloud.account(of: win.senderProfileID, in: crew) {
            record["senderAccount"] = account as NSString
        }
        if let photo = win.photo, FileManager.default.fileExists(atPath: photo.path) {
            record["photo"] = CKAsset(fileURL: photo)
        }
        do {
            _ = try await cloud.container.publicCloudDatabase.save(record)
        } catch {
            log.error("report not sent: \(error)")
        }
    }

    /// **The photo check** (guideline 1.2's filter). Apple's on-device
    /// analysis, the one behind Sensitive Content Warning, runs on a photo
    /// before it goes to a crew. Flagged: the photo is not sent, the win still
    /// is, and the sender is told plainly.
    ///
    /// When the person has the analysis switched off in Settings it cannot
    /// run, and the photo goes as it would have before the check existed:
    /// the phone's owner has made that choice for every app.
    static func photoIsFine(_ jpeg: Data) async -> Bool {
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else { return true }
        let url = FileManager.default.temporaryDirectory.appending(path: "crew-check-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            try jpeg.write(to: url)
            let result = try await analyzer.analyzeImage(at: url)
            return !result.isSensitive
        } catch {
            // Unable to check is not the same as fine: hold the photo back.
            log.error("photo check failed, photo held back: \(error)")
            return false
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
