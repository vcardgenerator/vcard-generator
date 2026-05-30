import SwiftUI

struct OutputView: View {
    let text:   String
    let onCopy: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Header row with Copy button ───────────────────────────────────
            HStack {
                Text("Output")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    onCopy()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copied = false }
                    }
                } label: {
                    Label(
                        copied ? "Copied!" : "Copy",
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(GlassButtonStyle(cornerRadius: 8))
                .tint(copied ? .green : .primary)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: copied)
            }

            // ── Scrollable VCF text ───────────────────────────────────────────
            ScrollView {
                Text(text.isEmpty ? "Add buttons above to see output…" : text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .textSelection(.enabled)
                    .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
            }
            .frame(maxHeight: 280)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
