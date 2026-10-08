import Testing
import Foundation
import CloudKit
@testable import Strata

/// Feedback, the review row, the one automatic review ask, and the iCloud-full
/// line (2026-10-08).
///
/// Self-test, each of which re-injects a real bug:
/// - Let `ReviewAsk.shouldAsk` pass on the first day and `neverOnTheFirstDay`
///   fails: the ask would land on onboarding's day.
/// - Drop the version gate and `oncePerVersion` fails.
/// - Let a busy day pass and `oncePerVersion` fails: the tip and the review
///   would land on the same evening.
/// - Stop looking inside a partial failure and `quotaInsidePartialFailure`
///   fails, which is how mirroring actually reports a full iCloud.
@Suite("Support and review")
@MainActor
struct SupportTests {

    // MARK: - Feedback

    @Test("the mailto carries the address, subject and footer, escaped")
    func mailto() throws {
        let footer = Support.footer(version: "1.0", build: "108", model: "iPhone17,1", system: "26.0.1")
        #expect(footer.contains("Some Wins 1.0 (108)"))
        #expect(footer.contains("iPhone17,1, iOS 26.0.1"))
        let url = try #require(Support.mailtoURL(body: footer))
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.scheme == "mailto")
        #expect(parts.path == Support.address)
        #expect(parts.queryItems?.first { $0.name == "subject" }?.value == "Some Wins feedback")
        #expect(parts.queryItems?.first { $0.name == "body" }?.value == footer)
        #expect(!url.absoluteString.contains(" "), "a space in a mailto is a link that does not open")
    }

    @Test("the support address is written once, in Support")
    func oneAddress() throws {
        let hits = try SourceSweep.hits(matching: { $0.contains("jbett5@hotmail.com") })
            .filter { !$0.hasPrefix("Strata/Services/Support.swift:") && !$0.contains("PrivacyPolicyView.swift:") }
        #expect(hits.isEmpty, "the address is spelled out again: \(hits)")
    }

    // MARK: - The review row

    @Test("the review link needs a numeric App Store ID")
    func reviewURL() {
        #expect(Support.reviewURL(appStoreID: "6740000000")?.absoluteString
                == "https://apps.apple.com/app/id6740000000?action=write-review")
        #expect(Support.reviewURL(appStoreID: " 123 ")?.absoluteString
                == "https://apps.apple.com/app/id123?action=write-review")
        #expect(Support.reviewURL(appStoreID: nil) == nil)
        #expect(Support.reviewURL(appStoreID: "") == nil)
        #expect(Support.reviewURL(appStoreID: "$(APP_STORE_ID)") == nil)
    }

    // MARK: - The automatic ask

    private func ask(strips: Int = 2, first: String? = "2026-10-01", today: String = "2026-10-08",
                     asked: String? = nil, version: String = "1.0", busy: Bool = false) -> Bool {
        ReviewAsk.shouldAsk(strips: strips, firstDay: first, today: today,
                            askedVersion: asked, version: version, busyDay: busy)
    }

    @Test("the second developed strip asks; the first does not")
    func threshold() {
        #expect(ask())
        #expect(ask(strips: 5))
        #expect(!ask(strips: 1), "the first strip is the crew invite's moment")
    }

    @Test("never on the first day, so never on onboarding's")
    func neverOnTheFirstDay() {
        #expect(!ask(first: "2026-10-08", today: "2026-10-08"))
        #expect(!ask(first: nil))
    }

    @Test("once per version, and never on a day the tip or an invite was asked")
    func oncePerVersion() {
        #expect(!ask(asked: "1.0", version: "1.0"))
        #expect(ask(asked: "1.0", version: "1.1"))
        #expect(!ask(busy: true))
    }

    @Test("the first day is written once")
    func firstDayOnce() {
        let name = "review-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        defer { d.removePersistentDomain(forName: name) }
        ReviewAsk.noteLaunch(today: "2026-10-08", defaults: d)
        ReviewAsk.noteLaunch(today: "2026-10-09", defaults: d)
        #expect(d.string(forKey: ReviewAsk.firstDayKey) == "2026-10-08")
    }

    // MARK: - iCloud full

    @Test("a quota error is recognised, plain or wrapped")
    func quotaPlain() {
        let quota = NSError(domain: CKErrorDomain, code: CKError.Code.quotaExceeded.rawValue)
        #expect(StoreSyncStatus.isQuotaExceeded(quota))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134_400, userInfo: [NSUnderlyingErrorKey: quota])
        #expect(StoreSyncStatus.isQuotaExceeded(wrapped))
        #expect(!StoreSyncStatus.isQuotaExceeded(NSError(domain: CKErrorDomain, code: CKError.Code.networkUnavailable.rawValue)))
        #expect(!StoreSyncStatus.isQuotaExceeded(NSError(domain: NSCocoaErrorDomain, code: 4)))
    }

    @Test("a quota error inside a partial failure is recognised")
    func quotaInsidePartialFailure() {
        let quota = NSError(domain: CKErrorDomain, code: CKError.Code.quotaExceeded.rawValue)
        let partial = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue,
                              userInfo: [CKPartialErrorsByItemIDKey: ["record-1": quota] as [AnyHashable: Error]])
        #expect(StoreSyncStatus.isQuotaExceeded(partial))
    }
}
