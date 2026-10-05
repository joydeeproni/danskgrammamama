import Foundation

/// How ready the learner is for one topic: the share of its questions mastered.
struct TopicReadiness: Identifiable, Hashable {
    let topic: Topic
    let value: Double
    let seen: Int
    var id: String { topic.id }
    var percent: Int { Int((value * 100).rounded()) }
}

extension ProgressStore {
    func readiness(content: ContentStore) -> [TopicReadiness] {
        let byTopic = content.byTopic
        return Topic.all.map { topic in
            let pool = byTopic[topic.id] ?? []
            return TopicReadiness(topic: topic, value: mastery(of: pool), seen: seenCount(of: pool))
        }
    }

    /// Exam readiness: every topic weighs the same, as on the paper.
    func overallReadiness(content: ContentStore) -> Double {
        let all = readiness(content: content)
        guard !all.isEmpty else { return 0 }
        return all.map(\.value).reduce(0, +) / Double(all.count)
    }

    /// The lowest topic once there is enough data to judge it.
    func weakestTopic(content: ContentStore) -> TopicReadiness? {
        readiness(content: content).filter { $0.seen >= 3 }.min { $0.value < $1.value }
    }
}

/// What today's set will contain, computed without shuffling so it is stable on screen.
struct DailyPlan: Hashable {
    let size: Int
    let reviews: Int
    let weakTopic: Topic?
    let weak: Int
    let fresh: Int
    /// The daily goal is already met; this is an extra round.
    let isBonus: Bool

    var minutes: Int { max(1, Int((Double(size) * 0.8).rounded())) }
}

/// Where a question in today's set came from. Shown on the card.
enum DailyKind: Hashable {
    case review, weak, fresh
}

struct DailySet {
    let questions: [Question]
    let kinds: [String: DailyKind]
}

extension SessionBuilder {
    func dailyPlan() -> DailyPlan {
        let settings = progress.settings
        let remaining = settings.dailyGoal - progress.todayCount
        let isBonus = remaining <= 0
        let size = isBonus ? settings.sessionLength : remaining

        let pool = content.questions(topic: nil, level: settings.preferredLevel)
        let due = progress.dueQuestions(from: pool)
        let reviews = min(due.count, (size + 1) / 2)

        let weakTopic = progress.weakestTopic(content: content)?.topic
        var weak = 0
        if let weakTopic {
            let dueIDs = Set(due.prefix(reviews).map(\.id))
            let available = pool.filter { $0.topic == weakTopic.id && !dueIDs.contains($0.id) }.count
            weak = min(available, (size - reviews) * 2 / 3)
        }
        return DailyPlan(size: size, reviews: reviews, weakTopic: weakTopic, weak: weak,
                         fresh: max(0, size - reviews - weak), isBonus: isBonus)
    }

    /// Builds the questions for a plan: due reviews, then the weakest topic, then new items.
    func daily(_ plan: DailyPlan) -> DailySet {
        let pool = content.questions(topic: nil, level: progress.settings.preferredLevel)
        var chosen: [Question] = []
        var kinds: [String: DailyKind] = [:]
        var used = Set<String>()

        func take(_ candidates: [Question], _ n: Int, as kind: DailyKind) {
            var taken = 0
            for q in candidates where taken < n && !used.contains(q.id) {
                chosen.append(q); used.insert(q.id); kinds[q.id] = kind; taken += 1
            }
        }

        take(progress.dueQuestions(from: pool), plan.reviews, as: .review)

        if let weakTopic = plan.weakTopic {
            take(freshFirst(pool.filter { $0.topic == weakTopic.id }), plan.weak, as: .weak)
        }

        let mastery = Dictionary(uniqueKeysWithValues: Topic.all.map {
            ($0.id, progress.mastery(of: content.byTopic[$0.id] ?? []))
        })
        // Unseen items from weaker topics first. Bucketing keeps some randomness between
        // topics at similar levels.
        let bucket = { (q: Question) in Int((mastery[q.topic] ?? 0) * 4) }
        let unseen = pool.filter { progress.isUnseen($0) }.shuffled().sorted { bucket($0) < bucket($1) }
        let seen = freshFirst(pool).filter { !progress.isUnseen($0) }
        take(unseen + seen, plan.size - chosen.count, as: .fresh)

        return DailySet(questions: chosen.shuffled(), kinds: kinds)
    }

    /// Unseen items first (shuffled), then earlier misses, then the oldest seen.
    private func freshFirst(_ pool: [Question]) -> [Question] {
        let unseen = pool.filter { progress.isUnseen($0) }.shuffled()
        let seen = pool.filter { !progress.isUnseen($0) }.sorted { a, b in
            let ra = progress.record(for: a.id), rb = progress.record(for: b.id)
            if ra?.lastCorrect != rb?.lastCorrect { return ra?.lastCorrect == false }
            return (ra?.lastSeen ?? .distantPast) < (rb?.lastSeen ?? .distantPast)
        }
        return unseen + seen
    }
}
