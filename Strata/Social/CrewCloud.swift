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

/// Where crews are kept. `CloudKitCrewCloud` on a phone; `FakeCrewCloud` in
/// every test and behind `-strataSeedCrew`.
///
/// **Records only, no policy.** Caps, the crew day, the outbox and what is
/// allowed to leave the phone are `SocialStore`'s; this layer moves fields.
@MainActor
protocol CrewCloud: AnyObject {
    /// A crew zone in the private database changed since the last ask
    /// (`CrewPushRoute`). A requirement, so the CloudKit cloud's answer is
    /// the one called through `any CrewCloud`, not the default below.
    func privateCrewZonesChanged() async -> Bool
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
    /// One crew, with its members, as last synced: what a live sync reads
    /// after `syncOnly` brought its zone up to date. Nil when it is gone.
    func fetchCrew(_ crew: CrewID) async throws -> Crew?
    /// Every shared win still in a crew's zone.
    func fetchWins(in crew: CrewID) async throws -> [SharedWin]
    /// Every reaction in a crew's zone.
    func fetchReactions(in crew: CrewID) async throws -> [Reaction]
    /// Every line of the day chat still in a crew's zone.
    func fetchMessages(in crew: CrewID) async throws -> [CrewMessage]
    /// Writes a record whole: a key that is absent is cleared.
    func save(_ fields: RecordFields, type: CrewRecordType, name: String, in crew: CrewID) async throws
    func delete(type: CrewRecordType, name: String, in crew: CrewID) async throws
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
    /// Whether a crew's zone in your private database changed since the last
    /// ask (`CrewPushRoute`). A cloud that cannot tell says yes, which is the
    /// old behaviour: refresh.
    func privateCrewZonesChanged() async -> Bool { true }
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
