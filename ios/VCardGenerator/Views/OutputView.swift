import SwiftUI

struct OutputView: View {
    let text:   String
    let onCopy: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Copy button row
            HStack {
                Spacer()
                Button {
                    onCopy()
                    withAnimation(.spring(duration: 0.2)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Text(copied ? "Copied!" : "Copy")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "7A7A96"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                }
                .background(Color(hex: "1A1A24"), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(hex: "2A2A38"), lineWidth: 1))
                .buttonStyle(.plain)
                .contentTransition(.identity)
            }
            .padding(.bottom, 8)

            // Text output
            ScrollView {
                Text(text.isEmpty ? "Add buttons above to see output…" : text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(
                        text.isEmpty
                            ? Color(hex: "7A7A96")
                            : Color(hex: "9b8ff8")
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 300)
            // iOS 26 Liquid Glass
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
