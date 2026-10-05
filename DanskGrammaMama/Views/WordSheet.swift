import SwiftUI

/// Shown when a word in a sentence is tapped: what it means, and a button to keep it.
struct WordSheet: View {
    let word: String
    let context: String

    @Environment(Glossary.self) private var glossary
    @Environment(FlashcardStore.self) private var flashcards
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss

    @State private var entry: GlossaryEntry?
    @State private var aiLoading = false
    @State private var aiFailed = false
    @State private var saved = false

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var alreadySaved: Bool { entry.map { flashcards.contains($0.word) } ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry?.word ?? Glossary.clean(word))
                            .font(.serif(34, .semibold, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.ink)
                        if let entry, !entry.subtitle.isEmpty {
                            Text(entry.subtitle).font(.ui(15, relativeTo: .subheadline)).foregroundStyle(Theme.pencil)
                        }
                    }

                    if let entry, entry.hasMeaning {
                        Text(entry.en)
                            .font(.ui(20, relativeTo: .title3))
                            .fixedSize(horizontal: false, vertical: true)
                        if let forms = entry.forms, !forms.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bøjning")
                                    .font(.ui(12.5, .semibold, relativeTo: .caption)).foregroundStyle(Theme.pencil)
                                Text(forms).font(.serif(16))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.paperTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.edge, lineWidth: 1))
                        }
                    } else if aiLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Slår op …").foregroundStyle(Theme.pencil)
                        }
                    } else if aiFailed {
                        Text(language == .danish
                             ? "Ordet står ikke i ordlisten, og den lokale model kunne ikke slå det op."
                             : "This word is not in the built-in list, and the on-device model could not look it up.")
                            .foregroundStyle(Theme.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !context.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I sætningen")
                                .font(.ui(12.5, .semibold, relativeTo: .caption)).foregroundStyle(Theme.pencil)
                            Text(context)
                                .font(.serif(16))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    if let entry, entry.hasMeaning {
                        if alreadySaved || saved {
                            Label("Gemt under Ord",
                                  systemImage: "checkmark.circle.fill")
                                .font(.ui(17, .medium, relativeTo: .body))
                                .foregroundStyle(Style.correct)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Button {
                                flashcards.add(entry: entry, context: context)
                                saved = true
                            } label: {
                                Label("Gem ordet",
                                      systemImage: "plus.rectangle.on.rectangle")
                            }
                            .buttonStyle(InkButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.paper)
        .presentationCornerRadius(30)
        .tint(Theme.ink)
        .task { await load() }
    }

    private func load() async {
        if let hit = glossary.lookup(word), hit.hasMeaning {
            entry = hit
            return
        }
        guard progress.settings.useAI, DanishTutor.shared.availability.isAvailable else {
            aiFailed = true
            return
        }
        aiLoading = true
        do {
            entry = try await DanishTutor.shared.lookupWord(Glossary.clean(word), context: context)
        } catch {
            aiFailed = true
        }
        aiLoading = false
    }
}
