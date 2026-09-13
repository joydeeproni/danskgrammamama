import SwiftUI

/// Free writing, checked offline by rules and, where available, by the on-device model.
struct WriteView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(ContentStore.self) private var content
    @Environment(Glossary.self) private var glossary

    @State private var taskIndex = 0
    @State private var text = ""
    @State private var ruleIssues: [WritingIssue] = []
    @State private var aiFeedback: WritingFeedback?
    @State private var checked = false
    @State private var loading = false
    @State private var errorText: String?
    @State private var tappedWord: String?
    @FocusState private var editorFocused: Bool

    private var language: ExplanationLanguage { progress.settings.explanationLanguage }
    private var availability: TutorAvailability { DanishTutor.shared.availability }
    private var aiUsable: Bool { progress.settings.useAI && availability.isAvailable }

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
    private var allIssues: [WritingIssue] { (aiFeedback?.issues ?? []) + ruleIssues }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                taskCard
                editor
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(Style.wrong)
                }
                if checked { results }
            }
            .padding(20)
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(language == .danish ? "Skriv" : "Write")
        .safeAreaInset(edge: .bottom) { checkBar }
        .sheet(item: Binding(get: { tappedWord.map(IdentifiableWord.init) },
                             set: { tappedWord = $0?.value })) { item in
            WordSheet(word: item.value, context: text)
        }
    }

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language == .danish ? "Opgave" : "Task")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(language == .danish ? "Ny opgave" : "New task") {
                    taskIndex = (taskIndex + 1) % WriteView.tasks.count
                    reset()
                }
                .font(.subheadline)
            }
            Text(task.da).font(.system(.body, design: .serif)).fixedSize(horizontal: false, vertical: true)
            if language == .english {
                Text(task.en).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextEditor(text: $text)
                .frame(minHeight: 180)
                .font(.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Style.corner))
                .onChange(of: text) { _, _ in if checked { checked = false } }
            HStack(spacing: 10) {
                Text("\(wordCount) \(language == .danish ? "ord" : "words")")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if wordCount < 5 {
                    Text(language == .danish ? "Skriv mindst fem ord" : "Write at least five words")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var checkBar: some View {
        VStack(spacing: 6) {
            Button {
                editorFocused = false
                check()
            } label: {
                if loading {
                    HStack(spacing: 8) { ProgressView().tint(.white); Text(language == .danish ? "Retter …" : "Checking …") }
                } else {
                    Label(language == .danish ? "Ret min dansk" : "Check my Danish", systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(loading || wordCount < 5)
            .opacity(wordCount < 5 ? 0.5 : 1)

            if !aiUsable {
                Text(language == .danish
                     ? "Retter med grammatikregler på enheden. AI-feedback kræver Apple Intelligence."
                     : "Checking with on-device grammar rules. AI feedback needs Apple Intelligence.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 8).padding(.top, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var results: some View {
        if allIssues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label(language == .danish ? "Ingen fejl fundet" : "No errors found", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(Style.correct)
                Text(language == .danish
                     ? aiUsable ? "Hverken reglerne eller modellen fandt noget at rette." : "Reglerne på enheden fandt ikke noget. Slå Apple Intelligence til for en grundigere kontrol."
                     : aiUsable ? "Neither the rules nor the model found anything to correct." : "The on-device rules found nothing. Turn on Apple Intelligence for a deeper check.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text(language == .danish ? "\(allIssues.count) ting at rette" : "\(allIssues.count) things to fix")
                    .font(.headline)
                ForEach(allIssues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(issue.original).strikethrough().foregroundStyle(Style.wrong)
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                            Text(issue.correction).bold().foregroundStyle(Style.correct)
                        }
                        .font(.system(.subheadline, design: .serif))
                        Text(issue.rule).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }

        if let fb = aiFeedback {
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .danish ? "Rettet tekst" : "Corrected text")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                SentenceView(segments: [.text(fb.correctedText)],
                             gapState: { _ in .pending }, gapNumber: { _ in nil },
                             font: .system(.body, design: .serif),
                             onWordTap: { tappedWord = $0 })
                if !fb.comment.isEmpty {
                    Divider()
                    Text(fb.comment).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func reset() {
        text = ""
        ruleIssues = []
        aiFeedback = nil
        checked = false
        errorText = nil
    }

    private func check() {
        errorText = nil
        aiFeedback = nil
        ruleIssues = WritingChecker(glossary: glossary, verbs: content.verbs).check(text)
        checked = true
        guard aiUsable else { return }
        loading = true
        let t = text, taskText = task.da, lang = language
        Task {
            do {
                aiFeedback = try await DanishTutor.shared.reviewWriting(t, task: taskText, language: lang)
            } catch {
                errorText = (lang == .danish ? "AI-kontrollen fejlede: " : "The AI check failed: ")
                    + error.localizedDescription
            }
            loading = false
        }
    }
}
