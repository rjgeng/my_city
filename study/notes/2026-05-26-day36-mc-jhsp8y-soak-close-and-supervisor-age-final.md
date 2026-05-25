# Day 36 — mc-jhsp8y soak close + supervisor-age experiment final data point

- **Plan authored:** 2026-05-25 PM (end of Day-35; inherited from Day-35 §6 Step 4 punt)
- **Planned execution:** 2026-05-26
- **Status:** Plan stamped. Morning read goes into §6 Step 1 on execution.

Day-36 is the **final day of the supervisor-soak observation window.** Two purposes:

1. **Collect the final supervisor-age data point** (~52h continuous PID 30349 at fire time) — completes the rebaselined 3-point experiment that started Day-34. This is the only remaining G2 work.
2. **Ambient G1 observation** — the writer-signature hypothesis was confirmed n=3 at Day-35; no new G1 test today. Today's fire is informational unless it's a striking edge case.

**Anti-plan #15 LIFTS at Day-36 EOD**, unlocking deferred work (gc-init bead filing, fix-shape candidate selection from mc-aep8yk, co_thinking/co_ops rig adds).

---

## 0. Process note

Day-35 closed cleanly (commit pending at time of this plan-stamp): mc-jhsp8y note appended + status promoted to "ready for fix-shape design," mc-aep8yk filed as P3 decision bead with 5 candidate fix shapes, marker archived + cleared.

---

## 1. Pre-flight context (brief)

**State at Day-35 EOD (2026-05-25):**

