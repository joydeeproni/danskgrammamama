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
    var font: Font = .serif(21)
    /// Long reading texts get a fainter underline so the page does not look busy.
    var quiet = false
    var onWordTap: (String) -> Void

    @Environment(Glossary.self) private var glossary

    var body: some View {
        FlowLayout(lineSpacing: 8) {
            ForEach(Array(units.enumerated()), id: \.offset) { _, unit in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    if !unit.leading.isEmpty { Text(unit.leading).font(font).foregroundStyle(Theme.ink) }
                    switch unit.core {
                    case .word(let text, let lookupable):
                        WordChip(text: text, lookupable: lookupable, quiet: quiet, font: font) { onWordTap(text) }
                    case .gap(let index):
                        GapChip(state: gapState(index), number: gapNumber(index), font: font)
                    case .none:
                        EmptyView()
                    }
                    if !unit.trailing.isEmpty { Text(unit.trailing).font(font).foregroundStyle(Theme.ink) }
                }
            }
        }
    }

    private enum Token {
        case word(String, Bool)
        case plain(String)
        case gap(Int)
    }

    /// A word or gap with the punctuation that belongs to it, so a line never starts
    /// with a comma: trailing marks and spaces stick to the word before, opening marks
    /// like » stick to the word after.
    private struct Unit {
        enum Core { case word(String, Bool), gap(Int), none }
        var leading = ""
        var core: Core
        var trailing = ""
    }

    private var units: [Unit] {
        var units: [Unit] = []
        var pending = ""
        for token in tokens {
            switch token {
            case .word(let w, let lookupable):
                units.append(Unit(leading: pending, core: .word(w, lookupable)))
                pending = ""
            case .gap(let i):
                units.append(Unit(leading: pending, core: .gap(i)))
                pending = ""
            case .plain(let text):
                guard !units.isEmpty else { pending += text; continue }
                if let cut = text.lastIndex(where: \.isWhitespace) {
                    units[units.count - 1].trailing += String(text[...cut])
                    pending += String(text[text.index(after: cut)...])
                } else {
                    units[units.count - 1].trailing += text
                }
            }
        }
        if !pending.isEmpty {
            if units.isEmpty { units.append(Unit(leading: pending, core: .none)) }
            else { units[units.count - 1].trailing += pending }
        }
        return units
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
    var quiet = false
    let font: Font
    let action: () -> Void

    var body: some View {
        if lookupable {
            Button(action: action) {
                Text(text)
                    .font(font)
                    .underline(true, pattern: .dot, color: Theme.pencil.opacity(quiet ? 0.3 : 0.7))
                    .foregroundStyle(Theme.ink)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(scale: 0.9))
            .accessibilityHint("Viser, hvad \(text) betyder")
        } else {
            Text(text).font(font).foregroundStyle(Theme.ink)
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
            if let number { Text("\(number)").font(.ui(11, .bold).monospacedDigit()).foregroundStyle(Theme.pencil) }
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
            Text("______").font(font).foregroundStyle(Theme.pencil.opacity(0.5))
        case .active:
            Text("______").font(font).foregroundStyle(Theme.red)
        case .correct(let answer):
            Text(answer).font(font).bold().foregroundStyle(Theme.correct)
        case .chosen(let given):
            Text(given).font(font).bold().foregroundStyle(Theme.ink)
        case .wrong(let given, let answer):
            let struck = Text(given.isEmpty ? "—" : given).font(font).strikethrough(color: Theme.red).foregroundStyle(Theme.redText)
            let right = Text(answer).font(font).bold().foregroundStyle(Theme.correct)
            // Side by side when it fits on the line, otherwise the correction goes underneath.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) { struck; right }
                VStack(alignment: .leading, spacing: 2) {
                    struck.fixedSize(horizontal: false, vertical: true)
                    right.fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var background: Color {
        switch state {
        case .correct: return Theme.correctWash
        case .wrong: return Theme.redWash
        case .active: return Theme.redWash
        default: return .clear
        }
    }

    private var border: Color {
        switch state {
        case .correct: return Theme.correct.opacity(0.55)
        case .wrong: return Theme.red.opacity(0.55)
        case .active: return Theme.red
        default: return Theme.edge
        }
    }
}
