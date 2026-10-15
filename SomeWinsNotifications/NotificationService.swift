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
        // A line in the chat opens the chat (`CrewNotifications.chatKey`);
        // a win or a reaction opens its win.
        if kind == .message {
            content.userInfo["chat"] = "1"
            content.userInfo["message"] = winID
            content.categoryIdentifier = CrewNoteActions.chatCategory
        } else if kind == .win || kind == .reaction {
            content.userInfo["win"] = winID
            // A friend's win, as against a reaction to yours: what the fold
            // below looks for.
            if kind == .win {
                content.userInfo["news"] = "win"
                content.categoryIdentifier = CrewNoteActions.winCategory
            }
        }
        let request = request.identifier
        // **A busy chat rings once** (`CrewChatPending`): asked here, once
        // for this push, before any words.
        let zone = cache?.crews[crew]?.zoneName
        let rings = kind != .message || zone.map { CrewChatPending.rings(crew: $0) } ?? true
        // Words from the names alone first, so a timeout still says who.
        apply(cache, kind: kind, crew: crew, sender: sender, winID: winID, read: Read(), rings: rings, to: content)

        task = Task {
            let read = await Self.read(kind: kind, crew: crew, sender: sender, winID: winID,
                                       in: cache?.crews[crew])
            guard !Task.isCancelled else { return }
            self.apply(cache, kind: kind, crew: crew, sender: sender, winID: winID, read: read, rings: rings, to: content)
            // **One notification a crew's chat**: the ones before this one
            // leave the lock screen, found by what they are (a chat line in
            // this crew), not by ids kept somewhere, which two pushes close
            // together got wrong.
            if kind == .message, let zone {
                let center = UNUserNotificationCenter.current()
                let earlier = await center.deliveredNotifications().filter {
                    $0.request.identifier != request && $0.request.content.userInfo["chat"] != nil
                        && $0.request.content.userInfo["crew"] as? String == zone
                }.map(\.request.identifier)
                if !earlier.isEmpty, !Task.isCancelled { center.removeDeliveredNotifications(withIdentifiers: earlier) }
            }
            // **One win, one notification** (2026-10-12): a win sent to two
            // crews you share with its sender can arrive once for each. The
            // earlier one leaves; this one stays.
            if kind == .win {
                let center = UNUserNotificationCenter.current()
                let earlier = await center.deliveredNotifications().filter {
                    $0.request.identifier != request && $0.request.content.userInfo["news"] as? String == "win"
                        && $0.request.content.userInfo["win"] as? String == winID
                }.map(\.request.identifier)
                if !earlier.isEmpty, !Task.isCancelled { center.removeDeliveredNotifications(withIdentifiers: earlier) }
            }
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
                       winID: String, read: Read, rings: Bool, to content: UNMutableNotificationContent) {
        // Before the words, so a ping the extension cannot word still
        // arrives at its level (`CrewAlertLevel`): a friend's win quietly.
        CrewAlertLevel.apply(to: content, kind: kind,
                             tagsMe: cache.map { read.withPeople.contains($0.me) } ?? false)
        /// Into the list with no sound and no lighting up.
        func quiet() {
            content.interruptionLevel = .passive
            content.sound = nil
            content.relevanceScore = 0.2
        }
        if !rings { quiet() }
        guard let cache else { return }
        let words: (title: String, body: String)
        switch kind {
        case .message:
            // A drawing an older build threw onto a tower is not a line in
            // the chat and is never pinged; one that arrives anyway says
            // nothing of it, and makes no sound.
            guard read.line != CrewPingRecord.tossMarker else { return quiet() }
            words = cache.chatWords(crew: crew, sender: sender, text: read.line, hasPicture: read.hasPicture)
        case .joined:
            words = cache.joinedWords(crew: crew, sender: sender, name: read.title)
        case .milestone:
            // Only a number a crew is ever told (`CrewPingRecord.milestones`).
            guard let said = cache.milestoneWords(crew: crew, days: winID) else { return }
            words = said
        case .win, .reaction:
            words = cache.words(kind: kind, crew: crew, sender: sender, winID: winID,
                                title: read.title, emoji: read.emoji, line: read.line,
                                tagsMe: read.withPeople.contains(cache.me))
        }
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
        /// A chat line that came with a picture (a doodle, a strip).
        var hasPicture = false
    }

    /// The fields that make the words: a win's title and who it names, or a
    /// reaction's emoji and its reply line. Read only when the record really
    /// is from the sender the ping names, so a ping cannot put words in
    /// someone's mouth.
    /// **The friend's win, from the public database, opened with the crew's
    /// key** (2026-10-09: crews moved out of personal iCloud). The key is in
    /// the app group (`CrewKeyRing`); without it, or if the box will not
    /// open, the notification keeps its plain fallback words.
    private static func read(kind: CrewPingRecord.Kind, crew: String, sender: String, winID: String,
                             in known: CrewNoteCache.Crew?) async -> Read {
        // Someone joining is not among this phone's members yet: their ping
        // names them by the tag of the profile id it carries, and nothing
        // else here needs them known.
        let joiner = kind == .joined && CrewPingRecord.tag(winID) == sender ? winID : nil
        guard let known, let from = known.members[sender]?.profileID ?? joiner,
              // **The crew's key now, and no older one** (the re-key review):
              // this cannot check who wrote a record, so a win sealed with a
              // key a removed person still holds, naming a friend as its
              // sender, would have been shown on the lock screen in their
              // name. Until the app learns a new key, the plain words stand.
              let key = CrewKeyRing().all[known.zoneName], case let keys = [key] else { return Read() }
        let db = CKContainer(identifier: CrewNoteCache.containerID).publicCloudDatabase
        func open(_ kind: String, _ name: String) async -> [String: String]? {
            let recordName = CrewItemRecord.name(crew: known.zoneName, kind: kind, name: name)
            let id = CKRecord.ID(recordName: recordName)
            guard let record = try? await db.records(for: [id], desiredKeys: ["box"])[id]?.get(),
                  let box = record["box"] as? Data else { return nil }
            return CrewItemRecord.strings(in: box, keys: keys, recordName: recordName)
        }
        switch kind {
        case .win:
            guard let fields = await open("SharedWin", winID),
                  fields["senderProfileID"]?.lowercased() == from.lowercased() else { return Read() }
            let people = (fields["withPeople"] ?? "").split(separator: ",").map(String.init)
            return Read(title: fields["title"], withPeople: people)
        case .message:
            // `winID` is the line's own id; its words are opened as a win's are.
            guard let fields = await open("Message", winID),
                  fields["senderProfileID"]?.lowercased() == from.lowercased() else { return Read() }
            return Read(line: fields["text"] ?? "", hasPicture: !(fields["_slots"] ?? "").isEmpty)
        case .joined:
            // `winID` is the joiner's profile id: their name is on their own
            // member record, which this phone may not have read yet.
            guard let fields = await open("Member", winID) else { return Read() }
            return Read(title: fields["firstName"])
        case .milestone:
            return Read()
        case .reaction:
            guard let fields = await open("Reaction", "\(winID)-\(from)"),
                  fields["profileID"]?.lowercased() == from.lowercased(),
                  let emoji = fields["emoji"]?.prefix(1), !emoji.isEmpty else { return Read() }
            return Read(emoji: String(emoji), line: fields["line"].map { String($0.prefix(80)) })
        }
    }
}
