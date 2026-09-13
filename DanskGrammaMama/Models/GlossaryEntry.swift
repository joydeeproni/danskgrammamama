import Foundation

/// One dictionary entry: the lemma, its word class, and an English meaning.
struct GlossaryEntry: Codable, Hashable, Identifiable {
    let word: String
    /// substantiv, verbum, adjektiv … Decoded from the JSON key "class".
    let wordClass: String
    let article: String
    let en: String
    /// Verb paradigm, e.g. "vælge – vælger – valgte – har valgt". Empty for other classes.
    var forms: String?

    private enum CodingKeys: String, CodingKey {
        case word, article, en, forms
        case wordClass = "class"
    }

    init(word: String, wordClass: String, article: String, en: String, forms: String? = nil) {
        self.word = word
        self.wordClass = wordClass
        self.article = article
        self.en = en
        self.forms = forms
    }

    var id: String { word.lowercased() }

    /// "en kommune · substantiv" or "verbum"
    var subtitle: String {
        var parts: [String] = []
        if !article.isEmpty, article != "—" { parts.append("\(article) \(word)") }
        if !wordClass.isEmpty { parts.append(wordClass) }
        return parts.joined(separator: " · ")
    }

    var hasMeaning: Bool { !en.isEmpty && en != "—" }
}

struct GlossaryFile: Codable {
    let entries: [String: GlossaryEntry]
    let forms: [String: String]
}

/// A word the learner tapped and kept. Stored in the flashcard diary.
struct Flashcard: Codable, Hashable, Identifiable {
    let id: String              // the lemma, lowercased
    var word: String            // display form of the lemma
    var meaning: String
    var wordClass: String
    var article: String
    var paradigm: String?
    /// The sentence the word was tapped in, so the card keeps its context.
    var context: String
    var added: Date
    var timesShown: Int
    var timesKnown: Int
    var lastShown: Date?

    var subtitle: String {
        var parts: [String] = []
        if !article.isEmpty, article != "—" { parts.append("\(article) \(word)") }
        if !wordClass.isEmpty { parts.append(wordClass) }
        return parts.joined(separator: " · ")
    }
}
