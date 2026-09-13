import Foundation
import Observation

/// Loads the bundled question bank, cloze texts, topic guides and verb list once at launch.
@Observable
final class ContentStore {
    private(set) var questions: [Question] = []
    private(set) var guides: [String: TopicGuide] = [:]
    private(set) var verbs: [Verb] = []
    private(set) var loadErrors: [String] = []

    init() {
        load()
    }

    var byTopic: [String: [Question]] {
        Dictionary(grouping: questions, by: \.topic)
    }

    func questions(topic: String?, level: Int) -> [Question] {
        questions.filter { q in
            (topic == nil || q.topic == topic!) && (level == 0 || q.level == level)
        }
    }

    func guide(for topic: String) -> TopicGuide? { guides[topic] }

    private func load() {
        let decoder = JSONDecoder()
        var loaded: [Question] = []
        for topic in Topic.all {
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
