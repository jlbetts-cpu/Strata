import Foundation
import StoreKit

/// **Support Some Wins** (the owner, 2026-10-08: "I do want some sort of way
/// to donate to me"). Three tips, in-app purchases because guideline 3.1.1
/// requires it for anything digital, and never called a donation, which is a
/// charity's word. A tip unlocks nothing and nothing is held back without one.
/// Spec: `docs/superpowers/specs/2026-10-08-tip-jar-design.md`.
@Observable
final class TipJar {
    static let shared = TipJar()

    enum ProductID {
        static let small = "somewins.tip.small"
        static let medium = "somewins.tip.medium"
        static let large = "somewins.tip.large"
        static let all = [small, medium, large]
    }

    private(set) var products: [Product] = []
    private(set) var isPurchasing = false
    private(set) var tips: Int

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updates: Task<Void, Never>?
    nonisolated static let tipsKey = "tips.count"
    /// The one ask has happened, shown or tipped through; it never comes back.
    nonisolated static let askedKey = "tips.asked"
    /// Strips developed, counted for the ask's rule.
    nonisolated static let stripsKey = "tips.strips"
    /// The day a crew invite was asked for, so the two never share a day.
    nonisolated static let inviteDayKey = "tips.inviteDay"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tips = defaults.integer(forKey: Self.tipsKey)
    }

    var hasTipped: Bool { tips > 0 }

    /// At launch: tips bought on another device, interrupted or waiting on
    /// Ask to Buy are finished here, or the App Store asks again forever.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            for await result in Transaction.unfinished { await handle(result) }
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: ProductID.all) else { return }
        products = loaded.filter { ProductID.all.contains($0.id) }.sorted { $0.price < $1.price }
    }

    /// True when the tip went through.
    func tip(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        guard let result = try? await product.purchase(),
              case .success(let verification) = result,
              case .verified(let transaction) = verification else { return false }
        await transaction.finish()
        record(productID: product.id)
        return true
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result, ProductID.all.contains(transaction.productID) else { return }
        await transaction.finish()
        record(productID: transaction.productID)
    }

    private func record(productID: String) {
        tips += 1
        defaults.set(tips, forKey: Self.tipsKey)
        // A tip is the answer to the ask; it is never asked after one.
        defaults.set(true, forKey: Self.askedKey)
        Analytics.shared.signal(.tipPurchased, [.tier(Self.tier(of: productID))])
    }

    nonisolated static func tier(of productID: String) -> AnalyticsField.Tier {
        switch productID {
        case ProductID.small: .small
        case ProductID.medium: .medium
        default: .large
        }
    }

    /// The tip's name as the App Store has it, or ours while it loads.
    nonisolated static func name(of productID: String) -> String {
        switch productID {
        case ProductID.small: "Small Tip"
        case ProductID.medium: "Kind Tip"
        default: "Generous Tip"
        }
    }

    // MARK: - The one ask

    /// A strip was developed. Counted, because the ask waits for the third,
    /// and remembered until the booth closes, because the ask only follows a
    /// strip that was just developed.
    func noteStripDeveloped() {
        defaults.set(defaults.integer(forKey: Self.stripsKey) + 1, forKey: Self.stripsKey)
        justDeveloped = true
    }

    @ObservationIgnored private var justDeveloped = false

    /// Asked as the booth closes: whether the one ask follows it now.
    func takeAsk(today: String) -> Bool {
        defer { justDeveloped = false }
        return justDeveloped && shouldAsk(today: today)
    }

    /// A crew invite was asked for today.
    func noteInviteAsked(on day: String) {
        defaults.set(day, forKey: Self.inviteDayKey)
    }

    /// Whether to ask now, after a strip was developed.
    func shouldAsk(today: String) -> Bool {
        Self.shouldAsk(strips: defaults.integer(forKey: Self.stripsKey),
                       asked: defaults.bool(forKey: Self.askedKey),
                       tipped: hasTipped,
                       inviteDay: defaults.string(forKey: Self.inviteDayKey),
                       today: today)
    }

    /// **Once, ever, from the third developed strip on**, never after a tip,
    /// never on a day a crew invite was asked for (the first strip is the
    /// invite's moment, `docs/launch-plan.md`).
    nonisolated static func shouldAsk(strips: Int, asked: Bool, tipped: Bool, inviteDay: String?, today: String) -> Bool {
        strips >= 3 && !asked && !tipped && inviteDay != today
    }

    func markAsked() {
        defaults.set(true, forKey: Self.askedKey)
    }

    // MARK: - Words

    enum Copy {
        static let section = "Support Some Wins"
        static let line = "Some Wins is made by one person. If it makes your days a little better, a tip keeps it going."
        static let thanks = "Thank you, genuinely."
        static let askTitle = "A small thank you"
        static let askLine = "Some Wins is made by one person, and it's free. If it's been good to you, you can leave a tip."
        static let notNow = "Not now"
    }
}
