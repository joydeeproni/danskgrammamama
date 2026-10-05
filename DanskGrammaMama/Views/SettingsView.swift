import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(ContentStore.self) private var content
    @Environment(Glossary.self) private var glossary
    @Environment(FlashcardStore.self) private var flashcards
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private var settings: Binding<AppSettings> {
        Binding(get: { progress.settings }, set: { progress.settings = $0 })
    }

    private var examDate: Binding<Date> {
        Binding(get: { progress.settings.examDate ?? Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now },
                set: { settings.wrappedValue.examDate = $0 })
    }

    private var appearance: Binding<Appearance> {
        Binding(get: { progress.settings.appearance ?? .system },
                set: { settings.wrappedValue.appearance = $0 })
    }

    private var inputModeDescription: String {
        switch progress.settings.inputMode {
        case .choice: return "Vælg mellem fire muligheder. Svaret og forklaringen kommer med det samme."
        case .typed: return "Skriv selv svaret; de fire muligheder kan vises som hjælp. Sværere og tættere på den skriftlige prøve."
        case .mixed: return "Cirka halvdelen skriver du, resten vælger du."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Jeg har en prøvedato", isOn: Binding(
                        get: { progress.settings.examDate != nil },
                        set: { settings.wrappedValue.examDate = $0 ? examDate.wrappedValue : nil }))
                    if progress.settings.examDate != nil {
                        DatePicker("Prøvedato", selection: examDate, in: Date.now..., displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "da_DK"))
                    }
                    Stepper("Prøvesæt: \(settings.wrappedValue.examMinutes) min", value: settings.examMinutes, in: 5...40, step: 5)
                } header: {
                    Text("Prøven")
                } footer: {
                    Text("I dag tæller ned til datoen.")
                }

                Section("Hver dag") {
                    Stepper("Dagens mål: \(settings.wrappedValue.dailyGoal) spørgsmål", value: settings.dailyGoal, in: 5...60, step: 5)
                    Stepper("Ekstra runde: \(settings.wrappedValue.sessionLength) kort", value: settings.sessionLength, in: 5...30, step: 5)
                    Picker("Niveau", selection: settings.preferredLevel) {
                        Text("Blandet").tag(0)
                        Text("Niveau 1").tag(1)
                        Text("Niveau 2").tag(2)
                    }
                }

                Section {
                    Picker("Svar", selection: settings.inputMode) {
                        Text("Vælg").tag(InputMode.choice)
                        Text("Skriv").tag(InputMode.typed)
                        Text("Blandet").tag(InputMode.mixed)
                    }
                    .pickerStyle(.segmented)
                    Text(inputModeDescription).font(.ui(13)).foregroundStyle(Theme.pencil)
                } header: {
                    Text("Sådan svarer du")
                }

                Section {
                    Picker("Forklaringer", selection: settings.explanationLanguage) {
                        Text("Engelsk").tag(ExplanationLanguage.english)
                        Text("Dansk").tag(ExplanationLanguage.danish)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Forklaringer")
                } footer: {
                    Text("Grammatiske begreber står på dansk uanset hvad, så de passer til din undervisning.")
                }

                Section("Udseende") {
                    Picker("Udseende", selection: appearance) {
                        Text("System").tag(Appearance.system)
                        Text("Lys").tag(Appearance.light)
                        Text("Mørk").tag(Appearance.dark)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Brug AI på telefonen", isOn: settings.useAI)
                    Text(DanishTutor.shared.availability.message)
                        .font(.ui(13)).foregroundStyle(Theme.pencil)
                } header: {
                    Text("AI-hjælp")
                } footer: {
                    Text("Bruger Apples model på telefonen. Din tekst forlader aldrig telefonen. Alle forklaringer er skrevet i hånden og virker uden.")
                }

                Section {
                    LabeledContent("Gemte ord", value: "\(flashcards.cards.count)")
                    LabeledContent("Ord i ordbogen", value: "\(glossary.count)")
                } header: {
                    Text("Ord")
                } footer: {
                    Text("Tryk på et understreget ord i en øvelse for at se betydningen og gemme det. Widgetten viser et nyt gemt ord hver time.")
                }

                Section("Fremskridt") {
                    LabeledContent("Spørgsmål i banken", value: "\(content.questions.count)")
                    LabeledContent("Besvaret", value: "\(progress.data.totalAnswered)")
                    LabeledContent("Rigtige", value: "\(progress.data.totalCorrect)")
                    LabeledContent("Til gentagelse", value: "\(progress.dueCount(in: content.questions))")
                    Button("Nulstil al fremgang", role: .destructive) { confirmReset = true }
                }

                Section {
                    Text("Lavet til Prøve i Dansk 3 (B2). \(Topic.all.count) emner. Fejl kommer igen efter 1 dag og derefter 3 dage, indtil du har svaret rigtigt to gange.")
                        .font(.ui(13)).foregroundStyle(Theme.pencil)
                }
            }
            .font(.ui(16))
            .scrollContentBackground(.hidden)
            .background(Theme.table.ignoresSafeArea())
            .navigationTitle("Indstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Færdig") { dismiss() }
                        .font(.ui(16, .semibold))
                }
            }
            .confirmationDialog("Nulstil al fremgang?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Nulstil", role: .destructive) { progress.resetAll() }
            } message: {
                Text("Række, gentagelser og parathed bliver slettet. Indstillingerne beholdes.")
            }
        }
        .tint(Theme.ink)
        .presentationBackground(Theme.table)
    }
}
