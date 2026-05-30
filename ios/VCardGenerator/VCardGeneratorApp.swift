import SwiftUI

@main
struct VCardGeneratorApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "hapticsEnabled": true,
            "reduceMotion":   false
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.blue)
        }
    }
}
