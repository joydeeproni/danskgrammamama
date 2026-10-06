import Foundation
import Observation

/// The four practice decks under Ord: words, phrases, fixed expressions and idioms.
enum VocabDeck: String, CaseIterable, Identifiable, Codable {
    case words, phrases, fixed, udtryk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .words: return "Ord"
        case .phrases: return "Fraser"
        case .fixed: return "Faste forbindelser"
        case .udtryk: return "Udtryk"
        }
    }

    /// What the deck is, in a few words.
    var subtitle: String {
        switch self {
        case .words: return "verber, adjektiver og småord · B2–C2"
        case .phrases: return "til at tale og skrive"
        case .fixed: return "tage hensyn til, i forhold til …"
        case .udtryk: return "idiomer og talemåder"
        }
    }
}

struct VocabItem: Identifiable, Hashable, Decodable {
    struct Example: Hashable, Decodable {
        let da: String
        let en: String
    }

    let da: String
    let en: String
    let example: Example
    let level: String
    // Deck-specific details; absent where they do not apply.
    let `class`: String?
    let forms: String?
    let rank: Int?
    let use: String?
    let register: String?
    let pattern: String?
    let literal: String?
    let meaningDa: String?

    var deck: VocabDeck = .words
    /// Stable across app versions. Words include their class, because a few are both an
    /// adjective and an adverb with different meanings (egentlig, faktisk).
    var id: String { "\(deck.rawValue):\(`class`.map { "\($0):" } ?? "")\(da.lowercased())" }

    private enum CodingKeys: String, CodingKey {
        case da, en, example, level, `class`, forms, rank, use, register, pattern, literal
        case meaningDa = "meaning_da"
    }

    /// A small line under the item on the front of the card.
    var tag: String? {
        switch deck {
        case .words: return `class`
        case .phrases: return use
        case .fixed: return nil
        case .udtryk: return register == "uformel" ? "uformelt" : nil
        }
    }
}

private struct VocabFile: Decodable {
    let items: [VocabItem]
}

/// How well one card is known. Box 0 is new or missed; each "Kunne den" moves it up a box
/// and pushes it further out: 1, 3, 7, 14, 30, then 90 days.
struct VocabRecord: Codable, Hashable {
    var box = 0
    var due: Date? = nil
    var shown = 0
    var known = 0
    var lastShown: Date? = nil

    var isLearned: Bool { box >= 3 }
}

@Observable
final class VocabStore {
    static let intervals = [1, 3, 7, 14, 30, 90]
    static let sessionSize = 20

    private(set) var items: [VocabDeck: [VocabItem]] = [:]
    private(set) var records: [String: VocabRecord] = [:]
    private let fileURL: URL
    private let calendar = Calendar.current

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("vocab.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let raw = try? Data(contentsOf: fileURL),
           let saved = try? decoder.decode([String: VocabRecord].self, from: raw) {
            records = saved
        }
        for deck in VocabDeck.allCases {
            guard let url = Bundle.main.url(forResource: "vocab_\(deck.rawValue)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder().decode(VocabFile.self, from: data) else { continue }
            items[deck] = file.items.map { var item = $0; item.deck = deck; return item }
        }
    }

    func count(_ deck: VocabDeck) -> Int { items[deck]?.count ?? 0 }

    func learned(_ deck: VocabDeck) -> Int {
        (items[deck] ?? []).filter { records[$0.id]?.isLearned == true }.count
    }

    func due(_ deck: VocabDeck, now: Date = .now) -> [VocabItem] {
        (items[deck] ?? []).filter { item in
            guard let r = records[item.id], r.shown > 0, let due = r.due else { return false }
            return due <= now
        }
    }

    var totalLearned: Int { VocabDeck.allCases.map(learned).reduce(0, +) }
    var totalCount: Int { VocabDeck.allCases.map(count).reduce(0, +) }

    /// Due cards first, then new ones in the deck's order (most useful first).
    func session(_ deck: VocabDeck, size: Int = VocabStore.sessionSize) -> [VocabItem] {
        let dueCards = due(deck).sorted { (records[$0.id]?.due ?? .distantPast) < (records[$1.id]?.due ?? .distantPast) }
        let fresh = (items[deck] ?? []).filter { records[$0.id] == nil }
        return Array((dueCards + fresh).prefix(size))
    }

    func mark(_ item: VocabItem, known: Bool, now: Date = .now) {
        var r = records[item.id] ?? VocabRecord()
        r.shown += 1
        r.lastShown = now
        if known {
            r.known += 1
            r.box = min(r.box + 1, VocabStore.intervals.count)
            r.due = calendar.date(byAdding: .day, value: VocabStore.intervals[r.box - 1],
                                  to: calendar.startOfDay(for: now))
        } else {
            r.box = 0
            r.due = now
        }
        records[item.id] = r
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let raw = try? encoder.encode(records) {
            try? raw.write(to: fileURL, options: .atomic)
        }
    }
}
