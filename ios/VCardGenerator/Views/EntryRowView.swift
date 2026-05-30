import SwiftUI
import PhotosUI

struct EntryRowView: View {
    @Bindable var entry:     VCardEntry
    let index:       Int
    let isExpanded:  Bool
    let onToggle:    () -> Void
    let onDelete:    () -> Void
    let onDuplicate: () -> Void

    @State private var pickerItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            if isExpanded {
                Divider()
                    .transition(.opacity)
                detailBody
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // Whole card is Liquid Glass
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .onChange(of: pickerItem) { _, newItem in
            Task { @MainActor in
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let raw  = UIImage(data: data)
                else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    entry.image = VCardService.resizeImage(raw)
                }
                pickerItem = nil
            }
        }
    }

    // ── Header row ────────────────────────────────────────────────────────────
    private var headerRow: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("#\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 22, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !entry.subtitle.isEmpty {
                        Text(entry.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                }

                Spacer(minLength: 4)

                if entry.image != nil {
                    Circle()
                        .fill(.tint)
                        .frame(width: 7, height: 7)
                        .transition(.scale.combined(with: .opacity))
                }

                HStack(spacing: 8) {
                    Button(action: onDuplicate) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    // ── Detail body ───────────────────────────────────────────────────────────
    private var detailBody: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                fieldColumn(label: "Title") {
                    GlassTextField("Button Title", text: $entry.title)
                }
                fieldColumn(label: "Subtitle") {
                    GlassTextField("Short description", text: $entry.subtitle)
                }
            }

            fieldColumn(label: "Icon Image") {
                imageArea
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: entry.image != nil)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func fieldColumn<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── Image area ────────────────────────────────────────────────────────────
    @ViewBuilder
    private var imageArea: some View {
        if let img = entry.image {
            HStack(spacing: 12) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Image loaded")
                        .font(.subheadline.weight(.semibold))
                    Text("123 × 123 px")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    // Change: use PhotosPicker label directly
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Change")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(in: Capsule())
                    }

                    // Remove
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            entry.image = nil
                        }
                    } label: {
                        Text("Remove")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .tint(.red)
                }
            }
            .padding(12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
        } else {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.tint)
                    Text("Choose Image")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .glassEffect(in: Capsule())
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Glass Text Field

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
    }
}
