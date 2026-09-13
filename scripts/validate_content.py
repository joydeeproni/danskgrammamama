#!/usr/bin/env python3
"""Validate all question JSON files against docs/CONTENT_SCHEMA.md rules."""
import json, sys, glob, collections, re, os

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
                ex = b.get("explanation", {})
                for lang in ("en", "da"):
                    if not ex.get(lang) or len(ex[lang]) < 30: errors.append(f"{loc}#{i}: explanation.{lang} missing/too short")
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
        ex = q.get("explanation", {})
        for lang in ("en", "da"):
            if not ex.get(lang) or len(ex[lang]) < 30: errors.append(f"{loc}: explanation.{lang} missing/too short")
        if not q.get("tags"): errors.append(f"{loc}: tags missing")
        stats[(name, q.get("level"), t)] += 1
        stats[name] += 1

for k in sorted(k for k in stats if isinstance(k, str)):
    print(f"{k:14} total={stats[k]:3}  L1={stats[(k,1,'choice')]:3} L2={stats[(k,2,'choice')]:3}  cloze={stats[(k,'cloze')]:3}")
print(f"TOTAL questions: {len(ids)}")
if errors:
    print("\n".join(errors)); print(f"{len(errors)} error(s)"); sys.exit(1)
print("OK")
