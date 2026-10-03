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
    /// `ProfileStore.profileID` on this phone.
    var myProfileID: UUID { get }

    /// Makes the crew's zone and its share. Returns the invitation link.
    func createZone(_ crew: Crew) async throws -> URL
    /// The invitation link of a crew this phone is in.
    func shareURL(for crew: CrewID) async throws -> URL
    /// Joins the crew the invitation is for.
    func accept(_ invite: CrewInvite) async throws -> CrewID
    /// Every crew this phone is in, with its members.
    func fetchCrews() async throws -> [Crew]
    /// Every shared win still in a crew's zone.
    func fetchWins(in crew: CrewID) async throws -> [SharedWin]
    /// Every reaction in a crew's zone.
    func fetchReactions(in crew: CrewID) async throws -> [Reaction]
    /// Writes a record whole: a key that is absent is cleared.
    func save(_ fields: RecordFields, type: CrewRecordType, name: String, in crew: CrewID) async throws
    func delete(type: CrewRecordType, name: String, in crew: CrewID) async throws
    /// Leaves a crew someone else started.
    func leave(_ crew: CrewID) async throws
    /// Ends a crew you started, for everyone: its zone is deleted.
    func endCrew(_ crew: CrewID) async throws
    func removeParticipant(_ profileID: UUID, from crew: CrewID) async throws
}
