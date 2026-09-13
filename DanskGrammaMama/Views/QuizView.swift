import SwiftUI

struct AnsweredItem: Identifiable, Hashable {
    let question: Question
    let given: String
    let correct: Bool
    var id: String { question.id }
}

/// A practice/review/drill session with immediate feedback after every question.
struct QuizView: View {
    let questions: [Question]
    let title: String

    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var answered: [AnsweredItem] = []
    @State private var finished = false

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
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.question.filledPrompt)
                                .font(.system(.body, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 6) {
                                Text(item.given.isEmpty ? "—" : item.given).strikethrough().foregroundStyle(Style.wrong)
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                                Text(item.question.answer).bold().foregroundStyle(Style.correct)
                            }
                            .font(.subheadline)
                            Text(item.question.explanation.text(in: language))
                                .font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .card()
                    }
                }

                Button("Done") { onDone() }.buttonStyle(PrimaryButtonStyle())
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
