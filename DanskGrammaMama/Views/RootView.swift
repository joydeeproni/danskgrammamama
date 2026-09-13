import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Practice", systemImage: "square.and.pencil") }
            NavigationStack { TopicsView() }
                .tabItem { Label("Topics", systemImage: "list.bullet") }
            NavigationStack { ExamView() }
                .tabItem { Label("Exam", systemImage: "timer") }
            NavigationStack { WriteView() }
                .tabItem { Label("Write", systemImage: "text.alignleft") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// MARK: - Shared style helpers

enum Style {
    static let corner: CGFloat = 12
    static let correct = Color.green
    static let wrong = Color.red
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct MasteryBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill))
                Capsule().fill(Color.accentColor).frame(width: max(0, geo.size.width * value))
            }
        }
        .frame(height: 4)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: Style.corner))
            .foregroundStyle(.white)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
            .overlay(RoundedRectangle(cornerRadius: Style.corner).strokeBorder(Color.accentColor.opacity(configuration.isPressed ? 0.4 : 0.9)))
            .foregroundStyle(Color.accentColor)
    }
}
