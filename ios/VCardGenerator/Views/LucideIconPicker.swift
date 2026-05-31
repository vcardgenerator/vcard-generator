import SwiftUI
import WebKit

// MARK: - Shared CDN base ──────────────────────────────────────────────────────
// The grid resolves lucide-static's concrete version from unpkg's @latest
// redirect and stores the pinned base here. Reusing it for the preview/render
// fetches avoids paying that redirect again — which is exactly why the *first*
// icon used to load blank while later ones were instant (redirect since cached).

@MainActor
final class LucideCDN {
    static let shared = LucideCDN()
    private init() {}

    var iconsBase = "https://unpkg.com/lucide-static@latest/icons/"
    func url(for name: String) -> URL? { URL(string: iconsBase + name + ".svg") }
}

// MARK: - Entry point sheet ───────────────────────────────────────────────────

struct LucideIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (UIImage, String) -> Void

    @State private var pendingIconName: String? = nil   // set when user taps an icon
    @State private var showColorPicker = false
    @State private var searchText      = ""
    @State private var gridLoading     = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("lucide.dev/icons")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                LucideWebGrid(
                    searchText: searchText,
                    onSelect: { name in
                        pendingIconName = name
                        showColorPicker = true
                    },
                    onReady: {
                        withAnimation(.easeOut(duration: 0.25)) { gridLoading = false }
                    }
                )
                .overlay {
                    if gridLoading {
                        VStack(spacing: 12) {
                            ProgressView().scaleEffect(1.2)
                            Text("Loading icons…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search Lucide icons")
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
                    onSelect(image, name)
                    dismiss()
                }
            }
        }
    }

    // ── Fallback list (used only if the live fetch fails) ─────────────────────
    static let fallbackIcons: [String] = [
        "activity", "airplay", "alarm-clock", "alert-circle", "alert-triangle",
        "anchor", "archive", "arrow-down", "arrow-left", "arrow-right", "arrow-up",
        "award", "bell", "book", "bookmark", "box", "calendar", "camera", "check",
        "chevron-down", "chevron-left", "chevron-right", "chevron-up", "circle",
        "clock", "cloud", "code", "coffee", "compass", "copy", "credit-card",
        "download", "edit", "eye", "file", "file-text", "filter", "flag", "folder",
        "gift", "globe", "grid", "heart", "home", "image", "info", "key", "layers",
        "link", "list", "lock", "mail", "map", "map-pin", "menu", "message-circle",
        "mic", "monitor", "moon", "music", "package", "paperclip", "pause", "phone",
        "play", "plus", "power", "printer", "save", "search", "send", "settings",
        "share", "shield", "shopping-cart", "smartphone", "star", "sun", "tag",
        "target", "terminal", "trash", "trending-up", "user", "users", "video",
        "volume", "wifi", "x", "zap"
    ].sorted()
}

// MARK: - WKWebView icon grid ─────────────────────────────────────────────────

