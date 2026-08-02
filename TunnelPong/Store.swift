import Foundation
import StoreKit

/// StoreKit 2 wrapper for the single non-consumable "supporter" purchase.
///
/// Native StoreKit only — no third-party SDK, so the project keeps its
/// zero-dependency property.
///
/// The source of truth for ownership is always `Transaction.currentEntitlements`,
/// which Apple verifies. The UserDefaults copy is a *cache* so the title screen
/// can render correctly at launch before StoreKit has answered, and offline.
/// It is never trusted on its own to grant anything of value — that would be
/// trivially defeatable, and there is nothing here worth defeating.
@MainActor
final class Store {

    static let shared = Store()

    /// Must match the product ID created in App Store Connect (and in
    /// Products.storekit for local testing).
    static let supporterID = "com.brooksmoore.tunnelpong.supporter"

    private static let cacheKey = "isSupporter"

    private(set) var product: Product?
    private(set) var isSupporter: Bool {
        didSet {
            guard isSupporter != oldValue else { return }
            UserDefaults.standard.set(isSupporter, forKey: Store.cacheKey)
            onChange?()
        }
    }

    /// Fired whenever ownership or product availability changes, so the scene
    /// can relayout without polling.
    var onChange: (() -> Void)?

    /// Localized price ("$0.99"), or nil until the product loads. Never
    /// hard-code a price string — the App Store returns it per storefront.
    var displayPrice: String? { product?.displayPrice }

    private var updatesTask: Task<Void, Never>?

    private init() {
        isSupporter = UserDefaults.standard.bool(forKey: Store.cacheKey)
    }

    /// Call once at launch.
    func start() {
        // Transactions can arrive at any time — Ask to Buy approvals, purchases
        // made on another device, refunds. Listening is required to stay correct.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? Self.verified(update) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Store.supporterID])
            product = products.first
        } catch {
            product = nil          // offline, or product not configured yet
        }
        onChange?()
    }

    /// Ask Apple what this Apple ID actually owns.
    func refreshEntitlements() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? Self.verified(entitlement),
               transaction.productID == Store.supporterID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isSupporter = owned
    }

    enum PurchaseOutcome { case success, pending, cancelled, unavailable, failed }

    func purchase() async -> PurchaseOutcome {
        guard let product else { return .unavailable }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return .success
            case .pending:
                // Ask to Buy / SCA — resolves later via Transaction.updates.
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// App Review requires a restore path for non-consumables. `AppStore.sync()`
    /// prompts for the Apple ID, so it must be user-initiated, never automatic.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isSupporter
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error
        }
    }
}
