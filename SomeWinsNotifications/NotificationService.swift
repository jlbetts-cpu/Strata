import CloudKit
import UserNotifications

/// **A ping, put into words.** iCloud delivers a ping as a plain alert ("A
/// friend added a win"); this runs before it is shown and writes what a friend
/// would say: the crew as the title, "Sam: Gym" underneath, grouped by crew,
/// and a tap that opens that win.
///
/// Names come from the app's cache in the app group. The win's title, or a
/// reaction's emoji, is read from the crew's own zone, with this person's own
/// access to it, and only those fields: never a photo, which the app shows
/// only after its on-device check. If iCloud cannot be reached in time, the
/// names alone still say who and where.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    /// The read and the system's deadline can finish at the same moment:
    /// whichever is first delivers, once.
    private let lock = NSLock()
    private var deliver: ((UNNotificationContent) -> Void)?
    private var best: UNMutableNotificationContent?
    private var task: Task<Void, Never>?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        deliver = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        best = content
        guard let note = CKNotification(fromRemoteNotificationDictionary: request.content.userInfo)
                as? CKQueryNotification,
              let fields = note.recordFields,
              let crew = fields[CrewPingRecord.crew] as? String,
              let sender = fields[CrewPingRecord.sender] as? String,
              let winID = fields[CrewPingRecord.win] as? String,
              let kind = (fields[CrewPingRecord.kind] as? String).flatMap(CrewPingRecord.Kind.init) else {
            contentHandler(content)
            return
        }
        let cache = CrewNoteCache.load()
        // The ping names the crew by its tag; the app's deep link wants the
        // crew itself.
        if let known = cache?.crews[crew] {
            content.threadIdentifier = known.zoneName
            content.userInfo["crew"] = known.zoneName
        }
        content.userInfo["win"] = winID
        // Words from the names alone first, so a timeout still says who.
        apply(cache, kind: kind, crew: crew, sender: sender, winID: winID, read: Read(), to: content)

        task = Task {
            let read = await Self.read(kind: kind, crew: crew, sender: sender, winID: winID,
                                       in: cache?.crews[crew])
            self.apply(cache, kind: kind, crew: crew, sender: sender, winID: winID, read: read, to: content)
            self.finish()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        task?.cancel()
        finish()
    }

    private func finish() {
        let ready: (((UNNotificationContent) -> Void), UNNotificationContent)? = lock.withLock {
            guard let deliver, let best else { return nil }
            self.deliver = nil
            return (deliver, best.copy() as! UNNotificationContent)
        }
        if let (deliver, content) = ready { deliver(content) }
    }

    private func apply(_ cache: CrewNoteCache?, kind: CrewPingRecord.Kind, crew: String, sender: String,
                       winID: String, read: Read, to content: UNMutableNotificationContent) {
        // Before the words, so a ping the extension cannot word still
        // arrives at its level (`CrewAlertLevel`): a friend's win quietly.
        CrewAlertLevel.apply(to: content, kind: kind,
                             tagsMe: cache.map { read.withPeople.contains($0.me) } ?? false)
        guard let cache else { return }
        let words = cache.words(kind: kind, crew: crew, sender: sender, winID: winID,
                                title: read.title, emoji: read.emoji, line: read.line,
                                tagsMe: read.withPeople.contains(cache.me))
        content.title = words.title
        content.body = words.body
    }

    /// What the record said, as far as it was read.
    struct Read {
        var title: String?
        var emoji: String?
        /// A reply's words, on a reaction record that has them.
        var line: String?
        /// The people a win names, as profile ids, so a tagged person is
        /// told they were added.
        var withPeople: [String] = []
    }

    /// The fields that make the words: a win's title and who it names, or a
    /// reaction's emoji and its reply line. Read only when the record really
    /// is from the sender the ping names, so a ping cannot put words in
    /// someone's mouth.
    private static func read(kind: CrewPingRecord.Kind, crew: String, sender: String, winID: String,
                             in known: CrewNoteCache.Crew?) async -> Read {
        guard let known, let from = known.members[sender]?.profileID else { return Read() }
        let container = CKContainer(identifier: CrewNoteCache.containerID)
        let db = known.joined ? container.sharedCloudDatabase : container.privateCloudDatabase
        let zone = CKRecordZone.ID(zoneName: known.zoneName, ownerName: known.zoneOwner)
        switch kind {
        case .win:
            let id = CKRecord.ID(recordName: winID, zoneID: zone)
            guard let record = try? await db.records(for: [id], desiredKeys: ["title", "senderProfileID", "withPeople"])[id]?.get(),
                  record["senderProfileID"] as? String == from else { return Read() }
            let people = ((record["withPeople"] as? String) ?? "").split(separator: ",").map(String.init)
            return Read(title: record["title"] as? String, withPeople: people)
        case .reaction:
            let id = CKRecord.ID(recordName: "\(winID)-\(from)", zoneID: zone)
            guard let record = try? await db.records(for: [id], desiredKeys: ["emoji", "profileID", "line"])[id]?.get(),
                  record["profileID"] as? String == from,
                  let emoji = (record["emoji"] as? String)?.prefix(1), !emoji.isEmpty else { return Read() }
            // As long as a reply may be and no longer, as the app reads it.
            let line = (record["line"] as? String).map { String($0.prefix(80)) }
            return Read(emoji: String(emoji), line: line)
        }
    }
}
