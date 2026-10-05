import SwiftUI

/// One question as a card. The front holds the sentence and the options, which never
/// move. Once every gap is answered the card turns over: the back gives the verdict,
/// the sentence with your word struck through, and why.
///
/// In exam mode (`reveal == false`) nothing is revealed and the card never turns.
struct QuestionCard: View {
    let question: Question
    let label: String?
    let reveal: Bool
    let inputMode: InputMode
    /// Called once, when the last gap has been answered.
    let onComplete: (_ correct: Bool, _ given: [String]) -> Void
    /// Called from the back of the card.
    let onContinue: () -> Void

    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var options: [[String]]
    @State private var given: [String]
    @State private var verdicts: [AnswerVerdict?]
    @State private var current = 0
    @State private var typed = ""
    @State private var showChoicesHint = false
    @State private var flipped = false
    @State private var tappedWord: String?
    @State private var aiFeedback: MistakeFeedback?
    @State private var aiLoading = false
    @State private var aiError: String?
    @FocusState private var fieldFocused: Bool

    init(question: Question, label: String?, reveal: Bool, inputMode: InputMode,
         onComplete: @escaping (Bool, [String]) -> Void, onContinue: @escaping () -> Void) {
        self.question = question
        self.label = label
        self.reveal = reveal
        // Mixed mode alternates per question so a session has some of each.
        self.inputMode = inputMode == .mixed ? (question.id.hashValue & 1 == 0 ? .choice : .typed) : inputMode
        self.onComplete = onComplete
        self.onContinue = onContinue
        _options = State(initialValue: question.blanks.map { $0.options.shuffled() })
        _given = State(initialValue: Array(repeating: "", count: question.blanks.count))
        _verdicts = State(initialValue: Array(repeating: nil, count: question.blanks.count))
    }

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var blank: Blank { question.blanks[current] }
    private var typing: Bool { inputMode == .typed }
    private var allAnswered: Bool { verdicts.allSatisfy { $0 != nil } }
    private var allCorrect: Bool { verdicts.allSatisfy { $0 == .correct } }
    private var topicTitle: String { Topic.byID(question.topic)?.titleDa ?? question.topic }

