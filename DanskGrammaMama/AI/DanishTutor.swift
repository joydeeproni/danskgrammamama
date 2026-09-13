import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Plain result types used by the views

struct MistakeFeedback: Hashable {
    let whyWrong: String
    let tip: String
    let example: String
}

struct WritingIssue: Hashable, Identifiable {
    let id = UUID()
    let original: String
    let correction: String
    let rule: String
}

struct WritingFeedback: Hashable {
    let correctedText: String
    let issues: [WritingIssue]
    let comment: String
}

enum TutorAvailability: Equatable {
    case available
    case unavailable(String)

    var isAvailable: Bool { self == .available }
    var message: String {
        switch self {
        case .available: return "On-device model ready."
        case .unavailable(let why): return why
        }
    }
}

enum TutorError: LocalizedError {
    case unavailable
    var errorDescription: String? { "The on-device model is not available on this device." }
}

// MARK: - Generable schemas (iOS 26+)

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GeneratedMistakeFeedback {
    @Guide(description: "One or two sentences: why the learner's answer is wrong in this particular sentence.")
    var whyWrong: String
    @Guide(description: "One short, memorable rule of thumb the learner can apply next time.")
    var tip: String
    @Guide(description: "One new Danish example sentence using the correct form, on a different subject than the quiz sentence.")
    var example: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedWordLookup {
    @Guide(description: "The dictionary form of the Danish word: infinitive for a verb, singular indefinite for a noun, base form for an adjective.")
    var lemma: String
    @Guide(description: "The word class in Danish: substantiv, verbum, adjektiv, adverbium, præposition, pronomen, konjunktion or talord.")
    var wordClass: String
    @Guide(description: "For a noun, en or et. Empty for every other word class.")
    var article: String
    @Guide(description: "A short English meaning, at most eight words. No full sentence.")
    var meaning: String
    @Guide(description: "For a verb, the paradigm 'infinitive - present - past - har/er participle'. For a noun, 'singular - definite - plural'. Empty otherwise.")
    var forms: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedWritingIssue {
    @Guide(description: "The exact words from the learner's text that contain the error.")
    var original: String
    @Guide(description: "The corrected words.")
    var correction: String
    @Guide(description: "The grammar rule in one sentence, naming the category (e.g. word order, verb form, preposition, noget/nogen/nogle, adjective ending).")
    var rule: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedWritingFeedback {
    @Guide(description: "The learner's full text with all grammar and spelling errors corrected, meaning unchanged.")
    var correctedText: String
    @Guide(description: "Each distinct error found, most important first. Empty if the text is correct.", .maximumCount(12))
    var issues: [GeneratedWritingIssue]
    @Guide(description: "Two or three sentences of encouraging, specific feedback on what to work on next for Prøve i Dansk 3.")
    var overallComment: String
}
#endif

// MARK: - Tutor

/// Thin wrapper around Apple's on-device language model. Everything stays on the phone.
@MainActor
final class DanishTutor {
    static let shared = DanishTutor()

    private init() {}

    var availability: TutorAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .unavailable("This iPhone does not support Apple Intelligence, so AI feedback is off. Everything else works.")
                case .appleIntelligenceNotEnabled:
                    return .unavailable("Turn on Apple Intelligence in Settings → Apple Intelligence & Siri to enable AI feedback.")
                case .modelNotReady:
                    return .unavailable("The on-device model is still downloading. Try again in a few minutes.")
                @unknown default:
                    return .unavailable("The on-device model is unavailable right now.")
                }
            }
        }
        #endif
        return .unavailable("AI feedback needs iOS 26 and an iPhone with Apple Intelligence. Everything else works without it.")
    }

    // MARK: Explain a wrong answer

    func explainMistake(question: Question, blankIndex: Int, learnerAnswer: String, language: ExplanationLanguage) async throws -> MistakeFeedback {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), availability.isAvailable {
            let blank = question.blanks[min(blankIndex, question.blanks.count - 1)]
            let session = LanguageModelSession(instructions: Self.mistakeInstructions(language: language))
            let prompt = """
            Text with gaps marked {1}, {2}, …: \(question.prompt)
            The gap in question: {\(blankIndex + 1)}
            Correct answer for that gap: \(blank.answer)
            Learner chose or wrote: \(learnerAnswer)
            Topic: \(Topic.byID(question.topic)?.titleEn ?? question.topic)
            Rule already shown to the learner: \(blank.explanation.en)
            Explain specifically what is wrong with "\(learnerAnswer)" in this gap. Do not repeat the rule text verbatim.
            """
            let response = try await session.respond(to: prompt, generating: GeneratedMistakeFeedback.self)
            let c = response.content
            return MistakeFeedback(whyWrong: c.whyWrong, tip: c.tip, example: c.example)
        }
        #endif
        throw TutorError.unavailable
    }

    // MARK: Look up a word

    func lookupWord(_ word: String, context: String) async throws -> GlossaryEntry {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), availability.isAvailable {
            let session = LanguageModelSession(instructions: Self.lookupInstructions)
            let prompt = """
            Danish word as it appears in the text: \(word)
            The sentence it appears in: \(context)
            Give the dictionary form and a short English meaning that fits this sentence.
            """
            let c = try await session.respond(to: prompt, generating: GeneratedWordLookup.self).content
            return GlossaryEntry(word: c.lemma.isEmpty ? word : c.lemma,
                                 wordClass: c.wordClass, article: c.article,
                                 en: c.meaning, forms: c.forms.isEmpty ? nil : c.forms)
        }
        #endif
        throw TutorError.unavailable
    }

    // MARK: Review free writing

    func reviewWriting(_ text: String, task: String, language: ExplanationLanguage) async throws -> WritingFeedback {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), availability.isAvailable {
            let session = LanguageModelSession(instructions: Self.writingInstructions(language: language))
            let prompt = """
            Writing task: \(task)
            Learner's text:
            \(text)
            """
            let response = try await session.respond(to: prompt, generating: GeneratedWritingFeedback.self)
            let c = response.content
            return WritingFeedback(
                correctedText: c.correctedText,
                issues: c.issues.map { WritingIssue(original: $0.original, correction: $0.correction, rule: $0.rule) },
                comment: c.overallComment
            )
        }
        #endif
        throw TutorError.unavailable
    }

    // MARK: Prompts

    private static func outputLanguage(_ language: ExplanationLanguage) -> String {
        language == .danish
            ? "Write all explanations in clear, simple Danish."
            : "Write all explanations in English, but keep Danish grammar terms in Danish (ledsætning, datid, bestemt form) and quote Danish words as they are."
    }

    private static let lookupInstructions = """
    You are a Danish-English dictionary for an adult learner at CEFR B2. \
    Given a Danish word and the sentence it appears in, return its dictionary form, word class, \
    and a short English meaning that fits that sentence. Be accurate and terse. \
    If the word is a compound, give the meaning of the whole compound.
    """

    private static func mistakeInstructions(language: ExplanationLanguage) -> String {
        """
        You are a precise, friendly Danish grammar tutor for an adult learner preparing for Prøve i Dansk 3 (CEFR B2). \
        The learner has just answered a fill-in-the-blank question wrongly. \
        Explain the specific error briefly and concretely, give one rule of thumb, and one fresh example sentence in Danish. \
        Never invent grammar; if unsure, stay general. Be concise. \(outputLanguage(language))
        """
    }

    private static func writingInstructions(language: ExplanationLanguage) -> String {
        """
        You are an examiner and tutor for Prøve i Dansk 3 (CEFR B2), skriftlig fremstilling. \
        Correct the learner's Danish text: grammar (word order, verb forms, noget/nogen/nogle, prepositions, plural, adjective endings, pronouns), \
        spelling, and clearly unidiomatic phrasing. Keep the learner's meaning and style; do not rewrite freely. \
        List each distinct error once. If the text is correct, say so and return it unchanged. \(outputLanguage(language))
        """
    }
}
