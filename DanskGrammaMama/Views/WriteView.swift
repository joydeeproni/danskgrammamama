import SwiftUI

/// Free writing checked by the on-device model. Mirrors PD3 skriftlig fremstilling in miniature.
struct WriteView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var taskIndex = 0
    @State private var text = ""
    @State private var feedback: WritingFeedback?
    @State private var loading = false
    @State private var errorText: String?

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var availability: TutorAvailability { DanishTutor.shared.availability }

    static let tasks: [(da: String, en: String)] = [
        ("Skriv 3–5 sætninger: Hvilke fordele og ulemper er der ved at arbejde hjemmefra?",
         "Write 3–5 sentences: What are the advantages and disadvantages of working from home?"),
        ("Skriv 3–5 sætninger: Bør kommunerne gøre mere for at få folk til at cykle? Begrund dit svar.",
         "Write 3–5 sentences: Should municipalities do more to get people cycling? Give reasons."),
        ("Skriv 3–5 sætninger: Fortæl om en gang, du flyttede, og hvad der var svært ved det.",
         "Write 3–5 sentences: Describe a time you moved house and what was difficult about it."),
        ("Skriv 3–5 sætninger: Hvad synes du om, at arbejdspladser blander sig i medarbejdernes sundhed?",
         "Write 3–5 sentences: What do you think of workplaces getting involved in employees' health?"),
        ("Skriv 3–5 sætninger: Beskriv, hvordan din hverdag har ændret sig, siden du kom til Danmark.",
         "Write 3–5 sentences: Describe how your daily life has changed since you came to Denmark."),
        ("Skriv en kort mail (4–6 sætninger) til en ven, hvor du foreslår, at I mødes i weekenden, og forklarer hvorfor.",
         "Write a short email (4–6 sentences) to a friend suggesting you meet at the weekend and explaining why."),
        ("Skriv 3–5 sætninger: Hvorfor er det svært for nogle nyuddannede at få deres første job?",
         "Write 3–5 sentences: Why is it hard for some new graduates to get their first job?"),
        ("Skriv 3–5 sætninger: Hvad kan staten gøre for at reducere antallet af trafikulykker?",
         "Write 3–5 sentences: What can the state do to reduce the number of traffic accidents?")
    ]

    private var task: (da: String, en: String) { WriteView.tasks[taskIndex] }
    private var wordCount: Int { text.split { $0.isWhitespace || $0.isNewline }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(language == .danish ? "Opgave" : "Task").font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(language == .danish ? "Ny opgave" : "New task") {
                            taskIndex = (taskIndex + 1) % WriteView.tasks.count
                            feedback = nil
                        }
                        .font(.subheadline)
                    }
                    Text(task.da).font(.system(.body, design: .serif)).fixedSize(horizontal: false, vertical: true)
                    if language == .english {
                        Text(task.en).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .card()

                VStack(alignment: .trailing, spacing: 6) {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .font(.body)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.sentences)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
                    Text("\(wordCount) \(language == .danish ? "ord" : "words")").font(.caption).foregroundStyle(.secondary)
                }

                if availability.isAvailable {
                    Button {
                        check()
                    } label: {
                        if loading {
                            HStack(spacing: 8) { ProgressView().tint(.white); Text(language == .danish ? "Retter …" : "Checking …") }
                        } else {
                            Label(language == .danish ? "Ret min dansk" : "Check my Danish", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(loading || wordCount < 5)
                    .opacity(wordCount < 5 ? 0.5 : 1)
                } else {
                    Text(availability.message).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(Style.wrong)
                }

                if let fb = feedback { result(fb) }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(language == .danish ? "Skriv" : "Write")
    }

    private func result(_ fb: WritingFeedback) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if fb.issues.isEmpty {
                Label(language == .danish ? "Ingen fejl fundet" : "No errors found", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Style.correct).font(.headline)
            } else {
                Text(language == .danish ? "\(fb.issues.count) ting at rette" : "\(fb.issues.count) things to fix").font(.headline)
                ForEach(fb.issues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(issue.original).strikethrough().foregroundStyle(Style.wrong)
                            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                            Text(issue.correction).bold().foregroundStyle(Style.correct)
                        }
                        .font(.subheadline)
                        Text(issue.rule).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Divider()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(language == .danish ? "Rettet tekst" : "Corrected text").font(.subheadline.weight(.semibold))
                Text(fb.correctedText).font(.system(.body, design: .serif)).fixedSize(horizontal: false, vertical: true)
            }
            Text(fb.comment).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func check() {
        loading = true
        errorText = nil
        feedback = nil
        let t = text, taskText = task.da, lang = language
        Task {
            do {
                feedback = try await DanishTutor.shared.reviewWriting(t, task: taskText, language: lang)
            } catch {
                errorText = error.localizedDescription
            }
            loading = false
        }
    }
}
