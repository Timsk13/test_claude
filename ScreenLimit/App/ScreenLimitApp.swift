import SwiftUI

@main
struct ScreenLimitApp: App {
    @StateObject private var model = LimitsModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
