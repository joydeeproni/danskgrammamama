import SwiftUI

/// Practise one vocabulary deck: today's due cards, then new ones. "Ikke endnu" sends a
/// card to the bottom of the pile to come back in the same round; "Spring over" does the
/// same without counting.
struct VocabSessionView: View {
    let deck: VocabDeck

    @Environment(VocabStore.self) private var vocab
    @Environment(FlashcardStore.self) private var flashcards
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cards: [VocabItem] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var drag: CGSize = .zero
    @State private var horizontalDrag: Bool?
    @State private var knownCount = 0
    @State private var seen: Set<String> = []
    @State private var retries: [String: Int] = [:]
    @State private var started = false

    private var card: VocabItem? { index < cards.count ? cards[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(systemImage: "xmark", label: "Luk") { dismiss() }
                Spacer()
                Text(deck.title)
                    .font(.ui(16, .semibold, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 8)

            if let card {
                deckView(card)
            } else if started {
                summary
            }
        }
        .background(Theme.table.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !started else { return }
            cards = vocab.session(deck)
            started = true
        }
    }

    // MARK: Deck

    private func deckView(_ card: VocabItem) -> some View {
        VStack(spacing: 18) {
            PaperStack(sheets: cards.count - index - 1, seed: 51) {
                Button { turn() } label: {
                    FlipCard(flipped: flipped) {
                        front(card)
                    } back: {
                        back(card)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.98))
                .paper(lifted: drag != .zero)
                .overlay(alignment: .top) { stamps }
                .offset(drag)
                .rotationEffect(.degrees(Double(drag.width) * 0.065), anchor: .bottom)
                .simultaneousGesture(dragGesture)
                .id("\(card.id)-\(index)")
                .transition(.asymmetric(insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
                                        removal: .identity))
            }
            .padding(.bottom, 30)

            HStack(spacing: 10) {
                Button("Ikke endnu") { answer(false) }
                    .buttonStyle(PaperButtonStyle())
                Button("Kunne den") { answer(true) }
                    .buttonStyle(InkButtonStyle())
            }

            HStack {
                Text("\(cards.count - index) tilbage")
                    .font(.ui(13).monospacedDigit())
                    .foregroundStyle(Theme.pencil)
                Spacer()
                if cards.count - index > 1 {
                    Button { skip() } label: {
                        Label("Spring over", systemImage: "arrow.uturn.down")
                            .font(.ui(14, .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 16)
    }

    private func front(_ card: VocabItem) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(card.level)
                    .font(.ui(12, .bold))
                    .foregroundStyle(Theme.pencil)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.chip, in: Capsule())
                Spacer()
                if vocab.records[card.id] == nil {
                    Text("Ny")
                        .font(.ui(12, .bold))
                        .foregroundStyle(Theme.redText)
                }
            }
            Spacer()
            Text(card.da)
                .font(.serif(frontSize(card.da), .medium, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            if let tag = card.tag, !tag.isEmpty {
                Text(tag)
                    .font(.ui(14))
                    .foregroundStyle(Theme.pencil)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Text("Tryk for at vende")
                .font(.ui(13))
                .foregroundStyle(Theme.pencil)
        }
        .padding(22)
    }

    private func frontSize(_ text: String) -> CGFloat {
        switch text.count {
        case ..<16: return 38
        case ..<32: return 30
        default: return 24
        }
    }

    private func back(_ card: VocabItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(card.da)
                    .font(.serif(19, .medium))
                    .foregroundStyle(Theme.pencil)
                Text(card.en)
                    .font(.ui(26, .bold, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let forms = card.forms, !forms.isEmpty {
                    Text(forms).font(.serif(16)).foregroundStyle(Theme.ink)
                }
                if let pattern = card.pattern, !pattern.isEmpty {
                    Text(pattern).font(.ui(15, .medium)).foregroundStyle(Theme.ink)
                }
                if let meaning = card.meaningDa, !meaning.isEmpty {
                    Text(meaning).font(.ui(15)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let literal = card.literal, !literal.isEmpty {
                    Text("Ordret: \(literal)").font(.ui(13)).foregroundStyle(Theme.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Rectangle().fill(Theme.rule).frame(height: 0.75).padding(.vertical, 4)
                Text(card.example.da)
                    .font(.serif(17))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.example.en)
                    .font(.ui(13))
                    .foregroundStyle(Theme.pencil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

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

    // MARK: Summary

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if cards.isEmpty {
                    Text("Ingen kort i dag")
                        .font(.ui(26, .bold))
                    Text("Du er igennem bunken. Nye kort kommer, når du har lært dem, du har i gang.")
                        .font(.ui(16)).foregroundStyle(Theme.pencil)
                } else {
                    Text("Runden er klaret")
                        .font(.ui(26, .bold))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(knownCount)").font(.ui(56, .bold))
                        Text("af \(seen.count) kunne du").font(.ui(18, .semibold)).foregroundStyle(Theme.pencil)
                    }
                }
                let learned = vocab.learned(deck), total = vocab.count(deck)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(learned) af \(total) lært i \(deck.title.lowercased())")
                        .font(.ui(14, .semibold).monospacedDigit())
                        .foregroundStyle(Theme.pencil)
                    Meter(value: total == 0 ? 0 : Double(learned) / Double(total), height: 6)
                }
                .padding(.top, 6)
                Button("En runde til") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        cards = vocab.session(deck)
                        index = 0
                        knownCount = 0
                        seen = []
                        retries = [:]
                    }
                }
                .buttonStyle(InkButtonStyle())
                .padding(.top, 8)
                .disabled(vocab.session(deck).isEmpty)
                Button("Tilbage") { dismiss() }
                    .buttonStyle(PaperButtonStyle())
            }
            .foregroundStyle(Theme.ink)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paper()
            .padding(20)
        }
    }

    // MARK: Actions

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

    private func answer(_ known: Bool) {
        guard let card else { return }
        vocab.mark(card, known: known)
        // Cards you could not answer also go to "Mine gemte ord", to see again there and in the widget.
        if !known {
            flashcards.add(word: card.da, meaning: card.en, wordClass: card.kindLabel,
                           paradigm: card.forms ?? card.pattern, context: card.example.da)
        }
        if !seen.contains(card.id) {
            seen.insert(card.id)
            if known { knownCount += 1 }
        }
        Haptics.soft()
        // A missed card comes back at the end of the round, at most twice.
        let again = !known && (retries[card.id] ?? 0) < 2
        if again { retries[card.id, default: 0] += 1 }
        move(out: CGSize(width: (known ? 1 : -1) * 560, height: drag.height + 70), requeue: again)
    }

    private func skip() {
        guard index < cards.count - 1 else { return }
        Haptics.tap()
        move(out: CGSize(width: 0, height: 420), requeue: true)
    }

    private func move(out offset: CGSize, requeue: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.9)) {
            drag = offset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.15 : 0.26)) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
                flipped = false
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                if requeue {
                    cards.append(cards.remove(at: index))
                } else {
                    index += 1
                }
            }
        }
    }
}

