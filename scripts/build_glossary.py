#!/usr/bin/env python3
"""Build Content/glossary.json from the glossary_*.txt sources plus verbs_list.json.

Produces:
  entries: lemma -> {word, class, article, en}
  forms:   inflected form -> lemma   (verb paradigms, noun inflections, irregular plurals)
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
CONTENT = os.path.join(HERE, "..", "DanskGrammaMama", "Content")

entries = {}   # lemma -> dict
forms = {}     # form -> lemma

def add_form(form, lemma):
    f = form.lower()
    if f and f not in entries and f not in forms:
        forms[f] = lemma

IRREGULAR_PLURALS = {
    "barn": ["børn", "børnene", "barnet"],
    "mand": ["mænd", "mændene", "manden"],
    "hånd": ["hænder", "hænderne", "hånden"],
    "fod": ["fødder", "fødderne", "foden"],
    "tand": ["tænder", "tænderne", "tanden"],
    "bog": ["bøger", "bøgerne", "bogen"],
    "nat": ["nætter", "nætterne", "natten"],
    "øje": ["øjne", "øjnene", "øjet"],
    "menneske": ["mennesker", "menneskene", "mennesket"],
    "forælder": ["forældre", "forældrene"],
    "kollega": ["kolleger", "kollegerne", "kollegaen"],
    "regel": ["regler", "reglerne", "reglen"],
    "kursus": ["kurser", "kurserne", "kurset"],
    "år": ["året", "årene"],
    "tilbud": ["tilbuddet", "tilbuddene"],
    "krav": ["kravet", "kravene"],
    "forhold": ["forholdet", "forholdene"],
    "sted": ["stedet", "stederne", "steder"],
    "voksen": ["voksne", "den voksne"],
    "lille": ["små", "lilla"],
    "gammel": ["gamle", "gammelt", "ældre", "ældst"],
    "stor": ["stort", "store", "større", "størst"],
    "god": ["godt", "gode", "bedre", "bedst"],
    "lang": ["langt", "lange", "længere", "længst"],
    "få": ["færre", "færrest"],
    "mange": ["flere", "flest", "meget", "mere", "mest"],
}

# --- nouns -------------------------------------------------------------
for line in open(os.path.join(HERE, "glossary_nouns.txt"), encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    word, article, en = line.split("|", 2)
    entries[word.lower()] = {"word": word, "class": "substantiv", "article": article, "en": en}

# --- other word classes ------------------------------------------------
CLASS_NAMES = {"adj": "adjektiv", "adv": "adverbium", "prep": "præposition",
               "pron": "pronomen", "conj": "konjunktion", "num": "talord", "other": ""}
for line in open(os.path.join(HERE, "glossary_other.txt"), encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    cls, word, en = line.split("|", 2)
    entries.setdefault(word.lower(), {"word": word, "class": CLASS_NAMES.get(cls, ""), "article": "", "en": en})

# --- verbs -------------------------------------------------------------
verb_en = {}
for line in open(os.path.join(HERE, "glossary_verbs.txt"), encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    word, en = line.split("|", 1)
    verb_en[word] = en

paradigms = json.load(open(os.path.join(CONTENT, "verbs_list.json"), encoding="utf-8"))["verbs"]
by_inf = {v["infinitive"]: v for v in paradigms}

for word, en in verb_en.items():
    v = by_inf.get(word)
    note = ""
    if v:
        note = f'{v["infinitive"]} – {v["present"]} – {v["past"]} – {v["auxiliary"]} {v["participle"]}'
    entries[word.lower()] = {"word": word, "class": "verbum", "article": "", "en": en, "forms": note}

# Every verb in the paradigm list maps its forms back to the infinitive,
# even when we have no English gloss: the app can still show the paradigm.
for v in paradigms:
    lemma = v["infinitive"].lower()
    if lemma not in entries:
        entries[lemma] = {"word": v["infinitive"], "class": "verbum", "article": "", "en": "",
                          "forms": f'{v["infinitive"]} – {v["present"]} – {v["past"]} – {v["auxiliary"]} {v["participle"]}'}

for v in paradigms:
    lemma = v["infinitive"].lower()
    for f in (v["present"], v["past"], v["participle"]):
        for part in f.split("/"):
            add_form(part.strip(), lemma)
    # passive -s forms
    stem = v["infinitive"].split(" ")[0]
    add_form(stem + "s", lemma)
    add_form(v["present"] + "s", lemma)

# --- generated noun / adjective inflections ----------------------------
for lemma, e in list(entries.items()):
    if e["class"] == "substantiv":
        base = lemma
        art = e.get("article")
        # A noun ending in -er (agent noun) pluralises with -e / -ne: lærer, lærere, lærerne.
        agent = base.endswith("er")
        # Short word, single vowel + single consonant: the consonant doubles (antal -> antallet).
        doubled = base + base[-1] if (len(base) >= 3 and base[-1] not in "aeiouyæøå"
                                      and base[-2] in "aeiouyæøå" and base[-3] not in "aeiouyæøå") else None
        for stem in filter(None, [base, doubled]):
            if art == "en":
                add_form(stem + ("n" if stem.endswith("e") else "en"), lemma)
                add_form(stem + ("r" if stem.endswith("e") else "e" if agent else "er"), lemma)
                add_form(stem + ("rne" if stem.endswith("e") else "ne" if agent else "erne"), lemma)
            elif art == "et":
                add_form(stem + ("t" if stem.endswith("e") else "et"), lemma)
                add_form(stem + ("r" if stem.endswith("e") else "e" if agent else "er"), lemma)
                add_form(stem + ("rne" if stem.endswith("e") else "ne" if agent else "erne"), lemma)
                add_form(stem + "ene", lemma)
            # -e plural is common for both genders (hus -> huse, dag -> dage)
            if not stem.endswith("e"):
                add_form(stem + "e", lemma)
                add_form(stem + "ene", lemma)
            add_form(stem + "s", lemma)      # genitive
            add_form(stem + "es", lemma)
    elif e["class"] == "adjektiv":
        base = lemma
        if not base.endswith("e"):
            add_form(base + "t", lemma)
            add_form(base + "e", lemma)
            add_form(base + "ere", lemma)
            add_form(base + "est", lemma)
            add_form(base + "este", lemma)
            # -ig and -lig adjectives keep the g: vigtig -> vigtigt, vigtige
            if base.endswith(("el", "en", "er")):
                syncopated = base[:-2] + base[-1]
                add_form(syncopated + "e", lemma)

for lemma, extra in IRREGULAR_PLURALS.items():
    if lemma in entries:
        for f in extra:
            forms[f.lower()] = lemma

out = {"entries": entries, "forms": forms}
path = os.path.join(CONTENT, "glossary.json")
json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
print(f"{len(entries)} entries, {len(forms)} inflected forms -> {os.path.basename(path)}")

# Coverage report against the question bank
import glob, re, collections
seen = collections.Counter()
for p in glob.glob(os.path.join(CONTENT, "*.json")):
    if "guide_" in p or "verbs_list" in p or "glossary" in p: continue
    d = json.load(open(p, encoding="utf-8"))
    for q in d["questions"]:
        text = q["prompt"] + " " + " ".join(b["answer"] for b in q.get("blanks", []) if isinstance(b, dict))
        if q.get("answer"): text += " " + q["answer"]
        for w in re.findall(r"[a-zA-ZæøåÆØÅ]+", text.lower()):
            if len(w) > 2: seen[w] += 1
known = sum(c for w, c in seen.items() if w in entries or w in forms)
total = sum(seen.values())
print(f"coverage: {known}/{total} word occurrences = {100*known/total:.1f}%")
missing = [(c, w) for w, c in seen.items() if w not in entries and w not in forms]
missing.sort(reverse=True)
print("top uncovered:", " ".join(w for c, w in missing[:60]))
