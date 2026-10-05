import SwiftUI

/// The table. One top card holds everything that matters today: days to the exam,
/// readiness, what is holding you back, and today's set with a single button.
struct TodayView: View {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @Environment(FlashcardStore.self) private var flashcards
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showSettings = false
    @State private var showExamDate = false
    @State private var dealt = TodayView.hasDealt

    /// The deal animation plays once per launch, not every time Today reappears.
    private static var hasDealt = false

    private var plan: DailyPlan { SessionBuilder(content: content, progress: progress).dailyPlan() }
    private var topics: [TopicReadiness] { progress.readiness(content: content) }
    private var readiness: Int { Int((progress.overallReadiness(content: content) * 100).rounded()) }
    private var weakest: TopicReadiness? { progress.weakestTopic(content: content) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 18)

                PaperStack(sheets: plan.isBonus ? 7 : min(max(plan.size - 1, 3), 14), seed: 11, radius: Theme.todayRadius) {
                    topCard
                }
                .dealt(dealt, order: 0, reduceMotion: reduceMotion)
                .padding(.bottom, 72)

                sideStacks

                if !content.loadErrors.isEmpty {
                    Text(content.loadErrors.joined(separator: "\n"))
                        .font(.ui(13)).foregroundStyle(Theme.redText)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.table.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showExamDate) { ExamDateSheet() }
        .onAppear {
            progress.logReadiness(progress.overallReadiness(content: content))
            guard !dealt else { return }
            TodayView.hasDealt = true
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { dealt = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.dayFormatter.string(from: .now).capitalizedFirst)
                    .font(.ui(17, .semibold, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    WeekDots()
                    Text(streakText)
                        .font(.ui(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.pencil)
                }
            }
            Spacer()
            IconButton(systemImage: "slider.horizontal.3", label: "Indstillinger") { showSettings = true }
                .offset(x: 10, y: -6)
        }
    }

    private var streakText: String {
        switch progress.currentStreak {
        case 0: return "Ingen række endnu"
        case 1: return "1 dag i træk"
        default: return "\(progress.currentStreak) dage i træk"
        }
    }

    // MARK: Top card

