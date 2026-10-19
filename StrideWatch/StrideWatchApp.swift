import SwiftUI

@main
struct StrideWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .onAppear {
                    WatchBridge.shared.activate()
                    WatchSession.shared.requestAuthorization()
                }
        }
    }
}
