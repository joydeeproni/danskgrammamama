import SwiftUI

/// One question with one or more gaps.
///
/// In practice mode the verdict, the correct answer and the explanation appear the
/// instant an option is tapped. Every word in the sentence is tappable for its meaning.
struct QuestionView: View {
    let question: Question
    let number: Int
    let total: Int
    let immediateFeedback: Bool
    let inputMode: InputMode
    let onAnswered: (_ correct: Bool, _ given: [String]) -> Void
    let onNext: () -> Void

    @Environment(ProgressStore.self) private var progress
    @State private var options: [[String]]
    @State private var given: [String]
    @State private var verdicts: [AnswerVerdict?]
    @State private var current = 0
    @State private var typed = ""
    @State private var showChoicesHint = false
    @State private var tappedWord: String?
    @State private var aiFeedback: MistakeFeedback?
    @State private var aiLoading = false
    @State private var aiError: String?
    @FocusState private var fieldFocused: Bool

    init(question: Question, number: Int, total: Int, immediateFeedback: Bool, inputMode: InputMode,
         onAnswered: @escaping (Bool, [String]) -> Void, onNext: @escaping () -> Void) {
        self.question = question
        self.number = number
        self.total = total
        self.immediateFeedback = immediateFeedback
        self.inputMode = inputMode == .mixed ? .choice : inputMode
        self.onAnswered = onAnswered
        self.onNext = onNext
        _options = State(initialValue: question.blanks.map { $0.options.shuffled() })
        _given = State(initialValue: Array(repeating: "", count: question.blanks.count))
        _verdicts = State(initialValue: Array(repeating: nil, count: question.blanks.count))
    }

    private var blank: Blank { question.blanks[current] }
    private var currentVerdict: AnswerVerdict? { verdicts[current] }
    private var answeredCurrent: Bool { currentVerdict != nil }
    private var isCorrect: Bool { currentVerdict == .correct }
    private var isLastGap: Bool { current == question.blanks.count - 1 }
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var typing: Bool { inputMode == .typed }
    private var showVerdict: Bool { answeredCurrent && immediateFeedback }

    var body: some View {
        VStack(spacing: 0) {
            ProgressBar(value: Double(number - 1) / Double(max(1, total)))
                .padding(.horizontal, 20).padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metaLine
                    sentenceCard
                    if showVerdict {
                        verdictBanner
                        explanationCard
                    }
                    if typing && !answeredCurrent { typedField }
                    optionList
                }
                .padding(20)
                .padding(.bottom, 90)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(item: Binding(get: { tappedWord.map(IdentifiableWord.init) },
                             set: { tappedWord = $0?.value })) { item in
            WordSheet(word: item.value, context: question.filledPrompt)
        }
        .onAppear { if typing { fieldFocused = true } }
    }

    // MARK: Pieces

