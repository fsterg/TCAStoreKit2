import ComposableArchitecture
import SwiftUI

@main
struct TCATemplateApp: App {
    var body: some Scene {
        WindowGroup {
            MainView(
                store: Store(
                    initialState: Main.State(),
                    reducer: Main()
                )
            )
        }
    }
}
