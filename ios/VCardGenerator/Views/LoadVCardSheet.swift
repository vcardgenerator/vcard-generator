import SwiftUI
import UniformTypeIdentifiers

struct LoadVCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onLoad: ([VCardEntry]) -> Void

    @State private var pastedText = ""
    @State private var showPicker = false
    @State private var errorMsg:  String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {

                    // ── File picker ──────────────────────────────────────────
                    fieldSection(label: "Upload a .vcf file") {
                        Button { showPicker = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                Text("Choose .vcf file")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                        .buttonStyle(GlassButtonStyle())
                    }

                    // ── Divider ──────────────────────────────────────────────
                    HStack(spacing: 12) {
                        Rectangle().fill(.separator).frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle().fill(.separator).frame(height: 1)
                    }

                    // ── Paste ────────────────────────────────────────────────
                    fieldSection(label: "Paste raw vCard text") {
                        TextEditor(text: $pastedText)
                            .font(.system(.caption, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(height: 160)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }

                    // ── Error ────────────────────────────────────────────────
                    if let msg = errorMsg {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(msg)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── Action buttons ───────────────────────────────────────
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlassButtonStyle())
                        .tint(.secondary)

                        Button(action: loadPaste) {
                            Text("Load")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                }
                .padding(20)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: errorMsg != nil)
            }
            .navigationTitle("Load vCard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [
                UTType(filenameExtension: "vcf") ?? .text,
                .text, .plainText
            ]
        ) { result in
            guard let url = try? result.get(),
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            finish(VCardService.parseVCF(text))
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    @ViewBuilder
    private func fieldSection<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadPaste() {
        let text = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                errorMsg = "Paste some vCard text first."
            }
            return
        }
        finish(VCardService.parseVCF(text))
    }

    private func finish(_ entries: [VCardEntry]) {
        guard !entries.isEmpty else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                errorMsg = "No valid vCard blocks found."
            }
            return
        }
        onLoad(entries)
        dismiss()
    }
}
