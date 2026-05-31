import SwiftUI
import UIKit

// MARK: - UITextView wrapper (handles large strings without crashing)

private struct MonoTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 10, bottom: 14, right: 10)
        tv.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.textColor = .label
        tv.isScrollEnabled = false          // outer ScrollView handles scrolling
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        guard tv.text != text else { return }
        tv.text = text
    }
}

// MARK: - Output View

struct OutputView: View {
    let text:   String
    let onCopy: () -> Void

    @State private var copied = false

    // Cap the on-screen preview so very large output (base64 images) doesn't lag.
    private let previewLimit = 6000
    private var isTruncated: Bool { text.count > previewLimit }
    private var previewText: String {
        isTruncated ? String(text.prefix(previewLimit)) + "\n\n…" : text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Disclaimer + Copy button ──────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {
                if isTruncated {
                    Text("This isn\u{2019}t the full output shown due to lag, but when you copy it, it will be the full output.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                GlassEffectContainer {
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
                    .glassEffect(in: Capsule())
                    .buttonStyle(.plain)
                    .tint(copied ? .green : .primary)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: copied)
                }
            }

            // ── Scrollable VCF text ───────────────────────────────────────────
            ScrollView {
                Group {
                    if text.isEmpty {
                        Text("Add buttons to see output…")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    } else {
                        MonoTextView(text: previewText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
            }
            .frame(maxHeight: 280)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