struct LucideWebGrid: UIViewRepresentable {
    var searchText: String
    var onSelect:   (String) -> Void
    var onReady:    () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "iconTapped")
        config.userContentController.add(context.coordinator, name: "gridReady")
        config.userContentController.add(context.coordinator, name: "resolvedBase")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.backgroundColor = .clear
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.navigationDelegate = context.coordinator
        wv.loadHTMLString(Self.gridHTML(), baseURL: nil)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        let safe = searchText.replacingOccurrences(of: "\\", with: "\\\\")
                             .replacingOccurrences(of: "'", with: "\\'")
        wv.evaluateJavaScript("filterIcons('\(safe)')", completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onReady: onReady)
    }

    // ── Coordinator ───────────────────────────────────────────────────────────
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onSelect: (String) -> Void
        let onReady:  () -> Void
        init(onSelect: @escaping (String) -> Void, onReady: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onReady  = onReady
        }

        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "iconTapped":
                if let name = message.body as? String {
                    DispatchQueue.main.async { self.onSelect(name) }
                }
            case "gridReady":
                DispatchQueue.main.async { self.onReady() }
            case "resolvedBase":
                if let base = message.body as? String, !base.isEmpty {
                    Task { @MainActor in LucideCDN.shared.iconsBase = base }
                }
            default:
                break
            }
        }

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

    // ── Grid HTML — fetches the full icon list from Lucide at runtime ──────────
    private static func gridHTML() -> String {
        let fallbackJSON = LucideIconPickerSheet.fallbackIcons
            .map { "\"\($0)\"" }
            .joined(separator: ",")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
        <style>
        *{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}
        body{background:transparent;font-family:-apple-system,sans-serif;padding:12px 12px 32px;}
        #grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(70px,1fr));gap:8px;}
        .cell{display:flex;flex-direction:column;align-items:center;justify-content:center;
              gap:6px;padding:10px 4px;border-radius:14px;cursor:pointer;
              background:rgba(120,120,128,0.16);transition:background .12s;}
        .cell:active{background:rgba(0,122,255,0.30);}
        .cell img{width:28px;height:28px;display:block;}
        .cell span{font-size:8.5px;color:#8a8a8e;text-align:center;
                   word-break:break-all;line-height:1.15;max-height:2.3em;overflow:hidden;}
        .hidden{display:none!important;}
        /* Lucide SVGs are black strokes — invert to white in dark mode so they stay visible */
        @media (prefers-color-scheme: dark){ .cell img{ filter:invert(1); } }
        </style>
        </head>
        <body>
        <div id="grid"></div>
        <script>
        const fallback=[\(fallbackJSON)];
        const grid=document.getElementById("grid");

        function build(names, base){
          const frag=document.createDocumentFragment();
          names.forEach(name=>{
            const cell=document.createElement("div");
            cell.className="cell"; cell.dataset.name=name;
            const img=document.createElement("img");
            img.src=base+name+".svg"; img.loading="lazy"; img.width=28; img.height=28;
            const lbl=document.createElement("span"); lbl.textContent=name;
            cell.appendChild(img); cell.appendChild(lbl);
            cell.addEventListener("click",()=>{
              window.webkit.messageHandlers.iconTapped.postMessage(name);
            });
            frag.appendChild(cell);
          });
          grid.appendChild(frag);
        }

        function filterIcons(q){
          const lq=q.toLowerCase();
          grid.querySelectorAll(".cell").forEach(c=>{
            c.classList.toggle("hidden", lq.length>0 && c.dataset.name.indexOf(lq)===-1);
          });
        }

        async function init(){
          let names=fallback;
          let base="https://unpkg.com/lucide-static@latest/icons/";
          try{
            const res=await fetch("https://unpkg.com/lucide-static@latest/tags.json");
            const m=res.url.match(/lucide-static@([^/]+)/);
            const tags=await res.json();
            names=Object.keys(tags).sort();
            if(m){ base="https://unpkg.com/lucide-static@"+m[1]+"/icons/"; }
          }catch(e){ /* keep fallback */ }
          window.webkit.messageHandlers.resolvedBase.postMessage(base);
          build(names, base);
          window.webkit.messageHandlers.gridReady.postMessage("ready");
        }
        init();
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
    @State private var selectedPreset   = "Black"
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

                    // ── Preview ───────────────────────────────────────────────
                    LucideIconPreview(iconName: iconName, color: selectedColor)
                        .frame(width: 96, height: 96)
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
                                                Circle().stroke(.gray.opacity(0.35), lineWidth: 1)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.accentColor, lineWidth: 2.5)
                                                    .opacity(selectedPreset == label ? 1 : 0)
                                            )
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
                                selectedPreset = ""
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

        // Same renderer/cache the preview used, so this is usually instant.
        guard let image = await LucideRenderer.shared.render(iconName: iconName,
                                                             colorHex: selectedColor.hexString)
        else { isRendering = false; return }

        onConfirm(image)
        dismiss()
    }
}

// MARK: - Icon preview (renders to a UIImage via the shared renderer) ──────────

private struct LucideIconPreview: View {
    let iconName: String
    let color:    Color

    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(UIColor.secondarySystemBackground))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .transition(.opacity)
            } else {
                ProgressView()
            }
        }
        // Re-render whenever the chosen color changes; the old image stays
        // on screen until the new one is ready (no progress-flash on recolor).
        .task(id: color.hexString) {
            let img = await LucideRenderer.shared.render(iconName: iconName,
                                                         colorHex: color.hexString)
            if !Task.isCancelled, let img {
                withAnimation(.easeInOut(duration: 0.2)) { image = img }
            }
        }
    }
}

