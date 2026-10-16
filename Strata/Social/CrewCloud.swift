import Foundation

/// An invitation as it reaches the app: the link, and on a device the
/// `CKShare.Metadata` the system handed over with it.
nonisolated struct CrewInvite: @unchecked Sendable {
    let url: URL
    let metadata: AnyObject?

    init(url: URL, metadata: AnyObject? = nil) {
        self.url = url
        self.metadata = metadata
    }
}

/// Where crews are kept. `PublicCrewCloud` on a phone; `FakeCrewCloud` in
/// every test and behind `-strataSeedCrew`.
///
/// **Records only, no policy.** Caps, the crew day, the outbox and what is
/// allowed to leave the phone are `SocialStore`'s; this layer moves fields.
@MainActor
protocol CrewCloud: AnyObject {
    /// `ProfileStore.profileID` on this phone, or, once `prepare` has run on
    /// a second phone of the same person, the one their first phone made.
    var myProfileID: UUID { get }

    /// Anything to settle before the first call: the identity record that
    /// makes two phones on one iCloud account one person.
    func prepare() async
    /// Forgets everything held for the account that was signed in.
    func reset()
    /// Who is signed in to iCloud, asked fresh: what tells a real change of
    /// account from the many times iOS says the account changed when it
    /// did not.
    func account() async -> CrewAccount

    /// Makes the crew's zone and its share. Returns the invitation link.
    func createZone(_ crew: Crew) async throws -> URL
    /// The invitation link of a crew this phone is in.
    func shareURL(for crew: CrewID) async throws -> URL
    /// Joins the crew the invitation is for.
    func accept(_ invite: CrewInvite) async throws -> CrewID
    /// Every crew this phone is in, with its members.
    func fetchCrews() async throws -> [Crew]
    /// The crews this phone still belongs to, whether or not `fetchCrews`
    /// could read them this time. Nil when the cloud cannot tell the two
    /// apart, and then a crew missing from `fetchCrews` is gone.
    func heldCrews() -> Set<CrewID>?
    /// One crew, with its members, as last synced: what a live sync reads
    /// after `syncOnly` brought its zone up to date. Nil when it is gone.
    func fetchCrew(_ crew: CrewID) async throws -> Crew?
    /// Every shared win still in a crew's zone.
    func fetchWins(in crew: CrewID) async throws -> [SharedWin]
    /// Every reaction in a crew's zone.
    func fetchReactions(in crew: CrewID) async throws -> [Reaction]
    /// Every line of the day chat still in a crew's zone.
    func fetchMessages(in crew: CrewID) async throws -> [CrewMessage]
    /// Every story still in a crew's zone, its end passed or not: the clock
    /// is the reader's to apply (`StoryClock`).
    func fetchStories(in crew: CrewID) async throws -> [CrewStory]
    /// Personal-chat invitations left in a crew's zone (`CrewPersonal`).
    func fetchPersonals(in crew: CrewID) async throws -> [PersonalInvite]
    /// A member's published public key, for sealing to them alone.
    func memberPublicKey(_ profileID: UUID, in crew: CrewID) -> String?
    /// Opens something sealed to this phone's own key.
    func openSealed(_ data: Data, info: Data) -> Data?
    /// Writes a record whole: a key that is absent is cleared.
    /// **Takes a username for this account** (`Handle`): true when it is
    /// this account's now, false when someone else has it.
    func claimHandle(_ handle: String) async throws -> Bool
    /// Lets one of this account's usernames go: true when it is gone (or
    /// was never there), false to try again later.
    @discardableResult func releaseHandle(_ handle: String) async -> Bool
    /// **Whether a member's username is theirs**: the claim's creator is the
    /// account that wrote their member record. Nil when it cannot be told.
    func verifyHandle(_ handle: String, of profileID: UUID, in crew: CrewID) async -> Bool?

    func save(_ fields: RecordFields, type: CrewRecordType, name: String, in crew: CrewID) async throws
    func delete(type: CrewRecordType, name: String, in crew: CrewID) async throws
    /// Turns away from a crew just accepted and not joined (the cap was
    /// reached, or it was full): nothing of yours in it is touched.
    func decline(_ crew: CrewID) async
    /// A join that went through: the member record is written. Until this
    /// or `decline`, the crew is only being joined.
    func settle(_ crew: CrewID) async
    /// Said before anything of yours in the crew is deleted: the leaving
    /// itself, where a cloud keeps one.
    func willLeave(_ crew: CrewID) async throws
    /// Leaves a crew someone else started.
    func leave(_ crew: CrewID) async throws
    /// Ends a crew you started, for everyone: its zone is deleted.
    func endCrew(_ crew: CrewID) async throws
    func removeParticipant(_ profileID: UUID, from crew: CrewID) async throws
    /// Brings ONE crew up to date, cheaply: true when anything in it
    /// changed. The crew on screen asks this every few seconds.
    func syncOnly(_ crew: CrewID) async throws -> Bool
    /// The developer's bans, read again now if they have not been lately
    /// (`force`: a crew was opened). True when they changed.
    func refreshModeration(force: Bool) async -> Bool

    // MARK: Pings (`CrewPingRecord`)

    /// Leaves a ping in the public database. Returns its record name, for
    /// deleting it a day later.
    func ping(_ fields: [String: String]) async throws -> String
    /// A ping under a name every phone would give it, so only the first
    /// is left: a crew's milestone, which every phone can see was reached.
    func pingOnce(_ fields: [String: String], named name: String) async throws -> Bool
    /// Deletes this phone's own pings. Best effort: one missed is deleted
    /// next time.
    func deletePings(_ names: [String]) async
    /// Asks iCloud to send this phone the pings `plan` describes, replacing
    /// what it asked for before.
    func listen(for plan: CrewPingPlan) async throws
    /// Where a crew's zone lives, for the notification extension to read it.
    func zoneLocation(of crew: CrewID) -> (owner: String, joined: Bool)?
}

extension CrewCloud {
    /// A pretend cloud has nothing to fetch: it says something may have
    /// changed and lets the full refresh find out.
    func syncOnly(_ crew: CrewID) async throws -> Bool { true }

    /// A pretend cloud bans nobody.
    func refreshModeration(force: Bool) async -> Bool { false }

    /// Out of every crew, by default. CloudKit reads its own cache instead,
    /// with no request at all.
    func fetchCrew(_ crew: CrewID) async throws -> Crew? {
        try await fetchCrews().first { $0.id == crew }
    }
}

/// The iCloud account behind the crews, as far as can be told right now.
nonisolated enum CrewAccount: Equatable, Sendable {
    /// Signed in, as this user record.
    case signedIn(String)
    case signedOut
    /// Restricted, busy, offline or not answering: nothing can be said, and
    /// nothing may be thrown away on it.
    case unknown
}

extension CrewCloud {
    /// Where accepting is joining (the stand-in cloud), turning away is
    /// leaving.
    func decline(_ crew: CrewID) async { try? await leave(crew) }
    /// Where nothing can say who was first (the stand-in), it is left.
    func pingOnce(_ fields: [String: String], named name: String) async throws -> Bool {
        _ = try await ping(fields)
        return true
    }
    func settle(_ crew: CrewID) async {}
    func heldCrews() -> Set<CrewID>? { nil }
    func willLeave(_ crew: CrewID) async throws {}
}
