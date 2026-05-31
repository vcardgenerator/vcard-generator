import SwiftUI
import WebKit

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
            .ignoresSafeArea(edges: .bottom)
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

// MARK: - Live icon preview (instant, colors update with no snapshot delay) ────

private struct LucideIconPreview: View {
    let iconName: String
    let color:    Color

    @State private var svg: String? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(UIColor.secondarySystemBackground))
            if let svg {
                SVGLiveView(svg: svg, colorHex: color.hexString)
                    .padding(18)
                    .transition(.opacity)
            } else {
                ProgressView()
            }
        }
        .task(id: iconName) {
            guard let url = URL(string: "https://unpkg.com/lucide-static@latest/icons/\(iconName).svg"),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let s = String(data: data, encoding: .utf8) else { return }
            withAnimation(.easeInOut(duration: 0.2)) { svg = s }
        }
    }
}

// Inline-SVG WKWebView whose stroke follows CSS `color` (Lucide uses
// stroke="currentColor"), so recoloring is an instant JS call — no snapshot.
private struct SVGLiveView: UIViewRepresentable {
    let svg:      String
    let colorHex: String

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.isUserInteractionEnabled = false
        context.coordinator.loadedColor = colorHex
        wv.loadHTMLString(Self.html(svg: svg, colorHex: colorHex), baseURL: nil)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        guard context.coordinator.loadedColor != colorHex else { return }
        context.coordinator.loadedColor = colorHex
        wv.evaluateJavaScript("document.body.style.color='\(colorHex)';", completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var loadedColor = "" }

    private static func html(svg: String, colorHex: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="initial-scale=1,maximum-scale=1">
        <style>
        *{margin:0;padding:0;}
        html,body{width:100%;height:100%;display:flex;align-items:center;
                  justify-content:center;background:transparent;color:\(colorHex);}
        svg{width:100%!important;height:100%!important;display:block;}
        </style></head><body>\(svg)</body></html>
        """
    }
}

// MARK: - SVG → UIImage renderer (fixed offset) ───────────────────────────────

@MainActor
final class SVGRenderer {
    static let shared = SVGRenderer()
    private init() {}

    func render(svgString: String, colorHex: String = "#111827", size: CGFloat = 120) async -> UIImage? {
        let dim = Int(size)

        var svg = svgString.replacingOccurrences(of: "currentColor", with: colorHex)
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
        try? await Task.sleep(for: .milliseconds(550))

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
