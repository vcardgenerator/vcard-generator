import SwiftUI

@main
struct VCardGeneratorApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "hapticsEnabled": true
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.blue)
        }
    }
}
