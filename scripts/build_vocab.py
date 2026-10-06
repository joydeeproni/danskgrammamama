#!/usr/bin/env python3
"""Merge the vocabulary deck parts into the app's content files.

Inputs: scripts/vocab_parts/<deck>-<part>.json (written to SPEC.md in that folder).
Outputs: DanskGrammaMama/Content/vocab_{words,phrases,fixed,udtryk}.json

- removes duplicates within a deck (words: same class and lemma; others: same text)
  and across decks (an item already in an earlier deck is dropped from a later one)
- drops crude language that is not useful exam vocabulary
- orders cards so a new learner meets the most useful first: words by frequency rank,
  other decks B2 → C1 → C2 with their parts interleaved
"""
import glob, json, os, re, sys, unicodedata
from itertools import zip_longest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "scripts", "vocab_parts")
DST = os.path.join(ROOT, "DanskGrammaMama", "Content")

# Checked before the other decks, so a shared item stays where it is most useful.
DECK_ORDER = ["words", "fixed", "phrases", "udtryk"]
CRUDE = re.compile(r"\b(røv\w*|skid\w*|pis\w*|sgu|fanden|satan\w*|lort\w*|fuck\w*)\b", re.I)
LEVEL = {"B2": 0, "C1": 1, "C2": 2}


def norm(text):
    text = unicodedata.normalize("NFC", text.lower()).replace("…", "")
    return re.sub(r"[^a-zæøå ]+", "", text).strip()


def load(deck):
    parts = []
    for path in sorted(glob.glob(os.path.join(SRC, f"{deck}-*.json"))):
        with open(path, encoding="utf-8") as f:
            parts.append(json.load(f)["items"])
    return parts


def interleave(parts):
    """B2 items of every part first, then C1, then C2; parts alternate within a level."""
    out = []
    for level in ("B2", "C1", "C2"):
        lists = [[it for it in p if it.get("level") == level] for p in parts]
        for row in zip_longest(*lists):
            out.extend(it for it in row if it is not None)
    return out


def main():
    taken = set()
    report = []
    for deck in DECK_ORDER:
        parts = load(deck)
        if not parts:
            print(f"{deck}: no parts yet", file=sys.stderr)
            continue
        if deck == "words":
            items = [it for p in parts for it in p]
            # B2 before C1 before C2; within a level the most frequent first. The frequency
            # list is spoken Danish, so written words without a rank go after the ranked ones.
            items.sort(key=lambda it: (LEVEL.get(it["level"], 1), it.get("rank") or 100000))
        else:
            items = interleave(parts)
        kept, crude, dupes = [], 0, 0
        seen = set()
        for it in items:
            text = it["da"] + " " + it["example"]["da"]
            if CRUDE.search(text):
                crude += 1
                continue
            key = (it.get("class"), norm(it["da"])) if deck == "words" else norm(it["da"])
            cross = norm(it["da"])
            if key in seen or (deck != "words" and cross in taken):
                dupes += 1
                continue
            seen.add(key)
            kept.append(it)
        taken |= {norm(it["da"]) for it in kept}
        with open(os.path.join(DST, f"vocab_{deck}.json"), "w", encoding="utf-8") as f:
            json.dump({"deck": deck, "items": kept}, f, ensure_ascii=False, separators=(",", ":"))
        levels = {lv: sum(1 for it in kept if it["level"] == lv) for lv in LEVEL}
        report.append(f"{deck:8} {len(kept):5} kept  ({dupes} duplicates, {crude} crude dropped)  {levels}")
    print("\n".join(report))


if __name__ == "__main__":
    main()
