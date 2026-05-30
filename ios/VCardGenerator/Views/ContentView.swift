import SwiftUI

// MARK: - Shared glass button style (used across all views)

struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var store       = VCardStore()
    @State private var expandedIDs = Set<UUID>()
    @State private var showLoad    = false
    @State private var showShare   = false
    @State private var shareURL:   URL? = nil

    var body: some View {
        NavigationStack {
            List {
                // ── Entries ───────────────────────────────────────────────────
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
                                onToggle: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        toggleExpand(entry.id)
                                    }
                                },
                                onDelete: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        store.removeEntry(entry)
                                    }
                                },
                                onDuplicate: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        let copy = store.duplicateEntry(entry)
                                        expandedIDs.insert(copy.id)
                                    }
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity),
                                removal:   .scale(scale: 0.88).combined(with: .opacity)
                            ))
                        }
                        .onMove  { store.moveEntries(from: $0, to: $1) }
                        .onDelete {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                store.removeEntries(at: $0)
                            }
                        }
                    }
                } header: {
                    Text("Buttons")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                // ── Action bar ────────────────────────────────────────────────
                Section {
                    actionBar
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                // ── Output ────────────────────────────────────────────────────
                Section {
                    OutputView(text: store.vcfText, onCopy: copyVCF)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 40, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("vCard Generator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Load") { showLoad = true }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton().fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showLoad) {
            LoadVCardSheet { loaded in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    store.loadEntries(loaded)
                    loaded.forEach { expandedIDs.insert($0.id) }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ActivityView(items: [url]) }
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
            VStack(spacing: 4) {
                Text("No buttons yet")
                    .font(.headline)
                Text("Tap Add Button to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }

    // ── Action bar ────────────────────────────────────────────────────────────
    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    let entry = VCardEntry()
                    store.entries.append(entry)
                    expandedIDs.insert(entry.id)
                }
            } label: {
                Label("Add Button", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(GlassButtonStyle())

            Button(action: exportVCF) {
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(GlassButtonStyle())
            .tint(.green)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
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
