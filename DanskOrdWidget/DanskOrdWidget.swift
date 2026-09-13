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

struct DanskOrdWidgetView: View {
    var entry: WordEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack(spacing: 4) {
                Image(systemName: "character.book.closed").font(.caption2)
                Text(entry.isStarter ? "Dansk" : "Dine ord").font(.caption2.weight(.semibold))
                Spacer()
                if entry.total > 0 && !entry.isStarter {
                    Text("\(entry.total)").font(.caption2.monospacedDigit())
                }
            }
            .foregroundStyle(.secondary)

            Text(entry.card.word)
                .font(.system(size: family == .systemSmall ? 22 : 28, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            if entry.revealed {
                Text(entry.card.meaning)
                    .font(family == .systemSmall ? .caption : .subheadline)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(family == .systemSmall ? 3 : 2)
                if family != .systemSmall, let p = entry.card.paradigm, !p.isEmpty {
                    Text(p).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                if family == .systemLarge {
                    Text(entry.card.context)
                        .font(.footnote).italic().foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            } else if !entry.card.subtitle.isEmpty {
                Text(entry.card.subtitle)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(intent: RevealMeaningIntent(cardID: entry.card.id)) {
                Text(entry.revealed ? "Skjul" : "Vis betydning")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
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
