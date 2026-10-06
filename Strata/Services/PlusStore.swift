import Foundation
import Observation
import StoreKit

/// **Some Wins Plus** (the owner, 2026-10-06: "they should be a free trial and
/// monthy or weekly, or yearly plan"). The plan, prices and what Plus holds
/// are in `docs/monetization.md`, "Revised 2026-10-06".
///
/// This is the plumbing only: products, purchase, restore and the
/// entitlement. Nothing is gated on it yet, and nothing in the app looks
/// different, until the paywall's design is the owner's.
///
/// The entitlement is cached in the defaults so Plus things never flash
/// locked on the first frame, and is corrected from StoreKit at launch and on
/// every transaction update (a refund, a lapse, Family Sharing, Ask to Buy).
@MainActor
@Observable
final class PlusStore {
    static let shared = PlusStore()

    enum ProductID {
        static let yearly = "somewins.plus.yearly"
        static let monthly = "somewins.plus.monthly"
        static let lifetime = "somewins.plus.lifetime"
        /// Yearly first: it carries the free trial, and it is the plan most
        /// people should choose.
        static let all = [yearly, monthly, lifetime]
    }

    private(set) var isPlus: Bool
    private(set) var products: [Product] = []
    private(set) var isPurchasing = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updates: Task<Void, Never>?
    nonisolated static let cacheKey = "plus.entitled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isPlus = defaults.bool(forKey: Self.cacheKey)
    }

    /// At launch: listen for transactions, then read the current entitlement
    /// and the products.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh(); await loadProducts() }
    }

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: ProductID.all) else { return }
        products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
    }

    /// Plus is on while any of the three products is a verified, unrevoked
    /// entitlement.
    func refresh() async {
        var ids: [String] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            ids.append(transaction.productID)
        }
        set(Self.entitled(by: ids))
    }

    /// True when the purchase went through. A cancelled sheet, a pending Ask
    /// to Buy, or a failed check are all false, and say nothing: the paywall
    /// decides what to show.
    func buy(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        guard let result = try? await product.purchase(),
              case .success(let verification) = result,
              case .verified(let transaction) = verification else { return false }
        await transaction.finish()
        await refresh()
        return isPlus
    }

    /// Restore: asks the App Store to sync, then reads the entitlement again.
    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private func set(_ on: Bool) {
        isPlus = on
        defaults.set(on, forKey: Self.cacheKey)
    }

    /// The rule, apart from StoreKit so it can be tested.
    nonisolated static func entitled(by productIDs: [String]) -> Bool {
        productIDs.contains { ProductID.all.contains($0) }
    }

    /// How many crews someone may be in: 3 free (the owner: "I think we
    /// should give them 3 crews free I feel like that is fair"), more with Plus.
    /// Not wired to `CrewCaps` yet: lowering the free cap before there is a
    /// way to upgrade would only take something away.
    nonisolated static func crewLimit(plus: Bool) -> Int { plus ? 10 : 3 }
}
