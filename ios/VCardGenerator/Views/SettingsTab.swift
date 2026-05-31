import SwiftUI

struct SettingsTab: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptics", systemImage: "waveform")
                    }
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
