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

/// A session as a deck of cards. The pile under the top card is what is left, so the
/// deck itself is the progress bar. Answer a card, then throw it away or press Fortsæt.
struct DeckSessionView: View {
    enum Mode: Hashable {
        case practice
        case exam(minutes: Int)
    }

    /// Held in state on purpose: the route builds a freshly shuffled list, which SwiftUI
    /// re-evaluates whenever the stack re-renders. Owning it here keeps the session stable.
    @State private var questions: [Question]
    @State private var kinds: [String: DailyKind]
    let title: String
    let mode: Mode
    let allReviews: Bool

    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var answered: [AnsweredItem] = []
    @State private var finished = false
    @State private var cardDone = false
    @State private var drag: CGSize = .zero
    @State private var horizontalDrag: Bool?
    @State private var before: [TopicReadiness] = []
    @State private var started = Date()
    @State private var remaining = 0
    @State private var confirmQuit = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(questions: [Question], kinds: [String: DailyKind] = [:], title: String,
         mode: Mode = .practice, allReviews: Bool = false) {
        _questions = State(initialValue: questions)
        _kinds = State(initialValue: kinds)
        self.title = title
        self.mode = mode
        self.allReviews = allReviews
        if case .exam(let minutes) = mode { _remaining = State(initialValue: minutes * 60) }
    }

    private var isExam: Bool { if case .exam = mode { return true } else { return false } }
    private var left: Int { questions.count - index }

    var body: some View {
        VStack(spacing: 0) {
            header
            if questions.isEmpty {
                emptyDeck
            } else if finished {
                SessionResultView(items: answered, before: before, isExam: isExam,
                                  seconds: Int(Date().timeIntervalSince(started)),
                                  onDone: { dismiss() }, onAgain: isExam ? nil : { oneMoreRound() })
                    .transition(.opacity.combined(with: .offset(y: 30)))
            } else {
                deck
            }
        }
        .background(Theme.table.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if before.isEmpty { before = progress.readiness(content: content) }
        }
        .onReceive(ticker) { _ in
            guard isExam, !finished, !questions.isEmpty else { return }
            if remaining > 0 { remaining -= 1 } else { finish() }
        }
        .confirmationDialog("Stop sættet?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Stop", role: .destructive) { dismiss() }
        } message: {
            Text("Det, du har svaret på, er gemt.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            IconButton(systemImage: "xmark", label: "Luk") {
                if !finished && !answered.isEmpty && left > 0 { confirmQuit = true } else { dismiss() }
            }
            Spacer()
            Text(isExam && !finished ? timeString : title)
                .font(.ui(16, .semibold, relativeTo: .headline).monospacedDigit())
                .foregroundStyle(isExam && remaining < 60 && !finished ? Theme.redText : Theme.ink)
                .contentTransition(.numericText(countsDown: true))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
    }

    private var timeString: String { String(format: "%d:%02d", remaining / 60, remaining % 60) }

    // MARK: Deck

    private var deck: some View {
        let q = questions[index]
        return VStack(spacing: 0) {
            PaperStack(sheets: left - 1, seed: 21) {
                QuestionCard(question: q, label: label(for: q), reveal: !isExam,
                             inputMode: progress.settings.inputMode,
                             onComplete: { correct, given in record(q, correct, given) },
                             onContinue: { throwCard(direction: -1) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .paper(lifted: drag != .zero)
                    .offset(drag)
                    .rotationEffect(.degrees(Double(drag.width) * 0.065), anchor: .bottom)
                    .simultaneousGesture(dragGesture)
                    .id(q.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
                        removal: .identity))
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 52)

            VStack(spacing: 3) {
                (Text("\(left)").font(.ui(14, .bold).monospacedDigit())
                    + Text(left == 1 ? " kort tilbage i bunken" : " kort tilbage i bunken"))
                    .font(.ui(14, relativeTo: .footnote))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                Text(isExam ? "Svarene vises, når prøven er slut." : cardDone ? "Træk kortet væk, eller tryk Fortsæt." : " ")
                    .font(.ui(13, relativeTo: .caption))
                    .foregroundStyle(Theme.pencil)
            }
            .padding(.bottom, 12)
        }
    }

    private func label(for q: Question) -> String? {
        if allReviews { return "Gentagelse" }
        switch kinds[q.id] {
        case .review: return "Gentagelse"
        case .weak: return "Svageste emne"
        case .fresh: return progress.isUnseen(q) ? "Ny" : nil
        case nil: return nil
        }
    }

    private var emptyDeck: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("Ingen kort i bunken")
                    .font(.serif(26, .semibold, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                Text(allReviews ? "Der er ikke noget at gentage lige nu. Fejl kommer tilbage dagen efter."
                                : "Der er ingen spørgsmål, der passer til det valg endnu.")
                    .font(.ui(16))
                    .foregroundStyle(Theme.pencil)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Tilbage") { dismiss() }
                    .buttonStyle(InkButtonStyle())
                    .padding(.top, 8)
            }
            .padding(22)
            .paper()
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if horizontalDrag == nil { horizontalDrag = abs(v.translation.width) > abs(v.translation.height) }
                guard horizontalDrag == true else { return }
                if cardDone {
                    drag = v.translation
                } else {
                    // An unanswered card resists, then springs back.
                    let d = v.translation.width
                    drag = CGSize(width: (d < 0 ? -1 : 1) * 46 * (1 - exp(-abs(d) / 90)), height: 0)
                }
            }
            .onEnded { v in
                defer { horizontalDrag = nil }
                guard horizontalDrag == true else { return }
                let fling = abs(v.predictedEndTranslation.width) > 260
                if cardDone && (abs(v.translation.width) > 110 || fling) {
                    throwCard(direction: v.translation.width < 0 ? -1 : 1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { drag = .zero }
                }
            }
    }

    // MARK: Actions

    private func record(_ q: Question, _ correct: Bool, _ given: [String]) {
        progress.record(question: q, correct: correct)
        answered.append(AnsweredItem(question: q, given: given, correct: correct))
        cardDone = true
        #if DEBUG
        if DebugLaunch.answer == "run" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { throwCard(direction: -1) }
        }
        #endif
        if isExam {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { throwCard(direction: -1) }
        }
    }

