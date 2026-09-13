import Foundation

/// Generates typed verb-form questions from the learner's 500-verb list.
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
        var en: String {
            switch self {
            case .present: return "present"
            case .past: return "past"
            case .perfect: return "perfect (har/er + participle)"
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
        let prompt = "\(verb.infinitive)  →  \(form.da): ___"

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

        return Question(
            id: id,
            topic: "verbs",
            level: verb.isIrregular ? 2 : 1,
            type: .typed,
            prompt: prompt,
            hint: form == .perfect ? "(skriv med har/er)" : "(skriv formen)",
            options: nil,
            answer: answer,
            accepted: accepted.isEmpty ? nil : accepted,
            explanation: Explanation(en: en, da: da),
            tags: ["verbdrill", form.da, verb.isIrregular ? "uregelmæssig" : "regelmæssig"]
        )
    }
}
