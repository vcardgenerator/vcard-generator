import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct EntryRowView: View {
    @Bindable var entry:     VCardEntry
    let index:       Int
    let isExpanded:  Bool
    let onToggle:    () -> Void
    let onDelete:    () -> Void
    let onDuplicate: () -> Void

    @State private var pickerItem:      PhotosPickerItem? = nil
    @State private var showPhotoPicker  = false
    @State private var showLucidePicker = false

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
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        // ── Image source pickers ──────────────────────────────────────────────
        // NOTE: the file picker is presented imperatively (UIKit) rather than via
        // .fileImporter — stacking .fileImporter between .photosPicker and .sheet
        // on one List-row view makes SwiftUI silently drop its result.
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem,
                      matching: .images, photoLibrary: .shared())
        .sheet(isPresented: $showLucidePicker) {
            LucideIconPickerSheet { image, name in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    entry.image     = VCardService.resizeImage(image)
                    entry.imageName = name
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { @MainActor in
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let raw  = UIImage(data: data)
                else { return }
                let name = Self.photoFilename(for: item)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    entry.image     = VCardService.resizeImage(raw)
                    entry.imageName = name
                }
                pickerItem = nil
            }
        }
    }

    // Raster image formats UIImage can actually decode (excludes SVG/PDF, which
    // appear selectable under the generic `.image` type but won't load).
    private static let importableImageTypes: [UTType] = {
        var types: [UTType] = [.png, .jpeg, .heic, .heif, .gif, .tiff, .bmp]
        if let webp = UTType("org.webmproject.webp") { types.append(webp) }
        return types
    }()

    // Best-effort original filename (e.g. IMG_0001.HEIC). Only resolves when the
    // user has already granted Photos access; otherwise falls back to "Photo".
    private static func photoFilename(for item: PhotosPickerItem) -> String {
        guard let id = item.itemIdentifier else { return "Photo" }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return "Photo" }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return "Photo" }
        return PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "Photo"
    }

    // ── Header row ────────────────────────────────────────────────────────────
    private var headerRow: some View {
        Button {
            Haptics.impact(.light)
            onToggle()
        } label: {
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
                    Button {
                        Haptics.impact(.medium)
                        onDuplicate()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive) {
                        Haptics.impact(.rigid)
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
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

    // ── White-tinted SF Symbol for menus (UIKit menus override .foregroundStyle,
    //    so we bake the color into an .alwaysOriginal UIImage) ──────────────────
    private func menuIcon(_ systemName: String) -> Image {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let base   = UIImage(systemName: systemName, withConfiguration: config) ?? UIImage()
        let white  = base.withTintColor(.white, renderingMode: .alwaysOriginal)
        return Image(uiImage: white)
    }

    @ViewBuilder
    private var imageSourceMenuItems: some View {
        Button { showPhotoPicker  = true } label: {
            Label { Text("Photo Library") } icon: { menuIcon("photo") }
        }
        Button { presentFilePicker() } label: {
            Label { Text("Choose File") }   icon: { menuIcon("folder.badge.plus") }
        }
        Button { showLucidePicker = true } label: {
            Label { Text("Lucide Icons") }  icon: { menuIcon("square.grid.3x3") }
        }
    }

    // ── Image area ────────────────────────────────────────────────────────────
    @ViewBuilder
    private var imageArea: some View {
        if let img = entry.image {
            VStack(spacing: 12) {
                // ── Thumbnail + info ──────────────────────────────────────────
                HStack(spacing: 12) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.imageName ?? "Image loaded")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(Int(img.size.width)) × \(Int(img.size.height)) px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                // ── Change / Remove on their own full-width row ───────────────
                GlassEffectContainer {
                    HStack(spacing: 8) {
                        Menu {
                            imageSourceMenuItems
                        } label: {
                            Text("Change")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                        }
                        .glassEffect(in: Capsule())

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                entry.image     = nil
                                entry.imageName = nil
                            }
                        } label: {
                            Text("Remove")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                        }
                        .glassEffect(in: Capsule())
                        .buttonStyle(.plain)
                        .tint(.red)
                    }
                }
            }
            .padding(12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
        } else {
            // ── No image — Choose Image dropdown ──────────────────────────────
            GlassEffectContainer {
                Menu {
                    imageSourceMenuItems
                } label: {
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
                }
                .glassEffect(in: Capsule())
            }
            .transition(.opacity)
        }
    }

    // ── File picker (imperative UIKit presentation) ───────────────────────────
    private func presentFilePicker() {
        FileImagePicker.present(types: Self.importableImageTypes) { raw, name in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                entry.image     = VCardService.resizeImage(raw)
                entry.imageName = name
            }
        }
    }
}

// MARK: - Imperative document picker for images
//
// Presented directly on the top view controller so it never collides with the
// other SwiftUI presentation modifiers on the row. `asCopy: true` hands back a
// sandbox-local copy, so reading it never hits iCloud-materialization or
// security-scope problems.

@MainActor
enum FileImagePicker {
    private final class Delegate: NSObject, UIDocumentPickerDelegate {
        let onPick: (UIImage, String) -> Void
        init(onPick: @escaping (UIImage, String) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            defer { FileImagePicker.retained = nil }
            guard let url = urls.first,
                  let data = try? Data(contentsOf: url),
                  let img  = UIImage(data: data) else { return }
            onPick(img, url.lastPathComponent)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            FileImagePicker.retained = nil
        }
    }

    private static var retained: Delegate?      // keep the delegate alive while open

    static func present(types: [UTType], onPick: @escaping (UIImage, String) -> Void) {
        let delegate = Delegate(onPick: onPick)
        retained = delegate

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = delegate
        picker.allowsMultipleSelection = false
        topViewController()?.present(picker, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let keyWindow = windows.first { $0.isKeyWindow } ?? windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
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
