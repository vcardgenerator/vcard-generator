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
                Divider().background(Color(hex: "2A2A38"))
                detailBody
            }
        }
        // iOS 26 Liquid Glass card
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: pickerItem) { _, newItem in
            Task { @MainActor in
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let raw  = UIImage(data: data)
                else { return }
                entry.image = VCardService.resizeImage(raw)
                pickerItem  = nil          // reset so same image can be re-picked
            }
        }
    }

    // ── Header row ────────────────────────────────────────────────────────────
    private var headerRow: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "7C6AF7").opacity(0.55))

                Text("#\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: "7C6AF7"))
                    .monospacedDigit()
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
                    }
                }

                Spacer(minLength: 4)

                // Image dot indicator
                if entry.image != nil {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "34C98A"), Color(hex: "2EBBCC")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 7, height: 7)
                }

                // Inline action buttons
                HStack(spacing: 6) {
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
                    .animation(.spring(duration: 0.22), value: isExpanded)
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
                    DarkTextField("Button Title", text: $entry.title)
                }
                fieldColumn(label: "Subtitle") {
                    DarkTextField("Short description", text: $entry.subtitle)
                }
            }

            fieldColumn(label: "Icon Image (optional)") {
                imageArea
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func fieldColumn<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "7A7A96"))
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(hex: "2A2A38"), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Image loaded")
                        .font(.subheadline.weight(.semibold))
                    Text("123 × 123 px")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    // Change — wraps PhotosPicker so the whole label is tappable
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Change")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(Color(hex: "7C6AF7").opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(hex: "7C6AF7").opacity(0.3)))
                            .foregroundStyle(Color(hex: "7C6AF7"))
                    }

                    // Remove
                    Button("Remove") {
                        entry.image = nil
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Color(hex: "F75A5A").opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(hex: "F75A5A").opacity(0.25)))
                    .foregroundStyle(Color(hex: "F75A5A"))
                    .buttonStyle(.plain)
                }
            }
            .padding(13)
            .background(Color(hex: "14141E"), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "2A2A38"), lineWidth: 1))
        } else {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .foregroundStyle(Color(hex: "7C6AF7"))
                    Text("Tap to choose an image")
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
        }
    }
}

// ── Dark text field ───────────────────────────────────────────────────────────
struct DarkTextField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color(hex: "14141E"), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(hex: "2A2A38"), lineWidth: 1)
            )
            .foregroundStyle(Color(hex: "F0F0F8"))
            .tint(Color(hex: "7C6AF7"))
            .font(.system(size: 15))
    }
}
