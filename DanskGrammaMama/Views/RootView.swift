import SwiftUI

/// No tab bar: the app is one table. Today is the top card; topics, words and this
/// week's paper are small stacks beside it, pushed onto the same navigation stack.
struct RootView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var path: [Route] = []
    #if DEBUG
    @State private var debugWord: IdentifiableWord?
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            TodayView()
                .routeDestinations()
        }
        #if DEBUG
        .onAppear {
            path = DebugLaunch.initialPath(progress: progress)
            debugWord = UserDefaults.standard.string(forKey: "word").map(IdentifiableWord.init)
        }
        .sheet(item: $debugWord) { WordSheet(word: $0.value, context: "Mange danske arbejdspladser blev tvunget til at indføre hjemmearbejde.") }
        #endif
        .tint(Theme.ink)
        .font(.ui(17))
        .preferredColorScheme((progress.settings.appearance ?? .system).colorScheme)
    }
}

/// Kept for the few places that still name the verdict colours directly.
enum Style {
    static let correct = Theme.correct
    static let wrong = Theme.red
}

#if DEBUG
/// Opens a screen straight from a launch argument, for screenshots:
/// `-screen daily|topics|topic|words|week|exam` and `-answer wrong|right`.
enum DebugLaunch {
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }
    static var answer: String? { UserDefaults.standard.string(forKey: "answer") }

    static func initialPath(progress: ProgressStore) -> [Route] {
        switch screen {
        case "daily": return [.daily(DailyPlan(size: 15, reviews: 0, weakTopic: nil, weak: 0, fresh: 15, isBonus: false))]
        case "topics": return [.topics]
        case "topic": return [.topics, .topic("prepositions")]
        case "words": return [.words]
        case "week": return [.week]
        case "exam": return [.week, .exam(minutes: progress.settings.examMinutes)]
        case "reading": return [.topics, .topic(Topic.readingID)]
        case "readingset": return [.readingSet(nil)]
        case "vocab-words": return [.words, .vocab(.words)]
        case "vocab-phrases": return [.words, .vocab(.phrases)]
        case "vocab-fixed": return [.words, .vocab(.fixed)]
        case "vocab-udtryk": return [.words, .vocab(.udtryk)]
        default: return []
        }
    }
}
#endif