- **mc-jhsp8y:** OPEN, **characterized**. Writer-signature discriminator confirmed n=3 across Days 31/34/35. Closes when a fix lands and is validated.
- **mc-aep8yk:** OPEN, P3 decision. Fix-shape design space enumerated. Acceptance: pick a single candidate + file a follow-on implementation bead.
- **mc-1zccc2, mc-4m2da1, mc-iho25h, mc-z92fpi:** OPEN, awaiting mc-jhsp8y fix landing.
- **mc-mxl4vc:** OPEN, blocked on beads v1.0.5.
- **All compactor-related PRs:** stable (no open PRs against the compactor).
- **gc binary:** HEAD-fad5d3f. Supervisor PID 30349 alive since 2026-05-24 04:33:35 PT (~52h continuous by Day-36 ~08:55 PT, assuming anti-plan #15 holds).
- **Quarantine dir:** empty (Day-35 marker archived + cleared).
- **Pending deferred work** (becomes available at Day-36 EOD):
  - File `/tmp/bead-draft-gc-init-silent-supervisor-cycle.md` as a new bead (drafted Day-34).
  - Pick a fix-shape candidate from mc-aep8yk and file implementation bead.
  - Begin co_thinking + co_ops rig additions per [[project_post_day34_rig_expansion_plan]].
  - Prepare gc warn+confirm PR (target Wed 5/27 AM for opening, per timing analysis).

**Carry-forward (load-bearing):**

- Day-35 lesson #1: within-cycle correction is valid science.
- Day-35 lesson #2: time-windowed grep results need explicit "as of" timestamps.
- Day-35 lesson #3: wait the full window before calling falsification on a no-fire branch.

---

## 2. Execution sequence

### Step A — No clearance needed (quarantine dir already empty)

### Step 1 — Morning read (5/26 ~09:15 PT — widened to absorb Day-35-style late-edge fires)

```bash
date; gc version; ps -o pid,etime,command -p 30349   # expect ~52h continuous

# Today's compactor events
grep -E '"type":"order\.(fired|completed|failed)"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-26T00:00:00")) | "\(.ts)  \(.type)  \(.message // "-")"'

# Doctor fire timing (ambient — for writer-signature pattern continuity check)
grep -E '"type":"order\.fired"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-doctor") and (.ts >= "2026-05-26T08:00:00")) | "\(.ts)  \(.type)"'

# Quarantine state
ls -la .gc/runtime/packs/dolt/compact-quarantine/
for f in .gc/runtime/packs/dolt/compact-quarantine/*; do
  [ -f "$f" ] && echo "=== $(basename $f) ===" && cat "$f" && echo
done

# Standard ambient watch
gh release list --repo gastownhall/beads --limit 3
bd list 2>/dev/null | grep -E 'mc-(jhsp8y|aep8yk|1zccc2|4m2da1|mxl4vc|z92fpi|iho25h)'
```

### Step 2 — Record fire time + writer-signature continuity check

### Step 3 — EOD: archive any marker, prepare for anti-plan #15 lift

### Step 4 — Post-Day-36-EOD: file gc-init bead, begin fix-shape selection (separate work session, NOT part of Day-36 EOD)

---

## 3. Decision matrix (small — only ambient observations today)

| Outcome | Branch | Action |
|---|---|---|
| Clean fire | Soak continues quietly | Note. Continuity-of-evidence point: doctor outside flatten or no concurrent hq order. |
| Marker, doctor inside flatten | n=4 confirms hypothesis further (3 positives) | Note. Strengthens mc-jhsp8y characterization further. Archive + clear marker. |
| Marker, doctor outside flatten | n=1 contradicting case | Note. Other writers may also trigger; revisit mc-jhsp8y characterization. Investigate writer ledger like Day-35. |
| No fire by 09:30 PT | Dispatcher concern | Investigate; could indicate the late-edge drift from Day-35 has continued past the bound. |
| Supervisor PID 30349 dead or restarted | Anti-plan #15 violation | G2 experiment broken again (3rd time). Restart baseline OR accept incomplete experimental design. |

**Modal expectation:** clean fire or marker (~50/50 each given Day-31/34/35 base rate). Doctor-inside-flatten correlates with marker per characterization. No strong prior on fire-time direction (Day-35's +22m jump means anything from 08:30 to 09:30 is plausible).

---

## 4. Falsifiable predictions

**No load-bearing G1 today** — the writer-signature hypothesis was confirmed Day-35. Today's data is corroborating-or-edge-case for mc-jhsp8y.

- **G2 (supervisor-age, final data point):**
  - *Field:* If anti-plan #15 holds, supervisor PID 30349 ~52h continuous at fire time. Three-point sequence: Day-34 (~4h, fire 08:52:40), Day-35 (~28h, fire 09:14:54), Day-36 (~52h, fire ???). Discriminating outcomes:
    - **Bounded/stabilizing**: Day-36 fire in 09:05–09:25 PT (small Δ from Day-35).
    - **Continuing acceleration**: Day-36 fire >09:25 PT (Δ > +10m).
    - **Reverting/cyclic**: Day-36 fire < 08:55 PT.
  - *Falsifier:* fire outside 08:30–09:30 PT OR supervisor PID changed.

- **G3 (beads release, ambient):**
  - *Field:* v1.0.4 stays latest.
  - *Falsifier:* v1.0.5 ships.

---

## 5. Anti-plans

**Inherited (still apply until Day-36 EOD):**

1–14. (As Day-35; most are now ambient since mc-jhsp8y is characterized and mc-w9iua4/PR #2136 closed.)

15. **LOAD-BEARING through Day-36 fire (~5/26 09:00–09:30 PT):** no laptop sleep, no `gc init`/cities/supervisor/upgrade/dashboard restart anywhere on machine, no binary swap, no killing supervisor/dolt-server PIDs. **LIFTS AT DAY-36 EOD.**

16. **Don't reframe mid-flight** if Day-36 fire produces unexpected data — record as-is, defer interpretation to follow-on work.

17. **Don't fold gc-init-silent-cycle bead into compactor work** — orthogonal concerns.

**New for Day-36:**

18. **Don't start deferred work (gc-init bead filing, mc-aep8yk candidate selection, co_thinking/co_ops adds) UNTIL Day-36 EOD writeup is committed and pushed.** The EOD is the formal lift point for anti-plan #15. Starting deferred work before EOD risks contaminating the final G2 data point if any operation requires supervisor lifecycle interaction.

19. **Don't pick a fix-shape candidate from mc-aep8yk during the Day-36 EOD writeup itself.** Candidate selection is a separate diagnose-day. Day-36 EOD is the END of the soak cycle, not the START of the implementation cycle.

---

## 6. Execution log

### Step A: no clearance needed (DONE — quarantine dir empty entering Day-36)

### Step 1: morning read (pending — execute 5/26 ~09:15 PT)

### Step 2: writer-signature continuity check (pending)

### Step 3: EOD recheck + bead update (pending)

### Step 4: post-Day-36-EOD work (separate session, NOT part of Day-36 EOD)

---

### G1–G3 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