    private func throwCard(direction: CGFloat) {
        guard cardDone else { return }
        Haptics.soft()
        let out = reduceMotion ? Animation.easeOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.9)
        withAnimation(out) {
            drag = CGSize(width: direction * 560, height: drag.height + 70)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.15 : 0.26)) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { drag = .zero }
            cardDone = false
            if index + 1 < questions.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { index += 1 }
            } else {
                finish()
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        if isExam {
            let score = answered.filter(\.correct).count
            progress.recordExam(ExamResult(date: .now, score: score, total: questions.count,
                                           seconds: Int(Date().timeIntervalSince(started))))
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { finished = true }
    }

    private func oneMoreRound() {
        let builder = SessionBuilder(content: content, progress: progress)
        let set = builder.daily(builder.dailyPlan())
        before = progress.readiness(content: content)
        answered = []
        index = 0
        started = .now
        questions = set.questions
        kinds = set.kinds
        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { finished = false }
    }
}

// MARK: - Result

/// What is left when the deck is gone: one card with the score, what moved, the misses
/// with their rule, and tomorrow's pile.
struct SessionResultView: View {
    let items: [AnsweredItem]
    let before: [TopicReadiness]
    let isExam: Bool
    let seconds: Int
    let onDone: () -> Void
    let onAgain: (() -> Void)?

    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @State private var showAfter = false

    private var correct: Int { items.filter(\.correct).count }
    private var missed: [AnsweredItem] { items.filter { !$0.correct } }
    private var after: [TopicReadiness] { progress.readiness(content: content) }

    private func overall(_ list: [TopicReadiness]) -> Int {
        guard !list.isEmpty else { return 0 }
        return Int((list.map(\.value).reduce(0, +) / Double(list.count) * 100).rounded())
    }

