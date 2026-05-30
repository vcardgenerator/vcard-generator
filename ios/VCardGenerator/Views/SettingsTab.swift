import SwiftUI

struct SettingsTab: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("reduceMotion")   private var reduceMotion   = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Feedback", systemImage: "waveform")
                    }
                    Toggle(isOn: $reduceMotion) {
                        Label("Reduce Motion", systemImage: "circle.dotted.and.circle")
                    }
                } header: {
                    Text("Accessibility")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsTab()
}