    private var metaLine: some View {
        HStack(spacing: 6) {
            Text("\(number) / \(total)").font(.footnote.monospacedDigit().weight(.medium))
            if question.isCloze {
                Text("· \(language == .danish ? "hul" : "gap") \(current + 1)/\(question.blanks.count)")
                    .font(.footnote.monospacedDigit())
            }
            Spacer()
            Text(Topic.byID(question.topic)?.title(in: language) ?? question.topic).font(.footnote)
            Text("L\(question.level)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .foregroundStyle(.secondary)
    }

    private var sentenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SentenceView(
                segments: question.segments,
                gapState: gapState(_:),
                gapNumber: { question.isCloze ? $0 + 1 : nil },
                font: .system(question.isCloze ? .body : .title3, design: .serif),
                onWordTap: { tappedWord = $0 }
            )
            if let hint = question.hint, !hint.isEmpty {
                Text(hint).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func gapState(_ i: Int) -> GapState {
        guard let v = verdicts[i] else { return i == current ? .active : .pending }
        guard immediateFeedback else { return .chosen(given[i]) }
        return v == .correct ? .correct(question.blanks[i].answer)
                             : .wrong(given: given[i], answer: question.blanks[i].answer)
    }

    private var verdictBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text(verdictTitle).font(.headline)
                if !isCorrect {
                    Text("\(language == .danish ? "Rigtigt svar" : "Correct answer"): \(blank.answer)")
                        .font(.subheadline)
                } else if currentVerdict == .nearMiss {
                    Text(language == .danish ? "Tæt på – tjek stavningen." : "Close. Check the spelling.")
                        .font(.subheadline)
                }
            }
            Spacer()
        }
        .foregroundStyle(isCorrect ? Style.correct : Style.wrong)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isCorrect ? Style.correct : Style.wrong).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Style.corner))
    }

    private var verdictTitle: String {
        if isCorrect { return language == .danish ? "Rigtigt" : "Correct" }
        return language == .danish ? "Ikke helt" : "Not quite"
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language == .danish ? "Hvorfor" : "Why").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Language", selection: languageBinding) {
                    ForEach(ExplanationLanguage.allCases) { Text($0.short).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 108)
            }
            Text(blank.explanation.text(in: language))
                .fixedSize(horizontal: false, vertical: true)
            aiSection
        }
        .card()
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
                HStack(spacing: 8) {
                    ProgressView()
                    Text(language == .danish ? "Tænker …" : "Thinking …").foregroundStyle(.secondary)
                }
            } else if let aiError {
                Text(aiError).font(.footnote).foregroundStyle(.secondary)
            } else {
                Button { askTutor() } label: {
                    Label(language == .danish ? "Hvorfor var mit svar forkert?" : "Why was my answer wrong?",
                          systemImage: "sparkles")
                }
                .font(.subheadline)
            }
        }
    }

    private var typedField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(language == .danish ? "Skriv svaret …" : "Type the answer …", text: $typed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($fieldFocused)
                .onSubmit { if !answeredCurrent { submit(typed) } }
                .font(.title3)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
                .overlay(RoundedRectangle(cornerRadius: Style.corner)
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1.5))
            if showChoicesHint {
                Text(options[current].joined(separator: "   ·   "))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Button(language == .danish ? "Vis valgmuligheder" : "Show the choices") { showChoicesHint = true }
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var optionList: some View {
        if !typing || answeredCurrent {
            VStack(spacing: 10) {
                ForEach(options[current], id: \.self) { option in
                    Button { submit(option) } label: {
                        HStack(spacing: 10) {
                            Text(option)
                                .font(.body.weight(.medium))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if showVerdict {
                                if option == blank.answer {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Style.correct)
                                } else if option == given[current] {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Style.wrong)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(optionFill(option), in: RoundedRectangle(cornerRadius: Style.corner))
                        .overlay(RoundedRectangle(cornerRadius: Style.corner)
                            .strokeBorder(optionBorder(option), lineWidth: 1.5))
                        .foregroundStyle(optionText(option))
                    }
                    .buttonStyle(.plain)
                    .disabled(answeredCurrent)
                }
            }
        }
    }

    private func optionFill(_ option: String) -> Color {
        guard showVerdict else { return Color(.secondarySystemGroupedBackground) }
        if option == blank.answer { return Style.correct.opacity(0.12) }
        if option == given[current] { return Style.wrong.opacity(0.12) }
        return Color(.secondarySystemGroupedBackground).opacity(0.6)
    }

    private func optionBorder(_ option: String) -> Color {
        guard showVerdict else { return Color(.separator).opacity(0.4) }
        if option == blank.answer { return Style.correct }
        if option == given[current] { return Style.wrong }
        return .clear
    }

    private func optionText(_ option: String) -> Color {
        guard showVerdict else { return .primary }
        if option == blank.answer || option == given[current] { return .primary }
        return .secondary
    }

    private var bottomBar: some View {
        Group {
            if showVerdict {
                Button(nextTitle) { advance() }
                    .buttonStyle(PrimaryButtonStyle())
            } else if typing && !answeredCurrent {
                Button(language == .danish ? "Tjek" : "Check") { submit(typed) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(typed.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            } else if !immediateFeedback {
                Text(language == .danish ? "Vælg et svar" : "Choose an answer")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 8).padding(.top, 8)
        .background(.bar)
    }

    private var nextTitle: String {
        if !isLastGap { return language == .danish ? "Næste hul" : "Next gap" }
        if number == total { return language == .danish ? "Afslut" : "Finish" }
        return language == .danish ? "Fortsæt" : "Continue"
    }

    private var languageBinding: Binding<ExplanationLanguage> {
        Binding(get: { progress.settings.explanationLanguage },
                set: { newValue in
                    var s = progress.settings
                    s.explanationLanguage = newValue
                    progress.settings = s
                })
    }

    // MARK: Actions

    private func submit(_ answer: String) {
        guard !answeredCurrent else { return }
        let v = typing ? AnswerChecker.checkTyped(answer, for: blank) : AnswerChecker.checkChoice(answer, for: blank)
        given[current] = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.snappy(duration: 0.2)) { verdicts[current] = v }
        fieldFocused = false
        Haptics.verdict(correct: v == .correct)
        if verdicts.allSatisfy({ $0 != nil }) {
            onAnswered(verdicts.allSatisfy { $0 == .correct }, given)
        }
        if !immediateFeedback { advance() }
    }

    private func advance() {
        if isLastGap {
            onNext()
        } else {
            withAnimation(.snappy(duration: 0.2)) { current += 1 }
            typed = ""
            showChoicesHint = false
            aiFeedback = nil
            aiError = nil
            if typing { fieldFocused = true }
        }
    }

    private func askTutor() {
        aiLoading = true
        aiError = nil
        let q = question, i = current, g = given[current], lang = language
        Task {
            do {
                aiFeedback = try await DanishTutor.shared.explainMistake(question: q, blankIndex: i,
                                                                        learnerAnswer: g, language: lang)
            } catch {
                aiError = (lang == .danish ? "Kunne ikke hente forklaring: " : "Could not get an explanation: ")
                    + error.localizedDescription
            }
            aiLoading = false
        }
    }
}

/// Wraps a tapped word so it can drive a sheet(item:).
struct IdentifiableWord: Identifiable {
    let value: String
    var id: String { value }
}

enum Haptics {
    static func verdict(correct: Bool) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        #endif
    }
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
