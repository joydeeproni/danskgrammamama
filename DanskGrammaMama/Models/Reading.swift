import Foundation

/// Læseforståelse 2 sets as written in reading.json: Delprøve 2A, 2B and 3 per set.
struct ReadingFile: Decodable {
    let sets: [ReadingSet]
}

struct ReadingSet: Decodable, Identifiable {
    struct Part2A: Decodable {
        struct Item: Decodable {
            let question: String
            let options: [String]
            let answer: Int
            let explanation: Explanation
        }
        let title: String
        let text: String
        let questions: [Item]
    }

    struct Part2B: Decodable {
        let title: String
        let text: String
        let parts: [String: String]
        let answers: [String]
        let explanations: [Explanation]
        let unused: Explanation?
    }

    struct Part3: Decodable {
        struct Gap: Decodable {
            let options: [String]
            let answer: String
            let explanation: Explanation
        }
        let title: String
        let text: String
        let gaps: [Gap]
    }

    let id: String
    let source: String
    let difficulty: Int
    let part2a: Part2A
    let part2b: Part2B
    let part3: Part3

    private var level: Int { difficulty >= 3 ? 2 : 1 }

    /// The three tasks as question cards. 2A is one card with three questions about the
    /// text; 2B and 3 are gap texts. Options keep the paper's order, because letters matter.
    var questions: [Question] {
        let letters = part2b.parts.keys.sorted()
        let partTexts = letters.map { "\(part2b.parts[$0] ?? "")" }
        return [
            Question(id: "reading-\(id)-1-2a", topic: Topic.readingID, level: level, type: .cloze,
                     prompt: part2a.text, hint: nil,
                     blanks: part2a.questions.map {
                         Blank(options: $0.options, answer: $0.options[min($0.answer, $0.options.count - 1)],
                               explanation: $0.explanation, question: $0.question)
                     },
                     tags: ["2A"], reading: ReadingInfo(part: .part2a, title: part2a.title, source: source)),
            Question(id: "reading-\(id)-2-2b", topic: Topic.readingID, level: level, type: .cloze,
                     prompt: part2b.text, hint: nil,
                     blanks: zip(part2b.answers, part2b.explanations).map { letter, explanation in
                         Blank(options: partTexts, answer: part2b.parts[letter] ?? "", explanation: explanation)
                     },
                     tags: ["2B"], reading: ReadingInfo(part: .part2b, title: part2b.title, source: source)),
            Question(id: "reading-\(id)-3-3", topic: Topic.readingID, level: level, type: .cloze,
                     prompt: part3.text, hint: nil,
                     blanks: part3.gaps.map { Blank(options: $0.options, answer: $0.answer, explanation: $0.explanation) },
                     tags: ["3"], reading: ReadingInfo(part: .part3, title: part3.title, source: source))
        ]
    }
}

extension Question {
    /// The letter a reading option carries on the paper (A, B, C …), by its position.
    func letter(of option: String, inBlank i: Int) -> String? {
        guard reading != nil, let idx = blanks[i].options.firstIndex(of: option) else { return nil }
        return String(UnicodeScalar(UInt8(65 + idx)))
    }
}

extension Question {
    /// The prompt split into paragraphs at blank lines, so long reading texts keep their shape.
    var paragraphs: [[Segment]] {
        var result: [[Segment]] = [[]]
        for seg in segments {
            switch seg {
            case .gap:
                result[result.count - 1].append(seg)
            case .text(let t):
                for (k, piece) in t.components(separatedBy: "\n\n").enumerated() {
                    if k > 0 { result.append([]) }
                    let trimmed = piece.trimmingCharacters(in: .newlines)
                    if !trimmed.isEmpty { result[result.count - 1].append(.text(trimmed)) }
                }
            }
        }
        return result.filter { !$0.isEmpty }
    }
}
