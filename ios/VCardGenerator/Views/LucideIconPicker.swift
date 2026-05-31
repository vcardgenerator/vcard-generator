import SwiftUI
import WebKit

// MARK: - Entry point sheet ───────────────────────────────────────────────────

struct LucideIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (UIImage) -> Void

    @State private var pendingIconName: String? = nil   // set when user taps an icon
    @State private var showColorPicker = false
    @State private var searchText      = ""

    var body: some View {
        NavigationStack {
            LucideWebGrid(searchText: searchText) { name in
                pendingIconName = name
                showColorPicker = true
            }
            .ignoresSafeArea(edges: .bottom)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search \(LucideIconPickerSheet.icons.count) icons")
            .navigationTitle("Lucide Icons")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            if let name = pendingIconName {
                LucideColorPickerSheet(iconName: name) { image in
                    onSelect(image)
                    dismiss()
                }
            }
        }
    }

    // ── Icon list (sorted) ────────────────────────────────────────────────────
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

// MARK: - WKWebView icon grid ─────────────────────────────────────────────────

struct LucideWebGrid: UIViewRepresentable {
    var searchText: String
    var onSelect:   (String) -> Void

    // Build the full HTML page once; JS handles filtering client-side
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "iconTapped")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.backgroundColor = .clear
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.navigationDelegate = context.coordinator
        wv.loadHTMLString(Self.gridHTML(), baseURL: nil)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        // Escape JS string — single-quote-safe
        let safe = searchText.replacingOccurrences(of: "'", with: "\\'")
        wv.evaluateJavaScript("filterIcons('\(safe)')", completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    // ── Coordinator ───────────────────────────────────────────────────────────
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onSelect: (String) -> Void
        init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }

        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "iconTapped",
                  let name = message.body as? String else { return }
            DispatchQueue.main.async { self.onSelect(name) }
        }

        // Open external links in Safari, not in the WKWebView
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }

    // ── Grid HTML (all icons embedded as <img> tags, lazy-loaded) ─────────────
    private static func gridHTML() -> String {
        let iconsJSON = LucideIconPickerSheet.icons
            .map { "\"\($0)\"" }
            .joined(separator: ",")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
        <style>
        *{box-sizing:border-box;margin:0;padding:0;}
        body{background:transparent;font-family:-apple-system,sans-serif;padding:12px;}
        #grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(72px,1fr));gap:8px;}
        .cell{display:flex;flex-direction:column;align-items:center;justify-content:center;
              gap:5px;padding:8px 4px;border-radius:12px;cursor:pointer;
              background:rgba(120,120,128,0.12);}
        .cell:active{background:rgba(0,122,255,0.18);}
        .cell img{width:32px;height:32px;display:block;}
        .cell span{font-size:9px;color:#888;text-align:center;word-break:break-all;line-height:1.2;}
        .hidden{display:none!important;}
        </style>
        </head>
        <body>
        <div id="grid"></div>
        <script>
        const icons=[\(iconsJSON)];
        const base="https://unpkg.com/lucide-static@latest/icons/";
        const grid=document.getElementById("grid");
        icons.forEach(name=>{
          const cell=document.createElement("div");
          cell.className="cell";
          cell.dataset.name=name;
          const img=document.createElement("img");
          img.src=base+name+".svg";
          img.loading="lazy";
          img.width=32;img.height=32;
          const lbl=document.createElement("span");
          lbl.textContent=name;
          cell.appendChild(img);
          cell.appendChild(lbl);
          cell.addEventListener("click",()=>{
            window.webkit.messageHandlers.iconTapped.postMessage(name);
          });
          grid.appendChild(cell);
        });
        function filterIcons(q){
          const lq=q.toLowerCase();
          grid.querySelectorAll(".cell").forEach(c=>{
            c.classList.toggle("hidden",lq.length>0&&!c.dataset.name.includes(lq));
          });
        }
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - Color picker sheet ───────────────────────────────────────────────────

struct LucideColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let iconName:  String
    let onConfirm: (UIImage) -> Void

    @State private var selectedColor    = Color(red: 0.07, green: 0.07, blue: 0.07)
    @State private var selectedPreset   = "Black"   // tracks which swatch is active
    @State private var isRendering      = false

    private let presets: [(String, Color)] = [
        ("Black",  Color(red: 0.07, green: 0.07, blue: 0.07)),
        ("White",  Color(red: 0.95, green: 0.95, blue: 0.95)),
        ("Blue",   Color(red: 0.00, green: 0.48, blue: 1.00)),
        ("Green",  Color(red: 0.20, green: 0.78, blue: 0.35)),
        ("Red",    Color(red: 1.00, green: 0.23, blue: 0.19)),
        ("Orange", Color(red: 1.00, green: 0.58, blue: 0.00)),
        ("Purple", Color(red: 0.69, green: 0.32, blue: 0.87)),
        ("Teal",   Color(red: 0.19, green: 0.68, blue: 0.71)),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Preview (color swatch with icon name) ─────────────────
                    VStack(spacing: 10) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 80, height: 80)
                            .shadow(color: selectedColor.opacity(0.4), radius: 10, y: 4)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor.hexString)
                    }
                    .padding(.top, 8)

                    Text(iconName)
                        .font(.headline)

                    // ── Preset swatches ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PRESETS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                            spacing: 10
                        ) {
                            ForEach(presets, id: \.0) { label, color in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        selectedColor  = color
                                        selectedPreset = label
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.accentColor, lineWidth: 2.5)
                                                    .opacity(selectedPreset == label ? 1 : 0)
                                            )
                                            .shadow(color: color.opacity(0.4), radius: 4, y: 2)
                                        Text(label)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))

                    // ── Custom color picker ───────────────────────────────────
                    HStack {
                        Text("Custom Color")
                            .font(.subheadline)
                        Spacer()
                        ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: selectedColor) { _, _ in
                                selectedPreset = ""  // deselect preset ring
                            }
                    }
                    .padding(16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))

                    // ── Use Icon button ───────────────────────────────────────
                    GlassEffectContainer {
                        Button {
                            Task { await renderAndConfirm() }
                        } label: {
                            Group {
                                if isRendering {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                } else {
                                    Label("Use Icon", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                            }
                        }
                        .glassEffect(in: Capsule())
                        .buttonStyle(.plain)
                        .tint(.green)
                        .disabled(isRendering)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func renderAndConfirm() async {
        guard !isRendering else { return }
        isRendering = true

        guard let url = URL(string: "https://unpkg.com/lucide-static@latest/icons/\(iconName).svg"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let svgString  = String(data: data, encoding: .utf8)
        else { isRendering = false; return }

        let hex = selectedColor.hexString
        guard let image = await SVGRenderer.shared.render(svgString: svgString, colorHex: hex)
        else { isRendering = false; return }

        onConfirm(image)
        dismiss()
    }
}

// MARK: - SVG → UIImage renderer (fixed offset) ───────────────────────────────

@MainActor
final class SVGRenderer {
    static let shared = SVGRenderer()
    private init() {}

    func render(svgString: String, colorHex: String = "#111827", size: CGFloat = 120) async -> UIImage? {
        let dim = Int(size)

        // Replace `currentColor` AND any existing width/height attributes on the root <svg>
        // so the SVG doesn't fight our CSS sizing.
        var svg = svgString
            .replacingOccurrences(of: "currentColor", with: colorHex)

        // Strip width="..." and height="..." attrs from the opening <svg tag
        svg = stripSVGDimensions(svg)

        let html = """
        <!DOCTYPE html><html>
        <head>
        <meta name="viewport" content="width=\(dim),initial-scale=1,maximum-scale=1">
        <style>
        *{margin:0;padding:0;border:0;}
        html,body{
          width:\(dim)px;height:\(dim)px;
          overflow:hidden;
          background:transparent;
          display:flex;align-items:center;justify-content:center;
        }
        svg{
          width:\(dim - 16)px!important;
          height:\(dim - 16)px!important;
          display:block;
          flex-shrink:0;
        }
        </style></head>
        <body>\(svg)</body></html>
        """

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return nil }

        let frame = CGRect(x: -(CGFloat(dim) + 40), y: 0,
                          width: CGFloat(dim), height: CGFloat(dim))
        let wv = WKWebView(frame: frame)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.backgroundColor = .clear
        window.addSubview(wv)

        wv.loadHTMLString(html, baseURL: nil)
        // Wait for render — 700ms is generous but reliable
        try? await Task.sleep(for: .milliseconds(700))

        let snapConfig = WKSnapshotConfiguration()
        snapConfig.rect = CGRect(origin: .zero,
                                 size: CGSize(width: CGFloat(dim), height: CGFloat(dim)))
        snapConfig.afterScreenUpdates = true

        return await withCheckedContinuation { continuation in
            wv.takeSnapshot(with: snapConfig) { image, _ in
                wv.removeFromSuperview()
                continuation.resume(returning: image)
            }
        }
    }

    // Remove width="xx" and height="xx" from the first <svg ...> tag only
    private func stripSVGDimensions(_ svg: String) -> String {
        guard let svgRange = svg.range(of: "<svg", options: .caseInsensitive),
              let closeRange = svg.range(of: ">", range: svgRange.upperBound..<svg.endIndex)
        else { return svg }

        let tagContent = String(svg[svgRange.upperBound..<closeRange.lowerBound])

        // Remove width="..." and height="..."
        var cleaned = tagContent
        let pattern = #"\s+(width|height)="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }

        return svg.replacingCharacters(
            in: svgRange.upperBound..<closeRange.lowerBound,
            with: cleaned
        )
    }
}
