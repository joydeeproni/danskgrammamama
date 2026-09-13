import Foundation

enum QuestionType: String, Codable, Hashable {
    case choice
    case typed   // legacy value in old JSON; treated as choice
    case cloze
}

enum ExplanationLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case danish

    var id: String { rawValue }
    var label: String { self == .english ? "English" : "Dansk" }
    var short: String { self == .english ? "EN" : "DA" }
}

/// How the learner answers. Every item ships with 4 options, so any mode works for any item.
enum InputMode: String, Codable, CaseIterable, Identifiable {
    case choice
    case typed
    case mixed

    var id: String { rawValue }
    var label: String {
        switch self {
        case .choice: return "Multiple choice"
        case .typed: return "Type the answer"
        case .mixed: return "Mixed"
        }
    }
}

struct Explanation: Codable, Hashable {
    let en: String
    let da: String

    func text(in language: ExplanationLanguage) -> String {
        language == .danish ? da : en
    }
}

/// One gap in a question: its options, the correct answer and the explanation.
struct Blank: Decodable, Hashable {
    let options: [String]
    let answer: String
    let accepted: [String]?
    let explanation: Explanation

    init(options: [String], answer: String, accepted: [String]? = nil, explanation: Explanation) {
        self.options = options
        self.answer = answer
        self.accepted = accepted
        self.explanation = explanation
    }

    var allAccepted: [String] { [answer] + (accepted ?? []) }
}

/// A quiz item with one or more gaps. Single-gap items are written with `___` in JSON,
/// multi-gap (cloze) items with `{1}`, `{2}`, … Both are normalised to `{n}` here.
struct Question: Decodable, Identifiable, Hashable {
    let id: String
    let topic: String
    let level: Int
    let type: QuestionType
    let prompt: String          // gaps as {1}, {2}, …
    let hint: String?
    let blanks: [Blank]
    let tags: [String]

    init(id: String, topic: String, level: Int, type: QuestionType, prompt: String,
         hint: String?, blanks: [Blank], tags: [String]) {
        self.id = id
        self.topic = topic
        self.level = level
        self.type = type
        self.prompt = prompt
        self.hint = hint
        self.blanks = blanks
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case id, topic, level, type, prompt, hint, options, answer, accepted, explanation, blanks, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        topic = try c.decode(String.self, forKey: .topic)
        level = try c.decode(Int.self, forKey: .level)
        let rawType = try c.decode(QuestionType.self, forKey: .type)
        hint = try c.decodeIfPresent(String.self, forKey: .hint)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        let rawPrompt = try c.decode(String.self, forKey: .prompt)

        if rawType == .cloze {
            type = .cloze
            prompt = rawPrompt
            blanks = try c.decode([Blank].self, forKey: .blanks)
        } else {
            type = .choice
            prompt = rawPrompt.replacingOccurrences(of: "___", with: "{1}")
            let options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
            let answer = try c.decode(String.self, forKey: .answer)
            let accepted = try c.decodeIfPresent([String].self, forKey: .accepted)
            let explanation = try c.decode(Explanation.self, forKey: .explanation)
            blanks = [Blank(options: options, answer: answer, accepted: accepted, explanation: explanation)]
        }
    }

    // MARK: Derived

    var isCloze: Bool { blanks.count > 1 }

    /// First blank's answer; for cloze items the answers joined.
    var answer: String { blanks.map(\.answer).joined(separator: " · ") }

    var explanation: Explanation { blanks[0].explanation }

    enum Segment: Hashable {
        case text(String)
        case gap(Int)   // 0-based blank index
    }

    /// The prompt split into literal text and gap markers.
    var segments: [Segment] {
        var result: [Segment] = []
        var rest = Substring(prompt)
        while let open = rest.firstIndex(of: "{") {
            guard let close = rest[open...].firstIndex(of: "}"),
                  let n = Int(rest[rest.index(after: open)..<close]) else {
                result.append(.text(String(rest)))
                return result
            }
            if open > rest.startIndex { result.append(.text(String(rest[..<open]))) }
            result.append(.gap(n - 1))
            rest = rest[rest.index(after: close)...]
        }
        if !rest.isEmpty { result.append(.text(String(rest))) }
        return result
    }

    /// The text with every gap filled with its correct answer.
    var filledPrompt: String {
        segments.map { seg -> String in
            switch seg {
            case .text(let t): return t
            case .gap(let i): return i < blanks.count ? blanks[i].answer : "…"
            }
        }.joined()
    }

    var isGenerated: Bool { id.hasPrefix("verbdrill-") }
}

struct TopicFile: Decodable {
    let topic: String
    let questions: [Question]
}

struct Verb: Codable, Hashable, Identifiable {
    let infinitive: String
    let present: String
    let past: String
    let auxiliary: String
    let participle: String
    let group: String

    var id: String { infinitive }
    var isIrregular: Bool { group.hasPrefix("uregel") }
    /// "har/er" verbs accept either auxiliary.
    var auxiliaries: [String] { auxiliary.split(separator: "/").map(String.init) }
    var perfect: String { "\(auxiliaries[0]) \(participle)" }
}

struct VerbFile: Codable {
    let verbs: [Verb]
}