/// One deck on the Ord page: how much is learned and how many cards wait today.
struct VocabDeckCard: View {
    let deck: VocabDeck
    @Environment(VocabStore.self) private var vocab

    var body: some View {
        let total = vocab.count(deck), learned = vocab.learned(deck), due = vocab.due(deck).count
        NavigationLink(value: Route.vocab(deck)) {
            PaperStack(sheets: 3, seed: deck.rawValue.count * 7, step: 2.2, radius: Theme.smallRadius) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(deck.title)
                        .font(.ui(16, .bold, relativeTo: .headline))
                        .foregroundStyle(Theme.ink)
                    Text(deck.subtitle)
                        .font(.ui(12, relativeTo: .caption))
                        .foregroundStyle(Theme.pencil)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(learned)").font(.ui(28, .bold, relativeTo: .title))
                        Text("/\(total)").font(.ui(14, .semibold)).foregroundStyle(Theme.pencil)
                    }
                    .foregroundStyle(Theme.ink)
                    Meter(value: total == 0 ? 0 : Double(learned) / Double(total), height: 5)
                        .padding(.vertical, 6)
                    Text(due > 0 ? "\(due) til gentagelse" : "lært")
                        .font(.ui(12, .semibold, relativeTo: .caption).monospacedDigit())
                        .foregroundStyle(due > 0 ? Theme.redText : Theme.pencil)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
                .paper(radius: Theme.smallRadius)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
    }
}
