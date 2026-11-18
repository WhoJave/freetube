import SwiftUI

// Independent iOS 16 target: intentionally does not link SwiftData, Observation,
// FFmpeg or the iOS 17-only app. See iOS16/README.md for feature limitations.
@main
struct FreeTube16App: App {
    var body: some Scene {
        WindowGroup {
            BrowserScreen()
                .preferredColorScheme(.dark)
        }
    }
}
