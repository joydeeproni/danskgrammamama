import SwiftUI

/// The topic stack spread out: nine cards, the weakest in red.
struct TopicsView: View {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @State private var spread = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        let topics = progress.readiness(content: content)
        let weakest = progress.weakestTopic(content: content)?.id
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Emner")
                    .font(.serif(38, .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 4)
                Text("Hvert emne har sine regler, tricks og klassiske fejl, og sine egne øvelser.")
                    .font(.ui(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.pencil)
                    .padding(.bottom, 22)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { i, t in
                        NavigationLink(value: Route.topic(t.id)) {
                            TopicTile(readiness: t, isWeakest: t.id == weakest)
                        }
                        .buttonStyle(PressStyle())
                        .offset(y: spread ? 0 : -CGFloat(i) * 6)
                        .opacity(spread ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.84).delay(Double(i) * 0.03), value: spread)
                    }
                }
                .padding(.bottom, 20)

                Text("Tallet er den del af emnets spørgsmål, du har svaret rigtigt på og ikke skal gentage.")
                    .font(.ui(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.pencil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .tableBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { spread = true }
    }
}

private struct TopicTile: View {
    let readiness: TopicReadiness
    let isWeakest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(readiness.percent)")
                .font(.ui(34, .bold, relativeTo: .title).monospacedDigit())
                .foregroundStyle(isWeakest ? Theme.redText : Theme.ink)
            + Text(" %")
                .font(.ui(15, .bold, relativeTo: .footnote))
                .foregroundStyle(isWeakest ? Theme.redText : Theme.pencil)
            Spacer(minLength: 10)
            Text(readiness.topic.titleDa)
                .font(.ui(13, .semibold, relativeTo: .footnote))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            ReadinessBar(value: readiness.value, tint: isWeakest ? Theme.red : Theme.ink, height: 3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .paper(radius: 14)
        .accessibilityElement(children: .combine)
    }
}

/// One topic: how ready you are, how to crack it, and the button to practise it.
struct TopicPageView: View {
    let topic: Topic
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @State private var open: Set<Int> = [0]
    @State private var level = 0

