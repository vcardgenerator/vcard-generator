import UIKit

struct VCardService {

    // MARK: Image resize

    static func resizeImage(_ image: UIImage, to size: CGSize = CGSize(width: 123, height: 123)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: Build

    @MainActor
    static func buildVCF(entries: [VCardEntry]) -> String {
        guard !entries.isEmpty else { return "" }
        return entries.map { entry in
            var lines = [
                "BEGIN:VCARD",
                "VERSION:3.0",
                "N;CHARSET=utf-8:\(entry.title);;;;",
                "ORG:\(entry.subtitle);"
            ]
            if let image = entry.image {
                let resized = resizeImage(image)
                if let b64 = resized.pngData()?.base64EncodedString() {
                    lines.append("PHOTO;ENCODING=b: \(b64)")
                }
            }
            lines.append("END:VCARD")
            return lines.joined(separator: "\n")
        }.joined(separator: "\n")
    }

    // MARK: Parse

    @MainActor
    static func parseVCF(_ text: String) -> [VCardEntry] {
        // Normalize line endings
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r",   with: "\n")
        // Unfold RFC-2425 continuation lines (line starting with space/tab)
        let unfolded = normalized.replacingOccurrences(
            of: "\n[ \t]", with: "", options: .regularExpression
        )

        guard let regex = try? NSRegularExpression(
            pattern: "BEGIN:VCARD([\\s\\S]*?)END:VCARD",
            options: .caseInsensitive
        ) else { return [] }

        let nsStr  = unfolded as NSString
        let range  = NSRange(location: 0, length: nsStr.length)
        let matches = regex.matches(in: unfolded, range: range)

        return matches.compactMap { match -> VCardEntry? in
            guard let r = Range(match.range(at: 1), in: unfolded) else { return nil }
            return parseBlock(String(unfolded[r]))
        }
    }

    @MainActor
    private static func parseBlock(_ block: String) -> VCardEntry? {
        let lines = block
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var title    = ""
        var subtitle = ""
        var imageB64: String? = nil

        for line in lines {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIdx]).lowercased()
            let val = String(line[line.index(after: colonIdx)...])

            if key == "n" || key.hasPrefix("n;") {
                let name = val.components(separatedBy: ";").first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if !name.isEmpty { title = name }
            } else if key == "fn" && title.isEmpty {
                title = val.trimmingCharacters(in: .whitespaces)
            } else if key == "org" {
                subtitle = val
                    .replacingOccurrences(of: ";+$", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            } else if key.contains("encoding=b") {
                imageB64 = val.trimmingCharacters(in: .whitespaces)
            }
        }

        let entry = VCardEntry(
            title:    title.isEmpty ? "Button Title" : title,
            subtitle: subtitle
        )
        if let b64 = imageB64,
           let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
           let img  = UIImage(data: data) {
            entry.image = img
        }
        return entry
    }
}
