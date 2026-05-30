import Observation
import UIKit

@MainActor
@Observable
final class VCardEntry: Identifiable {
    var id       = UUID()
    var title    = "Button Title"
    var subtitle = "Short description"
    var image: UIImage? = nil

    init(
        id: UUID = UUID(),
        title: String = "Button Title",
        subtitle: String = "Short description",
        image: UIImage? = nil
    ) {
        self.id       = id
        self.title    = title
        self.subtitle = subtitle
        self.image    = image
    }
}
