import Foundation
import Observation

/// Loads the bundled question bank, cloze texts, topic guides and verb list once at launch.
@Observable
final class ContentStore {
    private(set) var questions: [Question] = []
    private(set) var guides: [String: TopicGuide] = [:]
    private(set) var verbs: [Verb] = []
    private(set) var loadErrors: [String] = []
    private(set) var readingSets: [ReadingSet] = []

    init() {
        load()
    }

    var byTopic: [String: [Question]] {
        Dictionary(grouping: questions, by: \.topic)
    }

    /// Questions for a topic, or for all grammar topics when `topic` is nil. Reading
    /// tasks are long, so they only come when asked for by topic.
    func questions(topic: String?, level: Int) -> [Question] {
        questions.filter { q in
            (topic.map { q.topic == $0 } ?? (q.topic != Topic.readingID)) && (level == 0 || q.level == level)
        }
    }

    /// One whole reading set (2A, 2B, 3) in exam order.
    func readingSet(_ id: String) -> [Question] {
        questions.filter { $0.reading != nil && $0.id.hasPrefix("reading-\(id)-") }
            .sorted { $0.id < $1.id }
    }

    var readingSetIDs: [String] { readingSets.map(\.id) }

    func guide(for topic: String) -> TopicGuide? { guides[topic] }

    private func load() {
        let decoder = JSONDecoder()
        var loaded: [Question] = []
        for topic in Topic.all where topic.id != Topic.readingID {
            for name in [topic.id, "cloze_\(topic.id)"] {
                guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
                    if name == topic.id { loadErrors.append("Missing \(name).json") }
                    continue
                }
                do {
                    let file = try decoder.decode(TopicFile.self, from: try Data(contentsOf: url))
                    loaded.append(contentsOf: file.questions.filter { !$0.blanks.isEmpty })
                } catch {
                    loadErrors.append("\(name).json: \(error.localizedDescription)")
                }
            }
            if let url = Bundle.main.url(forResource: "guide_\(topic.id)", withExtension: "json") {
                do {
                    guides[topic.id] = try decoder.decode(TopicGuide.self, from: try Data(contentsOf: url))
                } catch {
                    loadErrors.append("guide_\(topic.id).json: \(error.localizedDescription)")
                }
            }
        }
        if let url = Bundle.main.url(forResource: "guide_\(Topic.readingID)", withExtension: "json") {
            do {
                guides[Topic.readingID] = try decoder.decode(TopicGuide.self, from: try Data(contentsOf: url))
            } catch {
                loadErrors.append("guide_reading.json: \(error.localizedDescription)")
            }
        }
        if let url = Bundle.main.url(forResource: "reading", withExtension: "json") {
            do {
                readingSets = try decoder.decode(ReadingFile.self, from: try Data(contentsOf: url)).sets
                loaded.append(contentsOf: readingSets.flatMap(\.questions))
            } catch {
                loadErrors.append("reading.json: \(error.localizedDescription)")
            }
        }
        questions = loaded

        if let url = Bundle.main.url(forResource: "verbs_list", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? decoder.decode(VerbFile.self, from: data) {
            verbs = file.verbs
        } else {
            loadErrors.append("Missing verbs_list.json")
        }
    }
}
