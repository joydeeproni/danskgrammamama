# Dansk grammatik – PD3 practice app

A minimalist iOS app for the grammar Prøve i Dansk 3 (CEFR B2) actually tests:
verb forms, noget/nogen/nogle, prepositions, singular/plural, den/det/de/dem/disse,
connectors (Delprøve 3 style), word order, adjectives with sin/hans, and der/som/hvad
plus the formal register the written exam rewards.

## What's in it

- **358 questions**, all multiple choice, across nine topics and two levels.
  Every question has an explanation in English and Danish.
- **Multi-gap items**: 54 level-2 texts with two or more gaps, including short
  paragraphs in the style of Læseforståelse Delprøve 3.
- **Instant feedback**: tap an option and the verdict, the correct answer and the
  reason appear at once, with the sentence redrawn showing your word struck through
  next to the right one.
- **Tap any word** in an exercise to see what it means. Underlined words are the ones
  the app can explain. Keeping a word adds it to your word diary.
- **Flashcards and a home-screen widget** built from the words you kept. The widget
  shows a new word every hour with a button that reveals the meaning.
- **How to crack this topic**: each topic has a guide with the rules, a usable exam
  hack per rule, worked examples and the classic traps.
- **Verb drill** generated from the 500-verb study list.
- **Spaced repetition**: a miss returns after 1 day, then 3 days, until you get it
  right twice. Sessions lean toward your weakest topics.
- **One daily set**: the app counts down to your exam date, shows how ready you are
  across the nine topics, and builds today's set from due reviews, your weakest topic
  and new questions. No tabs: Today is the top card of a deck; topics, words and this
  week's mock paper and writing task are smaller stacks beside it.
- **Per-topic readiness, streak**, and a timed 20-question mock paper.
- **Light and dark mode**, set in Settings or following the system. Type is Schibsted
  Grotesk and Source Serif 4 (SIL Open Font License, in `Resources/Fonts`).
- **Writing practice** checked offline by grammar rules and, where the device
  supports it, by Apple's on-device model. Nothing leaves the phone.

## Install on your iPhone

Requirements: a Mac with Xcode 16 or newer, an iPhone on iOS 17 or newer, and an
Apple ID. The AI features additionally need iOS 26 and an iPhone that supports Apple
Intelligence; everything else works without them.

1. Open `DanskGrammaMama.xcodeproj` in Xcode.
2. Signing is set up for team `JQMKQ2K7JR` with automatic signing, and both targets
   carry the `group.dk.joydeep.danskgrammamama` App Group, so the widget shows your
   own saved words. To build under another team, change the team on both targets in
   **Signing & Capabilities**; if the bundle identifier is taken, change
   `PRODUCT_BUNDLE_IDENTIFIER` on both targets, keeping the widget's id prefixed by the app's.
3. Plug in your iPhone, pick it as the run destination, and press **Run** (⌘R).
4. On the phone: Settings → General → VPN & Device Management → trust your certificate.

With a free Apple ID the app expires after 7 days; press Run again to reinstall.
Progress is kept.

### The widget and free Apple IDs

The widget reads the word diary through the App Group. Free Apple IDs cannot use App
Groups: to build with one, remove the App Groups capability from both targets. The
widget then shows a built-in starter deck of PD3 vocabulary instead of your own words.

## Project layout

```
DanskGrammaMama/
  App/        entry point
  Models/     Question (one or more gaps), Topic, TopicGuide, GlossaryEntry, Flashcard
  Engine/     ContentStore, ProgressStore (spaced repetition), SessionBuilder,
              AnswerChecker, VerbDrill, Glossary (Danish→English lookup),
              FlashcardStore, WritingChecker (offline grammar rules)
  AI/         DanishTutor – Foundation Models wrapper, availability-gated
  Views/      SwiftUI screens, FlowLayout and SentenceView for tappable words
  Content/    <topic>.json, cloze_<topic>.json, guide_<topic>.json,
              glossary.json, verbs_list.json
DanskOrdWidget/   home-screen widget
scripts/      validate_content.py, build_glossary.py, build_verbs.py + sources
docs/         CONTENT_SCHEMA.md – how to write more questions, texts and guides
```

Both targets use synchronised folders, so new files dropped into `DanskGrammaMama/`
or `DanskOrdWidget/` are picked up automatically.

## Working on the content

```
python3 scripts/validate_content.py     # checks every question against the schema
python3 scripts/build_glossary.py       # rebuilds glossary.json and reports coverage
python3 scripts/build_verbs.py          # rebuilds verbs_list.json from the verb list
```

The glossary covers 86% of the word occurrences in the question bank directly. The app
resolves the rest at runtime by stripping genitives and inflections and by looking up
the head of a compound, and falls back to the on-device model for anything left.

## Notes on the content

Questions were written to the level of the Sommer 2023 PD3 papers but are original:
no exam text is reused. Where standard Danish allows two answers, the distractors are
chosen so that exactly one option is right, and the explanation says what else would
have worked.
