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

    /// What a report is about: one win, a person (their name, photo and
    /// head), or the crew itself (its name and picture, which anyone in it
    /// may change). The 2026-10-03 audit: only today's wins could be
    /// reported, and a name or a picture could not be at all.
    enum Subject {
        case win(SharedWin)
        case person(CrewMember)
        case crew(Crew)
        /// A reply's line (`Reaction.line`), seen by the win's owner.
        case reply(Reaction)
    }

    /// A report goes to Some Wins, never to the crew: a `Report` record in the
    /// app's PUBLIC database, readable only by its writer and the Moderator
    /// role (the developer). It names the crew, what is reported, the reason,
    /// the iCloud ACCOUNT behind it (as CloudKit recorded it, not as the app
    /// says), and carries the photograph if there is one, so it can be judged
    /// and the account banned. Which kind of thing it is rides in the title
    /// ("Person: Sam", "Crew: Roommates"), so no schema change was needed.
    ///
    /// A report that cannot be sent now (no signal) is kept and sent at the
    /// next refresh: a report that silently vanished is not one. Returns
    /// whether it went now.
    @discardableResult
    static func report(_ subject: Subject, in crew: CrewID, reason: Reason) async -> Bool {
        let store = SocialStore.shared
        var fields: [String: String] = [
            "crew": crew.rawValue,
            "reporter": store.me.uuidString,
            "reason": reason.rawValue,
        ]
        var photo: URL?
        let cloud = store.cloud as? CloudKitCrewCloud
        switch subject {
        case .win(let win):
            fields["winID"] = win.winID.uuidString
            fields["sender"] = win.senderProfileID.uuidString
            fields["title"] = win.title
            fields["senderAccount"] = cloud?.account(of: win.senderProfileID, in: crew)
            photo = win.photo
        case .person(let member):
            fields["sender"] = member.profileID.uuidString
            fields["title"] = "Person: " + (member.firstName.isEmpty ? "(no name)" : member.firstName)
            fields["senderAccount"] = cloud?.account(of: member.profileID, in: crew)
            photo = member.photo
        case .reply(let reaction):
            fields["winID"] = reaction.winID.uuidString
            fields["sender"] = reaction.profileID.uuidString
            fields["title"] = "Reply: " + (reaction.line ?? "")
            fields["senderAccount"] = cloud?.account(of: reaction.profileID, in: crew)
        case .crew(let c):
            fields["title"] = "Crew: " + (c.name.isEmpty ? "(no name)" : c.name)
            fields["senderAccount"] = cloud?.lastEditor(of: crew)
            photo = c.photo
        }
        if let photo { fields["photoPath"] = photo.path }
        if await send(fields) { return true }
        var pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: String]] ?? []
        pending.append(fields)
        UserDefaults.standard.set(pending, forKey: pendingKey)
        return false
    }

    private static let pendingKey = "crews.pendingReports"

    /// Reports kept for want of a signal, sent now. Called after a refresh.
    static func sendPending() async {
        let pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: String]] ?? []
        guard !pending.isEmpty else { return }
        var left: [[String: String]] = []
        for fields in pending where !(await send(fields)) { left.append(fields) }
        UserDefaults.standard.set(left, forKey: pendingKey)
    }

    private static func send(_ fields: [String: String]) async -> Bool {
        guard let cloud = SocialStore.shared.cloud as? CloudKitCrewCloud else {
            log.notice("report (no cloud): \(fields["reason"] ?? "", privacy: .public)")
            return true
        }
        let record = CKRecord(recordType: "Report")
        for (key, value) in fields where key != "photoPath" { record[key] = value as NSString }
        if let saved = fields["photoPath"],
           case let path = CrewFiles.here(URL(fileURLWithPath: saved)).path,
           FileManager.default.fileExists(atPath: path) {
            record["photo"] = CKAsset(fileURL: URL(fileURLWithPath: path))
        }
        do {
            _ = try await cloud.container.publicCloudDatabase.save(record)
            return true
        } catch {
            log.error("report not sent, kept for later: \(error)")
            return false
        }
    }

    /// The old entry point, a win.
    static func report(win: SharedWin, in crew: CrewID, reason: Reason) async {
        await report(.win(win), in: crew, reason: reason)
    }

    /// How this phone treats a friend's photograph (see
    /// `SocialStore.photoIsShown`).
    enum Incoming: Equatable { case show, check, hide }

    static var incoming: Incoming {
        if SCSensitivityAnalyzer().analysisPolicy != .disabled { return .check }
        return CrewAge.current.seesPhotosUnchecked ? .show : .hide
    }

    /// **The photo check** (guideline 1.2's filter). Apple's on-device
    /// analysis, the one behind Sensitive Content Warning, runs on a photo
    /// before it goes to a crew. Flagged: the photo is not sent, the win still
    /// is, and the sender is told plainly.
    ///
    /// When the person has the analysis switched off in Settings it cannot
    /// run, and the photo goes as it would have before the check existed:
    /// the phone's owner has made that choice for every app.
    /// A friend's photograph, checked: true fine, false flagged, nil when the
    /// check could not run. Nil is not remembered, so it is tried again
    /// rather than hiding the photo for good (it was stored as flagged).
    static func verdict(_ jpeg: Data) async -> Bool? {
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else { return true }
        let url = FileManager.default.temporaryDirectory.appending(path: "crew-verdict-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            try jpeg.write(to: url)
            return try await !analyzer.analyzeImage(at: url).isSensitive
        } catch {
            log.error("photo check could not run, will try again: \(error)")
            return nil
        }
    }

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
        store.block(profileID, name: store.crew(crew)?.member(profileID)?.shortName ?? "")
        if store.crew(crew)?.isOwner(store.me) == true {
            do { try await store.remove(member: profileID, from: crew) } catch {
                log.error("blocked member not removed: \(error)")
            }
        }
    }
}
