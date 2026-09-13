import Foundation

/// Assembles quiz sessions: due reviews first, then unseen items weighted
/// toward weak topics, then older items the learner has missed before.
struct SessionBuilder {
    let content: ContentStore
    let progress: ProgressStore

    func practice(topic: String?, level: Int, count: Int) -> [Question] {
        let pool = content.questions(topic: topic, level: level)
        guard !pool.isEmpty else { return [] }

        var chosen: [Question] = []
        var used = Set<String>()

        let due = progress.dueQuestions(from: pool)
        for q in due.prefix(max(1, count / 2)) {
            chosen.append(q); used.insert(q.id)
        }

        let masteryByTopic = Dictionary(uniqueKeysWithValues: Topic.all.map {
            ($0.id, progress.mastery(of: content.byTopic[$0.id] ?? []))
        })

        // Unseen items: shuffle, then favour weak topics when mixing topics.
        var unseen = pool.filter { !used.contains($0.id) && progress.isUnseen($0) }.shuffled()
        if topic == nil {
            unseen.sort { a, b in
                let ma = masteryByTopic[a.topic] ?? 0, mb = masteryByTopic[b.topic] ?? 0
                // Bucket so randomness survives within similar mastery.
                return Int(ma * 4) < Int(mb * 4)
            }
        }
        for q in unseen where chosen.count < count {
            chosen.append(q); used.insert(q.id)
        }

        // Fallback: seen items, misses first, oldest first.
        if chosen.count < count {
            let rest = pool.filter { !used.contains($0.id) }.sorted { a, b in
                let ra = progress.record(for: a.id), rb = progress.record(for: b.id)
                if ra?.lastCorrect != rb?.lastCorrect { return ra?.lastCorrect == false }
                return (ra?.lastSeen ?? .distantPast) < (rb?.lastSeen ?? .distantPast)
            }
            for q in rest where chosen.count < count {
                chosen.append(q); used.insert(q.id)
            }
        }
        return chosen.shuffled()
    }

    func review(count: Int) -> [Question] {
        Array(progress.dueQuestions(from: content.questions).prefix(count)).shuffled()
    }

    /// PD3-style mixed paper: ~2 per topic, mostly level 2, unseen preferred.
    func exam(count: Int = 20) -> [Question] {
        var chosen: [Question] = []
        var used = Set<String>()
        let perTopic = max(1, count / Topic.all.count)

        func pick(from pool: [Question], _ n: Int) {
            let ranked = pool.filter { !used.contains($0.id) }.shuffled().sorted { a, b in
                let ua = progress.isUnseen(a) ? 0 : 1, ub = progress.isUnseen(b) ? 0 : 1
                if ua != ub { return ua < ub }
                return a.level > b.level
            }
            for q in ranked.prefix(n) { chosen.append(q); used.insert(q.id) }
        }

        for topic in Topic.all.shuffled() {
            let pool = content.byTopic[topic.id] ?? []
            let hard = pool.filter { $0.level == 2 }
            pick(from: hard.isEmpty ? pool : hard, perTopic)
        }
        if chosen.count < count {
            pick(from: content.questions, count - chosen.count)
        }
        return Array(chosen.prefix(count)).shuffled()
    }

    func verbDrill(count: Int, irregularOnly: Bool) -> [Question] {
        VerbDrill.questions(from: content.verbs, count: count, irregularOnly: irregularOnly)
    }
}
