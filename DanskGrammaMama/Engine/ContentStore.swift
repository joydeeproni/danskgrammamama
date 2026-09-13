import Foundation
import Observation

/// Loads the bundled question bank and verb list once at launch.
@Observable
final class ContentStore {
    private(set) var questions: [Question] = []
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

    func question(id: String) -> Question? {
        questions.first { $0.id == id }
    }

    private func load() {
        let decoder = JSONDecoder()
        var loaded: [Question] = []
        for topic in Topic.all {
            guard let url = Bundle.main.url(forResource: topic.id, withExtension: "json") else {
                loadErrors.append("Missing \(topic.id).json")
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                let file = try decoder.decode(TopicFile.self, from: data)
                loaded.append(contentsOf: file.questions)
            } catch {
                loadErrors.append("\(topic.id).json: \(error.localizedDescription)")
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
