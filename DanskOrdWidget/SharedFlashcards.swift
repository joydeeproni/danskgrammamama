import Foundation

/// The widget's read-only view of the word diary.
///
/// The diary lives in the App Group container that the app writes to. When the
/// App Groups capability is not enabled (a free Apple ID cannot use it), the
/// container is unreachable and the widget falls back to a built-in starter deck,
/// so it always shows something useful.
enum SharedFlashcards {
    static let appGroup = "group.dk.joydeep.danskgrammamama"
    static let fileName = "flashcards.json"

    struct Card: Codable, Hashable {
        let id: String
        let word: String
        let meaning: String
        let wordClass: String
        let article: String
        let paradigm: String?
        let context: String

        var subtitle: String {
            var parts: [String] = []
            if !article.isEmpty, article != "—" { parts.append("\(article) \(word)") }
            if !wordClass.isEmpty { parts.append(wordClass) }
            return parts.joined(separator: " · ")
        }
    }

    /// Decoded loosely: the app's Flashcard has extra review fields the widget ignores.
    private struct StoredCard: Decodable {
        let id: String
        let word: String
        let meaning: String
        let wordClass: String
        let article: String
        let paradigm: String?
        let context: String
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> [Card] {
        guard let url = containerURL?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url) else { return starterDeck }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode([StoredCard].self, from: data), !stored.isEmpty else {
            return starterDeck
        }
        return stored.map { Card(id: $0.id, word: $0.word, meaning: $0.meaning,
                                 wordClass: $0.wordClass, article: $0.article,
                                 paradigm: $0.paradigm, context: $0.context) }
    }

    static var isUsingStarterDeck: Bool {
        guard let url = containerURL?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([StoredCard].self, from: data) else { return true }
        return stored.isEmpty
    }

    /// Words a PD3 candidate meets constantly. Used until the diary has entries.
    static let starterDeck: [Card] = [
        Card(id: "vedtage", word: "vedtage", meaning: "pass, adopt (a law)", wordClass: "verbum", article: "",
             paradigm: "vedtage – vedtager – vedtog – har vedtaget",
             context: "Folketinget vedtog loven om røgfri skoletid i 2019."),
        Card(id: "ledsætning", word: "ledsætning", meaning: "subordinate clause", wordClass: "substantiv", article: "en",
             paradigm: "en ledsætning – ledsætningen – ledsætninger", context: "I en ledsætning står ikke før verbet."),
        Card(id: "imidlertid", word: "imidlertid", meaning: "however (formal)", wordClass: "adverbium", article: "",
             paradigm: nil, context: "Antallet af cyklister er imidlertid ikke steget."),
        Card(id: "medføre", word: "medføre", meaning: "lead to, entail", wordClass: "verbum", article: "",
             paradigm: "medføre – medfører – medførte – har medført",
             context: "Reformen medførte store ændringer i sundhedsvæsenet."),
        Card(id: "hensyn", word: "hensyn", meaning: "consideration, regard", wordClass: "substantiv", article: "et",
             paradigm: "et hensyn – hensynet – hensyn", context: "Kommunen skal tage hensyn til naturen."),
        Card(id: "nemlig", word: "nemlig", meaning: "namely; the reason is that", wordClass: "adverbium", article: "",
             paradigm: nil, context: "Danskerne cykler meget. Landet er nemlig fladt."),
        Card(id: "undersøgelse", word: "undersøgelse", meaning: "survey, study", wordClass: "substantiv", article: "en",
             paradigm: "en undersøgelse – undersøgelsen – undersøgelser",
             context: "Undersøgelsen viser, at sygefraværet er faldet."),
        Card(id: "skyldes", word: "skyldes", meaning: "be due to, be caused by", wordClass: "verbum", article: "",
             paradigm: "skyldes – skyldes – skyldtes – har skyldtes",
             context: "Den stigende ulighed kan skyldes flere faktorer."),
        Card(id: "forudsætte", word: "forudsætte", meaning: "presuppose, require", wordClass: "verbum", article: "",
             paradigm: "forudsætte – forudsætter – forudsatte – har forudsat",
             context: "Ordningen forudsætter, at man har fast arbejde."),
        Card(id: "lønmodtager", word: "lønmodtager", meaning: "wage earner, employee", wordClass: "substantiv", article: "en",
             paradigm: "en lønmodtager – lønmodtageren – lønmodtagere",
             context: "Danske lønmodtagere arbejder færre timer end EU-gennemsnittet."),
        Card(id: "alligevel", word: "alligevel", meaning: "even so, nevertheless", wordClass: "adverbium", article: "",
             paradigm: nil, context: "Mange kender klimaaftrykket. De flyver alligevel."),
        Card(id: "udledning", word: "udledning", meaning: "emission", wordClass: "substantiv", article: "en",
             paradigm: "en udledning – udledningen – udledninger",
             context: "Landbrugets udledning af drivhusgasser skal ned."),
        Card(id: "overenskomst", word: "overenskomst", meaning: "collective agreement", wordClass: "substantiv", article: "en",
             paradigm: "en overenskomst – overenskomsten – overenskomster",
             context: "Parterne nåede til enighed om en ny overenskomst."),
        Card(id: "tilknytning", word: "tilknytning", meaning: "attachment, connection", wordClass: "substantiv", article: "en",
             paradigm: "en tilknytning – tilknytningen – tilknytninger",
             context: "Rapporten handler om nyuddannedes tilknytning til arbejdsmarkedet."),
        Card(id: "derimod", word: "derimod", meaning: "by contrast, on the other hand", wordClass: "adverbium", article: "",
             paradigm: nil, context: "I landkommunerne står lejlighederne derimod tomme.")
    ]
}