    private var topCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            countdown
                .padding(.bottom, 20)
            weakestRow
                .padding(.bottom, 22)
            PerforatedRule()
                .padding(.horizontal, -22)
                .padding(.bottom, 20)
            todaysSet
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paper(radius: Theme.todayRadius)
    }

    @ViewBuilder
    private var countdown: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let days = progress.daysUntilExam {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(days == 1 ? "1 dag til" : "\(days) dage til")
                        .contentTransition(.numericText(value: Double(days)))
                    PD3Stamp(size: 34)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 6 }
                }
                .accessibilityElement(children: .combine)
            } else {
                Button { showExamDate = true } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Hvornår er")
                        PD3Stamp(size: 30)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 6 }
                        Text("?")
                    }
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Vælg din prøvedato")
            }
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(readiness) %")
                        .contentTransition(.numericText(value: Double(readiness)))
                    Text(" parat").foregroundStyle(Theme.pencil)
                }
                Spacer(minLength: 0)
                trend
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: readiness)
        }
        .font(.ui(37, .bold, relativeTo: .largeTitle))
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// Readiness over the last three weeks, with the change since the first day shown.
    @ViewBuilder
    private var trend: some View {
        let points = progress.readinessTrend(days: 21)
        if points.count >= 2 {
            let delta = Int(((points.last!.value - points.first!.value) * 100).rounded())
            VStack(alignment: .trailing, spacing: 2) {
                Sparkline(values: points.map(\.value), height: 32)
                    .frame(width: 104)
                Text(delta == 0 ? "uændret" : (delta > 0 ? "+\(delta)" : "\(delta)") + " på \(points.count) dage")
                    .font(.ui(12, .semibold, relativeTo: .caption).monospacedDigit())
                    .foregroundStyle(delta > 0 ? Theme.correct : delta < 0 ? Theme.redText : Theme.pencil)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(delta >= 0 ? "Op \(delta) point på \(points.count) dage" : "Ned \(-delta) point på \(points.count) dage")
        }
    }

    private var weakestRow: some View {
        NavigationLink(value: weakest.map { Route.topic($0.id) } ?? Route.topics) {
            HStack(alignment: .center, spacing: 14) {
                if let weakest {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weakest.topic.shortDa)
                            .font(.serif(20, .semibold, relativeTo: .title3))
                            .foregroundStyle(Theme.redText)
                        Text("holder dig tilbage")
                            .font(.ui(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.pencil)
                    }
                } else {
                    Text("Tag et par sæt, så finder jeg dit svageste emne.")
                        .font(.ui(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    TopicBars(values: topics, weakest: weakest?.id, height: 26, barWidth: 5)
                    if let weakest {
                        Text("\(weakest.percent) %")
                            .font(.ui(13, .bold).monospacedDigit())
                            .foregroundStyle(Theme.redText)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private var todaysSet: some View {
        let plan = plan
        return VStack(alignment: .leading, spacing: 0) {
            let title = Text(plan.isBonus ? "Dagens mål er nået" : "Dagens sæt")
                .font(.serif(23, .semibold, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            let meta = Text("ca. \(plan.minutes) min")
                .font(.ui(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.pencil)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { title.lineLimit(1); Spacer(minLength: 12); meta.lineLimit(1) }
                VStack(alignment: .leading, spacing: 4) { title; meta }
            }
            .padding(.bottom, 14)

            let parts = setParts(plan)
            CompositionBar(parts: parts.map { .init(id: $0.label, value: $0.count, emphasised: $0.emphasised) })
                .padding(.bottom, 12)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                    if i > 0 {
                        Rectangle().fill(Theme.rule).frame(width: 0.75, height: 40).padding(.horizontal, 12)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(part.count)")
                            .font(.ui(30, .bold, relativeTo: .title))
                            .foregroundStyle(part.emphasised ? Theme.redText : Theme.ink)
                        Text(part.label)
                            .font(.ui(12.5, relativeTo: .caption))
                            .foregroundStyle(Theme.pencil)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 18)

            NavigationLink(value: Route.daily(plan)) {
                Text(plan.isBonus ? "Én runde til" : "Begynd · \(plan.size) kort")
            }
            .buttonStyle(InkButtonStyle())
        }
    }

    private struct SetPart {
        let count: Int
        let label: String
        let emphasised: Bool
    }

    /// Today's set in its parts; the weakest topic is the one in red.
    private func setParts(_ plan: DailyPlan) -> [SetPart] {
        var parts: [SetPart] = []
        if plan.reviews > 0 { parts.append(SetPart(count: plan.reviews, label: "gentag", emphasised: false)) }
        if plan.weak > 0, let topic = plan.weakTopic {
            parts.append(SetPart(count: plan.weak, label: topic.shortDa, emphasised: true))
        }
        if plan.fresh > 0 { parts.append(SetPart(count: plan.fresh, label: "nye", emphasised: false)) }
        if plan.reading > 0 { parts.append(SetPart(count: plan.reading, label: "læsning", emphasised: false)) }
        return parts
    }

    // MARK: Side stacks

    private var sideStacks: some View {
        HStack(alignment: .top, spacing: 12) {
            sideStack(.topics, seed: 4, sheets: 5, order: 1) {
                TopicBars(values: topics, weakest: weakest?.id, height: 40, barWidth: 5)
                Spacer(minLength: 12)
                bigNumber("\(topics.filter { $0.percent >= 70 }.count)", unit: "/\(topics.count)")
                Text("emner ≥ 70 %").font(.ui(12, relativeTo: .caption)).foregroundStyle(Theme.pencil).lineLimit(1).minimumScaleFactor(0.8)
            }
            sideStack(.week, seed: 7, sheets: 3, order: 2) {
                let history = progress.data.examHistory.prefix(6).reversed()
                ScoreColumns(scores: history.map { Double($0.score) / Double(max(1, $0.total)) }, height: 40)
                Spacer(minLength: 12)
                if let last = progress.data.examHistory.first {
                    bigNumber("\(last.score)", unit: "/\(last.total)")
                } else {
                    bigNumber("–", unit: "")
                }
                Text("prøvesæt").font(.ui(12, relativeTo: .caption)).foregroundStyle(Theme.pencil)
            }
            sideStack(.words, seed: 9, sheets: min(max(flashcards.cards.count / 5, 1), 6), order: 3) {
                let shown = flashcards.cards.reduce(0) { $0 + $1.timesShown }
                let known = flashcards.cards.reduce(0) { $0 + $1.timesKnown }
                VStack(alignment: .leading, spacing: 6) {
                    Text(shown == 0 ? "ikke øvet" : "\(Int((Double(known) / Double(shown) * 100).rounded())) % kunne")
                        .font(.ui(12, .semibold, relativeTo: .caption).monospacedDigit())
                        .foregroundStyle(Theme.pencil)
                    Meter(value: shown == 0 ? 0 : Double(known) / Double(shown), height: 6)
                }
                .frame(height: 40, alignment: .bottom)
                Spacer(minLength: 12)
                bigNumber("\(flashcards.cards.count)", unit: "")
                Text("gemte ord").font(.ui(12, relativeTo: .caption)).foregroundStyle(Theme.pencil)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private func bigNumber(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(value).font(.ui(30, .bold, relativeTo: .title))
            if !unit.isEmpty {
                Text(unit).font(.ui(15, .semibold, relativeTo: .footnote)).foregroundStyle(Theme.pencil)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private func sideStack<C: View>(_ route: Route, seed: Int, sheets: Int, order: Int,
                                    @ViewBuilder _ content: () -> C) -> some View {
        NavigationLink(value: route) {
            PaperStack(sheets: sheets, seed: seed, step: 2.2, radius: Theme.smallRadius) {
                VStack(alignment: .leading, spacing: 0, content: content)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
                    .paper(radius: Theme.smallRadius)
            }
        }
        .buttonStyle(PressStyle())
        .dealt(dealt, order: order, reduceMotion: reduceMotion)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "da_DK")
        f.dateFormat = "EEEE d. MMMM"
        return f
    }()
}

// MARK: - Deal animation

private struct Dealt: ViewModifier {
    let dealt: Bool
    let order: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: dealt || reduceMotion ? 0 : 520 + CGFloat(order) * 40)
            .opacity(dealt || !reduceMotion ? 1 : 0)
            .animation(.spring(response: 0.7, dampingFraction: 0.82).delay(Double(order) * 0.07), value: dealt)
    }
}

private extension View {
    func dealt(_ dealt: Bool, order: Int, reduceMotion: Bool) -> some View {
        modifier(Dealt(dealt: dealt, order: order, reduceMotion: reduceMotion))
    }
}

// MARK: - Exam date

/// Asks for the PD3 date so Today can count down to it.
struct ExamDateSheet: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Hvornår er din prøve?")
                .font(.ui(24, .bold, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            Text("Så tæller I dag ned til den, og dagens sæt bliver lagt efter tiden.")
                .font(.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.pencil)
            DatePicker("Prøvedato", selection: $date, in: Date.now..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "da_DK"))
                .tint(Theme.red)
            Button("Gem dato") {
                var s = progress.settings
                s.examDate = date
                progress.settings = s
                dismiss()
            }
            .buttonStyle(InkButtonStyle())
        }
        .padding(24)
        .presentationDetents([.large])
        .presentationBackground(Theme.paper)
        .onAppear { if let d = progress.settings.examDate { date = d } }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
    var lowercasedFirst: String {
        // Keep titles that start with a Danish function word ("noget · nogen …") as written.
        guard let first = first, first.isUppercase else { return self }
        return prefix(1).lowercased() + dropFirst()
    }
}
