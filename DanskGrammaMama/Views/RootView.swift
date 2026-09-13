import SwiftUI

struct RootView: View {
    @Environment(ProgressStore.self) private var progress
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label(language == .danish ? "Øv" : "Practice", systemImage: "square.and.pencil") }
            NavigationStack { TopicsView() }
                .tabItem { Label(language == .danish ? "Emner" : "Topics", systemImage: "list.bullet") }
            NavigationStack { FlashcardsView() }
                .tabItem { Label(language == .danish ? "Ord" : "Words", systemImage: "character.book.closed") }
            NavigationStack { ExamView() }
                .tabItem { Label(language == .danish ? "Prøve" : "Exam", systemImage: "timer") }
            NavigationStack { WriteView() }
                .tabItem { Label(language == .danish ? "Skriv" : "Write", systemImage: "text.alignleft") }
        }
    }
}

// MARK: - Shared style

enum Style {
    static let corner: CGFloat = 16
    static let correct = Color(red: 0.13, green: 0.60, blue: 0.35)
    static let wrong = Color(red: 0.80, green: 0.24, blue: 0.24)
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardBackground(padding: padding)) }
}

/// Thin capsule progress bar used at the top of a session.
struct ProgressBar: View {
    let value: Double
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill))
                Capsule().fill(Color.accentColor)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .animation(.snappy(duration: 0.25), value: value)
            }
        }
        .frame(height: height)
    }
}

struct MasteryBar: View {
    let value: Double
    var body: some View {
        ProgressBar(value: value, height: 4)
    }
}

/// A ring, used for the daily goal.
struct GoalRing: View {
    let value: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color(.systemFill), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: value)
        }
        .frame(width: size, height: size)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: Style.corner))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
            .overlay(RoundedRectangle(cornerRadius: Style.corner)
                .strokeBorder(Color(.separator).opacity(configuration.isPressed ? 0.8 : 0.5)))
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
