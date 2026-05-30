import Observation
import Foundation

@MainActor
@Observable
final class VCardStore {
    var entries: [VCardEntry] = []

    var vcfText: String {
        VCardService.buildVCF(entries: entries)
    }

    // MARK: Mutations

    func addEntry() {
        entries.append(VCardEntry())
    }

    func removeEntry(_ entry: VCardEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func removeEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    func moveEntries(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
    }

    func duplicateEntry(_ entry: VCardEntry) -> VCardEntry {
        let copy = VCardEntry(
            title:    entry.title + " Copy",
            subtitle: entry.subtitle,
            image:    entry.image
        )
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.insert(copy, at: idx + 1)
        } else {
            entries.append(copy)
        }
        return copy
    }

    func loadEntries(_ newEntries: [VCardEntry]) {
        entries.append(contentsOf: newEntries)
    }
}
