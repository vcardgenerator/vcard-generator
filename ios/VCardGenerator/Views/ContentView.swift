import SwiftUI

struct ContentView: View {
    @State private var store        = VCardStore()
    @State private var expandedIDs: Set<UUID> = []
    @State private var showLoad     = false
    @State private var showShare    = false
    @State private var shareURL: URL? = nil

    // ── Accent / palette ─────────────────────────────────────────────────────
    private let accent   = Color(hex: "7C6AF7")
    private let accent2  = Color(hex: "A978F5")
    private let success  = Color(hex: "34C98A")
    private let success2 = Color(hex: "2EBBCC")
    private let bgTop    = Color(hex: "0F0F13")
    private let bgBot    = Color(hex: "1A1A24")

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Background gradient ──────────────────────────────────────
                LinearGradient(
                    colors: [bgTop, bgBot],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // ── Content ──────────────────────────────────────────────────
                List {
                    // Entries section
                    Section {
                        if store.entries.isEmpty {
                            emptyState
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(store.entries) { entry in
                                let idx = (store.entries.firstIndex { $0.id == entry.id } ?? 0) + 1
                                EntryRowView(
                                    entry:       entry,
                                    index:       idx,
                                    isExpanded:  expandedIDs.contains(entry.id),
                                    onToggle:    { toggleExpand(entry.id) },
                                    onDelete:    { withAnimation { store.removeEntry(entry) } },
                                    onDuplicate: {
                                        let copy = store.duplicateEntry(entry)
                                        expandedIDs.insert(copy.id)
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(.init(top: 5, leading: 0, bottom: 5, trailing: 0))
                            }
                            .onMove  { store.moveEntries(from: $0, to: $1) }
                            .onDelete { store.removeEntries(at: $0) }
                        }
                    } header: {
                        sectionLabel("Buttons")
                    }

                    // Action bar section
                    Section {
                        actionBar
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }

                    // Output section
                    Section {
                        Rectangle()
                            .fill(Color(hex: "2A2A38"))
                            .frame(height: 1)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))

                        OutputView(text: store.vcfText, onCopy: copyVCF)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 40, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            // ── Navigation ───────────────────────────────────────────────────
            .navigationTitle("vCard Generator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Load") { showLoad = true }
                        .foregroundStyle(accent)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(accent)
        .preferredColorScheme(.dark)
        // ── Sheets ───────────────────────────────────────────────────────────
        .sheet(isPresented: $showLoad) {
            LoadVCardSheet { loaded in
                store.loadEntries(loaded)
                loaded.forEach { expandedIDs.insert($0.id) }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                ActivityView(items: [url])
            }
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📇")
                .font(.system(size: 52))
                .opacity(0.45)
            Text("No buttons yet — add one below")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        // iOS 26 Liquid Glass
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }

    // ── Action bar ────────────────────────────────────────────────────────────
    private var actionBar: some View {
        HStack(spacing: 10) {
            // Add Button
            Button {
                let entry = VCardEntry()
                store.entries.append(entry)
                expandedIDs.insert(entry.id)
            } label: {
                Label("Add Button", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .background(
                LinearGradient(colors: [accent, accent2],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(.white)
            .buttonStyle(.plain)

            // Download
            Button(action: exportVCF) {
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .background(
                LinearGradient(colors: [success, success2],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(Color(hex: "0a1a10"))
            .buttonStyle(.plain)
        }
    }

    // ── Section label ─────────────────────────────────────────────────────────
    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color(hex: "7A7A96"))
            .textCase(nil)
    }

    // ── Actions ───────────────────────────────────────────────────────────────
    private func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) { expandedIDs.remove(id) }
        else                        { expandedIDs.insert(id) }
    }

    private func copyVCF() {
        UIPasteboard.general.string = store.vcfText
    }

    private func exportVCF() {
        guard !store.entries.isEmpty else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shortcuts.vcf")
        try? store.vcfText.write(to: url, atomically: true, encoding: .utf8)
        shareURL = url
        showShare = true
    }
}

#Preview {
    ContentView()
}
