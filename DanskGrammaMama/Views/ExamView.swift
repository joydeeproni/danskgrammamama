import SwiftUI

/// PD3-style timed paper: 20 mixed questions, no feedback until the end.
struct ExamView: View {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .danish ? "Prøvesæt" : "Exam paper").font(.headline)
                    Text(language == .danish
                         ? "20 spørgsmål fra alle emner, mest niveau 2. \(progress.settings.examMinutes) minutter. Ingen feedback før til sidst – som til prøven."
                         : "20 questions across all topics, mostly level 2. \(progress.settings.examMinutes) minutes. No feedback until the end, like the real paper.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()

                NavigationLink {
                    ExamRunView(questions: SessionBuilder(content: content, progress: progress).exam(count: 20),
                                minutes: progress.settings.examMinutes)
                } label: {
                    Text(language == .danish ? "Start prøve" : "Start exam")
                }
                .buttonStyle(PrimaryButtonStyle())

                if !progress.data.examHistory.isEmpty {
                    Text(language == .danish ? "Tidligere prøver" : "Past papers").font(.headline).padding(.top, 8)
                    ForEach(progress.data.examHistory) { result in
                        HStack {
                            Text(result.date, style: .date).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(result.score) / \(result.total)").font(.body.monospacedDigit().weight(.medium))
                            Text("· \(result.seconds / 60) min").font(.footnote).foregroundStyle(.secondary)
                        }
                        .card()
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(language == .danish ? "Prøve" : "Exam")
    }
}

struct ExamRunView: View {
    @State private var questions: [Question]   // see QuizView for why this is state
    let minutes: Int

    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var answered: [AnsweredItem] = []
    @State private var remaining: Int
    @State private var finished = false
    @State private var started = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(questions: [Question], minutes: Int) {
        _questions = State(initialValue: questions)
        self.minutes = minutes
        _remaining = State(initialValue: minutes * 60)
    }

    var body: some View {
        Group {
            if finished || questions.isEmpty {
                ExamResultView(items: answered, total: questions.count) { dismiss() }
            } else {
                let q = questions[index]
                QuestionView(question: q, number: index + 1, total: questions.count, immediateFeedback: false,
                             inputMode: resolveInputMode(progress.settings.inputMode, for: q),
                             onAnswered: { correct, given in
                                 progress.record(question: q, correct: correct)
                                 answered.append(AnsweredItem(question: q, given: given, correct: correct))
                             },
                             onNext: { advance() })
                    .id(q.id)
            }
        }
        .navigationTitle(timeString)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onReceive(ticker) { _ in
            guard !finished else { return }
            if remaining > 0 { remaining -= 1 } else { finish() }
        }
    }

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private func advance() {
        if index + 1 < questions.count { index += 1 } else { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let score = answered.filter(\.correct).count
        progress.recordExam(ExamResult(date: .now, score: score, total: questions.count,
                                       seconds: Int(Date().timeIntervalSince(started))))
    }
}

struct ExamResultView: View {
    let items: [AnsweredItem]
    let total: Int
    let onDone: () -> Void

    @Environment(ProgressStore.self) private var progress
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var score: Int { items.filter(\.correct).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(score) / \(total)")
                        .font(.system(size: 44, weight: .light, design: .serif))
                    Text(language == .danish ? "\(items.count) besvaret" : "\(items.count) answered")
                        .foregroundStyle(.secondary)
                    Text(language == .danish
                         ? "Fejlene er lagt i din gennemgangskø."
                         : "Misses have been added to your review queue.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                }
                .card()

                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    AnsweredItemRow(item: item, language: language, showNumber: i + 1)
                }

                Button("Done") { onDone() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
    }
}
