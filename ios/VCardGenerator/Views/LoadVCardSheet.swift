import SwiftUI
import UniformTypeIdentifiers

struct LoadVCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onLoad: ([VCardEntry]) -> Void

    @State private var pastedText  = ""
    @State private var showPicker  = false
    @State private var errorMsg:   String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F13").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {

                        // ── File picker ──────────────────────────────────────
                        fieldSection(label: "Upload a .vcf file") {
                            Button { showPicker = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(Color(hex: "7C6AF7"))
                                    Text("Choose .vcf file")
                                        .foregroundStyle(Color(hex: "7A7A96"))
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                        )
                                        .foregroundStyle(Color(hex: "2A2A38"))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // ── Divider ──────────────────────────────────────────
                        HStack(spacing: 10) {
                            Rectangle().fill(Color(hex: "2A2A38")).frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "7A7A96"))
                            Rectangle().fill(Color(hex: "2A2A38")).frame(height: 1)
                        }

                        // ── Paste ────────────────────────────────────────────
                        fieldSection(label: "Paste raw vCard text") {
                            TextEditor(text: $pastedText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color(hex: "F0F0F8"))
                                .scrollContentBackground(.hidden)
                                .background(Color(hex: "14141E"),
                                            in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(hex: "2A2A38"), lineWidth: 1))
                                .frame(height: 160)
                        }

                        // ── Error ────────────────────────────────────────────
                        if let msg = errorMsg {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "F75A5A"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // ── Buttons ──────────────────────────────────────────
                        HStack(spacing: 10) {
                            Button("Cancel") { dismiss() }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color(hex: "1A1A24"),
                                            in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color(hex: "2A2A38"), lineWidth: 1))
                                .foregroundStyle(Color(hex: "7A7A96"))
                                .font(.subheadline.weight(.semibold))
                                .buttonStyle(.plain)

                            Button("Load", action: loadPaste)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "7C6AF7"), Color(hex: "A978F5")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.bold))
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Load vCard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "7C6AF7"))
                }
            }
        }
        .tint(Color(hex: "7C6AF7"))
        .preferredColorScheme(.dark)
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

    // ── Section helper ────────────────────────────────────────────────────────
    @ViewBuilder
    private func fieldSection<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "7A7A96"))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── Load logic ────────────────────────────────────────────────────────────
    private func loadPaste() {
        let text = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { errorMsg = "Paste some vCard text first."; return }
        finish(VCardService.parseVCF(text))
    }

    private func finish(_ entries: [VCardEntry]) {
        guard !entries.isEmpty else { errorMsg = "No valid vCard blocks found."; return }
        onLoad(entries)
        dismiss()
    }
}