    private var changes: [(topic: Topic, from: Int, to: Int)] {
        let old = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0.percent) })
        let touched = Set(items.map(\.question.topic))
        return after.compactMap { t in
            guard let from = old[t.id], touched.contains(t.id) else { return nil }
            return (t.topic, from, t.percent)
        }
        .sorted { ($0.to - $0.from) > ($1.to - $1.from) }
    }

    /// Questions due by the end of tomorrow.
    private var tomorrow: Int {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: .now)) ?? .now
        return progress.dueCount(in: content.questions, now: end.addingTimeInterval(-1))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                resultCard
                    .padding(.bottom, 34)

                PaperStack(sheets: min(max(tomorrow, 1), 6), seed: 5, step: 1.6, radius: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        Art(.review, size: 36)
                        Text("I morgen")
                            .font(.ui(16, .bold, relativeTo: .headline))
                        Spacer()
                        Text(tomorrow == 0 ? "Ingen gentagelser venter" : tomorrow == 1 ? "1 kort venter" : "\(tomorrow) kort venter")
                            .font(.ui(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.pencil)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .paper(radius: 10)
                }
                .padding(.bottom, 32)

                Button("Tilbage til I dag", action: onDone)
                    .buttonStyle(InkButtonStyle())
                if let onAgain {
                    Button("Én runde til", action: onAgain)
                        .buttonStyle(PaperButtonStyle())
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { showAfter = true }
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(isExam ? "Prøvesættet er afleveret" : "Sættet er klaret")
                    .font(.serif(30, .medium, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Art(isExam ? .exam : .flag, size: 84)
                    .scaleEffect(showAfter ? 1 : 0.6)
                    .opacity(showAfter ? 1 : 0)
                    .padding(.top, -6)
            }
            .padding(.bottom, 6)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(correct)")
                    .font(.ui(64, .bold, relativeTo: .largeTitle).monospacedDigit())
                Text("af \(items.count) rigtige")
                    .font(.ui(20, .semibold, relativeTo: .title3))
                    .foregroundStyle(Theme.pencil)
            }
            .foregroundStyle(Theme.ink)
            if isExam {
                Text("\(seconds / 60) min \(seconds % 60) s")
                    .font(.ui(15).monospacedDigit())
                    .foregroundStyle(Theme.pencil)
            }

            PerforatedRule()
                .padding(.horizontal, -22)
                .padding(.vertical, 20)

            HStack(alignment: .firstTextBaseline) {
                Text("Parat til PD3")
                    .font(.ui(16, .semibold, relativeTo: .headline))
                Spacer()
                let from = overall(before), to = overall(after)
                Text("\(showAfter ? to : from) %")
                    .font(.ui(30, .bold, relativeTo: .title).monospacedDigit())
                    .contentTransition(.numericText(value: Double(showAfter ? to : from)))
                if to != from {
                    Text(to > from ? "+\(to - from)" : "\(to - from)")
                        .font(.ui(15, .bold).monospacedDigit())
                        .foregroundStyle(to > from ? Theme.correct : Theme.redText)
                        .opacity(showAfter ? 1 : 0)
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(.bottom, 18)

            if !changes.isEmpty {
                Text("Hvad ændrede sig")
                    .font(.ui(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 4)
                ForEach(changes, id: \.topic.id) { change in
                    changeRow(change.topic, change.from, change.to)
                }
            }

            if !missed.isEmpty {
                Text(missed.count == 1 ? "Din fejl" : "Dine \(missed.count) fejl")
                    .font(.ui(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 22)
                    .padding(.bottom, 2)
                Text("Kommer igen i morgen.")
                    .font(.ui(14))
                    .foregroundStyle(Theme.pencil)
                    .padding(.bottom, 8)
                ForEach(missed) { item in
                    MissRow(item: item)
                }
            } else if isExam && !items.isEmpty {
                EmptyView()
            }

            if isExam {
                Text("Rigtige svar")
                    .font(.ui(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 22)
                    .padding(.bottom, 8)
                ForEach(items.filter(\.correct)) { item in
                    MissRow(item: item)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paper()
    }

    private func changeRow(_ topic: Topic, _ from: Int, _ to: Int) -> some View {
        let delta = to - from
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Art(topic: topic.id, size: 30)
                Text(topic.shortDa)
                    .font(.ui(15, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                ReadinessBar(value: Double(showAfter ? to : from) / 100, tint: delta < 0 ? Theme.red : Theme.ink)
                    .frame(width: 72)
                Text(delta == 0 ? "±0" : delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(.ui(14, .bold).monospacedDigit())
                    .foregroundStyle(delta > 0 ? Theme.correct : delta < 0 ? Theme.redText : Theme.pencil)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.vertical, 10)
            Rectangle().fill(Theme.rule).frame(height: 0.75)
        }
    }
}

/// One answered item on the result card: the sentence with the correction and the rule.
private struct MissRow: View {
    let item: AnsweredItem
    @Environment(ProgressStore.self) private var progress
    @State private var tappedWord: String?
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SentenceView(segments: item.question.segments,
                         gapState: { i in
                             let b = item.question.blanks[i]
                             let g = i < item.given.count ? item.given[i] : ""
                             return item.missedGaps.contains(i) ? .wrong(given: g, answer: b.answer) : .correct(b.answer)
                         },
                         gapNumber: { item.question.isCloze ? $0 + 1 : nil },
                         font: .serif(17, relativeTo: .body),
                         onWordTap: { tappedWord = $0 })
            if let first = item.missedGaps.first ?? item.question.blanks.indices.first {
                let text = item.question.blanks[first].explanation.text(in: progress.settings.explanationLanguage)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { open.toggle() }
                } label: {
                    Text(open ? text : text.firstSentence)
                        .font(.ui(14.5, relativeTo: .subheadline))
                        .foregroundStyle(Theme.pencil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint(open ? "Viser mindre" : "Viser hele forklaringen")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.edge, lineWidth: 1))
        .padding(.bottom, 8)
        .sheet(item: Binding(get: { tappedWord.map(IdentifiableWord.init) },
                             set: { tappedWord = $0?.value })) { w in
            WordSheet(word: w.value, context: item.question.filledPrompt)
        }
    }
}

extension String {
    /// Up to and including the first full stop that ends a sentence.
    var firstSentence: String {
        guard let r = range(of: ". ") else { return self }
        return String(self[..<r.lowerBound]) + "."
    }
}
