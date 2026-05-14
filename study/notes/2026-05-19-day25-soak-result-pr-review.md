# Day 25 — mc-w9iua4 soak result + PR #2136 review status

- **Plan authored:** 2026-05-14 (Day-24 evening, immediately after Day-24 close)
- **Planned execution:** 2026-05-19
- **Earliest sensible execution:** 2026-05-15 15:16 PT (when the 24h soak window closes)
- **Status:** Plan only.

Day-24 shipped PR #2136 (retry-with-backoff for `mol-dog-jsonl` push race) and started a 24h soak baseline. Day-25 reads what happened in both lanes — the soak measurement and the upstream review — then decides whether mc-w9iua4 can close.

This is a **read-day shape** — pure measurement + decision, no new fixes unless something unexpected surfaces. Budget ~45 min.

---

## 1. What Day-25 reads

### A. Soak result (mc-w9iua4)

The 24h soak window: `2026-05-14T22:16:17Z UTC` → `2026-05-15T22:16:17Z UTC` (15:16 PT 5/14 → 15:16 PT 5/15).

**Important caveat carried over from Day-24:** the city runs the UNPATCHED `jsonl-export.sh` (the fix is only in the PR branch, not installed locally). So the soak measures the **baseline failure rate of the current state**, not the fix's effectiveness.

Two things to check:

1. **mol-dog-jsonl exit-1 count** in the soak window. Day-23 saw 3 in 18h (≈1/6h). If today shows similar, the rate estimate is confirmed. If 0, the rate is actually much lower than thought.
2. **mol-dog-compactor exit-1 recurrence** (the Day-24 pre-flight surprise — first-ever compactor exit-1 at 08:04:16 PT, coincided with my bd_create write contention). If it recurs in soak → file a separate bead. If single-shot → write off as one-time noise.

```bash
# Count + categorize failures in soak window
gc events --type order.failed --since 25h 2>/dev/null \
  | jq -r 'select(.ts >= "2026-05-14T22:16:17Z") | "\(.ts)\t\(.subject)\t\(.message | gsub("\n";" ") | .[:60])"' \
  | sort

# Total count delta (was 84 at soak start)
grep -c '"type":"order.failed"' .gc/events.jsonl
```

### B. PR #2136 review status

Day-24 G4 predicted: merges within 7 days, likely 24-48h (per PR #2037 cadence).

```bash
gh pr view 2136 --repo gastownhall/gascity --json state,reviewDecision,statusCheckRollup,comments,mergeable
```

Three outcomes:
- **Merged:** confirm soak result + close mc-w9iua4 as `fixed via PR #2136 + 24h soak shows N failures (vs N expected)`
- **Approved, awaiting merge:** wait. Day-25 closes with "review approved, merge pending"
- **Changes requested:** read review comments, address inline (per §24 playbook)
- **No review yet:** check CI; if green, leave a brief nudge comment per §24

---

## 2. Decision matrix

| Soak result | PR status | Action |
|---|---|---|
| 0 mol-dog-jsonl exit-1 | merged | Close mc-w9iua4 as `fixed`; PR #2136 is the third upstream contribution to land |
| 0 mol-dog-jsonl exit-1 | open | Note that baseline rate is lower than thought; mc-w9iua4 stays OPEN until fix lands upstream + city upgrades + 24h post-install soak shows 0 |
| 1-3 mol-dog-jsonl exit-1 | merged | Close mc-w9iua4 once city upgrades to the new pack and a fresh 24h soak shows 0 |
| 1-3 mol-dog-jsonl exit-1 | open | Same as above — wait for upstream + reinstall |
| ≥4 mol-dog-jsonl exit-1 | any | Rate is HIGHER than thought. Re-evaluate. May need fix (3) flock or (4) stagger sooner. Update mc-w9iua4 + PR if needed. |
| mol-dog-compactor recurs | any | File separate bead. Don't merge with mc-w9iua4. |

---

## 3. G-predictions to check

- **G3 (Day-24): retry-with-backoff drops 24h rate to 0** — Day-25 can only PARTIALLY check this. The city isn't running the fix yet, so this G is technically still unmeasurable until upstream+install. What Day-25 CAN check: whether the baseline rate matches the Day-23 estimate.
- **G4 (Day-24): PR merges within 7 days** — Day-25 reads first datapoint (24h mark). Full check Day-26+.

---

## 4. Anti-plans

- **Don't open a second PR if review is still pending.** sjarmak's cadence on small fixes is fast; give it time.
- **Don't expand mc-w9iua4 scope** if mol-dog-compactor recurs — file separately.
- **Don't run another trace arm** unless the soak surfaces a NEW failure mode worth investigating. Day-24 confirmed arms are imprecise for this firing pattern; spending another 4h on a wrong-window arm is the trap.
- **Don't fold §22 footnotes today** — that's tour-day work. Day-25 is read-day, narrow scope.

---

## 5. Possible outputs

Depending on what Day-25 reads:

- **Best case:** mc-w9iua4 closes, PR merges, +1 upstream contribution counter (would be the 4th: #2037 merged, #1487 comment, #3880 comment, #2088 open, **#2136 merged**)
- **Median case:** soak result documented, PR still in review, mc-w9iua4 stays OPEN pending upstream + upgrade
- **Worst case:** soak surfaces a NEW failure mode (e.g. mol-dog-compactor recurrence) → file new bead, Day-25 ends with a deferral note

---

## 6. Execution log

(filled in on 2026-05-15 or whenever Day-25 actually runs)

### Soak result

- Window start: 2026-05-14T22:16:17Z
- Window end:
- Failures in window:
  - mol-dog-jsonl: ____
  - mol-dog-compactor: ____
  - other: ____

### PR #2136 status

- state:
- review decision:
- CI status:
- merge decision:

### G3 / G4 verdicts

- G3 (24h rate validation):
- G4 (PR merges <7 days):

### Decisions made

- mc-w9iua4 status:
- New beads filed:
- Any §22/§23/§24 candidates to queue:

### Surprises

(filled in as encountered)