// MARK: - SVG → UIImage renderer ───────────────────────────────────────────────
//
// One persistent, pre-warmed WKWebView, reused for every render. The old code
// spun up a *fresh* web view per call; the very first one hadn't warmed its web
// content process yet, so its snapshot came back blank ("first icon never loads,
// the next is instant"). A single warm web view + a per-render ready token (so we
// snapshot the actual new frame, not a stale one) makes the first render reliable.

@MainActor
final class LucideRenderer {
    static let shared = LucideRenderer()

    private let webView: WKWebView
    private let dim: CGFloat = 120
    private var cache: [String: UIImage] = [:]
    private var tail: Task<Void, Never> = Task {}

    private init() {
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.backgroundColor = .clear
    }

    /// Spin up the web content process at launch so the first real render is warm.
    func prewarm() {
        attach()
        webView.loadHTMLString("<!doctype html><html><body></body></html>", baseURL: nil)
    }

    private func attach() {
        guard webView.superview == nil else { return }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return }
        webView.frame = CGRect(x: -(dim + 40), y: 0, width: dim, height: dim)   // offscreen
        window.addSubview(webView)
    }

    func render(iconName: String, colorHex: String) async -> UIImage? {
        let key = "\(iconName)|\(colorHex.lowercased())"
        if let cached = cache[key] { return cached }

        // Serialize — there is only one shared web view.
        let previous = tail
        let work = Task { @MainActor () -> UIImage? in
            _ = await previous.value
            return await self.doRender(key: key, iconName: iconName, colorHex: colorHex)
        }
        tail = Task { _ = await work.value }
        return await work.value
    }

    private func doRender(key: String, iconName: String, colorHex: String) async -> UIImage? {
        if let cached = cache[key] { return cached }
        guard let url = LucideCDN.shared.url(for: iconName),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let rawSVG = String(data: data, encoding: .utf8) else { return nil }

        attach()
        let token = UUID().uuidString
        webView.loadHTMLString(Self.html(svg: Self.colorized(rawSVG, colorHex: colorHex),
                                         dim: Int(dim), token: token),
                               baseURL: nil)
        await waitForToken(token)

        let cfg = WKSnapshotConfiguration()
        cfg.rect = CGRect(x: 0, y: 0, width: dim, height: dim)
        cfg.afterScreenUpdates = true
        let image = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
            webView.takeSnapshot(with: cfg) { img, _ in cont.resume(returning: img) }
        }
        if let image { cache[key] = image }
        return image
    }

    /// Poll until the freshly loaded document reports our unique token, so we
    /// never snapshot a stale or half-loaded page.
    private func waitForToken(_ token: String, timeoutMs: Int = 2500) async {
        let start = Date()
        while Date().timeIntervalSince(start) * 1000 < Double(timeoutMs) {
            let current = await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
                webView.evaluateJavaScript("window.__t||''") { r, _ in
                    cont.resume(returning: (r as? String) ?? "")
                }
            }
            if current == token {
                try? await Task.sleep(for: .milliseconds(80))   // let the frame paint
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func colorized(_ svg: String, colorHex: String) -> String {
        stripDimensions(svg.replacingOccurrences(of: "currentColor", with: colorHex))
    }

    private static func html(svg: String, dim: Int, token: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=\(dim),initial-scale=1,maximum-scale=1">
        <style>
        *{margin:0;padding:0;border:0;}
        html,body{width:\(dim)px;height:\(dim)px;overflow:hidden;background:transparent;
                  display:flex;align-items:center;justify-content:center;}
        svg{width:\(dim - 16)px!important;height:\(dim - 16)px!important;display:block;flex-shrink:0;}
        </style></head>
        <body>\(svg)<script>window.__t="\(token)";</script></body></html>
        """
    }

    private static func stripDimensions(_ svg: String) -> String {
        guard let svgRange = svg.range(of: "<svg", options: .caseInsensitive),
              let closeRange = svg.range(of: ">", range: svgRange.upperBound..<svg.endIndex)
        else { return svg }

        let tagContent = String(svg[svgRange.upperBound..<closeRange.lowerBound])
        var cleaned = tagContent
        let pattern = #"\s+(width|height)="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }
        return svg.replacingCharacters(in: svgRange.upperBound..<closeRange.lowerBound, with: cleaned)
    }
}
