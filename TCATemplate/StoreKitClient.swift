/// `SWIFT_STRICT_CONCURRENCY` is set to `Complete`

import Dependencies
import StoreKit

public enum StoreKitClientError: Error {
    case productNotFound(String)
}

public struct StoreKitClient : Sendable {
    public var products: @Sendable ([String]) async throws -> [Product]
    public var purchase: @Sendable (String) async throws -> Bool
    public var purchased: @Sendable () async -> AsyncStream<[Product]>
    public var start: @Sendable () async -> Void
}

public extension DependencyValues {
    var storeKitClient: StoreKitClient {
        get { self[StoreKitClient.self] }
        set { self[StoreKitClient.self] = newValue }
    }
}

extension StoreKitClient: DependencyKey {
    public static let liveValue: StoreKitClient = {
        let allProducts = ActorIsolated<[Product]>([])
        let purchased = ActorIsolated<[Product]>([])

        return StoreKitClient(
            products: { productIds in
                let all = try await Product.products(for: productIds)
                await allProducts.setValue(all)
                return all
            },
            purchase: { productId in
                let all = await allProducts.value
                if let product = all.first(where: { $0.id == productId }) {
                    let result = try await product.purchase()
                    switch result {
                    case .success(let result):
                        return true
                    default:
                        return false
                    }
                } else {
                    throw StoreKitClientError.productNotFound(productId)
                }
            },
            purchased: {
                // TODO: yield whenever there's a change in purchased products
                // TODO: Is it possible to share()?
                AsyncStream { continuation in
                    continuation.yield([])
                    continuation.finish()
                }
            },
            start: {
                // Get current entitlements
                for await result in Transaction.currentEntitlements {
                    if case let .verified(transaction) = result {
                        // add transaction.productID in purchased
                    }
                }

                // Start observing IAP updates
                for await verificationResult in Transaction.updates {
                    switch verificationResult {
                    case let .verified(transaction):
                        if transaction.revocationDate == nil {
                            // add transaction.productID in purchased
                            // send receipt
                            // log analytics
                        } else {
                            // remove transaction.productID from purchased
                        }
                        await transaction.finish()
                    case let .unverified(transaction, error):
                        // log error
                        print("\(transaction.productID) failed verification: \(error.localizedDescription)")
                    }
                }
            }
        )
    }()
}
