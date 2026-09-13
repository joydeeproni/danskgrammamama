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
              blurbEn: "Nutid, datid, førnutid and førdatid; har vs. er; infinitive after at and modal verbs; s-passive; irregular verbs from your 500-verb list.",
              blurbDa: "Nutid, datid, førnutid og førdatid; har vs. er; infinitiv efter at og modalverber; s-passiv; uregelmæssige verber fra din liste med 500 verber."),
        Topic(id: "indefinite",
              titleDa: "noget · nogen · nogle", titleEn: "noget / nogen / nogle",
              blurbEn: "noget for quantities and neuter nouns, nogen in questions and negations, nogle for plural 'some'. Plus ingen, intet and nogensinde.",
              blurbDa: "noget om mængder og intetkønsord, nogen i spørgsmål og nægtelser, nogle om flertal. Desuden ingen, intet og nogensinde."),
        Topic(id: "prepositions",
              titleDa: "Præpositioner", titleEn: "Prepositions",
              blurbEn: "Time expressions (i, om, for … siden), i vs. på for places, and the fixed verb + preposition pairs PD3 rewards: interessere sig for, tage hensyn til, afhænge af …",
              blurbDa: "Tidsudtryk (i, om, for … siden), i vs. på om steder og de faste forbindelser, PD3 belønner: interessere sig for, tage hensyn til, afhænge af …"),
        Topic(id: "number",
              titleDa: "Ental og flertal", titleEn: "Singular & plural",
              blurbEn: "Plural endings -er / -e / -0, definite plural, vowel change (barn → børn), and quantifiers: mange/meget, få/lidt, flere/mere.",
              blurbDa: "Flertalsendelser -er / -e / -0, bestemt flertal, vokalskifte (barn → børn) og mængdeord: mange/meget, få/lidt, flere/mere."),
        Topic(id: "pronouns",
              titleDa: "den · det · de · dem · disse", titleEn: "Pronouns & demonstratives",
              blurbEn: "den vs. det by gender, de (subject) vs. dem (object), denne/dette/disse, det as placeholder subject, man and sig.",
              blurbDa: "den vs. det efter køn, de (subjekt) vs. dem (objekt), denne/dette/disse, det som formelt subjekt, man og sig."),
        Topic(id: "connectors",
              titleDa: "Forbinderord", titleEn: "Connectors",
              blurbEn: "The Delprøve 3 classic: imidlertid, dermed, derimod, nemlig, desuden, alligevel … Pick the word whose logic fits the text.",
              blurbDa: "Klassikeren fra Delprøve 3: imidlertid, dermed, derimod, nemlig, desuden, alligevel … Vælg det ord, hvis logik passer i teksten."),
        Topic(id: "wordorder",
              titleDa: "Ordstilling", titleEn: "Word order",
              blurbEn: "Inversion after a fronted adverbial, subject–adverb–verb inside ledsætninger, ikke placement, fordi vs. derfor, indirect questions.",
              blurbDa: "Inversion efter fremrykket adverbial, subjekt–adverbial–verbum i ledsætninger, placering af ikke, fordi vs. derfor, indirekte spørgsmål."),
        Topic(id: "adjectives",
              titleDa: "Adjektiver og ejestedord", titleEn: "Adjectives & possessives",
              blurbEn: "-0 / -t / -e endings, definite form always -e, predicative agreement, and sin/sit/sine vs. hans/hendes/deres.",
              blurbDa: "Endelserne -0 / -t / -e, bestemt form altid -e, kongruens efter verbet og sin/sit/sine vs. hans/hendes/deres."),
        Topic(id: "relatives",
              titleDa: "der · som · hvad og formelt sprog", titleEn: "Relatives & formal register",
              blurbEn: "der (subject only) vs. som, hvad/hvilket after whole clauses, hvad der in indirect questions, and formal phrases like på grund af, med henblik på, i forhold til.",
              blurbDa: "der (kun subjekt) vs. som, hvad/hvilket efter hele sætninger, hvad der i indirekte spørgsmål og formelle udtryk som på grund af, med henblik på, i forhold til.")
    ]

    static func byID(_ id: String) -> Topic? {
        all.first { $0.id == id }
    }
}
