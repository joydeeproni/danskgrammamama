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
                            .font(.system(size: 32, weight: .semibold, design: .serif))
                        if let entry, !entry.subtitle.isEmpty {
                            Text(entry.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    if let entry, entry.hasMeaning {
                        Text(entry.en)
                            .font(.title3)
                            .fixedSize(horizontal: false, vertical: true)
                        if let forms = entry.forms, !forms.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language == .danish ? "Bøjning" : "Forms")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(forms).font(.system(.subheadline, design: .serif))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                    } else if aiLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(language == .danish ? "Slår op …" : "Looking it up …").foregroundStyle(.secondary)
                        }
                    } else if aiFailed {
                        Text(language == .danish
                             ? "Ordet står ikke i ordlisten, og den lokale model kunne ikke slå det op."
                             : "This word is not in the built-in list, and the on-device model could not look it up.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !context.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language == .danish ? "I sætningen" : "In this sentence")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(context)
                                .font(.system(.subheadline, design: .serif)).italic()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    if let entry, entry.hasMeaning {
                        if alreadySaved || saved {
                            Label(language == .danish ? "Gemt i ordbogen" : "Saved to your word diary",
                                  systemImage: "checkmark.circle.fill")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Style.correct)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Button {
                                flashcards.add(entry: entry, context: context)
                                saved = true
                            } label: {
                                Label(language == .danish ? "Gem som flashcard" : "Save as a flashcard",
                                      systemImage: "plus.rectangle.on.rectangle")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language == .danish ? "Luk" : "Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
