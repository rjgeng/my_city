# Day 35 — mc-jhsp8y writer-signature discriminator test

- **Plan authored:** 2026-05-24 PM (end of Day-34; inherited from Day-34 §6 Step 4 punt)
- **Planned execution:** 2026-05-25
- **Status:** Plan stamped. Morning read goes into §6 Step 1 on execution.

Day-35 is a **single-hypothesis test day**. Day-34 surfaced a sharp discriminator between Day-33's clean fire and Day-34's marker recurrence: whether a hq-writing scheduled order fires inside the compactor's flatten window. Today tests that hypothesis directly. No new investigation scope; one G1 prediction; ambient G3 + G2.

---

## 1. Pre-flight context (brief)

**State at Day-34 EOD (2026-05-24):**

- **mc-jhsp8y:** OPEN, characterized-candidate stage. n=2 marker recurrences (Day-31, Day-34) with identical reason `post-flatten value hash changed with row-count increase`; n=1 clean (Day-33). Day-34 marker archived to `/tmp/mc-jhsp8y-day34-marker-archived-20260524-0949.txt` and cleared. Quarantine dir empty.
- **mc-w9iua4:** CLOSED Day-34 (PR #2136 merged 03:57 PT 5/24).
- **mc-1zccc2, mc-4m2da1, mc-iho25h, mc-z92fpi:** OPEN, awaiting mc-jhsp8y resolution.
- **mc-mxl4vc:** OPEN, blocked on beads v1.0.5.
- **PR #2136:** MERGED (no longer watched).
- **PR #2316, #2088:** stable post-merge.
- **gc binary:** HEAD-fad5d3f. Supervisor PID 30349 alive since 2026-05-24 04:33:35 PT (~28h continuous by Day-35 ~08:55 PT, assuming anti-plan #15 holds — laptop stayed awake + no `gc init`/upgrade/cities/supervisor/dashboard restart anywhere on machine).
- **Pending deferred work:** bead at `/tmp/bead-draft-gc-init-silent-supervisor-cycle.md` ready to file post-fire; co_thinking/co_ops rig additions deferred to post-Day-36-EOD.

**Carry-forward (the load-bearing ones):**

- Day-34 lesson #1: sharpen, don't abandon hypotheses on inconvenient data.
- Day-34 lesson #2: demote, don't keep load-bearing — patch plans before tests, not after.
- Day-33 lesson #6 + Day-34 lesson #7: supervisor-age confound + gc machine-global restart hazard. G2 still demoted today; load-bearing G2 returns earliest Day-36.

---

## 2. Execution sequence

### Step A — No clearance needed (quarantine dir already empty)

### Step 1 — Morning read (5/25 ~09:00 PT)

```bash
date; gc version; ps -o pid,etime,command -p 30349   # expect ~28h continuous

# Today's compactor events
grep -E '"type":"order\.(fired|completed|failed)"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-25T00:00:00")) | "\(.ts)  \(.type)  \(.message // "-")"'

# Quarantine state — race fired or not?
ls -la .gc/runtime/packs/dolt/compact-quarantine/
for f in .gc/runtime/packs/dolt/compact-quarantine/*; do
  [ -f "$f" ] && echo "=== $(basename $f) ===" && cat "$f" && echo
done

# THE LOAD-BEARING DATA — mol-dog-doctor fire timing relative to compactor flatten window
# Substitute actual compactor fire timestamps once known:
grep -E '"type":"order\.(fired|completed|failed)"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-doctor") and (.ts >= "2026-05-25T08:00:00")) | "\(.ts)  \(.type)"'

# Concurrent hq-writing actors during compactor flatten window
grep -E '"ts":"2026-05-25T08:[45]' .gc/events.jsonl \
  | jq -r 'select(.type | test("bead\\.|order\\.")) | "\(.ts)  \(.type)  \(.actor // "-")  \(.subject // "-")"' \
  | head -60

# Standard ambient watches (G3 only; PR-watch is empty post-#2136-merge)
gh release list --repo gastownhall/beads --limit 3
bd list 2>/dev/null | grep -E 'mc-(jhsp8y|1zccc2|4m2da1|mxl4vc|z92fpi|iho25h)'
```

### Step 2 — Branch selection per §3 matrix

### Step 3 — EOD recheck + bead update (mc-jhsp8y only)

### Step 4 — Day-36 punt

---

## 3. Decision matrix (2×2 on the load-bearing hypothesis)

Day-34 §Surprises #1 hypothesis: **the race fires iff at least one hq-writing scheduled order (most likely `mol-dog-doctor`) fires INSIDE the compactor's flatten window.**

| Doctor fire timing | Compact outcome | Branch | Verdict |
|---|---|---|---|
| INSIDE flatten window (Day-34-like) | Marker (same reason) | **(a) Confirms — modal** | Hypothesis holds. Open fix-shape design bead at P3 targeting either flatten-cycle retry or doctor-fire deferral during compact. |
| OUTSIDE flatten window (Day-33-like) | Clean (exit-0) | **(b) Confirms — modal** | Hypothesis holds (other direction). Continue observation; one more contradicting data point in either direction tightens further. |
| INSIDE flatten | Clean | (c) Falsifies | Doctor-fire-in-flatten is NOT sufficient. Hypothesis weakens; need to find the *additional* condition that Day-34 had and (c) lacked. Reverts to "evidence-record" stage. |
| OUTSIDE flatten | Marker | (d) Falsifies | Doctor-fire-in-flatten is NOT necessary. Other writers can trigger. Hypothesis weakens; widen to look at witness or controller activity correlation. |

**Modal expectation:** (a) ~35%, (b) ~35%, (c) ~15%, (d) ~15%. Either of (a)/(b) confirms the hypothesis (~70% combined); either of (c)/(d) falsifies it (~30%).

The clean 2×2 here is intentional — the goal is a discriminating test, not coverage of all possible outcomes.

---

## 4. Falsifiable predictions

**G1 is the ONLY load-bearing prediction today.**

- **G1 (writer-signature discriminator):**
  - *Field:* On Day-35, observe `mol-dog-doctor` fire timestamp and `mol-dog-compactor` fire/complete/fail timestamps. Test whether doctor's fire is contained in `[compactor.fired, compactor.completed_or_failed]`. Cross-tabulate with marker presence in `.gc/runtime/packs/dolt/compact-quarantine/`.
  - *Generator:* Day-34 §Surprises #1 — `mol-dog-doctor` writes 5+ bead events to hq during its fire; if that lands mid-compactor-flatten, the post-flatten value-hash check sees row-count growth and quarantines.
  - *Falsifier:* either (c) or (d) in the §3 matrix.

- **G2 (supervisor-age, ambient):**
  - *Field:* If anti-plan #15 held overnight, supervisor PID 30349 should be ~28h continuous at fire time. Record fire timestamp as data point for the new 3-point sequence (Day-34 ~4h, Day-35 ~28h, Day-36 ~52h).
  - *Falsifier:* PID changed or etime reset → restart happened, reset to Day-37 baseline.

- **G3 (beads release, ambient):**
  - *Field:* v1.0.4 stays latest. mc-mxl4vc remains blocked.
  - *Falsifier:* v1.0.5 ships.

---

## 5. Anti-plans

**Inherited (still apply):**

1. Don't re-arm `gastown.deacon`.
2. Don't open new PRs (the gc-init-silent-cycle bead at `/tmp/` can be FILED today since fire is past, but no PR yet).
3. ~~Don't preemptively rebase #2136~~ — N/A, merged.
4. ~~Don't nudge #2136~~ — N/A, merged.
5. Local-time prefix when greping `events.jsonl`.
6. Watch-day must produce an artifact.
7. Verb layer-disambiguation before structural conclusions.
8. No flatten-cycle-retry PR (design bead only, after fix-shape decision).
9. Don't unlatch `hold-until-soak` labels — soak still active (and mc-jhsp8y still open).
10. Preserve archived markers in `/tmp` (Day-31 + Day-34).
11. No fix-shape design today unless §3 branch (a) confirms cleanly.
12. ~~Don't characterize drift on a single Day-34 data point~~ — N/A, G2 demoted.
13. If §3 branch (a) fires (marker), archive + clear (don't preserve).
14. ~~Don't widen scope to writer-routing today~~ — Day-35 IS the routing/timing investigation, so this anti-plan is now FULFILLED, not violated.
15. **LOAD-BEARING (generalized): no laptop sleep, no `gc init` / upgrade / cities / supervisor / dashboard restart anywhere on machine, no binary swap, no killing supervisor/dolt-server PIDs.** Hold through Day-36 fire (~5/26 08:50 PT). Step 1 morning read MUST verify PID 30349 etime first.

**New for Day-35:**

16. **Test the hypothesis as written; don't reframe mid-flight.** If §3 branch (c) or (d) fires (falsification), accept the falsification and update the bead — do NOT salvage the hypothesis by adding epicycles. Falsification is information.
17. **Don't fold the gc-init-silent-cycle bead into mc-jhsp8y or any compactor work** — they're orthogonal concerns. File separately.

---

## 6. Execution log

### Step A: no clearance needed (DONE — quarantine dir empty entering Day-35)

### Step 1: morning read (pending — execute 5/25 ~09:00 PT)

### Step 2: branch selection per §3 matrix (pending)

### Step 3: EOD recheck + bead update (pending)

### Step 4: Day-36 punt (pending)

---

### G1–G3 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
