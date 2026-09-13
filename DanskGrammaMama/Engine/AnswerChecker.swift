import Foundation

enum AnswerVerdict: Equatable {
    case correct
    /// Wrong, but within one edit of the correct answer: probably a spelling slip.
    case nearMiss
    case wrong
}

struct AnswerChecker {
    static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        while let last = t.last, ".,;:!?".contains(last) { t.removeLast() }
        return t
    }

    /// Typed answers: case-insensitive, trailing punctuation ignored, alternatives accepted.
    static func checkTyped(_ input: String, for blank: Blank) -> AnswerVerdict {
        let given = normalize(input)
        guard !given.isEmpty else { return .wrong }
        if blank.allAccepted.map(normalize).contains(given) { return .correct }
        let canonical = normalize(blank.answer)
        if canonical.count >= 4, levenshtein(given, canonical) <= 1 { return .nearMiss }
        return .wrong
    }

    /// Chosen option: exact match only.
    static func checkChoice(_ option: String, for blank: Blank) -> AnswerVerdict {
        option == blank.answer ? .correct : .wrong
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }
}
