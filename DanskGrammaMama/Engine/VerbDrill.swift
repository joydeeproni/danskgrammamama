import Foundation

/// Generates verb-form questions (with 4 options) from the learner's 500-verb list.
struct VerbDrill {
    enum Form: CaseIterable {
        case present, past, perfect

        var da: String {
            switch self {
            case .present: return "nutid"
            case .past: return "datid"
            case .perfect: return "førnutid"
            }
        }
    }

    static func questions(from verbs: [Verb], count: Int, irregularOnly: Bool) -> [Question] {
        let pool = irregularOnly ? verbs.filter(\.isIrregular) : verbs
        guard !pool.isEmpty else { return [] }
        var result: [Question] = []
        var seen = Set<String>()
        var attempts = 0
        while result.count < count && attempts < count * 20 {
            attempts += 1
            guard let verb = pool.randomElement() else { break }
            // Weight past and perfect heavier; present is rarely the problem.
            let form: Form = [Form.past, .past, .perfect, .perfect, .present].randomElement()!
            let key = "\(verb.infinitive)-\(form)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(question(for: verb, form: form))
        }
        return result
    }

    static func question(for verb: Verb, form: Form) -> Question {
        let answer: String
        var accepted: [String] = []
        switch form {
        case .present: answer = verb.present
        case .past: answer = verb.past
        case .perfect:
            answer = verb.perfect
            for aux in verb.auxiliaries.dropFirst() { accepted.append("\(aux) \(verb.participle)") }
        }

        let slug = verb.infinitive.replacingOccurrences(of: " ", with: "_")
        let id = "verbdrill-\(slug)-\(form.da)"
        let prompt = "\(verb.infinitive)  →  \(form.da): {1}"

        let paradigm = "\(verb.infinitive) – \(verb.present) – \(verb.past) – \(verb.perfect)"
        var en = "\(verb.infinitive) is \(verb.isIrregular ? "irregular (uregelmæssigt)" : verb.group.hasPrefix("gruppe 1") ? "a group 1 verb (-ede / -et)" : "a group 2 verb (-te / -t)"): \(paradigm). Learn the four forms as one unit."
        var da = "\(verb.infinitive) er \(verb.isIrregular ? "uregelmæssigt" : verb.group.hasPrefix("gruppe 1") ? "et gruppe 1-verbum (-ede / -et)" : "et gruppe 2-verbum (-te / -t)"): \(paradigm). Lær de fire former som én enhed."
        if form == .perfect {
            if verb.auxiliaries.count > 1 {
                en += " Both har and er are possible: har for the activity itself, er for arriving somewhere or a completed change."
                da += " Både har og er er mulige: har om selve aktiviteten, er om at nå et sted eller en afsluttet forandring."
            } else if verb.auxiliaries[0] == "er" {
                en += " It takes er because it expresses movement or a change of state."
                da += " Det tager er, fordi det udtrykker bevægelse eller overgang."
            }
        }

        let blank = Blank(options: options(for: verb, form: form, answer: answer, excluding: accepted),
                          answer: answer,
                          accepted: accepted.isEmpty ? nil : accepted,
                          explanation: Explanation(en: en, da: da))
        return Question(
            id: id,
            topic: "verbs",
            level: verb.isIrregular ? 2 : 1,
            type: .choice,
            prompt: prompt,
            hint: form == .perfect ? "(med har/er)" : nil,
            blanks: [blank],
            tags: ["verbdrill", form.da, verb.isIrregular ? "uregelmæssig" : "regelmæssig"]
        )
    }

    /// Distractors: the verb's other forms, the wrong auxiliary, and a regularised error form.
    private static func options(for verb: Verb, form: Form, answer: String, excluding: [String]) -> [String] {
        var pool: [String] = []
        let stem = verb.infinitive.split(separator: " ").first.map(String.init) ?? verb.infinitive
        let base = stem.hasSuffix("e") ? String(stem.dropLast()) : stem
        let wrongAux = verb.auxiliaries[0] == "er" ? "har" : "er"

        switch form {
        case .present:
            pool = [verb.infinitive, verb.past, verb.participle, base + "r", base + "es"]
        case .past:
            pool = [verb.present, verb.participle, verb.infinitive,
                    verb.isIrregular ? base + "ede" : base + "te",
                    verb.isIrregular ? base + "te" : base + "ede",
                    verb.perfect]
        case .perfect:
            pool = ["\(wrongAux) \(verb.participle)",
                    "\(verb.auxiliaries[0]) \(verb.past)",
                    "\(verb.auxiliaries[0]) \(verb.infinitive)",
                    "\(verb.auxiliaries[0]) \(base)\(verb.isIrregular ? "et" : "t")",
                    verb.past]
        }

        var result: [String] = [answer]
        var banned = Set([answer] + excluding)
        for candidate in pool where !banned.contains(candidate) {
            result.append(candidate)
            banned.insert(candidate)
            if result.count == 4 { break }
        }
        // Pad if the verb's forms coincide (e.g. synes/synes).
        var pad = 1
        while result.count < 4 {
            let filler = base + ["ede", "te", "er", "t", "et"][pad % 5] + (pad > 4 ? "\(pad)" : "")
            if !banned.contains(filler) { result.append(filler); banned.insert(filler) }
            pad += 1
        }
        return result.shuffled()
    }
}
