import SwiftUI

/// The word diary: today's cards as a deck you turn over, and every saved word below.
struct WordsView: View {
    @Environment(FlashcardStore.self) private var flashcards
    @Environment(VocabStore.self) private var vocab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var deck: [Flashcard] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var known = 0
    @State private var drag: CGSize = .zero
    @State private var horizontalDrag: Bool?
    @State private var searchText = ""
    @State private var skipped: Set<String> = []

    private var card: Flashcard? { index < deck.count ? deck[index] : nil }

    private var filtered: [Flashcard] {
        guard !searchText.isEmpty else { return flashcards.cards }
        let q = searchText.lowercased()
        return flashcards.cards.filter { $0.word.lowercased().contains(q) || $0.meaning.lowercased().contains(q) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ord")
                            .font(.serif(38, .semibold, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.ink)
                        Text("\(vocab.totalLearned) af \(vocab.totalCount) lært")
                            .font(.ui(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.pencil)
                    }
                    Spacer()
                    Art(.words, size: 72)
                }
                .padding(.bottom, 18)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 22) {
                    ForEach(VocabDeck.allCases) { VocabDeckCard(deck: $0) }
                }
                .padding(.bottom, 40)

                Text("Mine gemte ord")
                    .font(.ui(20, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 14)

                if flashcards.cards.isEmpty {
                    emptyCard
                } else {
                    deckView
                        .padding(.bottom, 36)
                    wordList
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .tableBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if deck.isEmpty { deck = Array(flashcards.reviewOrder.prefix(10)) } }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Art(.words, size: 80)
            Text("Ingen ord endnu")
                .font(.serif(24, .semibold, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            Text("Tryk på et understreget ord i en øvelse, og gem det.")
                .font(.ui(16))
                .foregroundStyle(Theme.pencil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paper()
    }

    // MARK: Deck

    @ViewBuilder
    private var deckView: some View {
        if let card {
            VStack(spacing: 18) {
                PaperStack(sheets: deck.count - index - 1, seed: 33) {
                    Button { turn() } label: {
                        FlipCard(flipped: flipped) {
                            cardFront(card)
                        } back: {
                            cardBack(card)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle(scale: 0.98))
                    .paper(lifted: drag != .zero)
                    .overlay(alignment: .top) { stamps }
                    .offset(drag)
                    .rotationEffect(.degrees(Double(drag.width) * 0.065), anchor: .bottom)
                    .simultaneousGesture(dragGesture)
                    .id(card.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
                                            removal: .identity))
                    .accessibilityHint(flipped ? "" : "Vender kortet")
                }
                .padding(.bottom, 34)

                HStack(spacing: 10) {
                    Button("Ikke endnu") { answer(false) }
                        .buttonStyle(PaperButtonStyle())
                    Button("Kunne den") { answer(true) }
                        .buttonStyle(InkButtonStyle())
                }

                HStack {
                    Text(progressLine)
                        .font(.ui(13).monospacedDigit())
                        .foregroundStyle(Theme.pencil)
                    Spacer()
                    if deck.count - index > 1 {
                        Button { skip() } label: {
                            Label("Spring over", systemImage: "arrow.uturn.down")
                                .font(.ui(14, .semibold))
                        }
                        .foregroundStyle(Theme.ink)
                        .buttonStyle(PressStyle())
                        .accessibilityHint("Lægger kortet nederst i bunken")
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(known)")
                        .font(.ui(56, .bold).monospacedDigit())
                    Text("af \(deck.count) kunne du")
                        .font(.ui(18, .semibold))
                        .foregroundStyle(Theme.pencil)
                }
                .foregroundStyle(Theme.ink)
                Button("Tag kortene igen") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        deck = Array(flashcards.reviewOrder.prefix(10))
                        index = 0
                        known = 0
                        flipped = false
                    }
                }
                .buttonStyle(PaperButtonStyle())
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paper()
        }
    }

    private func cardFront(_ card: Flashcard) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(card.word)
                .font(.serif(40, .medium, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            if !card.subtitle.isEmpty {
                Text(card.subtitle)
                    .font(.ui(14))
                    .foregroundStyle(Theme.pencil)
            }
            Spacer()
            Text("Tryk for at vende")
                .font(.ui(13))
                .foregroundStyle(Theme.pencil)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func cardBack(_ card: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.word)
                .font(.serif(20, .medium))
                .foregroundStyle(Theme.pencil)
            Text(card.meaning)
                .font(.ui(28, .bold, relativeTo: .title))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let p = card.paradigm, !p.isEmpty {
                Text(p)
                    .font(.serif(16))
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 8)
            if !card.context.isEmpty {
                Text(card.context)
                    .font(.serif(15))
                    .foregroundStyle(Theme.pencil)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// "Kunne den" / "Ikke endnu" stamps that fade in as the card is dragged.
    private var stamps: some View {
        HStack {
            stamp("Kunne den", Theme.correct).opacity(Double(max(0, drag.width) / 110)).rotationEffect(.degrees(-8))
            Spacer()
            stamp("Ikke endnu", Theme.red).opacity(Double(max(0, -drag.width) / 110)).rotationEffect(.degrees(8))
        }
        .padding(18)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.ui(15, .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color, lineWidth: 2))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if horizontalDrag == nil { horizontalDrag = abs(v.translation.width) > abs(v.translation.height) }
                guard horizontalDrag == true else { return }
                drag = v.translation
            }
            .onEnded { v in
                defer { horizontalDrag = nil }
                guard horizontalDrag == true else { return }
                if abs(v.translation.width) > 110 || abs(v.predictedEndTranslation.width) > 260 {
                    answer(v.translation.width > 0)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { drag = .zero }
                }
            }
    }

    private func turn() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.82)) {
            flipped.toggle()
        }
    }

    private var progressLine: String {
        let left = deck.count - index
        let later = deck[index...].filter { skipped.contains($0.id) }.count
        return later > 0 ? "\(left) tilbage · \(later) sprunget over" : "\(index + 1) af \(deck.count)"
    }

    /// Puts the card at the bottom of the pile to come back to later.
    private func skip() {
        guard index < deck.count - 1 else { return }
        Haptics.tap()
        skipped.insert(deck[index].id)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            drag = CGSize(width: 0, height: 420)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
                flipped = false
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                deck.append(deck.remove(at: index))
            }
        }
    }

    private func answer(_ wasKnown: Bool) {
        guard let card else { return }
        flashcards.markReviewed(card, known: wasKnown)
        if wasKnown { known += 1 }
        Haptics.soft()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            drag = CGSize(width: (wasKnown ? 1 : -1) * 560, height: drag.height + 70)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
                flipped = false
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { index += 1 }
        }
    }

    // MARK: List

    private var wordList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Alle gemte ord")
                .font(.ui(16, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.pencil)
                TextField("Søg", text: $searchText)
                    .font(.ui(16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.chip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.bottom, 8)

            ForEach(filtered) { card in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(card.word)
                            .font(.serif(18, .semibold))
                        Spacer()
                        if card.timesShown > 0 {
                            Text("\(card.timesKnown)/\(card.timesShown)")
                                .font(.ui(12).monospacedDigit())
                                .foregroundStyle(Theme.pencil)
                        }
                    }
                    Text(card.meaning)
                        .font(.ui(15))
                    if !card.subtitle.isEmpty {
                        Text(card.subtitle)
                            .font(.ui(12.5))
                            .foregroundStyle(Theme.pencil)
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 0.75) }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Slet ordet", systemImage: "trash", role: .destructive) { flashcards.remove(card) }
                }
            }
        }
    }
}
