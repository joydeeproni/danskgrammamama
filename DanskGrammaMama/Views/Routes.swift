import SwiftUI

/// Every screen a session link can push.
///
/// Links push one of these values and the NavigationStack builds the screen from it.
/// A view-destination NavigationLink would be rebuilt every time the presenting screen
/// re-renders (which recording an answer causes), resetting the session's state.
enum QuizRoute: Hashable {
    case practice(topic: String?, level: Int, count: Int)
    case review(topic: String?, count: Int)
    case verbDrill(irregularOnly: Bool, count: Int)
    case exam(minutes: Int)
    case flashcards
    case topic(String)
    case guide(String)
}

/// Registers the destinations for `QuizRoute` on a NavigationStack's root.
struct QuizRouteDestinations: ViewModifier {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @Environment(FlashcardStore.self) private var flashcards

    func body(content view: Content) -> some View {
        view.navigationDestination(for: QuizRoute.self) { route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func destination(for route: QuizRoute) -> some View {
        let builder = SessionBuilder(content: content, progress: progress)
        let language = progress.settings.explanationLanguage
        switch route {
        case .practice(let topic, let level, let count):
            QuizView(questions: builder.practice(topic: topic, level: level, count: count),
                     title: topic.flatMap { Topic.byID($0)?.title(in: language) }
                        ?? (language == .danish ? "Øvelse" : "Practice"))
        case .review(let topic, let count):
            let pool = topic.map { content.byTopic[$0] ?? [] } ?? content.questions
            QuizView(questions: Array(progress.dueQuestions(from: pool).prefix(count)).shuffled(),
                     title: language == .danish ? "Gennemgang" : "Review")
        case .verbDrill(let irregularOnly, let count):
            QuizView(questions: builder.verbDrill(count: count, irregularOnly: irregularOnly),
                     title: irregularOnly
                        ? (language == .danish ? "Uregelmæssige verber" : "Irregular verbs")
                        : (language == .danish ? "Verber" : "Verb drill"))
        case .exam(let minutes):
            ExamRunView(questions: builder.exam(count: 20), minutes: minutes)
        case .flashcards:
            FlashcardReviewView(cards: flashcards.reviewOrder)
        case .topic(let id):
            if let topic = Topic.byID(id) { TopicDetailView(topic: topic) }
        case .guide(let id):
            if let topic = Topic.byID(id), let guide = content.guide(for: id) {
                TopicGuideView(topic: topic, guide: guide)
            }
        }
    }
}

extension View {
    func quizRouteDestinations() -> some View { modifier(QuizRouteDestinations()) }
}
