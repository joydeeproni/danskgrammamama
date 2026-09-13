#!/usr/bin/env python3
"""Turn scripts/verbs_source.txt (from the learner's '500 verber' list) into Content/verbs_list.json."""
import json, os
src = os.path.join(os.path.dirname(__file__), "verbs_source.txt")
out = os.path.join(os.path.dirname(__file__), "..", "DanskGrammaMama", "Content", "verbs_list.json")
verbs = []
for line in open(src, encoding="utf-8"):
    line = line.strip()
    if not line: continue
    inf, nutid, datid, perf, group = line.split("|")
    aux, participle = perf.split(" ", 1)
    verbs.append({"infinitive": inf, "present": nutid, "past": datid,
                  "auxiliary": aux, "participle": participle,
                  "group": {"b1": "gruppe 1 (-ede)", "b2": "gruppe 2 (-te)", "uv": "uregelmæssig"}[group]})
json.dump({"verbs": verbs}, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(verbs), "verbs written")
