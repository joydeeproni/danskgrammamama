import SwiftUI

/// Every screen that can be pushed from the table.
///
/// Links push one of these values and the NavigationStack builds the screen from it.
/// A view-destination NavigationLink would be rebuilt every time the presenting screen
/// re-renders (which recording an answer causes), resetting the session's state.
enum Route: Hashable {
    case daily(DailyPlan)
    case practice(topic: String?, level: Int, count: Int)
    case review(topic: String?, count: Int)
    case verbDrill(irregularOnly: Bool, count: Int)
    case exam(minutes: Int)
    case topics
    case topic(String)
    case words
    case week
    case write
}

/// Registers the destinations for `Route` on the NavigationStack's root.
struct RouteDestinations: ViewModifier {
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress

    func body(content view: Content) -> some View {
        view.navigationDestination(for: Route.self) { route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        let builder = SessionBuilder(content: content, progress: progress)
        switch route {
        case .daily(let plan):
            let set = builder.daily(plan)
            DeckSessionView(questions: set.questions, kinds: set.kinds, title: "Dagens sæt")
        case .practice(let topic, let level, let count):
            DeckSessionView(questions: builder.practice(topic: topic, level: level, count: count),
                            title: topic.flatMap { Topic.byID($0)?.titleDa } ?? "Øvelse")
        case .review(let topic, let count):
            let pool = topic.map { content.byTopic[$0] ?? [] } ?? content.questions
            DeckSessionView(questions: Array(progress.dueQuestions(from: pool).prefix(count)).shuffled(),
                            kinds: [:], title: "Gentagelse", allReviews: true)
        case .verbDrill(let irregularOnly, let count):
            DeckSessionView(questions: builder.verbDrill(count: count, irregularOnly: irregularOnly),
                            title: irregularOnly ? "Uregelmæssige verber" : "Verber")
        case .exam(let minutes):
            DeckSessionView(questions: builder.exam(count: 20), title: "Prøvesæt", mode: .exam(minutes: minutes))
        case .topics:
            TopicsView()
        case .topic(let id):
            if let topic = Topic.byID(id) { TopicPageView(topic: topic) }
        case .words:
            WordsView()
        case .week:
            WeekView()
        case .write:
            WriteView()
        }
    }
}

extension View {
    func routeDestinations() -> some View { modifier(RouteDestinations()) }

    /// The plain table behind every screen, with a quiet navigation bar.
    func tableBackground() -> some View {
        background(Theme.table.ignoresSafeArea())
            .toolbarBackground(Theme.table, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
