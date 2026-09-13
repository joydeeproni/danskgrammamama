import SwiftUI

struct AnsweredItem: Identifiable, Hashable {
    let question: Question
    let given: [String]
    let correct: Bool
    var id: String { question.id }

    /// Indices of gaps answered wrongly.
    var missedGaps: [Int] {
        question.blanks.indices.filter { i in
            i < given.count && AnswerChecker.checkTyped(given[i], for: question.blanks[i]) != .correct
        }
    }
}

/// Resolves the settings' input mode into a concrete mode for one question.
func resolveInputMode(_ mode: InputMode, for question: Question) -> InputMode {
    switch mode {
    case .mixed: return question.id.hashValue & 1 == 0 ? .choice : .typed
    default: return mode
    }
}

/// A practice/review/drill session with immediate feedback after every gap.
struct QuizView: View {
    /// Held in state on purpose: the caller builds a freshly shuffled list inside a
    /// NavigationLink destination, which SwiftUI re-evaluates whenever the parent
    /// re-renders. Owning the list here keeps the session stable while it runs.
    @State private var questions: [Question]
    let title: String

    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var answered: [AnsweredItem] = []
    @State private var finished = false

    init(questions: [Question], title: String) {
        _questions = State(initialValue: questions)
        self.title = title
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                ContentUnavailableView("Nothing to practise", systemImage: "checkmark.circle",
                                       description: Text("No questions match this selection yet."))
            } else if finished {
                SessionSummaryView(items: answered, title: title) { dismiss() }
            } else {
                let q = questions[index]
                QuestionView(question: q, number: index + 1, total: questions.count, immediateFeedback: true,
                             inputMode: resolveInputMode(progress.settings.inputMode, for: q),
                             onAnswered: { correct, given in
                                 progress.record(question: q, correct: correct)
                                 answered.append(AnsweredItem(question: q, given: given, correct: correct))
                             },
                             onNext: { advance() })
                    .id(q.id)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func advance() {
        if index + 1 < questions.count {
            withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
        } else {
            finished = true
        }
    }
}

/// Lists one answered item: the filled text, then each missed gap with its explanation.
struct AnsweredItemRow: View {
    let item: AnsweredItem
    let language: ExplanationLanguage
    var showNumber: Int? = nil
    @State private var tappedWord: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                if let n = showNumber {
                    Text("\(n).").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
                SentenceView(segments: [.text(item.question.filledPrompt)],
                             gapState: { _ in .pending }, gapNumber: { _ in nil },
                             font: .system(.body, design: .serif),
                             onWordTap: { tappedWord = $0 })
            }
            if item.correct {
                Label(language == .danish ? "Rigtigt" : "Correct", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).foregroundStyle(Style.correct)
            } else {
                ForEach(item.missedGaps, id: \.self) { i in
                    let b = item.question.blanks[i]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if item.question.isCloze {
                                Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Text(item.given[i].isEmpty ? "—" : item.given[i]).strikethrough().foregroundStyle(Style.wrong)
                            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                            Text(b.answer).bold().foregroundStyle(Style.correct)
                        }
                        .font(.subheadline)
                        Text(b.explanation.text(in: language))
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .card()
        .sheet(item: Binding(get: { tappedWord.map(IdentifiableWord.init) },
                             set: { tappedWord = $0?.value })) { item in
            WordSheet(word: item.value, context: self.item.question.filledPrompt)
        }
    }
}

struct SessionSummaryView: View {
    let items: [AnsweredItem]
    let title: String
    let onDone: () -> Void

    @Environment(ProgressStore.self) private var progress

    private var correct: Int { items.filter(\.correct).count }
    private var missed: [AnsweredItem] { items.filter { !$0.correct } }
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(correct) / \(items.count)")
                        .font(.system(size: 44, weight: .light, design: .serif))
                    Text(summaryLine).foregroundStyle(.secondary)
                    if !missed.isEmpty {
                        Text(language == .danish
                             ? "De forkerte kommer tilbage i morgen, og igen efter tre dage."
                             : "Missed items come back tomorrow, then again after three days.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                    }
                }
                .card()

                if !missed.isEmpty {
                    Text(language == .danish ? "Gennemgå" : "Review").font(.headline)
                    ForEach(missed) { item in
                        AnsweredItemRow(item: item, language: language)
                    }
                }

                Button(language == .danish ? "Færdig" : "Done") { onDone() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var summaryLine: String {
        let pct = items.isEmpty ? 0 : Int((Double(correct) / Double(items.count) * 100).rounded())
        switch pct {
        case 100: return language == .danish ? "Fejlfrit. Flot." : "Flawless."
        case 80...: return language == .danish ? "Stærkt. Kig på fejlene nedenfor." : "Strong. Look over the misses below."
        case 60...: return language == .danish ? "Godt på vej. Reglerne nedenfor er dem, der skal sidde." : "Getting there. The rules below are the ones to nail."
        default: return language == .danish ? "Svært sæt. Læs forklaringerne og prøv igen i morgen." : "Tough set. Read the explanations and try again tomorrow."
        }
    }
}
