import SwiftUI

/// The word diary: everything tapped and kept, plus a tap-to-flip review.
struct FlashcardsView: View {
    @Environment(FlashcardStore.self) private var flashcards
    @Environment(ProgressStore.self) private var progress
    @State private var searchText = ""
    @State private var reviewing = false

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    private var filtered: [Flashcard] {
        guard !searchText.isEmpty else { return flashcards.cards }
        let q = searchText.lowercased()
        return flashcards.cards.filter { $0.word.lowercased().contains(q) || $0.meaning.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if flashcards.cards.isEmpty {
                ContentUnavailableView {
                    Label(language == .danish ? "Ingen ord endnu" : "No words yet", systemImage: "character.book.closed")
                } description: {
                    Text(language == .danish
                         ? "Tryk på et understreget ord i en øvelse for at se betydningen. Ordet bliver gemt her og vist i widgetten."
                         : "Tap an underlined word in any exercise to see what it means. The word is kept here and shown in the widget.")
                }
            } else {
                List {
                    Section {
                        Button {
                            reviewing = true
                        } label: {
                            HStack {
                                Label(language == .danish ? "Gennemgå kort" : "Review cards", systemImage: "rectangle.on.rectangle.angled")
                                Spacer()
                                Text("\(flashcards.cards.count)").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        ForEach(filtered) { card in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(card.word).font(.system(.body, design: .serif).weight(.semibold))
                                    Spacer()
                                    if card.timesShown > 0 {
                                        Text("\(card.timesKnown)/\(card.timesShown)")
                                            .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                                    }
                                }
                                Text(card.meaning).font(.subheadline)
                                if !card.subtitle.isEmpty {
                                    Text(card.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            for i in indexSet { flashcards.remove(filtered[i]) }
                        }
                    } header: {
                        Text(language == .danish ? "Ordbog" : "Word diary")
                    }
                }
                .searchable(text: $searchText, prompt: language == .danish ? "Søg" : "Search")
            }
        }
        .navigationTitle(language == .danish ? "Ord" : "Words")
        .fullScreenCover(isPresented: $reviewing) {
            FlashcardReviewView(cards: flashcards.reviewOrder)
        }
    }
}

/// Tap to flip, then say whether you knew it.
struct FlashcardReviewView: View {
    let cards: [Flashcard]

    @Environment(FlashcardStore.self) private var flashcards
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var flipped = false
    @State private var known = 0

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var card: Flashcard? { index < cards.count ? cards[index] : nil }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(language == .danish ? "Luk" : "Close") { dismiss() }
                Spacer()
                if !cards.isEmpty {
                    Text("\(min(index + 1, cards.count)) / \(cards.count)")
                        .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Spacer()

            if let card {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { flipped.toggle() }
                } label: {
                    VStack(spacing: 16) {
                        Text(card.word)
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .multilineTextAlignment(.center)
                        if flipped {
                            Text(card.meaning)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.accentColor)
                            if let p = card.paradigm, !p.isEmpty {
                                Text(p).font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
                            }
                            Text(card.context)
                                .font(.system(.footnote, design: .serif)).italic()
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text(language == .danish ? "Tryk for at se betydningen" : "Tap to see the meaning")
                                .font(.footnote).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    Text("\(known) / \(cards.count)").font(.system(size: 44, weight: .light, design: .serif))
                    Text(language == .danish ? "kort du kunne" : "cards you knew").foregroundStyle(.secondary)
                }
            }

            Spacer()

            if card != nil {
                HStack(spacing: 12) {
                    Button(language == .danish ? "Ikke endnu" : "Not yet") { answer(false) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button(language == .danish ? "Kunne den" : "Knew it") { answer(true) }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal)
                .disabled(!flipped)
                .opacity(flipped ? 1 : 0.4)
            } else {
                Button(language == .danish ? "Færdig" : "Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
            }
        }
        .padding(.bottom, 20)
        .background(Color(.systemGroupedBackground))
    }

    private func answer(_ wasKnown: Bool) {
        guard let card else { return }
        flashcards.markReviewed(card, known: wasKnown)
        if wasKnown { known += 1 }
        withAnimation(.snappy(duration: 0.2)) {
            flipped = false
            index += 1
        }
    }
}
