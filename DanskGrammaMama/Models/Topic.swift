import Foundation

struct Topic: Identifiable, Hashable {
    let id: String
    let titleDa: String
    let titleEn: String
    let blurbEn: String
    let blurbDa: String

    func title(in language: ExplanationLanguage) -> String {
        language == .danish ? titleDa : titleEn
    }

    func blurb(in language: ExplanationLanguage) -> String {
        language == .danish ? blurbDa : blurbEn
    }

    static let all: [Topic] = [
        Topic(id: "verbs",
              titleDa: "Verbernes former", titleEn: "Verb forms",
              blurbEn: "Tenses, har vs. er, at + infinitive, passive, strong verbs.",
              blurbDa: "Tider, har vs. er, at + infinitiv, passiv, stærke verber."),
        Topic(id: "indefinite",
              titleDa: "noget · nogen · nogle", titleEn: "noget / nogen / nogle",
              blurbEn: "noget, nogen or nogle – and ingen, intet.",
              blurbDa: "noget, nogen eller nogle – og ingen, intet."),
        Topic(id: "prepositions",
              titleDa: "Præpositioner", titleEn: "Prepositions",
              blurbEn: "Time expressions, i vs. på, fixed verb + preposition pairs.",
              blurbDa: "Tidsudtryk, i vs. på, faste verbum + præposition."),
        Topic(id: "number",
              titleDa: "Ental og flertal", titleEn: "Singular & plural",
              blurbEn: "Plural endings, vowel change, mange/meget, flere/mere.",
              blurbDa: "Flertalsendelser, vokalskifte, mange/meget, flere/mere."),
        Topic(id: "pronouns",
              titleDa: "den · det · de · dem · disse", titleEn: "Pronouns & demonstratives",
              blurbEn: "den vs. det, de vs. dem, denne/dette/disse, man and sig.",
              blurbDa: "den vs. det, de vs. dem, denne/dette/disse, man og sig."),
        Topic(id: "connectors",
              titleDa: "Forbinderord", titleEn: "Connectors",
              blurbEn: "Delprøve 3: pick the word whose logic fits.",
              blurbDa: "Delprøve 3: vælg ordet, hvis logik passer."),
        Topic(id: "wordorder",
              titleDa: "Ordstilling", titleEn: "Word order",
              blurbEn: "Verb second, ikke before the verb in ledsætninger, fordi vs. derfor.",
              blurbDa: "Verbet på plads to, ikke før verbet i ledsætninger, fordi vs. derfor."),
        Topic(id: "adjectives",
              titleDa: "Adjektiver og ejestedord", titleEn: "Adjectives & possessives",
              blurbEn: "-0 / -t / -e endings and sin vs. hans.",
              blurbDa: "Endelserne -0 / -t / -e og sin vs. hans."),
        Topic(id: "relatives",
              titleDa: "der · som · hvad og formelt sprog", titleEn: "Relatives & formal register",
              blurbEn: "der vs. som, hvad vs. hvilket, formal phrases.",
              blurbDa: "der vs. som, hvad vs. hvilket, formelle udtryk.")
    ]

    static func byID(_ id: String) -> Topic? {
        all.first { $0.id == id }
    }
}