    var body: some View {
        FlipCard(flipped: flipped) {
            front
        } back: {
            back
        }
        .sheet(item: Binding(get: { tappedWord.map(IdentifiableWord.init) },
                             set: { tappedWord = $0?.value })) { item in
            WordSheet(word: item.value, context: question.filledPrompt)
        }
        .onAppear {
            if typing { fieldFocused = true }
            #if DEBUG
            if let mode = DebugLaunch.answer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let wrong = mode == "wrong" || (mode == "run" && abs(question.id.hashValue) % 4 == 0)
                    for i in question.blanks.indices {
                        let b = question.blanks[i]
                        current = i
                        submit(wrong ? (b.options.first { $0 != b.answer } ?? b.answer) : b.answer)
                    }
                }
            }
            #endif
        }
    }

    // MARK: Front

    private var front: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Theme.red).frame(width: 7, height: 7)
                Text(topicTitle)
                    .font(.ui(14, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let label {
                    Text(label)
                        .font(.ui(12.5, .medium, relativeTo: .caption))
                        .foregroundStyle(Theme.pencil)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Theme.chip, in: Capsule())
                }
            }
            .padding(.bottom, 14)

            Text(instruction)
                .font(.ui(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.pencil)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    SentenceView(segments: question.segments,
                                 gapState: gapState(_:),
                                 gapNumber: { question.isCloze ? $0 + 1 : nil },
                                 font: .serif(question.isCloze ? 20.5 : 25, relativeTo: question.isCloze ? .body : .title2),
                                 onWordTap: { tappedWord = $0 })
                    if let hint = question.hint, !hint.isEmpty {
                        Text(hint).font(.ui(14)).foregroundStyle(Theme.pencil)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            Spacer(minLength: 16)

            if typing && verdicts[current] == nil {
                typedField
            } else {
                optionGrid
            }
        }
        .padding(22)
    }

    private var instruction: String {
        if question.isCloze {
            return "Hul \(current + 1) af \(question.blanks.count). Vælg det ord, der passer."
        }
        return typing ? "Skriv det ord, der mangler." : "Vælg det ord, der passer."
    }

    private func gapState(_ i: Int) -> GapState {
        guard let v = verdicts[i] else { return i == current && !allAnswered ? .active : .pending }
        guard reveal else { return .chosen(given[i]) }
        return v == .correct ? .correct(question.blanks[i].answer)
                             : .wrong(given: given[i], answer: question.blanks[i].answer)
    }

    @ViewBuilder
    private var optionGrid: some View {
        let opts = options[current]
        let compact = opts.count <= 4 && opts.allSatisfy { $0.count <= 12 }
        let columns = compact ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                              : [GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(opts, id: \.self) { option in
                OptionButton(text: option, state: optionState(option), centered: compact) {
                    submit(option)
                }
                .disabled(verdicts[current] != nil)
            }
        }
        .id(current)
        .transition(.opacity.combined(with: .offset(y: 8)))
    }

    private func optionState(_ option: String) -> OptionButton.State {
        guard verdicts[current] != nil else { return .idle }
        guard reveal else { return option == given[current] ? .chosen : .dimmed }
        if option == blank.answer { return .right }
        if option == given[current] { return .wrong }
        return .dimmed
    }

    private var typedField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Skriv svaret", text: $typed)
                .font(.serif(21))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($fieldFocused)
                .onSubmit { submit(typed) }
                .padding(14)
                .background(Theme.paperTint, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .strokeBorder(Theme.red.opacity(0.6), lineWidth: 1.5))
            HStack {
                if showChoicesHint {
                    Text(options[current].joined(separator: "   ·   "))
                        .font(.ui(14)).foregroundStyle(Theme.pencil)
                } else {
                    Button("Vis valgmulighederne") { showChoicesHint = true }
                        .font(.ui(14, .medium)).foregroundStyle(Theme.ink)
                }
                Spacer()
            }
            Button("Tjek") { submit(typed) }
                .buttonStyle(InkButtonStyle())
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: Back

    private var back: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: allCorrect ? "checkmark" : "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(allCorrect ? Theme.correct : Theme.red, in: Circle())
                Text(allCorrect ? "Rigtigt." : "Ikke helt.")
                    .font(.ui(30, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(allCorrect ? Theme.correct : Theme.redText)
                Spacer(minLength: 8)
                LanguageToggle()
            }
            .padding(.bottom, 6)

            Text(answerLine)
                .font(.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.pencil)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SentenceView(segments: question.segments,
                                 gapState: gapState(_:),
                                 gapNumber: { question.isCloze ? $0 + 1 : nil },
                                 font: .serif(18, relativeTo: .body),
                                 onWordTap: { tappedWord = $0 })

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hvorfor?")
                            .font(.ui(15, .bold, relativeTo: .headline))
                            .foregroundStyle(Theme.ink)
                        ForEach(explainedGaps, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                if question.isCloze {
                                    Text("\(i + 1)")
                                        .font(.ui(13, .bold).monospacedDigit())
                                        .foregroundStyle(verdicts[i] == .correct ? Theme.correct : Theme.redText)
                                }
                                Text(question.blanks[i].explanation.text(in: language))
                                    .font(.ui(16, relativeTo: .body))
                                    .foregroundStyle(Theme.ink)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    aiSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            Rectangle().fill(Theme.rule).frame(height: 0.75).padding(.bottom, 14)

            HStack(spacing: 10) {
                Button {
                    withAnimation(flipAnimation) { flipped = false }
                } label: {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 17, weight: .semibold))
                }
                .buttonStyle(PaperButtonStyle())
                .frame(width: 56)
                .accessibilityLabel("Vend kortet")

                Button("Fortsæt", action: onContinue)
                    .buttonStyle(InkButtonStyle())
            }
        }
        .padding(22)
    }

    /// Missed gaps first, so the explanation that matters is on top.
    private var explainedGaps: [Int] {
        let missed = question.blanks.indices.filter { verdicts[$0] != .correct }
        let right = question.blanks.indices.filter { verdicts[$0] == .correct }
        return missed + right
    }

    private var answerLine: String {
        let missed = question.blanks.indices.filter { verdicts[$0] != .correct }
        if missed.isEmpty {
            return question.isCloze ? "Alle \(question.blanks.count) huller er rigtige." : "Det rigtige svar er \(question.blanks[0].answer)."
        }
        if question.isCloze {
            return missed.map { "\($0 + 1): \(question.blanks[$0].answer)" }.joined(separator: "   ")
        }
        if verdicts[0] == .nearMiss { return "Tæt på. Det staves \(question.blanks[0].answer)." }
        return "Det rigtige svar er \(question.blanks[0].answer)."
    }

    @ViewBuilder
    private var aiSection: some View {
        if !allCorrect, progress.settings.useAI, DanishTutor.shared.availability.isAvailable {
            VStack(alignment: .leading, spacing: 8) {
                if let fb = aiFeedback {
                    Label("Om dit svar", systemImage: "sparkles")
                        .font(.ui(15, .bold)).foregroundStyle(Theme.ink)
                    Text(fb.whyWrong).font(.ui(16)).foregroundStyle(Theme.ink)
                    Text(fb.tip).font(.ui(16)).foregroundStyle(Theme.pencil)
                    Text(fb.example).font(.serif(17)).foregroundStyle(Theme.ink)
                } else if aiLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Tænker …").font(.ui(15)).foregroundStyle(Theme.pencil)
                    }
                } else if let aiError {
                    Text(aiError).font(.ui(13)).foregroundStyle(Theme.pencil)
                } else {
                    Button { askTutor() } label: {
                        Label("Hvorfor var mit svar forkert?", systemImage: "sparkles")
                            .font(.ui(15, .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paperTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: Actions

    private var flipAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.82)
    }

    private func submit(_ answer: String) {
        guard verdicts[current] == nil else { return }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let v = typing ? AnswerChecker.checkTyped(trimmed, for: blank) : AnswerChecker.checkChoice(trimmed, for: blank)
        given[current] = trimmed
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { verdicts[current] = v }
        fieldFocused = false
        // Exam mode withholds the verdict, so it must not leak through the haptic either.
        if reveal { Haptics.verdict(correct: v == .correct) } else { Haptics.tap() }

        if allAnswered {
            onComplete(allCorrect, given)
            guard reveal else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(flipAnimation) { flipped = true }
            }
        } else {
            let next = current + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + (reveal ? 0.8 : 0.15)) {
                // Only move on if nothing else has moved the card in the meantime.
                guard current == next - 1, next < question.blanks.count else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    current = next
                    typed = ""
                    showChoicesHint = false
                }
                if typing { fieldFocused = true }
            }
        }
    }

    private func askTutor() {
        guard let i = explainedGaps.first else { return }
        aiLoading = true
        aiError = nil
        let q = question, g = given[i], lang = language
        Task {
            do {
                aiFeedback = try await DanishTutor.shared.explainMistake(question: q, blankIndex: i,
                                                                        learnerAnswer: g, language: lang)
            } catch {
                aiError = "Kunne ikke hente en forklaring: " + error.localizedDescription
            }
            aiLoading = false
        }
    }
}

