import SwiftUI

struct HomeView: View {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @Environment(FlashcardStore.self) private var flashcards

    private var dueCount: Int { progress.dueCount(in: content.questions) }
    private var level: Int { progress.settings.preferredLevel }
    private var length: Int { progress.settings.sessionLength }
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var goalFraction: Double {
        min(1, Double(progress.todayCount) / Double(max(1, progress.settings.dailyGoal)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                todayCard
                practiceButtons
                weakestTopic
                if !content.loadErrors.isEmpty {
                    Text(content.loadErrors.joined(separator: "\n"))
                        .font(.footnote).foregroundStyle(Style.wrong)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(language == .danish ? "Dansk grammatik" : "Danish grammar")
    }

    private var todayCard: some View {
        HStack(spacing: 18) {
            ZStack {
                GoalRing(value: goalFraction, size: 78)
                VStack(spacing: 0) {
                    Text("\(progress.todayCount)")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("/ \(progress.settings.dailyGoal)")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(progress.currentStreak > 0 ? .orange : .secondary)
                    Text(progress.currentStreak == 1
                         ? (language == .danish ? "1 dag i træk" : "1 day streak")
                         : (language == .danish ? "\(progress.currentStreak) dage i træk" : "\(progress.currentStreak) day streak"))
                        .font(.body.weight(.semibold))
                }
                Text(statusLine)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private var statusLine: String {
        if progress.goalReachedToday {
            return language == .danish ? "Dagens mål er nået. Alt herudover er bonus." : "Today's goal is done. Anything more is a bonus."
        }
        if !progress.practisedToday && progress.currentStreak > 0 {
            return language == .danish ? "Øv i dag for at holde din række." : "Practise today to keep your streak."
        }
        let left = progress.settings.dailyGoal - progress.todayCount
        return language == .danish ? "\(left) spørgsmål tilbage i dag." : "\(left) questions left today."
    }

    private var practiceButtons: some View {
        VStack(spacing: 10) {
            NavigationLink(value: QuizRoute.practice(topic: nil, level: level, count: length)) {
                Text(language == .danish ? "Øv \(length) spørgsmål" : "Practise \(length) questions")
            }
            .buttonStyle(PrimaryButtonStyle())

            if dueCount > 0 {
                NavigationLink(value: QuizRoute.review(topic: nil, count: max(length, min(dueCount, 20)))) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(language == .danish ? "Gennemgå \(dueCount) fejl" : "Review \(dueCount) missed")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: 10) {
                NavigationLink(value: QuizRoute.verbDrill(irregularOnly: false, count: length)) {
                    compactLabel(language == .danish ? "Verber" : "Verbs", "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SecondaryButtonStyle())

                NavigationLink(value: QuizRoute.verbDrill(irregularOnly: true, count: length)) {
                    compactLabel(language == .danish ? "Uregelmæssige" : "Irregulars", "exclamationmark.triangle")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if !flashcards.cards.isEmpty {
                NavigationLink(value: QuizRoute.flashcards) {
                    HStack {
                        Image(systemName: "rectangle.on.rectangle.angled")
                        Text(language == .danish ? "Gennemgå \(flashcards.cards.count) ord" : "Review \(flashcards.cards.count) words")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func compactLabel(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.footnote)
            Text(title).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    /// Points at the topic with the lowest mastery once there is data to judge by.
    @ViewBuilder
    private var weakestTopic: some View {
        let ranked = Topic.all
            .map { ($0, content.byTopic[$0.id] ?? []) }
            .filter { progress.seenCount(of: $0.1) >= 3 }
            .sorted { progress.mastery(of: $0.1) < progress.mastery(of: $1.1) }
        if let (topic, pool) = ranked.first {
            NavigationLink(value: QuizRoute.topic(topic.id)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .danish ? "Svageste emne" : "Weakest topic")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack {
                        Text(topic.title(in: language)).font(.body.weight(.medium))
                        Spacer()
                        Text("\(Int((progress.mastery(of: pool) * 100).rounded()))%")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    MasteryBar(value: progress.mastery(of: pool))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .buttonStyle(.plain)
        } else {
            Text(levelDescription)
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
    }

    private var levelDescription: String {
        switch level {
        case 1: return language == .danish ? "Kun niveau 1. Skift i Indstillinger." : "Level 1 only. Change in Settings."
        case 2: return language == .danish ? "Kun niveau 2. Skift i Indstillinger." : "Level 2 only. Change in Settings."
        default: return language == .danish
            ? "Blandede niveauer. Øvelserne vægter dine svageste emner."
            : "Mixed levels. Sessions lean toward your weakest topics."
        }
    }
}
