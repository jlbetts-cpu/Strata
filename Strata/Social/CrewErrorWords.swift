import CloudKit
import Foundation
import os

/// **Every crew error, in words a person knows what to do with** (the owner,
/// 2026-10-08: "the error messages for like creating a crew can that be
/// english like make sense like a user should instantly know what is wrong").
///
/// Before this, three places printed CloudKit's own text after a colon ("The
/// crew could not be started: Error saving record <CKRecordID: 0x8178...>
/// to server: Quota exceeded"), which is a sentence for a developer. Each
/// line here says what happened and what to do, in that order, and depends on
/// what you were doing: a full iCloud is YOURS when you start a crew and the
/// starter's when you join one. CloudKit's text still reaches the log.
nonisolated enum CrewErrorWords {
    enum Doing: Equatable { case starting, joining, inviting }

    private static let log = Logger(subsystem: "Strata", category: "crews.words")

    static let offline = "You're offline. Connect to Wi-Fi or mobile data and try again."
    static let signedOut = "Sign in to iCloud in Settings to use crews."
    static let busy = "iCloud is busy right now. Try again in a minute."
    static let yourICloudFull = "Your iCloud storage is full, so this can't be saved. Free up space in Settings, under your name, then iCloud."
    static let starterICloudFull = "The person who started this crew is out of iCloud space. Ask them to free some up, then tap the link again."
    static let wrongAccount = "This invite was sent to a different Apple Account. Ask your friend to invite the phone number or email this iPhone uses."
    static let ended = "This crew has ended, or the link is old. Ask for a new one."
    static let fullCrew = "That crew already has eight people, the most a crew can have."

    static func tooMany(_ doing: Doing) -> String {
        doing == .joining
            ? "You're in \(CrewCaps.crews) crews, the most you can be in. Leave one to join this one."
            : "You're in \(CrewCaps.crews) crews, the most you can be in. Leave one to start another."
    }

    static func fallback(_ doing: Doing) -> String {
        switch doing {
        case .starting: "The crew couldn't be started. Check your connection and try again."
        case .joining: "This crew couldn't be opened. Check your connection and tap the link again."
        case .inviting: "The invite couldn't be made. Check your connection and try again."
        }
    }

    /// The words for `error`, said while `doing`.
    static func say(_ error: Error, while doing: Doing) -> String {
        log.error("crew \(String(describing: doing), privacy: .public) failed: \(String(describing: error), privacy: .public)")
        if let crew = error as? CrewError { return words(for: crew, while: doing) }
        if let url = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(url.code) {
            return offline
        }
        guard let ck = SocialStore.ckErrors(error).first(where: { $0.code != .partialFailure })
                ?? (error as? CKError) else {
            return fallback(doing)
        }
        switch ck.code {
        case .quotaExceeded:
            return doing == .joining ? starterICloudFull : yourICloudFull
        case .networkUnavailable, .networkFailure:
            return offline
        case .notAuthenticated, .badContainer, .missingEntitlement:
            return signedOut
        case .requestRateLimited, .zoneBusy, .serviceUnavailable:
            return busy
        case .participantMayNeedVerification, .permissionFailure:
            return doing == .joining ? wrongAccount : fallback(doing)
        case .unknownItem, .zoneNotFound, .userDeletedZone:
            return doing == .joining ? ended : fallback(doing)
        default:
            return fallback(doing)
        }
    }

    static func words(for error: CrewError, while doing: Doing) -> String {
        switch error {
        case .tooManyCrews: tooMany(doing)
        case .crewFull: fullCrew
        case .notSignedIn: signedOut
        case .unknownCrew: doing == .joining ? ended : fallback(doing)
        case .flagOff, .notOwner: fallback(doing)
        case .photoNotAllowed: "That photo can't be used for a crew. Pick another one."
        case .photoNeeded: "Choose a photo for the crew first."
        case .notReady: "Agree to the crew rules first, then try again."
        }
    }
}
