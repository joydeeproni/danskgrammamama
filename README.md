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
- **Daily goal, streak, per-topic mastery**, and a timed 20-question exam paper.
- **Writing practice** checked offline by grammar rules and, where the device
  supports it, by Apple's on-device model. Nothing leaves the phone.

## Install on your iPhone

Requirements: a Mac with Xcode 16 or newer, an iPhone on iOS 17 or newer, and an
Apple ID. The AI features additionally need iOS 26 and an iPhone that supports Apple
Intelligence; everything else works without them.

1. Open `DanskGrammaMama.xcodeproj` in Xcode.
2. Select the `DanskGrammaMama` target → **Signing & Capabilities**, tick
   **Automatically manage signing** and choose your team. Do the same for the
   `DanskOrdWidgetExtension` target.
   If Xcode says the bundle identifier is taken, change `PRODUCT_BUNDLE_IDENTIFIER`
   on both targets, keeping the widget's id prefixed by the app's.
3. Plug in your iPhone, pick it as the run destination, and press **Run** (⌘R).
4. On the phone: Settings → General → VPN & Device Management → trust your certificate.

With a free Apple ID the app expires after 7 days; press Run again to reinstall.
Progress is kept.

### Making the widget show your own words

The widget reads the word diary from an App Group. Free Apple IDs cannot use App
Groups, so out of the box the widget shows a built-in starter deck of PD3 vocabulary.
To switch it to your own saved words (needs a paid developer account):

1. In **Signing & Capabilities**, add the **App Groups** capability to both targets
   and enable `group.dk.joydeep.danskgrammamama` on each. `DanskGrammaMama.entitlements`
   and `DanskOrdWidget.entitlements` in the repo already contain that group.
2. If you changed the bundle identifier, change the group id to match in both
   entitlements files, in `FlashcardStore.appGroup`, and in `SharedFlashcards.appGroup`.

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
