import Foundation

/// A rule-based check of Danish free writing.
///
/// It runs entirely offline and catches the error types PD3 marks hardest:
/// ledsætning word order, missing inversion, double definiteness, article and
/// adjective agreement, at/og confusion, and likely typos. It never rewrites the
/// text; it points at a span and names the rule. The on-device model, when
/// available, runs alongside it and adds what rules cannot see.
struct WritingChecker {
    let glossary: Glossary
    let verbs: [Verb]

    /// Words that open a ledsætning, where the order is subject – adverbial – verb.
    static let subordinators: Set<String> = [
        "fordi", "at", "som", "hvis", "når", "da", "selvom", "selv", "mens", "hvorimod",
        "inden", "efter", "før", "indtil", "hvorfor", "hvordan", "hvornår", "hvem", "hvad", "om"
    ]

    /// Adverbs that sit between subject and verb in a ledsætning.
    static let centralAdverbs: Set<String> = [
        "ikke", "aldrig", "altid", "ofte", "sjældent", "allerede", "stadig", "også",
        "kun", "måske", "nok", "vist", "gerne", "endnu", "helt", "virkelig"
    ]

    static let pronouns: Set<String> = [
        "jeg", "du", "han", "hun", "den", "det", "vi", "i", "de", "man", "der"
    ]

    /// Adverbials that commonly start a sentence and force inversion.
    static let frontedStarters: Set<String> = [
        "i", "om", "på", "til", "efter", "før", "under", "ved", "hver", "hvert",
        "derfor", "desuden", "imidlertid", "alligevel", "dermed", "således", "derimod",
        "nu", "så", "her", "der", "ofte", "altid", "somme", "af", "for", "med", "sidste", "næste", "hvert"
    ]

    /// Every finite present/past verb form we know, for spotting the verb in a clause.
    private var finiteForms: Set<String> {
        var set = Set<String>()
        for v in verbs {
            set.insert(v.present.lowercased())
            set.insert(v.past.lowercased())
        }
        for extra in ["er", "var", "har", "havde", "kan", "kunne", "skal", "skulle",
                      "vil", "ville", "må", "måtte", "bør", "burde", "gør", "gjorde",
                      "bliver", "blev", "får", "fik"] {
            set.insert(extra)
        }
        return set
    }

