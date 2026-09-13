# Question bank schema

Each topic is one JSON file in `DanskGrammaMama/Content/<topic>.json`:

```json
{
  "topic": "verbs",
  "questions": [ ...Question ]
}
```

## Question

| field | type | notes |
|---|---|---|
| `id` | string | `<topic>-<3 digits>`, unique, e.g. `verbs-001` |
| `topic` | string | one of the topic ids below |
| `level` | 1 or 2 | 1 = PD3 level, 2 = PD3 level but harder (longer sentence, subtler distractors, trickier rule) |
| `type` | `"choice"` or `"typed"` | choice = 4 options; typed = the learner types the missing word(s) |
| `prompt` | string | The sentence with exactly one blank written as `___` (three underscores). Full complex sentence, PD3 register. |
| `hint` | string, optional | Shown under the blank. For typed items REQUIRED, e.g. base form + tense `"(beslutte, datid)"` or `"(noget / nogen / nogle)"` |
| `options` | [string] | choice only. Exactly 4, the correct one included, order random. |
| `answer` | string | canonical correct answer, exactly as it fits the blank |
| `accepted` | [string], optional | typed only: other spellings/forms also accepted |
| `explanation` | object | `{"en": "...", "da": "..."}` 1-3 sentences each. Name the rule, say WHY the answer is right and WHY the most tempting distractor is wrong. Use Danish grammar terms in both (e.g. *ledsætning*, *bestemt form*, *datid*). |
| `tags` | [string] | 1-3 short lowercase tags for the sub-rule, e.g. `["datid","uregelmæssig"]` |

## Topic ids

| id | title (da) | title (en) | scope |
|---|---|---|---|
| `verbs` | Verbernes former | Verb forms | nutid/datid/førnutid/førdatid, har vs er + participle, infinitiv efter at/modalverber, passiv (-s / blive), imperativ, uregelmæssige verber |
| `indefinite` | noget · nogen · nogle | noget / nogen / nogle | noget (ubestemt mængde / intetkøn / "somewhat"), nogen (fælleskøn ental, i spørgsmål/nægtelser = any), nogle (flertal = some), ikke nogen/ikke noget, ingen/intet |
| `prepositions` | Præpositioner | Prepositions | i/på/til/ved/om/for/af/over/under/med/fra/hos/efter/mellem/blandt, time expressions (i 2020, om mandagen, for tre år siden, i tre år), fixed verb+præp (interessere sig for, glæde sig til, tage hensyn til, afhænge af, bidrage til, føre til, være enig i, deltage i, lægge vægt på) |
| `number` | Ental og flertal | Singular & plural | -er/-e/-0 plurals, bestemt flertal (-ene/-erne), vowel change (mand/mænd, barn/børn, bog/bøger), irregular, agreement of adjective and quantifier (mange/meget, få/lidt, flere/mere) |
| `pronouns` | den · det · de · dem · denne · disse | Pronouns & demonstratives | den/det/de as subject vs dem as object, det vs den by gender, denne/dette/disse, det som formal subject, "de, der …", man/en |
| `connectors` | Forbinderord | Connectors | imidlertid, dermed, derimod, nemlig, desuden, derfor, alligevel, dog, omvendt, således, ydermere, hermed, med andre ord, på den anden side, for det første; in PD3 Delprøve-3 style cloze: pick the connector whose logic (contrast/cause/addition/consequence) fits |
| `wordorder` | Ordstilling | Word order | inversion after fronted adverbial (I dag tager jeg…), ledsætning order (subject–adverb–verb: "…fordi han ikke kommer"), "fordi" vs "derfor", "ikke" placement, indirect questions (om/hvad der), "der" in relative subject clauses |
| `adjectives` | Adjektiver og ejestedord | Adjectives & possessives | -0/-t/-e endings, bestemt form takes -e (det store hus), adjectives after "den/det/de", predicative agreement (huset er stort), sin/sit/sine vs hans/hendes/deres, egen/eget/egne |
| `relatives` | der · som · hvad og formelt sprog | Relatives & formal register | der (subject only) vs som (subject/object), hvad/hvilket after whole clauses, "hvad der" in indirect questions, preposition + hvilken/som…til; plus formal collocations PD3 rewards: på grund af, med henblik på, i forhold til, som følge af, i modsætning til, i løbet af |

## Quality bar (read carefully)

- Level: Prøve i Dansk 3 = CEFR B2. Sentences must look like the exam's texts: society, work, health, environment, education, housing, family life in Denmark. Formal-neutral register, 12-25 words, usually a hovedsætning + ledsætning.
- Every sentence is ORIGINAL. Do not reuse sentences from published PD3 papers.
- Exactly one blank per prompt. The blank tests exactly one rule.
- Distractors must be tempting: a real word the learner could plausibly pick, not nonsense. For `choice`, one distractor should be the classic error (e.g. nogen where nogle is right).
- Danish must be 100% correct: spelling, commas (use the standard "startkomma" style is optional, but be consistent and never wrong), capitalisation, æ/ø/å.
- Explanations teach a transferable rule, not just "because it is right". Mention the trap. English explanation and Danish explanation carry the same content.
- Mix: ~55% choice, ~45% typed. ~50% level 1, ~50% level 2. Level 2 typed items are the hardest.
- Vary sentence subjects and topics; do not start every sentence the same way.
