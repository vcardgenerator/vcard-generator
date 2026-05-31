import SwiftUI

// MARK: - Root (provides shared store to both tabs)

struct ContentView: View {
    @State private var store = VCardStore()

    var body: some View {
        TabView {
            Tab("Buttons", systemImage: "square.stack.3d.up.fill") {
                BuilderTab(store: store)
            }
            Tab("Output", systemImage: "doc.text") {
                OutputTab(store: store)
            }
            Tab("Guide", systemImage: "book.fill") {
                GuideTab()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsTab()
            }
        }
    }
}

// MARK: - Builder Tab

struct BuilderTab: View {
    var store: VCardStore

    @State private var expandedIDs = Set<UUID>()
    @State private var showLoad    = false

    private var motion: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }

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
                                    withAnimation(motion) {
                                        store.removeEntry(entry)
                                    }
                                },
                                onDuplicate: {
                                    withAnimation(motion) {
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
                                removal:   .opacity
                            ))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Haptics.impact(.rigid)
                                    store.removeEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }

                // ── Add Button ────────────────────────────────────────────────
                Section {
                    GlassEffectContainer {
                        Button {
                            Haptics.impact(.medium)
                            withAnimation(motion) {
                                let entry = VCardEntry()
                                store.entries.append(entry)
                                expandedIDs.insert(entry.id)
                            }
                        } label: {
                            Label {
                                Text("Add Button")
                                    .font(.subheadline.weight(.bold))
                            } icon: {
                                Image(systemName: "plus")
                                    .foregroundStyle(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .glassEffect(in: Capsule())
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))

                    Text("Your output will appear in the Output tab")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 2, leading: 16, bottom: 8, trailing: 16))
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
            }
        }
        .sheet(isPresented: $showLoad) {
            LoadVCardSheet { loaded in
                withAnimation(motion) {
                    store.loadEntries(loaded)
                    loaded.forEach { expandedIDs.insert($0.id) }
                }
            }
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.fill")
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

    private func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) { expandedIDs.remove(id) }
        else                        { expandedIDs.insert(id) }
    }
}

// MARK: - Output Tab

struct OutputTab: View {
    var store: VCardStore

    @State private var vcfURL: URL? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    OutputView(text: store.vcfText, onCopy: copyVCF)

                    GlassEffectContainer {
                        if let url = vcfURL {
                            ShareLink(item: url) {
                                Label("Download .vcf", systemImage: "arrow.down.circle")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .glassEffect(in: Capsule())
                            .buttonStyle(.plain)
                            .tint(.green)
                        } else {
                            Button(action: {}) {
                                Label("Download .vcf", systemImage: "arrow.down.circle")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .glassEffect(in: Capsule())
                            .buttonStyle(.plain)
                            .disabled(true)
                            .opacity(0.4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Output")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: store.vcfText) { _, text in
            refreshVCFURL(text: text)
        }
        .onAppear {
            refreshVCFURL(text: store.vcfText)
        }
    }

    private func copyVCF() {
        Haptics.impact(.light)
        UIPasteboard.general.string = store.vcfText
    }

    private func refreshVCFURL(text: String) {
        guard !text.isEmpty, !store.entries.isEmpty else {
            vcfURL = nil
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shortcuts.vcf")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        vcfURL = url
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