// MARK: - Option

struct OptionButton: View {
    enum State { case idle, right, wrong, chosen, dimmed }

    let text: String
    let state: State
    var centered = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if !centered { label; Spacer(minLength: 4) } else { label }
                if state == .right || state == .wrong {
                    Image(systemName: state == .right ? "checkmark" : "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(state == .right ? Theme.correct : Theme.red)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: centered ? .center : .leading)
            .padding(.horizontal, 16)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(stroke, lineWidth: state == .idle || state == .dimmed ? 0.75 : 1.5))
            .opacity(state == .dimmed ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
        }
        .buttonStyle(PressStyle())
        .modifier(Shake(trigger: state == .wrong))
        .accessibilityValue(accessibilityValue)
    }

    private var label: some View {
        Text(text)
            .font(.serif(centered ? 20 : 17, relativeTo: .body))
            .strikethrough(state == .wrong, color: Theme.red)
            .foregroundStyle(state == .wrong ? Theme.redText : Theme.ink)
            .multilineTextAlignment(centered ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
    }

    private var fill: Color {
        switch state {
        case .right: return Theme.correctWash
        case .wrong: return Theme.redWash
        default: return Theme.paperTint
        }
    }

    private var stroke: Color {
        switch state {
        case .right: return Theme.correct
        case .wrong: return Theme.red
        case .chosen: return Theme.ink
        default: return Theme.edge
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .right: return "Rigtigt svar"
        case .wrong: return "Dit svar, forkert"
        case .chosen: return "Valgt"
        default: return ""
        }
    }
}

/// A small sideways shake for a wrong pick.
private struct Shake: ViewModifier {
    let trigger: Bool
    @State private var amount: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: amount)
            .onChange(of: trigger) { _, now in
                guard now, !reduceMotion else { return }
                withAnimation(.spring(response: 0.08, dampingFraction: 0.2)) { amount = 6 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { amount = 0 }
                }
            }
    }
}

/// EN / DA for explanations. Changes the setting, so it sticks.
struct LanguageToggle: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ExplanationLanguage.allCases) { lang in
                let on = progress.settings.explanationLanguage == lang
                Button(lang.short) {
                    var s = progress.settings
                    s.explanationLanguage = lang
                    withAnimation(.snappy(duration: 0.2)) { progress.settings = s }
                }
                .font(.ui(12.5, .bold))
                .foregroundStyle(on ? Theme.ink : Theme.pencil)
                .frame(width: 34, height: 28)
                .background(on ? Theme.paper : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(on ? Theme.edge : .clear, lineWidth: 0.75))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.paperTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sprog for forklaringer")
    }
}

// MARK: - Flip

/// Turns a card over around its vertical axis, swapping faces at the halfway point.
struct FlipCard<Front: View, Back: View>: View {
    let flipped: Bool
    @ViewBuilder var front: Front
    @ViewBuilder var back: Back

    var body: some View {
        FlipLayer(angle: flipped ? 180 : 0, front: front, back: back)
    }
}

private struct FlipLayer<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showingBack = angle > 90
        ZStack {
            front
                .opacity(showingBack ? 0 : 1)
                .allowsHitTesting(!showingBack)
                .accessibilityHidden(showingBack)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showingBack ? 1 : 0)
                .allowsHitTesting(showingBack)
                .accessibilityHidden(!showingBack)
        }
        // Lift a little while turning, like a card picked up off the table.
        .scaleEffect(1 + 0.04 * sin(angle * .pi / 180))
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}
