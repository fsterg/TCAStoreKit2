import ComposableArchitecture
import Dependencies
import StoreKit
import SwiftUI

struct Main: ReducerProtocol {
    @Dependency(\.storeKitClient) var storeKitClient

    struct State: Equatable {
        var products: [Product] = []
        var purchaseStatus: String = ""
    }

    enum Action {
        case purchaseButtonTapped(String)
        case setProducts([Product])
        case setPurchaseStatus(String)
        case viewLoaded
    }

    public var body: some ReducerProtocol<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .purchaseButtonTapped(let productId):
            return .run { send in
                let result = try await storeKitClient.purchase(productId)
                await send(.setPurchaseStatus(result ? "🟢 \(productId)" : "🔴 \(productId)"))
            } catch: { error, send in
                switch error {
                case StoreKitClientError.productNotFound(let product):
                    await send(.setPurchaseStatus("🔴 product not found: \(product)"))
                default:
                    await send(.setPurchaseStatus("🔴 purchase error: \(error.localizedDescription)"))
                }
            }
        case .setProducts(let products):
            state.products = products
            return .none
        case .setPurchaseStatus(let status):
            state.purchaseStatus = status
            return .none
        case .viewLoaded:
            return .run { send in
                let products = try await storeKitClient.products(["com.temp.productA", "com.temp.productB", "com.temp.productC"])
                await send(.setProducts(products))
            }
        }
    }

}

struct MainView: View {

    let store: StoreOf<Main>

    struct ViewState: Equatable {
        let products: [Product]
        let status: String

        init(state: Main.State) {
            self.products = state.products
            self.status = state.purchaseStatus
        }
    }

    var body: some View {
        WithViewStore(self.store, observe: ViewState.init ) { viewStore in
            ForEach(viewStore.products, id: \.id) { product in
                HStack {
                    VStack (alignment: .leading) {
                        Text("\(product.displayName)").font(.headline)
                        Text("\(product.displayPrice)").font(.caption)
                    }
                    Spacer()
                    Button {
                        viewStore.send(.purchaseButtonTapped(product.id))
                    } label: {
                        Text("Buy")
                    }

                }
                .padding()
            }
            VStack (spacing: 12) {
                Text(viewStore.status)
                Button("Action") {
                    //
                }
            }
            .padding()
            .task {
                viewStore.send(.viewLoaded)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(
            store: Store(
                initialState: Main.State(),
                reducer: Main()
            )
        )
    }
}
