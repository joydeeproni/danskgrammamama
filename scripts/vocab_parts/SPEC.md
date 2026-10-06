# PD3 vocabulary decks — shared spec

The app is a Danish exam-prep app for adults sitting Prøve i Dansk 3 (CEFR B2). These decks are
flashcards for learners pushing from B2 towards C1/C2. Learners will memorise what you write, so:
**correctness beats quantity.** Only real, current, natural Danish. If you are not sure an item
exists or is used the way you describe, leave it out. No duplicates. No invented idioms.

Danish spelling follows Retskrivningsordbogen (Dansk Sprognævn). Use » « for quotes only if needed.

## Item fields (all decks)
- `da`: the Danish item (lemma / phrase), lower case unless it must be capitalised. Use "…" (single
  character U+2026) where the learner fills in something, e.g. "Jeg er enig i, at …".
- `en`: short English meaning (max ~8 words). Several senses separated by "; ".
- `example`: {"da": natural Danish sentence, 6–18 words, B2–C1 level, about adult life in Denmark
  (work, family, society, politics, health, climate, housing, education, news) — never about
  the word itself; "en": faithful English translation}.
- `level`: "B2", "C1" or "C2".
Extra fields per deck are below. Write strict JSON (UTF-8, æøå as characters).

## Decks
### words — 2000 most useful NON-NOUN words for B2–C2
Fields: `da` (lemma: infinitive without "at", adjective in common gender singular indefinite),
`class` one of "verbum", "adjektiv", "adverbium", "konjunktion", "præposition", "pronomen",
"interjektion", `forms` (verbs: "nutid – datid – har/er + participium", e.g.
"afhænger – afhang – har afhængt"; adjectives: "t-form – e-form", e.g. "betydeligt – betydelige",
add comparison only if irregular, e.g. "bedre – bedst"; others: ""), `rank` (the best rank of ANY
inflected form of the lemma in the frequency list `da_50k.txt` in this folder — line number, 1-based —
or null if absent).
- NO nouns (substantiver) at all. Participles used as adjectives (berørt, afgørende) count as adjektiv.
- NO A1–A2 basics: e.g. hej, jeg, du, er, være, have, gå, komme, se, sige, god, stor, lille, ny,
  gammel, meget, mange, og, men, eller, i, på, til, med, her, der, nu, i dag, altid, aldrig, også,
  kun, lige, godt, dårlig, glad, sige, spise, drikke, sove, bo, arbejde, lære, tale, kunne, ville,
  skulle, måtte, få, give, tage, gøre, lave, finde, vide, tro, synes, tænke, hedde, begynde, slutte.
  Rule of thumb: if a learner at A2 already knows it, skip it.
- "Most common" means high frequency in real use (news, public information, work, the PD3 exam
  texts), not literary rarities. Use da_50k.txt (spoken/subtitles) as a guide, but also include
  frequent WRITTEN-register words that subtitles under-represent (imidlertid, foretage, væsentlig,
  ifølge, herunder, betydelig, hhv. is not a word — skip abbreviations).
- Reflexive verbs keep "sig": "beskæftige sig". Particle verbs (finde ud af, gå ind for) do NOT
  belong here (they are in the fixed-expressions deck).

### phrases — 1000 useful phrases / sentence frames (fraser) for B2–C2
Functional chunks a learner uses to *do* something in speech or writing: give an opinion, agree,
disagree, hedge, compare, conclude, describe a diagram, structure a talk, write a formal or
informal email, ask for clarification, interrupt politely, apologise, complain, suggest.
Fields: `use` (short Danish note on what it is for, e.g. "give sin mening", "beskrive et diagram"),
`register` "formel" | "neutral" | "uformel".
Not single words, not idioms (that's udtryk), not bare verb+preposition pairs (that's fixed).

### fixed — 1000 faste forbindelser (fixed expressions / collocations)
Word combinations that are fixed: verb + preposition (tage hensyn til, afhænge af, interessere sig
for), particle verbs (finde ud af, gå ind for, komme an på), adjective + preposition (afhængig af,
stolt af, ansvarlig for), noun + preposition (grunden til, interesse for), prepositional phrases
(i forhold til, på grund af, med henblik på, i stedet for), verb + noun collocations (træffe en
beslutning, stille et spørgsmål, gøre indtryk på).
Fields: `pattern` showing how it is used, e.g. "tage hensyn til noget/nogen", "i forhold til noget".
Not idioms with figurative meaning (that's udtryk).

### udtryk — 1000 idiomatic expressions (idiomer, talemåder, faste vendinger med overført betydning)
e.g. "slå to fluer med ét smæk", "have en finger med i spillet", "tage tyren ved hornene",
"det er ikke min kop te", "skyde genvej". Only expressions an educated Dane would recognise today.
Fields: `literal` (word-for-word English, so the image is clear), `meaning_da` (short Danish
explanation), `register` "formel" | "neutral" | "uformel".

## Output and process
- Write your items to `out/<deck>-<part>.json` as {"deck": "...", "items": [ ... ]}.
- Work in batches of ~100 and append (python), so nothing is lost if you are interrupted.
- After each batch run `python3 validate.py out/<your file>` and fix everything it reports.
- At the end, re-read a random 60 items critically (meaning right? example natural? level
  sensible? really in use?) and fix or delete bad ones.
