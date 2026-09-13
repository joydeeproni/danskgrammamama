import SwiftUI

/// How one gap should be drawn inside a sentence.
enum GapState: Equatable {
    case pending          // not answered yet, not the active gap
    case active           // the gap being answered now
    case correct(String)
    case wrong(given: String, answer: String)
    case chosen(String)   // exam mode: answered, verdict withheld
}

/// A Danish sentence where every word is tappable for its meaning and gaps are
/// drawn inline. Words the glossary knows are underlined; the rest are plain.
struct SentenceView: View {
    let segments: [Question.Segment]
    let gapState: (Int) -> GapState
    let gapNumber: (Int) -> Int?          // nil hides the little gap number
    var font: Font = .system(.title3, design: .serif)
    var onWordTap: (String) -> Void

    @Environment(Glossary.self) private var glossary

    var body: some View {
        FlowLayout(lineSpacing: 8) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                switch token {
                case .word(let text, let lookupable):
                    WordChip(text: text, lookupable: lookupable, font: font) { onWordTap(text) }
                case .plain(let text):
                    Text(text).font(font)
                case .gap(let index):
                    GapChip(state: gapState(index), number: gapNumber(index), font: font)
                }
            }
        }
    }

    private enum Token {
        case word(String, Bool)
        case plain(String)
        case gap(Int)
    }

    /// Splits the sentence into words, the punctuation and spaces around them, and gaps.
    private var tokens: [Token] {
        var result: [Token] = []
        for segment in segments {
            switch segment {
            case .gap(let i):
                result.append(.gap(i))
            case .text(let text):
                var current = ""
                var isWord = false
                func flush() {
                    guard !current.isEmpty else { return }
                    if isWord {
                        result.append(.word(current, glossary.lookup(current) != nil))
                    } else {
                        result.append(.plain(current))
                    }
                    current = ""
                }
                for ch in text {
                    let letter = ch.isLetter || ch == "-"
                    if letter != isWord { flush(); isWord = letter }
                    current.append(ch)
                }
                flush()
            }
        }
        return result
    }
}

/// One word. Underlined when the app can explain it.
private struct WordChip: View {
    let text: String
    let lookupable: Bool
    let font: Font
    let action: () -> Void

    var body: some View {
        if lookupable {
            Button(action: action) {
                Text(text)
                    .font(font)
                    .underline(true, pattern: .dot, color: Color.accentColor.opacity(0.55))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the meaning of \(text)")
        } else {
            Text(text).font(font)
        }
    }
}

/// One gap: a blank, the chosen word, or the correction.
private struct GapChip: View {
    let state: GapState
    let number: Int?
    let font: Font

    var body: some View {
        HStack(spacing: 4) {
            if let number { Text("\(number)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
            content
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(background, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(border, lineWidth: 1.5))
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .pending:
            Text("______").font(font).foregroundStyle(.tertiary)
        case .active:
            Text("______").font(font).foregroundStyle(Color.accentColor)
        case .correct(let answer):
            Text(answer).font(font).bold().foregroundStyle(Style.correct)
        case .chosen(let given):
            Text(given).font(font).bold().foregroundStyle(Color.accentColor)
        case .wrong(let given, let answer):
            HStack(spacing: 5) {
                Text(given.isEmpty ? "—" : given).font(font).strikethrough().foregroundStyle(Style.wrong)
                Text(answer).font(font).bold().foregroundStyle(Style.correct)
            }
        }
    }

    private var background: Color {
        switch state {
        case .correct: return Style.correct.opacity(0.10)
        case .wrong: return Style.wrong.opacity(0.10)
        case .active: return Color.accentColor.opacity(0.08)
        default: return .clear
        }
    }

    private var border: Color {
        switch state {
        case .correct: return Style.correct.opacity(0.5)
        case .wrong: return Style.wrong.opacity(0.5)
        case .active: return Color.accentColor.opacity(0.6)
        default: return Color(.separator)
        }
    }
}
