import SwiftUI

/// One question, its answer input, and (optionally) immediate feedback.
struct QuestionView: View {
    let question: Question
    let number: Int
    let total: Int
    let immediateFeedback: Bool
    let onAnswered: (_ correct: Bool, _ given: String) -> Void
    let onNext: () -> Void

    @Environment(ProgressStore.self) private var progress
    @State private var options: [String]
    @State private var selected: String?
    @State private var typed = ""
    @State private var verdict: AnswerVerdict?
    @State private var aiFeedback: MistakeFeedback?
    @State private var aiLoading = false
    @State private var aiError: String?
    @FocusState private var fieldFocused: Bool

    init(question: Question, number: Int, total: Int, immediateFeedback: Bool,
         onAnswered: @escaping (Bool, String) -> Void, onNext: @escaping () -> Void) {
        self.question = question
        self.number = number
        self.total = total
        self.immediateFeedback = immediateFeedback
        self.onAnswered = onAnswered
        self.onNext = onNext
        _options = State(initialValue: question.options?.shuffled() ?? [])
    }

    private var answered: Bool { verdict != nil }
    private var isCorrect: Bool { verdict == .correct }
    private var given: String { question.type == .choice ? (selected ?? "") : typed }
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressLine
                promptBlock
                if question.type == .choice { choiceBlock } else { typedBlock }
                if answered && immediateFeedback { feedbackBlock }
                Spacer(minLength: 8)
                bottomButton
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .onAppear { if question.type == .typed { fieldFocused = true } }
    }

    // MARK: Pieces

    private var progressLine: some View {
        HStack {
            Text("\(number) / \(total)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
            Text(Topic.byID(question.topic)?.title(in: language) ?? question.topic)
                .font(.footnote).foregroundStyle(.secondary)
            Text("· L\(question.level)").font(.footnote).foregroundStyle(.tertiary)
        }
    }

    private var promptBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            promptText
                .font(.system(.title3, design: .serif))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if let hint = question.hint, !hint.isEmpty {
                Text(hint).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var promptText: Text {
        let parts = question.promptParts
        let blank: Text
        if answered {
            if isCorrect {
                blank = Text(question.answer).bold().foregroundStyle(Style.correct)
            } else {
                blank = Text(given.isEmpty ? "—" : given).strikethrough().foregroundStyle(Style.wrong)
                    + Text(" ") + Text(question.answer).bold().foregroundStyle(Style.correct)
            }
        } else {
            blank = Text("______").foregroundStyle(Color.accentColor)
        }
        return Text(parts.before) + blank + Text(parts.after)
    }

    private var choiceBlock: some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button {
                    selected = option
                    if !immediateFeedback { submit() }
                } label: {
                    HStack {
                        Text(option).multilineTextAlignment(.leading)
                        Spacer()
                        if answered {
                            if option == question.answer {
                                Image(systemName: "checkmark").foregroundStyle(Style.correct)
                            } else if option == selected {
                                Image(systemName: "xmark").foregroundStyle(Style.wrong)
                            }
                        } else if option == selected {
                            Image(systemName: "circle.inset.filled").foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
                    .overlay(RoundedRectangle(cornerRadius: Style.corner).strokeBorder(borderColor(for: option), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .disabled(answered)
            }
        }
    }

    private func borderColor(for option: String) -> Color {
        if answered {
            if option == question.answer { return Style.correct }
            if option == selected { return Style.wrong }
            return .clear
        }
        return option == selected ? Color.accentColor : .clear
    }

    private var typedBlock: some View {
        TextField("Skriv svaret …", text: $typed)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.default)
            .submitLabel(.done)
            .focused($fieldFocused)
            .onSubmit { if !answered { submit() } }
            .disabled(answered)
            .font(.title3)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
            .overlay(RoundedRectangle(cornerRadius: Style.corner).strokeBorder(
                answered ? (isCorrect ? Style.correct : Style.wrong) : Color.accentColor.opacity(0.5), lineWidth: 1.5))
    }

    private var feedbackBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(verdictTitle, systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(isCorrect ? Style.correct : Style.wrong)
                Spacer()
                Picker("Language", selection: languageBinding) {
                    ForEach(ExplanationLanguage.allCases) { Text($0.short).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            if verdict == .nearMiss {
                Text(language == .danish ? "Tæt på – tjek stavningen." : "Close. Check the spelling.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text(question.filledPrompt)
                .font(.system(.body, design: .serif)).italic()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(question.explanation.text(in: language))
                .fixedSize(horizontal: false, vertical: true)
            aiSection
        }
        .card()
    }

    private var verdictTitle: String {
        if isCorrect { return language == .danish ? "Rigtigt" : "Correct" }
        return language == .danish ? "Ikke helt" : "Not quite"
    }

    @ViewBuilder
    private var aiSection: some View {
        if !isCorrect, progress.settings.useAI, DanishTutor.shared.availability.isAvailable {
            Divider()
            if let fb = aiFeedback {
                VStack(alignment: .leading, spacing: 8) {
                    Label(language == .danish ? "Om dit svar" : "About your answer", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                    Text(fb.whyWrong)
                    Text(fb.tip).foregroundStyle(.secondary)
                    Text(fb.example).font(.system(.body, design: .serif)).italic()
                }
                .fixedSize(horizontal: false, vertical: true)
            } else if aiLoading {
                HStack(spacing: 8) { ProgressView(); Text(language == .danish ? "Tænker …" : "Thinking …").foregroundStyle(.secondary) }
            } else if let aiError {
                Text(aiError).font(.footnote).foregroundStyle(.secondary)
            } else {
                Button {
                    askTutor()
                } label: {
                    Label(language == .danish ? "Hvorfor var mit svar forkert?" : "Why was my answer wrong?", systemImage: "sparkles")
                }
                .font(.subheadline)
            }
        }
    }

    private var bottomButton: some View {
        Group {
            if answered {
                Button(number == total ? "Finish" : "Next") { onNext() }
                    .buttonStyle(PrimaryButtonStyle())
            } else if immediateFeedback || question.type == .typed {
                Button("Check") { submit() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(given.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(given.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
    }

    private var languageBinding: Binding<ExplanationLanguage> {
        Binding(
            get: { progress.settings.explanationLanguage },
            set: { newValue in
                var s = progress.settings
                s.explanationLanguage = newValue
                progress.settings = s
            }
        )
    }

    // MARK: Actions

    private func submit() {
        guard !answered else { return }
        let v: AnswerVerdict
        if question.type == .choice {
            v = selected == question.answer ? .correct : .wrong
        } else {
            v = AnswerChecker.check(typed, for: question)
        }
        verdict = v
        fieldFocused = false
        onAnswered(v == .correct, given)
        if !immediateFeedback { onNext() }
    }

    private func askTutor() {
        aiLoading = true
        aiError = nil
        let q = question, g = given, lang = language
        Task {
            do {
                aiFeedback = try await DanishTutor.shared.explainMistake(question: q, learnerAnswer: g, language: lang)
            } catch {
                aiError = (lang == .danish ? "Kunne ikke hente forklaring: " : "Could not get an explanation: ") + error.localizedDescription
            }
            aiLoading = false
        }
    }
}
