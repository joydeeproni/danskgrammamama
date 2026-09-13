import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(ContentStore.self) private var content
    @Environment(Glossary.self) private var glossary
    @Environment(FlashcardStore.self) private var flashcards
    @State private var confirmReset = false

    private var settings: Binding<AppSettings> {
        Binding(get: { progress.settings }, set: { progress.settings = $0 })
    }

    private var inputModeDescription: String {
        switch progress.settings.inputMode {
        case .choice: return "Tap one of four options. The answer and explanation appear immediately."
        case .typed: return "Type the answer yourself; the four options can be shown as a hint. Harder, closer to the written exam."
        case .mixed: return "About half the questions are typed, half multiple choice."
        }
    }

    var body: some View {
        Form {
            Section("Explanations") {
                Picker("Language", selection: settings.explanationLanguage) {
                    ForEach(ExplanationLanguage.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Grammar terms stay in Danish either way, so they match your teacher's vocabulary.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Picker("Answer mode", selection: settings.inputMode) {
                    ForEach(InputMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(inputModeDescription).font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("Answering")
            }

            Section("Practice") {
                Stepper("Daily goal: \(settings.wrappedValue.dailyGoal) questions", value: settings.dailyGoal, in: 5...60, step: 5)
                Stepper("Session length: \(settings.wrappedValue.sessionLength)", value: settings.sessionLength, in: 5...30, step: 5)
                Picker("Level", selection: settings.preferredLevel) {
                    Text("Mixed").tag(0)
                    Text("Level 1").tag(1)
                    Text("Level 2").tag(2)
                }
                Stepper("Exam time: \(settings.wrappedValue.examMinutes) min", value: settings.examMinutes, in: 5...40, step: 5)
            }

            Section {
                Toggle("Use on-device AI", isOn: settings.useAI)
                Text(DanishTutor.shared.availability.message)
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("AI tutor")
            } footer: {
                Text("Uses Apple's on-device model. Your text never leaves the phone. Explanations for every question are written by hand and work without it.")
            }

            Section {
                LabeledContent("Saved words", value: "\(flashcards.cards.count)")
                LabeledContent("Dictionary entries", value: "\(glossary.count)")
            } header: {
                Text("Words")
            } footer: {
                Text("Tap any underlined word in an exercise to see what it means and keep it. Saved words appear in the Words tab and in the home-screen widget, which shows a new one every hour. To let the widget read your own words, add the App Groups capability to both targets in Xcode; without it the widget shows a built-in starter deck.")
            }

            Section("Progress") {
                LabeledContent("Questions in bank", value: "\(content.questions.count)")
                LabeledContent("Verbs in drill list", value: "\(content.verbs.count)")
                LabeledContent("Answered", value: "\(progress.data.totalAnswered)")
                LabeledContent("Correct", value: "\(progress.data.totalCorrect)")
                LabeledContent("Due for review", value: "\(progress.dueCount(in: content.questions))")
                Button("Reset all progress", role: .destructive) { confirmReset = true }
            }

            Section("About") {
                Text("Built for Prøve i Dansk 3 (CEFR B2). Question bank: \(Topic.all.count) topics. Missed items return after 1 day, then 3 days, until answered correctly twice.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { progress.resetAll() }
        } message: {
            Text("Streak, review queue and mastery will be cleared. Settings are kept.")
        }
    }
}
