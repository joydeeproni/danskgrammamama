import SwiftUI

// MARK: - Paper surface

/// A sheet of paper: hairline edge and layered soft shadows. In dark mode the shadows
/// turn black and deep, and a faint top highlight separates the card from the table.
struct PaperSurface: ViewModifier {
    var radius: CGFloat = Theme.cardRadius
    var fill: Color = Theme.paper
    var lifted = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = scheme == .dark
        content
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Theme.edge, lineWidth: 1))
            .overlay(alignment: .top) {
                if dark {
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(lifted ? 0.10 : 0.06), .clear],
                                                      startPoint: .top, endPoint: .center), lineWidth: 1)
                }
            }
            .shadow(color: dark ? .clear : Paper.shade.opacity(0.07), radius: 1, y: 1)
            .shadow(color: dark ? .clear : Paper.shade.opacity(lifted ? 0.22 : 0.14),
                    radius: lifted ? 13 : 8, y: lifted ? 12 : 6)
            .shadow(color: dark ? .black.opacity(lifted ? 0.85 : 0.7) : Paper.shade.opacity(lifted ? 0.32 : 0.24),
                    radius: lifted ? 35 : 22, y: lifted ? 30 : 16)
    }
}

enum Paper {
    /// Shadows are tinted with the ink colour rather than flat black.
    static let shade = Color(red: 20 / 255, green: 26 / 255, blue: 23 / 255)
}

extension View {
    func paper(radius: CGFloat = Theme.cardRadius, fill: Color = Theme.paper, lifted: Bool = false) -> some View {
        modifier(PaperSurface(radius: radius, fill: fill, lifted: lifted))
    }
}

// MARK: - Uneven stack

/// Draws `sheets` sheets of paper under the content, like a real pile: each sheet sits a
/// little lower, nudged by a seeded random amount, and from the second sheet down about
/// one in five sticks out further. Sheets are only ever moved, never rotated.
struct PaperStack<Content: View>: View {
    var sheets: Int
    var seed: Int = 1
    var step: CGFloat = 3
    var radius: CGFloat = Theme.cardRadius
    /// Squeeze tall piles into this many points so they never get absurd.
    var maxDepth: CGFloat = 42
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme

    private var visible: Int { max(0, min(sheets, 16)) }
    private var spacing: CGFloat { visible == 0 ? step : min(step, maxDepth / CGFloat(visible)) }

    var body: some View {
        content
            .background(alignment: .top) {
                ZStack {
                    ForEach((0..<visible).reversed(), id: \.self) { i in
                        let o = offset(for: i)
                        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                        let bottom = i == visible - 1
                        shape
                            .fill(i.isMultiple(of: 2) ? Theme.sheet : Theme.sheetAlt)
                            .overlay(shape.strokeBorder(Theme.edge, lineWidth: 1))
                            .shadow(color: Theme.sheetLine, radius: 0, y: 1)
                            .shadow(color: bottom ? shadow : .clear, radius: bottom ? 22 : 0, y: bottom ? 16 : 0)
                            .offset(x: o.width, y: o.height)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: visible)
    }

    private var shadow: Color {
        scheme == .dark ? .black.opacity(0.7) : Paper.shade.opacity(0.2)
    }

    /// Sheet `i` counts down from the card on top (0 is directly under it).
    private func offset(for i: Int) -> CGSize {
        let sign: CGFloat = unit(i, 0) < 0.5 ? -1 : 1
        var x = sign * (0.5 + unit(i, 1) * 2)
        let base = CGFloat(i + 1) * spacing
        var y = max(base + (unit(i, 2) * 2 - 1) * 1.2, CGFloat(i) * spacing + 0.6)
        if i >= 1, unit(i, 3) < 0.22 {
            let amount = 4 + unit(i, 4) * 5
            switch Int(unit(i, 5) * 3) {
            case 0: x -= amount
            case 1: x += amount
            default: y += amount
            }
        }
        return CGSize(width: x, height: y)
    }

    /// Deterministic noise in 0..<1, so the pile does not shuffle on every redraw.
    private func unit(_ i: Int, _ k: Int) -> CGFloat {
        var z = UInt64(bitPattern: Int64(seed &* 0x9E37 &+ i &* 0x85EB &+ k &* 0xC2B2 &+ 0x165667B1))
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return CGFloat(z % 10_000) / 10_000
    }
}

// MARK: - Buttons

/// The one strong button on a card.
struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(17, .semibold, relativeTo: .headline))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 16)
            .background(Theme.buttonFill.opacity(isEnabled ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .foregroundStyle(Theme.buttonText)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A quieter companion to `InkButtonStyle`.
struct PaperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(17, .medium, relativeTo: .headline))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(Theme.edge, lineWidth: 1))
            .foregroundStyle(Theme.ink)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Press feedback for anything card-shaped.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Round icon button used in headers.
struct IconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Small data marks

/// Nine vertical bars, one per topic; the weakest is red.
struct TopicBars: View {
    let values: [TopicReadiness]
    var weakest: String?
    var height: CGFloat = 34
    var barWidth: CGFloat = 7

    var body: some View {
        HStack(alignment: .bottom, spacing: barWidth * 0.6) {
            ForEach(values) { t in
                ZStack(alignment: .bottom) {
                    Capsule().fill(Theme.rule)
                    Capsule()
                        .fill(t.id == weakest ? Theme.red : Theme.ink.opacity(0.78))
                        .frame(height: max(barWidth, height * t.value))
                }
                .frame(width: barWidth, height: height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(values.map { "\($0.topic.titleDa) \($0.percent) procent" }.joined(separator: ", "))
    }
}

/// A thin horizontal readiness bar.
struct ReadinessBar: View {
    let value: Double
    var tint: Color = Theme.ink
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.rule)
                Capsule().fill(tint)
                    .frame(width: max(height, min(1, max(0, value)) * geo.size.width))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: value)
    }
}

/// The last seven days as dots, today last. Filled means practised.
struct WeekDots: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        HStack(spacing: 5) {
            ForEach((0..<7).reversed(), id: \.self) { back in
                let day = Calendar.current.date(byAdding: .day, value: -back, to: .now) ?? .now
                Circle()
                    .strokeBorder(Theme.ink.opacity(0.75), lineWidth: 1.2)
                    .background(Circle().fill(progress.practised(on: day) ? Theme.ink.opacity(0.75) : .clear))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The dotted line that separates the two halves of a card, like a tear-off.
struct PerforatedRule: View {
    var body: some View {
        Line()
            .stroke(Theme.edge, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 5]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

/// The red "PD3" stamp, as on the app icon.
struct PD3Stamp: View {
    var size: CGFloat = 26

    var body: some View {
        Text("PD3")
            .font(.ui(size * 0.82, .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.22)
            .padding(.vertical, size * 0.02)
            .background(Color(light: 0xC8102E, dark: 0xD7263F),
                        in: RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
    }
}

enum Haptics {
    static func verdict(correct: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
    }
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

/// Wraps a tapped word so it can drive a sheet(item:).
struct IdentifiableWord: Identifiable {
    let value: String
    var id: String { value }
}
