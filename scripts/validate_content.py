#!/usr/bin/env python3
"""Validate all question JSON files against docs/CONTENT_SCHEMA.md rules."""
import json, sys, glob, collections, re, os

def words(s):
    """Word count, ignoring pure symbols such as → and –."""
    return sum(1 for w in s.split() if re.search(r"\w", w))

MAX_EXPLANATION_WORDS = 25

def check_explanation(loc, ex):
    for lang in ("en", "da"):
        text = ex.get(lang, "")
        if len(text) < 15: errors.append(f"{loc}: explanation.{lang} missing/too short")
        elif words(text) > MAX_EXPLANATION_WORDS: errors.append(f"{loc}: explanation.{lang} has {words(text)} words (max {MAX_EXPLANATION_WORDS})")

ROOT = os.path.join(os.path.dirname(__file__), "..", "DanskGrammaMama", "Content")
TOPICS = {"verbs","indefinite","prepositions","number","pronouns","connectors","wordorder","adjectives","relatives"}
errors, ids = [], set()
stats = collections.Counter()

for path in sorted(glob.glob(os.path.join(ROOT, "*.json"))):
    name = os.path.basename(path)[:-5]
    is_cloze = name.startswith("cloze_")
    if is_cloze: name = name[len("cloze_"):]
    if name not in TOPICS:
        continue
    with open(path, encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            errors.append(f"{name}: invalid JSON: {e}"); continue
    if data.get("topic") != name:
        errors.append(f"{name}: topic field mismatch")
    for q in data.get("questions", []):
        qid = q.get("id", "?")
        loc = f"{name}/{qid}"
        if qid in ids: errors.append(f"{loc}: duplicate id")
        ids.add(qid)
        if is_cloze:
            if not re.fullmatch(rf"{name}-c\d{{2}}", qid): errors.append(f"{loc}: bad cloze id format")
            if q.get("topic") != name: errors.append(f"{loc}: topic mismatch")
            if q.get("level") != 2: errors.append(f"{loc}: cloze level must be 2")
            if q.get("type") != "cloze": errors.append(f"{loc}: type must be cloze")
            prompt = q.get("prompt", "")
            blanks = q.get("blanks", [])
            nums = [int(m) for m in re.findall(r"\{(\d+)\}", prompt)]
            if not blanks or len(blanks) < 2: errors.append(f"{loc}: cloze needs >= 2 blanks")
            if nums != list(range(1, len(blanks) + 1)): errors.append(f"{loc}: gap markers {nums} must be 1..{len(blanks)} in order")
            for i, b in enumerate(blanks, 1):
                opts = b.get("options"); ans = b.get("answer")
                if not isinstance(opts, list) or len(opts) != 4: errors.append(f"{loc}#{i}: needs 4 options")
                elif ans not in opts: errors.append(f"{loc}#{i}: answer not in options")
                elif len(set(opts)) != 4: errors.append(f"{loc}#{i}: duplicate options")
                check_explanation(f"{loc}#{i}", b.get("explanation", {}))
            if not q.get("tags"): errors.append(f"{loc}: tags missing")
            stats[(name, "cloze")] += 1
            stats[name] += 1
            continue
        if not re.fullmatch(rf"{name}-\d{{3}}", qid): errors.append(f"{loc}: bad id format")
        if q.get("topic") != name: errors.append(f"{loc}: topic mismatch")
        if q.get("level") not in (1, 2): errors.append(f"{loc}: level must be 1 or 2")
        t = q.get("type")
        if t != "choice": errors.append(f"{loc}: type must be choice (typed items are no longer supported)")
        prompt = q.get("prompt", "")
        if prompt.count("___") != 1: errors.append(f"{loc}: prompt must contain exactly one ___")
        ans = q.get("answer")
        if not ans or not isinstance(ans, str): errors.append(f"{loc}: missing answer")
        if t == "choice":
            opts = q.get("options")
            if not isinstance(opts, list) or len(opts) != 4: errors.append(f"{loc}: choice needs 4 options")
            elif ans not in opts: errors.append(f"{loc}: answer not in options")
            elif len(set(opts)) != 4: errors.append(f"{loc}: duplicate options")
        if t == "typed" and not q.get("hint"): errors.append(f"{loc}: typed needs hint")
        check_explanation(loc, q.get("explanation", {}))
        if not q.get("tags"): errors.append(f"{loc}: tags missing")
        stats[(name, q.get("level"), t)] += 1
        stats[name] += 1

# Topic guides: short on purpose, see docs/CONTENT_SCHEMA.md.
def check_text(loc, obj, limit):
    for lang in ("en", "da"):
        text = (obj or {}).get(lang, "")
        if not text: errors.append(f"{loc}.{lang}: missing")
        elif words(text) > limit: errors.append(f"{loc}.{lang}: {words(text)} words (max {limit})")

for topic in sorted(TOPICS):
    path = os.path.join(ROOT, f"guide_{topic}.json")
    loc = f"guide_{topic}"
    try:
        with open(path, encoding="utf-8") as f: g = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        errors.append(f"{loc}: {e}"); continue
    if g.get("topic") != topic: errors.append(f"{loc}: topic field mismatch")
    check_text(f"{loc}.intro", g.get("intro"), 15)
    sections = g.get("sections", [])
    if not 4 <= len(sections) <= 6: errors.append(f"{loc}: needs 4-6 sections, has {len(sections)}")
    for i, sec in enumerate(sections, 1):
        sl = f"{loc}.sections[{i}]"
        if "rules" in sec: errors.append(f"{sl}: use a single 'rule', not 'rules'")
        check_text(f"{sl}.title", sec.get("title"), 6)
        check_text(f"{sl}.rule", sec.get("rule"), 20)
        check_text(f"{sl}.hack", sec.get("hack"), 25)
        exs = sec.get("examples", [])
        if not 1 <= len(exs) <= 2: errors.append(f"{sl}: needs 1-2 examples")
        for j, ex in enumerate(exs, 1):
            if "**" not in ex.get("da", ""): errors.append(f"{sl}.examples[{j}]: bold the tested word")
            if words(ex.get("da", "")) > 10: errors.append(f"{sl}.examples[{j}]: {words(ex['da'])} Danish words (max 10)")
            if not ex.get("en"): errors.append(f"{sl}.examples[{j}]: missing en")
    traps = g.get("traps", [])
    if not 3 <= len(traps) <= 5: errors.append(f"{loc}: needs 3-5 traps, has {len(traps)}")
    for i, t in enumerate(traps, 1):
        check_text(f"{loc}.traps[{i}]", t, 14)
        if "✗" not in t.get("en", "") or "✓" not in t.get("en", ""): errors.append(f"{loc}.traps[{i}]: use ✗ wrong → ✓ right")

for k in sorted(k for k in stats if isinstance(k, str)):
    print(f"{k:14} total={stats[k]:3}  L1={stats[(k,1,'choice')]:3} L2={stats[(k,2,'choice')]:3}  cloze={stats[(k,'cloze')]:3}")
print(f"TOTAL questions: {len(ids)}")
if errors:
    print("\n".join(errors)); print(f"{len(errors)} error(s)"); sys.exit(1)
print("OK")
