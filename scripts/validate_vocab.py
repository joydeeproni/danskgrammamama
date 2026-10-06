#!/usr/bin/env python3
"""Validate vocabulary deck files. Usage: validate.py out/words-verbs.json [more files]"""
import json, re, sys, unicodedata

LEVELS = {"B2", "C1", "C2"}
CLASSES = {"verbum", "adjektiv", "adverbium", "konjunktion", "præposition", "pronomen", "interjektion"}
REGISTERS = {"formel", "neutral", "uformel"}
EXTRA = {
    "words": ["class", "forms", "rank"],
    "phrases": ["use", "register"],
    "fixed": ["pattern"],
    "udtryk": ["literal", "meaning_da", "register"],
}

def norm(s):
    s = unicodedata.normalize("NFC", s.lower()).replace("…", "").replace("...", "")
    return re.sub(r"[^a-zæøå ]+", "", s).strip()

def check(path):
    errors, warnings = [], []
    data = json.load(open(path, encoding="utf-8"))
    deck = data.get("deck")
    if deck not in EXTRA:
        return [f"{path}: deck must be one of {list(EXTRA)}"], []
    seen = {}
    for n, it in enumerate(data.get("items", [])):
        where = f"{path}#{n} {it.get('da', '?')!r}"
        for f in ["da", "en", "example", "level"] + EXTRA[deck]:
            if f not in it:
                errors.append(f"{where}: missing {f}")
        if not isinstance(it.get("da"), str) or not it.get("da", "").strip():
            errors.append(f"{where}: empty da"); continue
        if it.get("level") not in LEVELS:
            errors.append(f"{where}: level {it.get('level')!r}")
        ex = it.get("example") or {}
        if not ex.get("da") or not ex.get("en"):
            errors.append(f"{where}: example needs da and en")
        else:
            words = len(ex["da"].split())
            if words < 4 or words > 24:
                warnings.append(f"{where}: example has {words} words")
            if not re.search(r"[.!?»]$", ex["da"].strip()):
                warnings.append(f"{where}: example should end with punctuation")
        if len(it.get("en", "")) > 70:
            warnings.append(f"{where}: en is long ({len(it['en'])} chars)")
        if "..." in it["da"]:
            errors.append(f"{where}: use … (U+2026), not ...")
        if deck == "words":
            if it.get("class") not in CLASSES:
                errors.append(f"{where}: class {it.get('class')!r} (no nouns!)")
            if " " in it["da"].strip() and not it["da"].endswith(" sig"):
                warnings.append(f"{where}: multi-word entry in words deck")
            if it.get("class") == "verbum" and "–" not in it.get("forms", ""):
                errors.append(f"{where}: verb forms should be 'nutid – datid – perfektum'")
        if deck in ("phrases", "udtryk") and it.get("register") not in REGISTERS:
            errors.append(f"{where}: register {it.get('register')!r}")
        # Words may repeat across classes (faktisk: adjective and adverb).
        key = (it.get("class"), norm(it["da"])) if deck == "words" else norm(it["da"])
        if key in seen:
            errors.append(f"{where}: duplicate of #{seen[key]}")
        seen[key] = n
    return errors, warnings

if __name__ == "__main__":
    total_e = 0
    for p in sys.argv[1:]:
        e, w = check(p)
        total_e += len(e)
        n = len(json.load(open(p, encoding="utf-8")).get("items", []))
        print(f"{p}: {n} items, {len(e)} errors, {len(w)} warnings")
        for m in e[:40]: print("  ERROR", m)
        for m in w[:15]: print("  warn ", m)
    sys.exit(1 if total_e else 0)