    private var pool: [Question] { content.byTopic[topic.id] ?? [] }
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(topic.titleDa)
                    .font(.serif(38, .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if topic.titleEn != topic.titleDa {
                    Text(topic.titleEn)
                        .font(.ui(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.pencil)
                }

                statusCard
                    .padding(.vertical, 22)

                if let guide = content.guide(for: topic.id) {
                    Markdown.text(guide.intro.text(in: language))
                        .font(.ui(16, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 26)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Reglerne")
                            .font(.ui(20, .bold, relativeTo: .title3))
                        Spacer()
                        LanguageToggle()
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 12)

                    ForEach(Array(guide.sections.enumerated()), id: \.offset) { i, section in
                        GuideSection(number: i + 1, section: section, language: language, open: open.contains(i)) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                                if open.contains(i) { open.remove(i) } else { open.insert(i) }
                            }
                        }
                        .padding(.bottom, 10)
                    }

                    if !guide.traps.isEmpty {
                        Text("Klassiske fejl")
                            .font(.ui(20, .bold, relativeTo: .title3))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(guide.traps.enumerated()), id: \.offset) { _, trap in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Circle().fill(Theme.red).frame(width: 6, height: 6).offset(y: -2)
                                    Markdown.text(trap.text(in: language))
                                        .font(.ui(15, relativeTo: .body))
                                        .foregroundStyle(Theme.ink)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paper(radius: 16)
                    }
                } else {
                    Text(topic.blurbDa)
                        .font(.ui(16))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { practiceBar }
        .tableBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { level = progress.settings.preferredLevel }
    }

    private var statusCard: some View {
        let mastery = progress.mastery(of: pool)
        let due = progress.dueCount(in: pool)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("\(Int((mastery * 100).rounded())) %")
                    .font(.ui(34, .bold, relativeTo: .title).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                ReadinessBar(value: mastery, height: 5)
            }
            HStack(spacing: 0) {
                stat("Set", "\(progress.seenCount(of: pool)) af \(pool.count)")
                stat("Præcision", progress.accuracy(of: pool).map { "\(Int(($0 * 100).rounded())) %" } ?? "–")
                stat("Til gentagelse", "\(due)")
            }
            Text(topic.blurbDa)
                .font(.ui(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.pencil)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paper(radius: 18)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.ui(17, .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.ui(12.5, relativeTo: .caption))
                .foregroundStyle(Theme.pencil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var practiceBar: some View {
        let due = progress.dueCount(in: pool)
        let length = progress.settings.sessionLength
        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach([(0, "Blandet"), (1, "Niveau 1"), (2, "Niveau 2")], id: \.0) { value, name in
                    Button(name) {
                        withAnimation(.snappy(duration: 0.2)) { level = value }
                    }
                    .font(.ui(13.5, .semibold))
                    .foregroundStyle(level == value ? Theme.buttonText : Theme.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(level == value ? Theme.buttonFill : Theme.chip, in: Capsule())
                    .accessibilityAddTraits(level == value ? .isSelected : [])
                }
                Spacer()
            }
            HStack(spacing: 10) {
                if due > 0 {
                    NavigationLink(value: Route.review(topic: topic.id, count: 20)) {
                        Text("Gentag \(due)")
                    }
                    .buttonStyle(PaperButtonStyle())
                    .frame(maxWidth: 140)
                }
                NavigationLink(value: Route.practice(topic: topic.id, level: level, count: length)) {
                    Text("Øv \(topic.titleDa.lowercasedFirst)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(InkButtonStyle())
            }
            if topic.id == "verbs" {
                HStack(spacing: 10) {
                    NavigationLink(value: Route.verbDrill(irregularOnly: false, count: length)) { Text("Bøj verber") }
                    NavigationLink(value: Route.verbDrill(irregularOnly: true, count: length)) { Text("Uregelmæssige") }
                }
                .buttonStyle(PaperButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            // Solid table under the buttons, fading out above them so text slides under softly.
            VStack(spacing: 0) {
                LinearGradient(colors: [Theme.table.opacity(0), Theme.table], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
                Theme.table
            }
            .padding(.top, -24)
            .ignoresSafeArea()
        }
    }
}

/// One rule from the guide: the rules, the hack, and examples. Collapsible.
private struct GuideSection: View {
    let number: Int
    let section: TopicGuide.Section
    let language: ExplanationLanguage
    let open: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(number)")
                        .font(.ui(15, .bold).monospacedDigit())
                        .foregroundStyle(Theme.redText)
                        .frame(width: 18, alignment: .leading)
                    Text(section.title.text(in: language))
                        .font(.ui(17, .bold, relativeTo: .headline))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.pencil)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(open ? "Åben" : "Lukket")

            if open {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(section.rules.enumerated()), id: \.offset) { _, rule in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Rectangle().fill(Theme.pencil).frame(width: 7, height: 1.5).offset(y: -4)
                                Markdown.text(rule.text(in: language))
                                    .font(.ui(15, relativeTo: .body))
                                    .foregroundStyle(Theme.ink)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.redText)
                        Markdown.text(section.hack.text(in: language))
                            .font(.ui(15, .medium, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.paperTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.edge, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(section.examples.enumerated()), id: \.offset) { _, ex in
                            VStack(alignment: .leading, spacing: 2) {
                                Markdown.text(ex.da)
                                    .font(.serif(17, relativeTo: .body))
                                    .foregroundStyle(Theme.ink)
                                if language == .english {
                                    Text(ex.en)
                                        .font(.ui(13, relativeTo: .footnote))
                                        .foregroundStyle(Theme.pencil)
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paper(radius: 16)
    }
}

/// Renders the guides' light markdown. Bold stays bold; emphasis is set upright,
/// because the app uses no italic type.
enum Markdown {
    static func text(_ source: String) -> Text {
        guard var attributed = try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return Text(source)
        }
        for run in attributed.runs {
            guard var intent = run.inlinePresentationIntent, intent.contains(.emphasized) else { continue }
            intent.remove(.emphasized)
            attributed[run.range].inlinePresentationIntent = intent.isEmpty ? nil : intent
        }
        return Text(attributed)
    }
}
