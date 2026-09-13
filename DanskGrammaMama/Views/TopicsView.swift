import SwiftUI

struct TopicsView: View {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    var body: some View {
        List {
            Section {
                ForEach(Topic.all) { topic in
                    let pool = content.byTopic[topic.id] ?? []
                    NavigationLink(value: topic.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(topic.title(in: language)).font(.body.weight(.medium))
                                Spacer()
                                Text(masteryLabel(pool)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            MasteryBar(value: progress.mastery(of: pool))
                        }
                        .padding(.vertical, 6)
                    }
                }
            } footer: {
                Text(language == .danish
                     ? "Bjælken viser, hvor stor en del af emnets spørgsmål du har svaret rigtigt på og ikke skal gentage."
                     : "The bar shows the share of a topic's questions you have answered correctly and that are not waiting for review.")
            }
        }
        .navigationTitle(language == .danish ? "Emner" : "Topics")
        .navigationDestination(for: String.self) { id in
            if let topic = Topic.byID(id) { TopicDetailView(topic: topic) }
        }
    }

    private func masteryLabel(_ pool: [Question]) -> String {
        let seen = progress.seenCount(of: pool)
        if seen == 0 { return "\(pool.count) \(language == .danish ? "spørgsmål" : "questions")" }
        let due = progress.dueCount(in: pool)
        var s = "\(Int((progress.mastery(of: pool) * 100).rounded()))%"
        if due > 0 { s += " · \(due) \(language == .danish ? "til gennemgang" : "due") " }
        return s
    }
}

struct TopicDetailView: View {
    let topic: Topic
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @State private var level = 0

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var pool: [Question] { content.byTopic[topic.id] ?? [] }
    private var builder: SessionBuilder { SessionBuilder(content: content, progress: progress) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(topic.blurb(in: language))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        stat(language == .danish ? "Mestret" : "Mastered", "\(Int((progress.mastery(of: pool) * 100).rounded()))%")
                        Spacer()
                        stat(language == .danish ? "Præcision" : "Accuracy",
                             progress.accuracy(of: pool).map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                        Spacer()
                        stat(language == .danish ? "Set" : "Seen", "\(progress.seenCount(of: pool)) / \(pool.count)")
                    }
                    MasteryBar(value: progress.mastery(of: pool))
                }
                .card()

                Picker("Level", selection: $level) {
                    Text(language == .danish ? "Blandet" : "Mixed").tag(0)
                    Text("Level 1").tag(1)
                    Text("Level 2").tag(2)
                }
                .pickerStyle(.segmented)

                NavigationLink {
                    QuizView(questions: builder.practice(topic: topic.id, level: level, count: progress.settings.sessionLength),
                             title: topic.title(in: language))
                } label: {
                    Text(language == .danish ? "Øv dette emne" : "Practise this topic")
                }
                .buttonStyle(PrimaryButtonStyle())

                let due = progress.dueQuestions(from: pool)
                if !due.isEmpty {
                    NavigationLink {
                        QuizView(questions: due.shuffled(), title: topic.title(in: language))
                    } label: {
                        Text(language == .danish ? "Gennemgå \(due.count) fejl" : "Review \(due.count) due")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if topic.id == "verbs" {
                    NavigationLink {
                        QuizView(questions: builder.verbDrill(count: progress.settings.sessionLength, irregularOnly: true),
                                 title: language == .danish ? "Uregelmæssige verber" : "Irregular verbs")
                    } label: {
                        Text(language == .danish ? "Bøj uregelmæssige verber" : "Drill irregular verb forms")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(topic.title(in: language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { level = progress.settings.preferredLevel }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title3, design: .serif))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
