import SwiftUI

/// This week's two bigger moments: a timed mock paper and a short writing task.
struct WeekView: View {
    @Environment(ProgressStore.self) private var progress

    private var task: (da: String, en: String) {
        let week = Calendar.current.component(.weekOfYear, from: .now)
        return WriteView.tasks[week % WriteView.tasks.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Denne uge")
                    .font(.ui(34, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 18)

                PaperStack(sheets: 4, seed: 41) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prøvesæt")
                                    .font(.ui(24, .bold, relativeTo: .title))
                                Text("20 spørgsmål · \(progress.settings.examMinutes) min")
                                    .font(.ui(15).monospacedDigit())
                                    .foregroundStyle(Theme.pencil)
                            }
                            Spacer()
                            Art(.exam, size: 76)
                        }
                        .padding(.bottom, 18)
                        if !progress.data.examHistory.isEmpty {
                            history.padding(.bottom, 18)
                        }
                        NavigationLink(value: Route.exam(minutes: progress.settings.examMinutes)) {
                            Text("Start prøvesæt")
                        }
                        .buttonStyle(InkButtonStyle())
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paper()
                }
                .padding(.bottom, 44)

                PaperStack(sheets: 2, seed: 43) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center) {
                            Text("Skriveopgave")
                                .font(.ui(24, .bold, relativeTo: .title))
                            Spacer()
                            Art(.write, size: 76)
                        }
                        .padding(.bottom, 10)
                        Text(task.da)
                            .font(.serif(18))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 4)
                        if progress.settings.explanationLanguage == .english {
                            Text(task.en)
                                .font(.ui(14))
                                .foregroundStyle(Theme.pencil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        NavigationLink(value: Route.write) {
                            Text("Skriv")
                        }
                        .buttonStyle(PaperButtonStyle())
                        .padding(.top, 18)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paper()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .tableBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Past papers, newest first, as a row of bars.
    private var history: some View {
        let results = Array(progress.data.examHistory.prefix(8))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(results.reversed()) { r in
                    let share = Double(r.score) / Double(max(1, r.total))
                    VStack(spacing: 4) {
                        Text("\(r.score)")
                            .font(.ui(11, .bold).monospacedDigit())
                            .foregroundStyle(Theme.pencil)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(r.id == results.first?.id ? Theme.ink : Theme.ink.opacity(0.3))
                            .frame(width: 18, height: max(4, 54 * share))
                    }
                }
            }
            .frame(height: 74, alignment: .bottom)
            if let last = results.first {
                Text("Sidst: \(last.score) af \(last.total) på \(last.seconds / 60) min, \(last.date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "da_DK"))))")
                    .font(.ui(13))
                    .foregroundStyle(Theme.pencil)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
