import Foundation
import Observation

/// Danish → English lookup for the words in the question bank.
///
/// Resolution order: exact lemma, known inflected form, genitive -s stripped,
/// suffix stripping, and finally the head of a compound (ungdomsboliger → bolig).
/// Anything still unresolved is handed to the on-device model by the caller.
@Observable
final class Glossary {
    private(set) var entries: [String: GlossaryEntry] = [:]
    private(set) var forms: [String: String] = [:]

    init() {
        guard let url = Bundle.main.url(forResource: "glossary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(GlossaryFile.self, from: data) else { return }
        entries = file.entries
        forms = file.forms
    }

    var count: Int { entries.count }

    /// Strips punctuation and quotes from a tapped token.
    static func clean(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "-")))
             .lowercased()
    }

    func lookup(_ raw: String) -> GlossaryEntry? {
        let word = Glossary.clean(raw)
        guard word.count > 1 else { return nil }
        if let hit = resolve(word) { return hit }

        // Genitive: kommunens → kommunen → kommune
        if word.hasSuffix("s"), let hit = resolve(String(word.dropLast())) { return hit }

        // Common endings, longest first.
        for suffix in ["ernes", "erne", "ene", "ens", "ets", "er", "en", "et", "e", "s"] {
            if word.hasSuffix(suffix), word.count > suffix.count + 2 {
                let stem = String(word.dropLast(suffix.count))
                if let hit = resolve(stem) { return hit }
                // Undo consonant doubling: hullet → hul
                if let last = stem.last, stem.count > 2,
                   stem.dropLast().last == last, let hit = resolve(String(stem.dropLast())) { return hit }
            }
        }

        // Danish compounds are head-final: look up the longest known tail.
        if word.count >= 7 {
            for start in 3..<(word.count - 2) {
                let tail = String(word.dropFirst(start))
                guard tail.count >= 4 else { break }
                if let hit = resolve(tail) ?? resolveStripped(tail) {
                    let head = String(word.prefix(start)).trimmingCharacters(in: CharacterSet(charactersIn: "s-"))
                    let note = head.isEmpty ? hit.word : "\(head) + \(hit.word)"
                    return GlossaryEntry(word: word, wordClass: hit.wordClass, article: hit.article,
                                         en: "\(hit.en)  (compound: \(note))", forms: hit.forms)
                }
            }
        }
        return nil
    }

    private func resolve(_ word: String) -> GlossaryEntry? {
        if let e = entries[word] { return e }
        if let lemma = forms[word], let e = entries[lemma] { return e }
        return nil
    }

    private func resolveStripped(_ word: String) -> GlossaryEntry? {
        for suffix in ["erne", "ene", "er", "en", "et", "e"] where word.hasSuffix(suffix) {
            if let hit = resolve(String(word.dropLast(suffix.count))) { return hit }
        }
        return nil
    }
}
