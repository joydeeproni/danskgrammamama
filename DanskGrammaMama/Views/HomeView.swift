import SwiftUI

struct HomeView: View {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress

    private var builder: SessionBuilder { SessionBuilder(content: content, progress: progress) }
    private var dueCount: Int { progress.dueCount(in: content.questions) }
    private var level: Int { progress.settings.preferredLevel }
    private var length: Int { progress.settings.sessionLength }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dailyProgress
                actions
                if !content.loadErrors.isEmpty {
                    Text(content.loadErrors.joined(separator: "\n"))
                        .font(.footnote).foregroundStyle(Style.wrong)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dansk grammatik")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(progress.currentStreak)")
                    .font(.system(size: 40, weight: .light, design: .serif))
                Text("day streak")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(progress.data.totalCorrect)/\(progress.data.totalAnswered)")
                    .font(.system(size: 22, weight: .light, design: .serif))
                Text("correct overall").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var dailyProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(progress.todayCount) / \(progress.settings.dailyGoal)")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            MasteryBar(value: min(1, Double(progress.todayCount) / Double(max(1, progress.settings.dailyGoal))))
            if progress.goalReachedToday {
                Text("Goal reached. Anything more is a bonus.").font(.footnote).foregroundStyle(.secondary)
            } else if !progress.practisedToday, progress.data.streak > 0 {
                Text("Practise today to keep your streak.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var actions: some View {
        VStack(spacing: 12) {
            NavigationLink {
                QuizView(questions: builder.practice(topic: nil, level: level, count: length), title: "Practice")
            } label: {
                Text("Practice \(length) questions")
            }
            .buttonStyle(PrimaryButtonStyle())

            if dueCount > 0 {
                NavigationLink {
                    QuizView(questions: builder.review(count: max(length, min(dueCount, 20))), title: "Review")
                } label: {
                    Text("Review \(dueCount) due \(dueCount == 1 ? "mistake" : "mistakes")")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            NavigationLink {
                QuizView(questions: builder.verbDrill(count: length, irregularOnly: false), title: "Verb drill")
            } label: {
                Text("Verb drill from your 500-verb list")
            }
            .buttonStyle(SecondaryButtonStyle())

            NavigationLink {
                QuizView(questions: builder.verbDrill(count: length, irregularOnly: true), title: "Irregular verbs")
            } label: {
                Text("Irregular verbs only")
            }
            .buttonStyle(SecondaryButtonStyle())

            Text(levelDescription)
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }

    private var levelDescription: String {
        switch level {
        case 1: return "Level 1 only. Change in Settings."
        case 2: return "Level 2 only (hardest). Change in Settings."
        default: return "Mixed levels. Sessions lean toward your weakest topics."
        }
    }
}
