import Foundation
import Observation

/// The word diary: every word the learner tapped and kept.
///
/// Stored in the App Group container when one is configured, so the home-screen
/// widget can read the same file. Falls back to the app's own container.
@Observable
final class FlashcardStore {
    /// Set this to your App Group id in Signing & Capabilities to enable the widget.
    static let appGroup = "group.dk.joydeep.danskgrammamama"
    static let fileName = "flashcards.json"

    private(set) var cards: [Flashcard] = []

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var fileURL: URL { FlashcardStore.containerURL.appendingPathComponent(FlashcardStore.fileName) }

    init() { reload() }

    func reload() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([Flashcard].self, from: data) {
            cards = decoded
        }
    }

    func contains(_ lemma: String) -> Bool {
        cards.contains { $0.id == lemma.lowercased() }
    }

    @discardableResult
    func add(entry: GlossaryEntry, context: String) -> Bool {
        let id = entry.word.lowercased()
        guard !contains(id) else { return false }
        cards.insert(Flashcard(id: id, word: entry.word, meaning: entry.en,
                               wordClass: entry.wordClass, article: entry.article,
                               paradigm: entry.forms, context: context,
                               added: .now, timesShown: 0, timesKnown: 0, lastShown: nil), at: 0)
        save()
        return true
    }

    func remove(_ card: Flashcard) {
        cards.removeAll { $0.id == card.id }
        save()
    }

    func markReviewed(_ card: Flashcard, known: Bool) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i].timesShown += 1
        if known { cards[i].timesKnown += 1 }
        cards[i].lastShown = .now
        save()
    }

    /// Cards ordered for review: never shown first, then least recently shown.
    var reviewOrder: [Flashcard] {
        cards.sorted { a, b in
            (a.lastShown ?? .distantPast) < (b.lastShown ?? .distantPast)
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cards) else { return }
        try? data.write(to: fileURL, options: .atomic)
        WidgetRefresher.reload()
    }
}

/// Nudges the home-screen widget after the diary changes.
enum WidgetRefresher {
    static func reload() {
        #if canImport(WidgetKit) && !os(macOS)
        WidgetCenterProxy.reload()
        #endif
    }
}

#if canImport(WidgetKit)
import WidgetKit
enum WidgetCenterProxy {
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: "DanskOrdWidget")
    }
}
#endif
