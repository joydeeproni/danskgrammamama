import Foundation

/// "How to crack this topic": one rule and one exam trick per section, plus classic traps.
struct TopicGuide: Decodable, Hashable {
    struct Example: Decodable, Hashable {
        let da: String   // key word wrapped in **…**
        let en: String
    }

    struct Section: Decodable, Hashable, Identifiable {
        let title: Explanation
        let rule: Explanation
        let hack: Explanation
        let examples: [Example]
        var id: String { title.en }
    }

    let topic: String
    let intro: Explanation
    let sections: [Section]
    let traps: [Explanation]
}
