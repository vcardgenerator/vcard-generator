import Observation
import UIKit

@MainActor
@Observable
final class VCardEntry: Identifiable {
    // `nonisolated let` so Identifiable.id is accessible from any context (Swift 6)
    nonisolated let id: UUID
    var title    = "Button Title"
    var subtitle = "Short description"
    var image: UIImage? = nil
    var imageName: String? = nil      // source name (Lucide icon, file, or photo)

    init(
        id: UUID = UUID(),
        title: String = "Button Title",
        subtitle: String = "Short description",
        image: UIImage? = nil,
        imageName: String? = nil
    ) {
        self.id        = id
        self.title     = title
        self.subtitle  = subtitle
        self.image     = image
        self.imageName = imageName
    }
}
