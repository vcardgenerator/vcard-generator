import SwiftUI
import WebKit

// MARK: - Lucide Icon Picker Sheet

struct LucideIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (UIImage) -> Void

    @State private var searchText = ""
    @State private var isLoading  = false

    private var filtered: [String] {
        searchText.isEmpty
            ? Self.icons
            : Self.icons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            Task { await selectIcon(name) }
                        } label: {
                            Text(name)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search \(Self.icons.count) icons")
            .navigationTitle("Lucide Icons")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.2)
                        Text("Fetching icon…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    // ── Icon fetch & render ───────────────────────────────────────────────────
    @MainActor
    private func selectIcon(_ name: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "https://unpkg.com/lucide-static@latest/icons/\(name).svg"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let svgString = String(data: data, encoding: .utf8)
        else { return }

        guard let image = await SVGRenderer.shared.render(svgString: svgString) else { return }
        onSelect(image)
        dismiss()
    }

    // ── Icon list ─────────────────────────────────────────────────────────────
    static let icons: [String] = [
        "activity", "airplay", "alarm-clock", "alert-circle", "alert-octagon",
        "alert-triangle", "align-center", "align-justify", "align-left", "align-right",
        "anchor", "aperture", "archive", "arrow-down", "arrow-down-circle",
        "arrow-down-left", "arrow-down-right", "arrow-left", "arrow-left-circle",
        "arrow-right", "arrow-right-circle", "arrow-up", "arrow-up-circle",
        "arrow-up-left", "arrow-up-right", "at-sign", "award", "bar-chart",
        "bar-chart-2", "battery", "battery-charging", "bell", "bell-off",
        "bluetooth", "bold", "book", "book-open", "bookmark", "box",
        "briefcase", "calendar", "camera", "cast", "check", "check-circle",
        "check-square", "chevron-down", "chevron-left", "chevron-right", "chevron-up",
        "circle", "clipboard", "clock", "cloud", "cloud-drizzle", "cloud-lightning",
        "cloud-rain", "cloud-snow", "code", "coffee", "columns", "command",
        "compass", "copy", "cpu", "credit-card", "crop", "crosshair",
        "database", "delete", "disc", "dollar-sign", "download", "download-cloud",
        "droplets", "edit", "edit-2", "edit-3", "external-link", "eye", "eye-off",
        "fast-forward", "feather", "file", "file-minus", "file-plus", "file-text",
        "filter", "flag", "folder", "folder-minus", "folder-open", "folder-plus",
        "frown", "gift", "git-branch", "git-commit", "github", "globe",
        "grid", "hard-drive", "hash", "headphones", "heart", "help-circle",
        "home", "image", "inbox", "info", "italic", "key", "layers",
        "layout", "link", "link-2", "list", "loader", "lock", "log-in",
        "log-out", "mail", "map", "map-pin", "maximize", "maximize-2",
        "meh", "menu", "message-circle", "message-square", "mic", "mic-off",
        "minimize", "minus", "minus-circle", "monitor", "moon", "more-horizontal",
        "more-vertical", "music", "navigation", "octagon", "package", "paperclip",
        "pause", "pause-circle", "pen-tool", "percent", "phone", "phone-call",
        "phone-off", "pie-chart", "play", "play-circle", "plus", "plus-circle",
        "plus-square", "pocket", "power", "printer", "radio", "refresh-cw",
        "rewind", "rss", "save", "scissors", "search", "send", "server",
        "settings", "share", "share-2", "shield", "shopping-bag", "shopping-cart",
        "shuffle", "sidebar", "skip-back", "skip-forward", "slash", "sliders",
        "smartphone", "smile", "speaker", "square", "star", "stop-circle",
        "sun", "sunrise", "sunset", "tablet", "tag", "target", "terminal",
        "thumbs-down", "thumbs-up", "toggle-left", "toggle-right", "tool",
        "trash", "trash-2", "trending-down", "trending-up", "triangle",
        "truck", "tv", "type", "umbrella", "underline", "unlock",
        "upload", "upload-cloud", "user", "user-check", "user-minus",
        "user-plus", "user-x", "users", "video", "video-off", "voicemail",
        "volume", "volume-1", "volume-2", "volume-x", "watch", "wifi",
        "wifi-off", "wind", "x", "x-circle", "x-octagon", "x-square",
        "youtube", "zap", "zap-off", "zoom-in", "zoom-out"
    ].sorted()
}

// MARK: - SVG → UIImage renderer

@MainActor
final class SVGRenderer {
    static let shared = SVGRenderer()
    private init() {}

    func render(svgString: String, size: CGFloat = 120) async -> UIImage? {
        let dim = Int(size)
        let colored = svgString.replacingOccurrences(of: "currentColor", with: "#111827")
        let html = """
        <!DOCTYPE html><html>
        <head>
        <meta name="viewport" content="width=\(dim),initial-scale=1">
        <style>
        *{margin:0;padding:0;}
        html,body{width:\(dim)px;height:\(dim)px;background:transparent;
                  display:flex;align-items:center;justify-content:center;}
        svg{width:\(dim-16)px!important;height:\(dim-16)px!important;}
        </style></head>
        <body>\(colored)</body></html>
        """

        // Attach off-screen to window so WebKit renders properly
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return nil }

        let frame = CGRect(x: -CGFloat(dim) - 20, y: 0, width: CGFloat(dim), height: CGFloat(dim))
        let wv = WKWebView(frame: frame)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        window.addSubview(wv)

        wv.loadHTMLString(html, baseURL: nil)
        try? await Task.sleep(for: .milliseconds(700))

        let snapConfig = WKSnapshotConfiguration()
        snapConfig.afterScreenUpdates = true

        return await withCheckedContinuation { continuation in
            wv.takeSnapshot(with: snapConfig) { image, _ in
                wv.removeFromSuperview()
                continuation.resume(returning: image)
            }
        }
    }
}
