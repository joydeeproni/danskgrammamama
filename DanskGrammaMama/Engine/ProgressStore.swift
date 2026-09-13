import Foundation
import Observation

/// Per-question learning record. Spaced repetition: a miss schedules the item
/// for tomorrow, a hit on a due item pushes it 3 days out, a second hit retires it.
struct ItemRecord: Codable, Hashable {
    var timesSeen = 0
    var timesCorrect = 0
    var lastCorrect = false
    var successesNeeded = 0
    var intervalDays = 0
    var due: Date? = nil
    var lastSeen: Date? = nil

    var isInReviewQueue: Bool { successesNeeded > 0 }
    var isMastered: Bool { timesSeen > 0 && lastCorrect && successesNeeded == 0 }
}

struct AppSettings: Codable, Hashable {
    var explanationLanguage: ExplanationLanguage = .english
    var dailyGoal: Int = 15
    var preferredLevel: Int = 0      // 0 = mixed, 1, 2
    var useAI: Bool = true
    var examMinutes: Int = 15
    var sessionLength: Int = 10
}

struct ExamResult: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var score: Int
    var total: Int
    var seconds: Int
}

struct ProgressData: Codable {
    var records: [String: ItemRecord] = [:]
    var streak = 0
    var lastPracticeDay: Date? = nil
    var todayDay: Date? = nil
    var todayCount = 0
    var totalAnswered = 0
    var totalCorrect = 0
    var examHistory: [ExamResult] = []
    var settings = AppSettings()
}

@Observable
final class ProgressStore {
    private(set) var data: ProgressData
    private let fileURL: URL
    private let calendar = Calendar.current

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("progress.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(ProgressData.self, from: raw) {
            data = decoded
        } else {
            data = ProgressData()
        }
    }

    // MARK: - Settings

    var settings: AppSettings {
        get { data.settings }
        set { data.settings = newValue; save() }
    }

    var language: ExplanationLanguage { data.settings.explanationLanguage }

    // MARK: - Daily state

    var todayCount: Int {
        guard let day = data.todayDay, calendar.isDateInToday(day) else { return 0 }
        return data.todayCount
    }

    /// Streak counts only if the learner practised today or yesterday.
    var currentStreak: Int {
        guard let last = data.lastPracticeDay else { return 0 }
        if calendar.isDateInToday(last) || calendar.isDateInYesterday(last) { return data.streak }
        return 0
    }

    var practisedToday: Bool {
        guard let last = data.lastPracticeDay else { return false }
        return calendar.isDateInToday(last)
    }

    var goalReachedToday: Bool { todayCount >= data.settings.dailyGoal }

    // MARK: - Recording answers

    func record(question: Question, correct: Bool, now: Date = .now) {
        var r = data.records[question.id] ?? ItemRecord()
        r.timesSeen += 1
        r.lastSeen = now
        r.lastCorrect = correct
        let today = calendar.startOfDay(for: now)

        if correct {
            r.timesCorrect += 1
            if r.successesNeeded > 0 {
                r.successesNeeded -= 1
                if r.successesNeeded == 0 {
                    r.due = nil
                    r.intervalDays = 0
                } else {
                    r.intervalDays = ProgressStore.nextInterval(after: r.intervalDays)
                    r.due = calendar.date(byAdding: .day, value: r.intervalDays, to: today)
                }
            }
        } else {
            r.successesNeeded = 2
            r.intervalDays = 1
            r.due = calendar.date(byAdding: .day, value: 1, to: today)
        }
        data.records[question.id] = r

        data.totalAnswered += 1
        if correct { data.totalCorrect += 1 }

        if let day = data.todayDay, calendar.isDate(day, inSameDayAs: today) {
            data.todayCount += 1
        } else {
            data.todayDay = today
            data.todayCount = 1
        }

        if let last = data.lastPracticeDay {
            if !calendar.isDate(last, inSameDayAs: today) {
                data.streak = calendar.isDateInYesterday(last) ? data.streak + 1 : 1
                data.lastPracticeDay = today
            }
        } else {
            data.streak = 1
            data.lastPracticeDay = today
        }
        save()
    }

    static func nextInterval(after days: Int) -> Int {
        switch days {
        case ..<1: return 1
        case 1: return 3
        case 3: return 7
        case 7: return 14
        default: return 30
        }
    }

    func recordExam(_ result: ExamResult) {
        data.examHistory.insert(result, at: 0)
        if data.examHistory.count > 30 { data.examHistory.removeLast() }
        save()
    }

    func resetAll() {
        let settings = data.settings
        data = ProgressData()
        data.settings = settings
        save()
    }

    // MARK: - Queries

    func record(for id: String) -> ItemRecord? { data.records[id] }

    func dueQuestions(from pool: [Question], now: Date = .now) -> [Question] {
        pool.filter { q in
            guard let r = data.records[q.id], r.isInReviewQueue, let due = r.due else { return false }
            return due <= now
        }.sorted { (data.records[$0.id]?.due ?? now) < (data.records[$1.id]?.due ?? now) }
    }

    func dueCount(in pool: [Question], now: Date = .now) -> Int {
        dueQuestions(from: pool, now: now).count
    }

    func isUnseen(_ q: Question) -> Bool { data.records[q.id] == nil }

    /// Share of a topic's questions that are currently mastered (0…1).
    func mastery(of pool: [Question]) -> Double {
        guard !pool.isEmpty else { return 0 }
        let mastered = pool.filter { data.records[$0.id]?.isMastered == true }.count
        return Double(mastered) / Double(pool.count)
    }

    /// Accuracy across all attempts in a pool, or nil if never practised.
    func accuracy(of pool: [Question]) -> Double? {
        var seen = 0, correct = 0
        for q in pool {
            if let r = data.records[q.id] { seen += r.timesSeen; correct += r.timesCorrect }
        }
        return seen == 0 ? nil : Double(correct) / Double(seen)
    }

    func seenCount(of pool: [Question]) -> Int {
        pool.filter { data.records[$0.id] != nil }.count
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let raw = try? encoder.encode(data) {
            try? raw.write(to: fileURL, options: .atomic)
        }
    }
}