    func check(_ text: String) -> [WritingIssue] {
        var issues: [WritingIssue] = []
        let finite = finiteForms

        for sentence in sentences(in: text) {
            let words = tokenize(sentence)
            guard words.count > 2 else { continue }
            let lower = words.map { $0.lowercased() }

            // 1. Ledsætning: subordinator + verb + subject (inversion where there should be none).
            for i in 0..<(lower.count - 2) where WritingChecker.subordinators.contains(lower[i]) {
                let a = lower[i + 1], b = lower[i + 2]
                if finite.contains(a), WritingChecker.pronouns.contains(b), lower[i] != "om" || i > 0 {
                    issues.append(WritingIssue(
                        original: "\(words[i]) \(words[i + 1]) \(words[i + 2])",
                        correction: "\(words[i]) \(words[i + 2]) \(words[i + 1])",
                        rule: "Word order: after \(words[i]) you have a ledsætning, so the subject comes before the verb, never after it."))
                }
            }

            // 2. Ledsætning: subject + verb + ikke (the adverb belongs before the verb).
            for i in 0..<(lower.count - 3) where WritingChecker.subordinators.contains(lower[i]) {
                let subj = lower[i + 1], verb = lower[i + 2], adv = lower[i + 3]
                if WritingChecker.pronouns.contains(subj), finite.contains(verb),
                   WritingChecker.centralAdverbs.contains(adv) {
                    issues.append(WritingIssue(
                        original: "\(words[i]) \(words[i + 1]) \(words[i + 2]) \(words[i + 3])",
                        correction: "\(words[i]) \(words[i + 1]) \(words[i + 3]) \(words[i + 2])",
                        rule: "Word order: inside a ledsætning, \(words[i + 3]) goes between the subject and the verb."))
                }
            }

            // 3. Missing inversion after a fronted adverbial: "I dag jeg tager …"
            if lower.count >= 4, WritingChecker.frontedStarters.contains(lower[0]) {
                for split in 1...min(3, lower.count - 3) {
                    let subj = lower[split], verb = lower[split + 1]
                    if WritingChecker.pronouns.contains(subj), finite.contains(verb),
                       !WritingChecker.subordinators.contains(lower[0]) {
                        issues.append(WritingIssue(
                            original: "\(words[split]) \(words[split + 1])",
                            correction: "\(words[split + 1]) \(words[split])",
                            rule: "Word order: the sentence starts with an adverbial, so the verb must come second, before the subject."))
                        break
                    }
                }
            }

            // 4. Double definiteness: den/det/de/denne/dette/disse + adjective + definite noun.
            for i in 0..<(lower.count - 1) where ["den", "det", "de", "denne", "dette", "disse", "min", "mit", "mine", "sin", "sit", "sine"].contains(lower[i]) {
                let noun = lower[i + 1]
                if noun.hasSuffix("en") || noun.hasSuffix("et") || noun.hasSuffix("erne") {
                    if glossary.lookup(String(noun.dropLast(noun.hasSuffix("erne") ? 4 : 2))) != nil,
                       glossary.lookup(noun)?.wordClass == "substantiv" || glossary.lookup(noun) != nil {
                        let bare = String(noun.dropLast(noun.hasSuffix("erne") ? 4 : 2))
                        issues.append(WritingIssue(
                            original: "\(words[i]) \(words[i + 1])",
                            correction: "\(words[i]) \(bare)",
                            rule: "Double definiteness: after \(words[i]) the noun stays in the indefinite form."))
                    }
                }
            }

            // 5. et + adjective without -t: "et stor hus".
            for i in 0..<(lower.count - 2) where lower[i] == "et" {
                if let adj = glossary.lookup(lower[i + 1]), adj.wordClass == "adjektiv",
                   !lower[i + 1].hasSuffix("t"), !lower[i + 1].hasSuffix("e"),
                   glossary.lookup(lower[i + 2])?.wordClass == "substantiv" {
                    issues.append(WritingIssue(
                        original: "\(words[i]) \(words[i + 1]) \(words[i + 2])",
                        correction: "\(words[i]) \(words[i + 1])t \(words[i + 2])",
                        rule: "Adjective ending: an intetkøn noun with et takes -t on the adjective."))
                }
            }

            // 6. "og" where an infinitive marker "at" is meant: "prøve og gøre".
            for i in 1..<(lower.count - 1) where lower[i] == "og" {
                let before = lower[i - 1], after = lower[i + 1]
                let infinitives = Set(verbs.map { $0.infinitive.lowercased() })
                if infinitives.contains(after), ["prøve", "forsøge", "begynde", "huske", "glemme",
                                                 "love", "beslutte", "nå", "have", "får", "lyst"].contains(before) {
                    issues.append(WritingIssue(
                        original: "\(words[i - 1]) \(words[i]) \(words[i + 1])",
                        correction: "\(words[i - 1]) at \(words[i + 1])",
                        rule: "Use at, not og, before an infinitive: prøve at gøre, not prøve og gøre."))
                }
            }
        }

        // 7. Likely typos: one letter away from a word we know.
        for word in tokenize(text) {
            let w = Glossary.clean(word)
            guard w.count >= 4, glossary.lookup(w) == nil else { continue }
            if let near = nearestKnown(w) {
                issues.append(WritingIssue(original: word, correction: near,
                                           rule: "Spelling: this is one letter away from \(near)."))
            }
        }

        // Keep it short and never repeat the same span.
        var seen = Set<String>()
        return issues.filter { seen.insert($0.original.lowercased()).inserted }.prefix(12).map { $0 }
    }

    private func nearestKnown(_ word: String) -> String? {
        for candidate in glossary.entries.keys where abs(candidate.count - word.count) <= 1 {
            if AnswerChecker.levenshtein(word, candidate) == 1 { return candidate }
        }
        for (form, lemma) in glossary.forms where abs(form.count - word.count) <= 1 {
            if AnswerChecker.levenshtein(word, form) == 1 { return lemma }
        }
        return nil
    }

    private func sentences(in text: String) -> [String] {
        text.split(whereSeparator: { ".!?\n".contains($0) }).map(String.init)
    }

    private func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && $0 != "-" && $0 != "'" }).map(String.init)
    }
}
