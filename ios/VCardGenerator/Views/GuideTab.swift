import SwiftUI

struct GuideTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // ── Intro ─────────────────────────────────────────────────
                    Text("Once you\u{2019}ve built your buttons and copied the output, wire it up in the Shortcuts app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 16))

                    // ── Steps ─────────────────────────────────────────────────
                    stepCard("1", title: "Text",
                             desc: "Add a Text action. Paste your copied vCard output here \u{2014} tap Copy in the Output tab first.")

                    stepCard("2", title: "Set Name",
                             desc: "Add a Set Name action. Set the filename to \u{201c}Menu.vcf\u{201d}.")

                    stepCard("3", title: "Get Variable",
                             desc: "Add a Get Variable action. Select the Set Name result \u{2014} it will appear as \u{201c}Renamed Item\u{201d}. Tap \u{201c}Renamed Item\u{201d} and change its type to Contact.")

                    stepCard("4", title: "Choose From List",
                             desc: "Add a Choose From List action. Select \u{201c}Renamed Item\u{201d} as the input. When your shortcut runs, your buttons appear as a scrollable, tappable menu.")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // ── Step card ─────────────────────────────────────────────────────────────
    private func stepCard(_ number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.callout.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.blue, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    GuideTab()
}
