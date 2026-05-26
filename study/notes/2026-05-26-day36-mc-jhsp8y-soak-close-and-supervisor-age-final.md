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

### Step 1: morning read (DONE 09:17 PT first pass; 09:30 PT confirmation via user-pasted grep)

First-pass read at 09:17 found no compactor fire yet (window had just closed at 09:15). Per Day-35 lesson #3 ("wait the full window before calling falsification"), held to the 09:30 threshold. Fire happened at 09:21:31 — within the widened tolerance. See Step 2.

### Step 2: writer-signature continuity check (DONE — Branch (a), clean fire, n=4 confirmation)

- `order.fired` (compactor) 09:21:31.902 → `order.completed` 09:21:53.497 = **21.6s elapsed** (shortest observed; vs Day-33's 30.3s, Day-34's 51s, Day-35's 66s)
- `order.fired` (doctor) 09:22:15.832 — **22s AFTER compactor.completed** (outside flatten)
- Quarantine dir: empty post-fire. No marker.

Branch (a) per §3 matrix. n=4 reaffirmation of the writer-signature discriminator.

**Sub-finding (significant):** `hello-world/gastown.witness` created `mc-wisp-mlrn4x` at 09:21:34 (3s into the 22s flatten) and updated it at 09:21:43 (12s in). **Witness writes hit hq during flatten and the race still did not fire** — confirming the discriminator is *specifically* a SCHEDULED ORDER firing in the flatten window, not any concurrent hq write. Witnesses/controller/cache-reconcile wisps are insufficient.

### Step 3: EOD recheck + bead update (DONE)

- **No marker to archive** (clean fire). Quarantine dir empty entering and exiting Day-36.
- **mc-jhsp8y note** appended via `bd note --file` — captures n=4 four-day table, sharpened-hypothesis text (scheduled-order-not-any-write), G2 clean closure with 3-point uptime/fire-time table.
- **No new bead created today** — mc-aep8yk candidate selection is post-EOD work per anti-plan #19.

### Step 4: post-Day-36-EOD work (separate session, NOT part of this EOD)

Anti-plan #15 LIFTS upon this EOD commit landing. Deferred work unlocks (handle in a separate session):

- File `/tmp/bead-draft-gc-init-silent-supervisor-cycle.md` via `bd create`.
- Pick fix-shape candidate from mc-aep8yk (separate diagnose-day; anti-plan #19 forbids doing this *during* Day-36 EOD).
- Begin co_thinking + co_ops rig additions per [[project_post_day34_rig_expansion_plan]] — prefer city.toml-only path over `gc init` of a new city per [[feedback_gc_global_supervisor_ops]].
- Prepare gc warn+confirm PR for Wed 5/27 AM target.

---

### G1–G3 verdicts (EOD)

- **G1 (writer-signature ambient confirmation) — confirmed.** No load-bearing G1 today (hypothesis was confirmed Day-35). Today's data adds n=4 with a clean negative-control case (doctor outside flatten + clean) AND the witnesses-during-flatten-but-no-race sharpening sub-finding. The hypothesis is now stated more precisely: **the race fires when a scheduled order (not any writer) fires inside the compactor's flatten window AND creates beads on hq during it.**

- **G2 (supervisor-age experiment) — confirmed: stabilization, not continuing acceleration.** Three same-supervisor data points: ~4h (08:52:40) → ~28h (09:14:54, Δ +22m14s) → ~52h (09:21:31, Δ +6m37s). The +22m Day-35 jump was a one-time post-restart settling artifact; by ~52h uptime the cooldown clock had returned to small daily drift consistent with the pre-upgrade ~1-2 min/day baseline (5/13–5/20 history). The Day-33 EOD framing "drift is accelerating, not bounded" (commit 16753da) is empirically overturned by this 3-point record — but the record there stays as-written per the standard practice (preserve what was known then; capture corrections forward).

- **G3 (beads release) — confirmed.** v1.0.4 still latest (~17d). mc-mxl4vc still blocked.

### Surprises

1. **Day-36 flatten was much shorter than Days 33-35 (21.6s vs 30-66s).** Compactor returned in 22s after completing successfully — the success-path execution time is itself variable, not constant. Possibly correlates with hq size at flatten time, or with concurrent disk I/O level. Worth noting for future fix-design: any retry-with-backoff candidate (mc-aep8yk Candidate A or C) should not assume a fixed flatten duration.

2. **Doctor cadence remained ~20-25 min throughout the day** (27 fires from 00:15 to 09:22). The compactor "got lucky" by firing at 09:21:31, exactly in the middle of the 26m34s gap between doctor fires at 08:55:41 and 09:22:15. Day-34 and Day-35 fires landed inside doctor-fire windows; Day-36 missed both. **This isn't a property of the compactor — it's the dispatcher's interleaving** between two orders with different cadences. Future fix designs (Candidate D doctor-fire deferral) should think about whether the modal expectation is "collision" or "gap," and over how many days.

3. **G2 stabilization at ~52h** — the supervisor-age experiment, originally designed at Day-33 EOD as a 3-point sequence and rebaselined at Day-34 after the 04:33 PT supervisor restart, closed with a satisfying clean result. The framing that "drift was accelerating" was wrong; the framing that "drift would stabilize with continuous supervisor uptime" was right. This is the rare case where a rebaselined experiment recovered fully.

### What the day actually produced

1. **mc-jhsp8y n=4 with refined hypothesis** — scheduled-order-not-any-write specificity captured. Bead is now "characterized" with high confidence; mc-aep8yk fix-shape design space already exists, ready for candidate selection in follow-on work.

2. **G2 supervisor-age experiment closed** — three-day clean record showing stabilization. Lesson for future soak-experiment design: when a supervisor restart contaminates an experiment, rebaselining for one full uptime cycle (here, ~52h) can recover the original question if you're disciplined about the freeze.

3. **Anti-plan #15 lifts** at this EOD commit. ~52 hours of constraint-discipline end. Deferred queue unlocks: gc-init bead, candidate selection, rig adds, PR prep.

4. **Four-day soak cycle complete** — Day-33 (Step A clearance), Day-34 (n=2 marker with hypothesis sharpening), Day-35 (n=3 confirmation + fix-shape design bead), Day-36 (n=4 negative control + sharpening + G2 closure). Net diagnostic output: one well-characterized race + one design-space bead + one cross-cutting incident bead (gc-init silent cycle, drafted in /tmp).

### Process lessons captured

1. **Negative controls are as load-bearing as positive controls.** Day-33 and Day-36 are the negative cases (doctor outside flatten → clean). Without them, the Day-34 + Day-35 positive cases would be "two correlated observations" not "discriminator validated." Hypothesis testing requires explicit negative cases, not just successful replications.

2. **Sub-findings during validation runs sharpen the hypothesis.** Day-36 wasn't designed to test "are witnesses sufficient?" — but the witness-write-during-flatten was visible in the writer ledger and showed the answer (no). When verifying a hypothesis, look for *adjacent* questions the data accidentally answers; they're often the sharpening moves.

3. **Rebaselined experiments can recover.** The 04:33 PT 5/24 supervisor restart looked like a 2-day cost at the time (Day-35 → Day-37 push). It ended up as exactly that, AND the rebaselined 3-point sequence ran cleanly with a satisfying G2 result. Future trade-off for similar incidents: when a soak experiment is contaminated, rebaseline doesn't mean abandon — it means start a new clean clock and discipline-hold it.

4. **Preserve frozen records; capture corrections forward.** Day-33 EOD's "G2 drift is accelerating" framing was wrong (per today's data), but commit 16753da stays as-written. Corrections are captured in subsequent EOD writeups + memories. This is the standard practice and it works: the public record shows the actual investigative trajectory rather than an airbrushed retrospective.
