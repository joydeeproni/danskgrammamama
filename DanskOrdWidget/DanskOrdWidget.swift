import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Reveal button

/// Flips one card on the home screen. The revealed id is kept in the shared
/// defaults so the state survives the timeline reload the button triggers.
struct RevealMeaningIntent: AppIntent {
    static var title: LocalizedStringResource = "Show the meaning"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Card")
    var cardID: String

    init() {}
    init(cardID: String) { self.cardID = cardID }

    func perform() async throws -> some IntentResult {
        let key = "revealed"
        let defaults = SharedFlashcards.defaults
        if defaults.string(forKey: key) == cardID {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(cardID, forKey: key)
        }
        return .result()
    }
}

// MARK: - Timeline

struct WordEntry: TimelineEntry {
    let date: Date
    let card: SharedFlashcards.Card
    let revealed: Bool
    let total: Int
    let isStarter: Bool
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, card: SharedFlashcards.starterDeck[0], revealed: false,
                  total: SharedFlashcards.starterDeck.count, isStarter: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(entry(at: .now))
    }

    /// One entry per hour for the next day, so a new word appears every hour.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let calendar = Calendar.current
        let start = calendar.date(bySetting: .minute, value: 0, of: .now) ?? .now
        var entries: [WordEntry] = []
        for hour in 0..<24 {
            guard let date = calendar.date(byAdding: .hour, value: hour, to: start) else { continue }
            entries.append(entry(at: date))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> WordEntry {
        let cards = SharedFlashcards.load()
        guard !cards.isEmpty else {
            return WordEntry(date: date, card: SharedFlashcards.starterDeck[0], revealed: false,
                             total: 0, isStarter: true)
        }
        // Hours since the epoch pick the card, so it changes on the hour and is
        // the same across every widget instance.
        let hours = Int(date.timeIntervalSince1970 / 3600)
        let card = cards[abs(hours) % cards.count]
        let revealed = SharedFlashcards.defaults.string(forKey: "revealed") == card.id
        return WordEntry(date: date, card: card, revealed: revealed,
                         total: cards.count, isStarter: SharedFlashcards.isUsingStarterDeck)
    }
}

// MARK: - Views

/// The app's "Stak" look on the home screen: paper, ink, one PD3 red, system fonts.
private enum Paper {
    static let surface = Color(light: 0xFCFCFA, dark: 0x1C1C1E)
    static let ink = Color(light: 0x1B211F, dark: 0xF2F2F7)
    static let pencil = Color(light: 0x5C635F, dark: 0x98989F)
    static let rule = Color(light: 0x1B211F, dark: 0xF2F2F7, alpha: 0.14)
    static let red = Color(light: 0xC8102E, dark: 0xD7263F)
    static let buttonText = Color(light: 0xFFFFFF, dark: 0x000000)
}

private extension Color {
    init(light: UInt32, dark: UInt32, alpha: CGFloat = 1) {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

struct DanskOrdWidgetView: View {
    var entry: WordEntry
    @Environment(\.widgetFamily) private var family

    private var small: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 4 : 6) {
            HStack(spacing: 6) {
                Text("PD3")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Paper.red, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text(entry.isStarter ? "Dagens ord" : "Dine ord")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.pencil)
                Spacer(minLength: 0)
                if entry.total > 0 && !entry.isStarter {
                    Text("\(entry.total)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Paper.pencil)
                }
            }
            .padding(.bottom, small ? 2 : 4)

            Text(entry.card.word)
                .font(.system(size: small ? 24 : 30, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            if entry.revealed {
                Text(entry.card.meaning)
                    .font(.system(size: small ? 14 : 16, weight: .bold))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(small ? 3 : 2)
                if !small, let p = entry.card.paradigm, !p.isEmpty {
                    Text(p)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(Paper.pencil)
                        .lineLimit(1)
                }
                if family == .systemLarge, !entry.card.context.isEmpty {
                    Text(entry.card.context)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(Paper.pencil)
                        .lineLimit(4)
                        .padding(.top, 4)
                }
            } else if !entry.card.subtitle.isEmpty {
                Text(entry.card.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.pencil)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Line()
                .stroke(Paper.rule, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 4.5]))
                .frame(height: 1)
                .padding(.bottom, small ? 6 : 8)

            Button(intent: RevealMeaningIntent(cardID: entry.card.id)) {
                Text(entry.revealed ? "Skjul" : "Vis betydning")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paper.buttonText)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(Paper.ink, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Paper.surface, for: .widget)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

// MARK: - Widget

struct DanskOrdWidget: Widget {
    let kind = "DanskOrdWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            DanskOrdWidgetView(entry: entry)
        }
        .configurationDisplayName("Dagens ord")
        .description("Et ord fra din ordbog. Tryk for at se betydningen. Nyt ord hver time.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct DanskOrdWidgetBundle: WidgetBundle {
    var body: some Widget {
        DanskOrdWidget()
    }
}
