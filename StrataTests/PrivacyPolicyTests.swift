import Testing
import Foundation
@testable import Strata

/// The policy in the app and the one App Store Connect links to say the same
/// thing (2026-10-08: they had drifted, different dates and missing sections).
/// Both come from `tools/policy/policy.py`; this fails if either is edited by
/// hand or one is regenerated without the other.
///
/// Self-test: change one word in `docs/privacy.html` and `everyParagraphIsHosted`
/// fails naming the paragraph.
@Suite("PrivacyPolicy")
struct PrivacyPolicyTests {
    private static func hostedText() throws -> String {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let html = try String(contentsOf: repo.appending(path: "docs/privacy.html"), encoding: .utf8)
        let noTags = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return noTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    @Test("every paragraph in the app is in the hosted policy, word for word")
    func everyParagraphIsHosted() throws {
        let hosted = try Self.hostedText()
        for section in PrivacyPolicyText.sections {
            #expect(hosted.contains(section.title), "missing section \(section.title)")
            for paragraph in section.paragraphs {
                #expect(hosted.contains(paragraph), "not hosted: \(paragraph.prefix(60))")
            }
        }
        #expect(hosted.contains(PrivacyPolicyText.lede))
        #expect(hosted.contains("last updated \(PrivacyPolicyText.updated)"))
    }

    @Test("no long dashes in the policy")
    func noLongDashes() {
        for section in PrivacyPolicyText.sections {
            for paragraph in section.paragraphs {
                #expect(!paragraph.contains("\u{2014}") && !paragraph.contains("\u{2013}"))
            }
        }
    }
}
