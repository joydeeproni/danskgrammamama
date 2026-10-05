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
    /// Sends the card to the bottom of the pile. Nil hides the button.
    var onSkip: (() -> Void)? = nil

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
         onComplete: @escaping (Bool, [String]) -> Void, onContinue: @escaping () -> Void,
         onSkip: (() -> Void)? = nil) {
        self.onSkip = onSkip
        self.question = question
        self.label = label
        self.reveal = reveal
        // Mixed mode alternates per question so a session has some of each.
        self.inputMode = inputMode == .mixed ? (question.id.hashValue & 1 == 0 ? .choice : .typed) : inputMode
        self.onComplete = onComplete
        self.onContinue = onContinue
        // Reading tasks keep the paper's order, because the letters A, B, C … matter.
        _options = State(initialValue: question.blanks.map { question.reading == nil ? $0.options.shuffled() : $0.options })
        _given = State(initialValue: Array(repeating: "", count: question.blanks.count))
        _verdicts = State(initialValue: Array(repeating: nil, count: question.blanks.count))
    }

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var blank: Blank { question.blanks[current] }
    private var typing: Bool { inputMode == .typed }
    private var allAnswered: Bool { verdicts.allSatisfy { $0 != nil } }
    private var allCorrect: Bool { verdicts.allSatisfy { $0 == .correct } }
    private var topicTitle: String { Topic.byID(question.topic)?.shortDa ?? question.topic }

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

    @ViewBuilder
    private var front: some View {
        if let reading = question.reading {
            readingFront(reading)
        } else {
            gapFront
        }
    }

    private var cardHeader: some View {
        HStack(spacing: 8) {
            Art(topic: question.topic, size: 30)
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
    }

    @ViewBuilder
    private var skipButton: some View {
        if let onSkip, verdicts.allSatisfy({ $0 == nil }) {
            Button(action: onSkip) {
                Label("Spring over", systemImage: "arrow.uturn.down")
                    .font(.ui(14, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Theme.pencil)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .padding(.top, 8)
            .accessibilityHint("Lægger kortet nederst i bunken, så du kan tage det senere")
        }
    }

    /// A Læseforståelse task: the text, then the question or the parts to place.
    private func readingFront(_ reading: ReadingInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader.padding(.bottom, 12)
            Text(instruction)
                .font(.ui(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.pencil)
                .padding(.bottom, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reading.title)
                                .font(.serif(22, .semibold, relativeTo: .title3))
                                .foregroundStyle(Theme.ink)
                            Text("\(reading.part.title) · \(reading.source)")
                                .font(.ui(12.5, relativeTo: .caption))
                                .foregroundStyle(Theme.pencil)
                        }
                        .padding(.bottom, 4)

                        ForEach(Array(question.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            SentenceView(segments: paragraph,
                                         gapState: gapState(_:),
                                         gapNumber: { reading.part == .part2a ? nil : $0 + 1 },
                                         font: .serif(17, relativeTo: .body),
                                         quiet: true,
                                         onWordTap: { tappedWord = $0 })
                        }

                        if reading.part != .part3 {
                            Rectangle().fill(Theme.rule).frame(height: 0.75).padding(.vertical, 6)
                            if let q = blank.question {
                                Text(q)
                                    .font(.ui(17, .semibold, relativeTo: .headline))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            VStack(spacing: 0) { readingOptions }.id("options")
                            skipButton
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: current) { _, _ in
                    guard reading.part == .part2a else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { proxy.scrollTo("options", anchor: .center) }
                }
            }

            if reading.part == .part3 {
                Spacer(minLength: 12)
                optionGrid
                skipButton
            }
        }
        .padding(22)
    }

    /// Lettered options for 2A and 2B. In 2B a part already placed is not offered again.
    private var readingOptions: some View {
        let used = Set(given.prefix(current))
        let opts = options[current].filter { !used.contains($0) || $0 == given[current] }
        return VStack(spacing: 8) {
            ForEach(opts, id: \.self) { option in
                OptionButton(text: option, state: optionState(option), centered: false,
                             letter: question.letter(of: option, inBlank: current)) {
                    submit(option)
                }
                .disabled(verdicts[current] != nil)
            }
        }
        .id(current)
        .transition(.opacity.combined(with: .offset(y: 8)))
    }

    private var gapFront: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
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

            skipButton
        }
        .padding(22)
    }

    private var instruction: String {
        switch question.reading?.part {
        case .part2a: return "Spørgsmål \(current + 1) af \(question.blanks.count) · vælg A, B eller C"
        case .part2b: return "Hul \(current + 1) af \(question.blanks.count) · vælg den tekstdel, der passer"
        case .part3: return "Hul \(current + 1) af \(question.blanks.count) · vælg det ord, der passer"
        case nil: break
        }
        if question.isCloze {
            return "Hul \(current + 1) af \(question.blanks.count)"
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
                        .buttonStyle(PressStyle())
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
                if question.reading != nil {
                    readingReview
                } else {
                    gapReview
                }
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

    /// Each answer of a reading task: the question, your pick, the right one and why.
    private var readingReview: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(question.blanks.indices, id: \.self) { i in
                let right = verdicts[i] == .correct
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.ui(13, .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(right ? Theme.correct : Theme.red, in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        if let q = question.blanks[i].question {
                            Text(q).font(.ui(15, .semibold)).foregroundStyle(Theme.ink)
                        }
                        if !right {
                            Text(lettered(given[i], i))
                                .font(.ui(15))
                                .strikethrough(color: Theme.red)
                                .foregroundStyle(Theme.redText)
                        }
                        Text(lettered(question.blanks[i].answer, i))
                            .font(.ui(15, .semibold))
                            .foregroundStyle(Theme.correct)
                        Text(question.blanks[i].explanation.text(in: language))
                            .font(.ui(15, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(3)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    /// "B · Derfor", with long 2B parts cut to their opening words.
    private func lettered(_ option: String, _ i: Int) -> String {
        let text = option.count > 80 ? String(option.prefix(78)) + " …" : option
        guard let letter = question.letter(of: option, inBlank: i) else { return text }
        return "\(letter) · \(text)"
    }

    private var gapReview: some View {
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

    /// Missed gaps first, so the explanation that matters is on top.
    private var explainedGaps: [Int] {
        let missed = question.blanks.indices.filter { verdicts[$0] != .correct }
        let right = question.blanks.indices.filter { verdicts[$0] == .correct }
        return missed + right
    }

    private var answerLine: String {
        let missed = question.blanks.indices.filter { verdicts[$0] != .correct }
        if question.reading != nil {
            let right = question.blanks.count - missed.count
            return "\(right) af \(question.blanks.count) rigtige"
        }
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
        if !allCorrect, question.reading == nil, progress.settings.useAI, DanishTutor.shared.availability.isAvailable {
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
                    .buttonStyle(PressStyle())
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
    var letter: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: letter == nil ? .center : .firstTextBaseline, spacing: 10) {
                if let letter {
                    Text(letter)
                        .font(.ui(13, .bold))
                        .foregroundStyle(state == .right ? Theme.correct : state == .wrong ? Theme.redText : Theme.pencil)
                        .frame(width: 22, height: 22)
                        .background(Theme.chip, in: Circle())
                }
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
                .buttonStyle(PressStyle(scale: 0.9))
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
