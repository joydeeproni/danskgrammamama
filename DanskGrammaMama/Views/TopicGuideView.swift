import SwiftUI

/// The "how to crack this topic" sheet: rules, one hack per rule, examples, classic traps.
struct TopicGuideView: View {
    let topic: Topic
    let guide: TopicGuide

    @Environment(ProgressStore.self) private var progress
    private var language: ExplanationLanguage { progress.settings.explanationLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(guide.intro.text(in: language))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                Picker("Language", selection: languageBinding) {
                    ForEach(ExplanationLanguage.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                ForEach(Array(guide.sections.enumerated()), id: \.offset) { i, section in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(i + 1)").font(.footnote.monospacedDigit().weight(.semibold)).foregroundStyle(Color.accentColor)
                            Text(section.title.text(in: language)).font(.headline)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(section.rules.enumerated()), id: \.offset) { _, rule in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•").foregroundStyle(.secondary)
                                    Text(rule.text(in: language)).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "lightbulb").foregroundStyle(Color.accentColor)
                            Text(section.hack.text(in: language))
                                .font(.callout.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(section.examples.enumerated()), id: \.offset) { _, ex in
                                VStack(alignment: .leading, spacing: 2) {
                                    markdown(ex.da).font(.system(.body, design: .serif))
                                    if language == .english {
                                        Text(ex.en).font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .card()
                }

                if !guide.traps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(language == .danish ? "Klassiske fejl" : "Classic traps").font(.headline)
                        ForEach(Array(guide.traps.enumerated()), id: \.offset) { _, trap in
                            markdown(trap.text(in: language))
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .card()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(topic.title(in: language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func markdown(_ s: String) -> Text {
        if let attributed = try? AttributedString(markdown: s) {
            return Text(attributed)
        }
        return Text(s)
    }

    private var languageBinding: Binding<ExplanationLanguage> {
        Binding(
            get: { progress.settings.explanationLanguage },
            set: { newValue in
                var s = progress.settings
                s.explanationLanguage = newValue
                progress.settings = s
            }
        )
    }
}
