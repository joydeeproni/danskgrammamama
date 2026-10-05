#!/usr/bin/env python3
"""Validate DanskGrammaMama/Content/reading.json (PD3 Læseforståelse 2 sets)."""
import os
import json, re, sys

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "DanskGrammaMama", "Content", "reading.json")
errors, warnings = [], []

def err(sid, msg): errors.append(f"[{sid}] {msg}")
def warn(sid, msg): warnings.append(f"[{sid}] {msg}")

def check_expl(sid, where, e, max_words=50):
    if not isinstance(e, dict) or set(e) != {"en", "da"}:
        err(sid, f"{where}: explanation must have exactly en/da"); return
    for lang in ("en", "da"):
        t = e[lang]
        if not isinstance(t, str) or not t.strip():
            err(sid, f"{where}: empty {lang} explanation")
        elif len(t.split()) > max_words:
            warn(sid, f"{where}: {lang} explanation has {len(t.split())} words")

def check_text(sid, where, text):
    if re.search(r"\w-\s+\w", text):
        for m in re.finditer(r"\S*\w-\s+\w\S*", text):
            ctx = m.group(0)
            # "og/eller"-style suspended compounds ("hjerte- og ...") are real Danish
            if re.search(r"-\s+(og|eller)\b", ctx): continue
            warn(sid, f"{where}: possible hyphen-linebreak artifact: {ctx!r}")
    if "MAJ-JUNI" in text.upper().replace("–", "-"):
        err(sid, f"{where}: contains MAJ-JUNI header/footer")
    for line in text.split("\n"):
        if re.fullmatch(r"\s*\d{1,3}\s*", line):
            err(sid, f"{where}: page-number-only line {line!r}")
    if re.search(r"[ \t]{2,}", text): err(sid, f"{where}: double spaces")
    if re.search(r"\n{3,}", text): err(sid, f"{where}: more than one blank line between paragraphs")
    if text != text.strip(): err(sid, f"{where}: leading/trailing whitespace")
    if re.search(r" [.,;:!?]", text): warn(sid, f"{where}: space before punctuation")
    if "\f" in text or "\x07" in text: err(sid, f"{where}: control character")

def placeholders(text): return re.findall(r"\{(\d+)\}", text)

data = json.load(open(PATH, encoding="utf-8"))
sets = data.get("sets")
if not isinstance(sets, list) or not sets: sys.exit("no sets")
ids = [s.get("id") for s in sets]
if len(ids) != len(set(ids)): errors.append(f"duplicate ids: {ids}")

for s in sets:
    sid = s.get("id", "?")
    for k in ("id", "source", "difficulty", "part2a", "part2b", "part3"):
        if k not in s: err(sid, f"missing {k}")
    if not isinstance(s.get("difficulty"), int) or not 1 <= s["difficulty"] <= 5:
        err(sid, f"difficulty out of range: {s.get('difficulty')}")

    # --- 2A
    a = s["part2a"]
    if not a.get("title"): err(sid, "2A: no title")
    check_text(sid, "2A text", a["text"])
    if placeholders(a["text"]): err(sid, "2A text contains placeholders")
    qs = a["questions"]
    if len(qs) != 3: err(sid, f"2A: {len(qs)} questions")
    for i, q in enumerate(qs, 1):
        if not q["question"].strip(): err(sid, f"2A q{i}: empty question")
        if len(q["options"]) != 3: err(sid, f"2A q{i}: {len(q['options'])} options")
        if len(set(q["options"])) != len(q["options"]): err(sid, f"2A q{i}: duplicate options")
        if not isinstance(q["answer"], int) or not 0 <= q["answer"] < len(q["options"]):
            err(sid, f"2A q{i}: answer {q['answer']} out of range")
        for o in q["options"]: check_text(sid, f"2A q{i} option", o)
        check_text(sid, f"2A q{i}", q["question"])
        check_expl(sid, f"2A q{i}", q["explanation"])

    # --- 2B
    b = s["part2b"]
    if not b.get("title"): err(sid, "2B: no title")
    check_text(sid, "2B text", b["text"])
    paras = b["text"].split("\n\n")
    gap_paras = [p for p in paras if re.fullmatch(r"\{\d+\}", p)]
    if [p for p in paras if "{" in p and not re.fullmatch(r"\{\d+\}", p)]:
        err(sid, "2B: placeholder not on its own paragraph")
    if gap_paras != ["{%d}" % n for n in range(1, 6)]:
        err(sid, f"2B: placeholders {gap_paras}")
    if sorted(b["parts"]) != list("ABCDEFG"): err(sid, f"2B: parts {sorted(b['parts'])}")
    for k, t in b["parts"].items():
        check_text(sid, f"2B part {k}", t)
        if not t.strip(): err(sid, f"2B part {k} empty")
    ans = b["answers"]
    if len(ans) != 5: err(sid, f"2B: {len(ans)} answers")
    if len(set(ans)) != len(ans): err(sid, f"2B: duplicate answer letters {ans}")
    if any(x not in "ABCDEFG" or len(x) != 1 for x in ans): err(sid, f"2B: bad letters {ans}")
    if len(b["explanations"]) != 5: err(sid, f"2B: {len(b['explanations'])} explanations")
    for i, e in enumerate(b["explanations"], 1): check_expl(sid, f"2B {i}", e)
    check_expl(sid, "2B unused", b["unused"], max_words=50)
    unused = sorted(set("ABCDEFG") - set(ans))
    for lang in ("en", "da"):
        for letter in unused:
            if not re.search(r"\b%s\b" % letter, b["unused"][lang]):
                err(sid, f"2B unused ({lang}) does not mention leftover part {letter}")

    # --- 3
    c = s["part3"]
    if not c.get("title"): err(sid, "3: no title")
    check_text(sid, "3 text", c["text"])
    ph = placeholders(c["text"])
    if ph != [str(n) for n in range(1, 9)]: err(sid, f"3: placeholders {ph}")
    if re.search(r"\(\d\)|…|\.\.\.", c["text"]): err(sid, "3: leftover gap marker like (n) or …")
    if re.search(r"\{\d\} [.,;:!?]", c["text"]): err(sid, "3: space between gap and punctuation")
    gaps = c["gaps"]
    if len(gaps) != 8: err(sid, f"3: {len(gaps)} gaps")
    for i, g in enumerate(gaps, 1):
        if len(g["options"]) != 4: err(sid, f"3 gap {i}: {len(g['options'])} options")
        if len(set(g["options"])) != 4: err(sid, f"3 gap {i}: duplicate options")
        if g["answer"] not in g["options"]: err(sid, f"3 gap {i}: answer {g['answer']!r} not in options")
        check_expl(sid, f"3 gap {i}", g["explanation"])

print(f"{len(sets)} sets checked: {', '.join(ids)}")
for w in warnings: print("WARN ", w)
for e in errors: print("ERROR", e)
if errors: sys.exit(1)
print("OK" + (f" ({len(warnings)} warnings)" if warnings else ""))
