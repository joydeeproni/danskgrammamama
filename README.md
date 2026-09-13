# Dansk grammatik – PD3 quiz app

A minimalist iOS app for practising the grammar that Prøve i Dansk 3 (CEFR B2) tests:
verb forms, noget/nogen/nogle, prepositions, singular/plural, den/det/de/dem/disse,
connectors (Delprøve 3 style), word order, adjectives and sin/hans, der/som/hvad and formal register.

- 304 hand-written fill-in-the-blank questions (multiple choice and typed), two levels, each with an explanation in English and Danish.
- Verb drill generated from the 500-verb study list (`Content/verbs_list.json`).
- Spaced repetition: a miss comes back after 1 day, then 3 days, until answered correctly twice.
- Daily goal and streak, per-topic mastery bars, timed 20-question exam mode.
- On-device AI (Apple Foundation Models) explains *your* specific mistake and corrects free writing. Nothing leaves the phone. Everything else works without it.

## Install on your iPhone

Requirements: a Mac with Xcode 16 or newer (Xcode 26 for the AI features), an iPhone on iOS 17 or newer,
and a free Apple ID. AI features additionally need iOS 26 and an iPhone that supports Apple Intelligence
(iPhone 15 Pro or newer) with Apple Intelligence turned on.

1. Clone this repository and open `DanskGrammaMama.xcodeproj` in Xcode.
2. Select the `DanskGrammaMama` target → **Signing & Capabilities**.
   Tick **Automatically manage signing** and pick your personal team (add your Apple ID under Xcode → Settings → Accounts if needed).
   If Xcode complains that the bundle identifier is taken, change `PRODUCT_BUNDLE_IDENTIFIER` to something unique, e.g. `dk.yourname.danskgrammamama`.
3. Plug in your iPhone, choose it as the run destination, and press **Run** (⌘R).
4. First launch on the phone: Settings → General → VPN & Device Management → trust your developer certificate.
5. With a free Apple ID the app expires after 7 days; just press Run again to reinstall (progress is kept).
   With a paid developer account you can instead archive and distribute through TestFlight.

Optional: turn on Developer Mode on the phone if Xcode asks (Settings → Privacy & Security → Developer Mode).

## Project layout

```
DanskGrammaMama/
  App/        entry point
  Models/     Question, Topic, Verb
  Engine/     ContentStore (JSON loading), ProgressStore (persistence + spaced repetition),
              SessionBuilder (session/exam assembly), AnswerChecker, VerbDrill
  AI/         DanishTutor – Foundation Models wrapper, availability-gated (iOS 26+)
  Views/      SwiftUI screens
  Content/    one JSON file per topic + verbs_list.json
scripts/      validate_content.py (schema check), build_verbs.py (rebuilds verbs_list.json)
docs/         CONTENT_SCHEMA.md – how to write more questions
```

The Xcode project uses a synchronised folder, so new `.swift` or `.json` files dropped into `DanskGrammaMama/` are picked up automatically.

## Adding questions

Edit or add to the JSON files in `DanskGrammaMama/Content/` following `docs/CONTENT_SCHEMA.md`, then run:

```
python3 scripts/validate_content.py
```

## Notes on the content

Questions were written to the level of the Sommer 2023 PD3 papers (Læseforståelse Delprøve 3, Skriftlig fremstilling)
but are original: no exam text is reused. Where standard Danish genuinely allows two forms (e.g. der/som as subject,
nogen/nogle in plural questions), typed items accept both and the explanation says so.
