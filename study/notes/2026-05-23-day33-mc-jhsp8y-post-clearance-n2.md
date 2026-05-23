# Day 33 — mc-jhsp8y post-clearance n=2 prediction test

- **Plan authored:** 2026-05-22 PM (end of Day-32; inherited from Day-32 §6 Step 6 punt)
- **Planned execution:** 2026-05-23
- **Status:** Plan stamped. Step A (clearance) + §6 Step 1 (morning read) execute on Day-33.

Day-33 is the **post-clearance n=2 prediction test** for mc-jhsp8y. Day-32 reframed the bead from "in-flatten race to fix at detection layer" to "safety-net working as specced; operational burden is the manual-clear-only persistence policy." That reframe predicts the marker will re-arm on most busy days. **Today tests that prediction directly:** clear the Day-31 marker, let the 5/23 fire run, observe whether a new marker appears with the same reason.

Narrower scope than Day-32 — one load-bearing G1, plus ambient G2/G3/G4 watches.

---

## 0. Process note

Day-32 closed with two commits: `591a73b` (tracker housekeeping — #2088 moved to closed/merged) and `077e2a7` (Day-32 EOD writeup). The Day-32 EOD anti-plan was: "lock the prediction before changing state." This plan is that lock. Step A clearance happens *after* this plan is committed.

---

## 1. Pre-flight context

**State going into Day-33 (Day-32 EOD, 2026-05-22):**

- **mc-jhsp8y:** OPEN, evidence-record stage. Day-32 update added (concurrent-writer evidence, reframe, narrowed fix surface, updated acceptance criteria). Acceptance: **n=2 + design analysis = enough** to call structurally reproducible.
- **Day-31 quarantine marker** `.gc/runtime/packs/dolt/compact-quarantine/hq`: **STILL IN PLACE** at Day-32 EOD. Reason: `post-flatten value hash changed with row-count increase`, created 2026-05-21T15:31:51Z. Clearance deferred per X.2; required before Day-33 fire can attempt flatten.
- **mc-1zccc2 + mc-4m2da1:** OPEN, awaiting mc-jhsp8y resolution.
- **mc-iho25h + mc-z92fpi:** `hold-until-soak`, soak still active (mc-jhsp8y unresolved).
- **mc-w9iua4:** OPEN, blocked on PR #2136.
- **PR #2136:** OPEN, MERGEABLE, day 5 of post-Day-27-nudge silence. Wait-only per §24a.
- **PR #2088:** MERGED Day-30, validated stable Day-32 (G4 ✓). No further watch unless reverted.
- **PR #2316:** MERGED Day-29, validated working Day-31 (preflight retry succeeded, safety net engaged correctly). No watch.
- **Issue #3880 / beads release:** v1.0.4 still latest (~14d at Day-33 AM), mc-mxl4vc still blocked.
- **`gc` binary:** HEAD-fad5d3f (Day-30 upgrade holds).
- **gc supervisor:** PID 800, alive since 2026-05-22 17:51 PT (~13h continuous at Day-33 AM, 06:34 PT). *Day-32 EOD pre-flight line claimed PID 767 / ~50h — authoring error: PID 767 is Apple's `TrialArchivingService`, not gc. Real continuous run is shorter, which weakens G2 timing precision (cooldown clock had less settle time) but does not affect G1.*

**Carry-forward Day-32 lessons:**

1. Decision matrices need an "inherited state" column. Day-32's §3 matrix missed Branch (d) because it didn't model the persistent marker state.
2. `events.jsonl` is the authoritative concurrent-writer ledger. `dolt.log` only captures warnings/errors.
3. `gc dolt compact` is the manual repro of the order; useful diagnostic shortcut for any "compact failed" investigation.
4. The G1 prediction structure needs a clean starting state — today's clearance is what enables a valid G1 test.

---

## 2. Execution sequence

### Step A — Pre-fire clearance (5/23 ~07:00–08:25 PT, before fire window)

```bash
# Verify marker content matches what we think
cat .gc/runtime/packs/dolt/compact-quarantine/hq

# Archive snapshot (optional belt-and-suspenders — content is also preserved in
# git via Day-31/Day-32 plan files, but a physical copy is cheap insurance)
cp .gc/runtime/packs/dolt/compact-quarantine/hq \
   /tmp/mc-jhsp8y-day31-marker-archived-$(date +%Y%m%d-%H%M).txt

# Clear the marker — single rm, no other state touched
rm .gc/runtime/packs/dolt/compact-quarantine/hq

# Confirm dir is empty
ls -la .gc/runtime/packs/dolt/compact-quarantine/
```

After this, the compactor on its next fire will pass the `has_compact_marker` gate (`run.sh:1125-1128`) and attempt the full preflight → flatten → post-flatten verify cycle.

**Anti-plan #11 applies before Step A:** if for any reason Day-33 morning is rushed or interrupted, prefer doing nothing over a partial clearance. The deferred-clearance branch (d) is harmless; a botched clearance with unclear state is not.

### Step B — Morning read (5/23 ~08:35 PT, post-fire-window)

```bash
date; gc version

# 5/23 fire watch — was the n=2 marker created?
grep -E '"type":"order\.(fired|completed|failed)"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-23T00:00:00")) | "\(.ts)  \(.type)"'

# Quarantine state — did a NEW marker appear? what reason?
ls -la .gc/runtime/packs/dolt/compact-quarantine/
for f in .gc/runtime/packs/dolt/compact-quarantine/*; do
  [ -f "$f" ] && echo "=== $(basename $f) ===" && cat "$f" && echo
done

# pending-gc state — did a failed run leave anything queued?
ls -la .gc/runtime/packs/dolt/compact-pending-gc/

# Concurrent-writer ledger during 5/23 flatten window
# (expand window if fire-time differs from prediction)
grep -E '"ts":"2026-05-23T08:3[0-3]:' .gc/events.jsonl \
  | jq -r 'select(.type | test("bead\\.(created|updated|closed)|order\\.")) | "\(.ts)  \(.type)  \(.actor // "-")  \(.subject // "-")"' \
  | head -40

# Standard watches
gh pr view 2136 --repo gastownhall/gascity --json state,updatedAt,labels \
  | jq '{state, updatedAt, labels: [.labels[].name]}'
gh release list --repo gastownhall/beads --limit 3
bd list | grep -E 'mc-(jhsp8y|1zccc2|4m2da1|w9iua4|mxl4vc|z92fpi|iho25h)'
```

---

## 3. Decision matrix (4 branches, INCLUDING inherited-state column — Day-32 lesson #1)

| Pre-fire state | Fire outcome | Branch | Budget | Action |
|---|---|---|---:|---|
| **Marker cleared (G1 active)** | New marker w/ same reason (`value hash changed with row-count increase`) | **(a) Structurally reproducible — modal** | 60–90 min | n=2 confirmed. Update mc-jhsp8y: race characterized. **Open fix-shape bead** at P3 targeting persistence policy (no implementation today — anti-plan #11). |
| Marker cleared | New marker w/ different reason | (b) Wider scope | 60–90 min | Update mc-jhsp8y: append variant section. Reconsider fix shape (broader than persistence-policy-on-row-count-gain alone). |
| Marker cleared | No new marker, exit-0 (clean fire) | (c) Race write-spike-dependent | 30–45 min | Update mc-jhsp8y: note 5/23 clean. Reconsider whether Day-31's writer overlap was atypical (mol-dog-doctor scheduling collision?). Continue soak — 3+ clean fires to downgrade. |
| **Marker NOT cleared** (Step A skipped/aborted) | Day-31 marker blocks (same as Day-32) | (d) No-op for mc-jhsp8y | 15–30 min | No new race data. Punt to Day-34, or use Day-33 as design-bead authoring day for the fix-shape candidate. |
| Marker cleared | No fire AT ALL by 09:30 PT | "No fire" | 60–120 min | Diagnose dispatcher: `gc order check`, dispatcher trace, supervisor PID. Possibly separate bead. |
| **Beads v1.0.5 ships** (low prob) | Auxiliary work | +30–60 min | mc-mxl4vc city-upgrade workflow. |

**Modal reasoning:** branch (a) is modal — **~70%**. Day-31 evidence + Day-32 design analysis make reproduction near-certain on a busy hq (witnesses + scheduled orders write to hq every morning during the compactor window). (b) ~10% if a different code path in the safety-net family races today. (c) ~15% if Day-31's writer overlap was atypical. (d) ~3% (only if Step A is aborted). "No fire" ~2%.

---

## 4. Falsifiable predictions

**G1 is load-bearing today.** G2–G4 are ambient watches.

- **G1 (the n=2 prediction):**
  - *Field:* On Day-33 (5/23), `mol-dog-compactor` fires between 08:30–08:50 PT and writes a NEW quarantine marker file in `.gc/runtime/packs/dolt/compact-quarantine/` with reason matching Day-31's (`post-flatten value hash changed with row-count increase`). At least 1 known concurrent writer (witness or scheduled order) creates beads on hq during the 08:30–08:33 PT flatten window.
  - *Generator:* `hq` receives concurrent writes during the compactor's flatten window from witnesses + scheduled orders. The race is structurally reproducible on busy DBs, as derived from Day-32 analysis (run.sh:1536-1559 + 1382-1387 design intent).
  - *Falsifier:* branch (b) different reason; (c) no marker + exit-0; (d) marker uncleared so no flatten attempted; or no fire by 09:30 PT.

- **G2 (drift discriminator — ambient):**
  - *Field:* Fire lands 08:30–08:50 PT (same window as Day-31's 08:30:38 and Day-32's 08:36:12).
  - *Falsifier:* lands outside 08:30–08:50 → drift not bounded as Day-32 G2 suggested.

- **G3 (beads release — ambient):**
  - *Field:* v1.0.4 stays latest. mc-mxl4vc remains blocked.
  - *Falsifier:* v1.0.5 ships → trigger mc-mxl4vc city-upgrade workflow (auxiliary work, budget +30–60 min).

- **G4 (#2136 — ambient):**
  - *Field:* PR #2136 stays OPEN, no maintainer activity, day 5 of post-Day-27-nudge silence.
  - *Falsifier:* any maintainer action (label, comment, review, reviewer assignment).

---

## 5. Anti-plans

**Inherited (still apply):**

1. Don't re-arm `gastown.deacon` — quarantine markers + events.jsonl are the diagnosis vectors.
2. Don't open new PRs.
3. Don't preemptively rebase #2136.
4. Don't nudge #2136 (Day-27 nudge spent, §24a wait-only).
5. Local-time prefix when greping `events.jsonl` (Day-27 lesson).
6. Watch-day must produce an artifact (Day-29 anti-plan).
7. `gc dolt --help` style verbs need layer-disambiguation before structural conclusions.
8. Don't open a flatten-cycle-retry PR even if (a) confirms — design bead only, not implementation.
9. Don't unlatch `hold-until-soak` labels on mc-z92fpi / mc-iho25h yet — soak still active.
10. Don't delete or rotate the archived Day-31 marker if Step A creates one in /tmp.

**New for Day-33:**

11. **Don't decide fix shape today, even if branch (a) confirms.** The Day-33 outcome is "open fix-shape bead at P3," not "design the fix." Designing the fix is a separate diagnose/design day after the bead is filed and the user has had time to think.
12. **DO NOT clear today's Day-33 marker (if branch (a)/(b) fires).** Day-34 will need it as state for the next decision. Preserve evidence by default.
13. **If Step A is aborted/deferred for any reason** (oversleep, distraction, accidental compactor fire-before-clearance), accept branch (d) and don't try to retroactively force a flatten attempt by clearing mid-window. The race-window timing matters; a post-fire clearance is not a test of the same prediction.

---

## 6. Execution log

### Step A: pre-fire clearance (DONE 06:59 PT)

Marker content verified: `db=hq`, `reason=post-flatten value hash changed with row-count increase`, `created_at=2026-05-21T15:31:51Z`. Archived to `/tmp/mc-jhsp8y-day31-marker-archived-20260523-0659.txt`. Removed from `.gc/runtime/packs/dolt/compact-quarantine/hq`. Dir empty post-clearance.

### Step 1: morning read (DONE 08:57 PT, post-fire)

`gc version` HEAD-fad5d3f (unchanged). Fire happened earlier in the window — see §6 Step 2.

### Step 2: 5/23 compactor fire observation (DONE)

- `order.fired` 2026-05-23T08:48:35.756385-07:00 (+12m later than Day-31's 08:30:38; +12m later than Day-32's 08:36:12; trailing edge of the 08:30–08:50 G2 window with 1m25s margin)
- `order.completed` 2026-05-23T08:49:06.080321-07:00 (30.3s elapsed — full preflight → flatten → post-flatten verify success path)
- Quarantine dir: EMPTY post-fire. No new marker.
- Pending-gc dir: not present (would have been populated only on failed run).

### Step 3: branch selection per §3 matrix (DONE — Branch (c))

Matched **Branch (c) — "marker cleared, no new marker, exit-0 (clean fire)."** Predicted ~15%; happened. Modal Branch (a) (~70%) did not realize.

Action per matrix: *"Update mc-jhsp8y: note 5/23 clean. Reconsider whether Day-31's writer overlap was atypical. Continue soak — 3+ clean fires to downgrade."*

### Step 4: standard watches (DONE)

- **PR #2136**: OPEN, `updatedAt=2026-05-18T11:03:58Z` (unchanged from Day-32). Day 5 of post-Day-27-nudge silence. G4 ✓.
- **beads release**: v1.0.4 still latest (2026-05-09, 14d old). mc-mxl4vc still blocked. G3 ✓.
- **watched beads**: mc-jhsp8y, mc-1zccc2, mc-4m2da1, mc-w9iua4, mc-mxl4vc, mc-z92fpi, mc-iho25h all OPEN (no closures).

### Step 5: EOD recheck + tracker / bead updates (DONE / IN PROGRESS)

- `mc-jhsp8y` note appended via `bd note --file` — captures today's clean fire, writer-presence evidence, Day-32 hypothesis weakening, rescinded acceptance criteria.
- This plan file: §6 Steps 1–5 + verdicts/surprises/produced/lessons sections filled (this commit).
- `upstream-engagement-tracker.md`: no update needed today (PR state unchanged).

### Step 6: Day-34 punt (DONE)

Day-34 plan stamped: `study/notes/2026-05-24-day34-mc-jhsp8y-soak-n2-and-g2-drift.md`. Two load-bearing predictions (G1 n=2 clean continuation, G2 drift discriminator — promoted from ambient per Day-33 lesson #3). No Step A (quarantine dir already empty). Widened fire-window 08:30–09:30 PT given Day-33 trajectory. Three new anti-plans: don't conclude bounded/unbounded on one point (#12), don't over-preserve a recurrence marker (#13), don't widen to routing investigation today (#14).

---

### G1–G4 verdicts (EOD)

- **G1 — falsified.** Field prediction was "new marker w/ reason `post-flatten value hash changed with row-count increase`." Actual: no marker, exit-0. Matches the listed falsifier "(c) no marker + exit-0." Generator hypothesis ("hq receives concurrent writes during flatten → race is structurally reproducible on busy DBs") is weakened, not destroyed — writers were present, race did not fire. Some additional condition matters.

- **G2 — confirmed but precarious.** Fire at 08:48:35 PT, within the 08:30–08:50 PT window with only 1m25s margin before falsification at 09:00+. Drift trajectory across three data points: 08:30:38 → 08:36:12 → 08:48:35 (Δ +5m34s, then +12m23s — accelerating). One more day inside the window, but if the pattern holds the window will be breached by Day-34 or Day-35.

- **G3 — confirmed.** v1.0.4 still latest (~14d). mc-mxl4vc blocked.

- **G4 — confirmed.** PR #2136 unchanged at 2026-05-18T11:03:58Z. Day 5 of post-Day-27-nudge silence. Wait-only per §24a.

### Surprises

1. **Branch (c) realized, not modal (a).** Day-32 design analysis predicted reproduction with ~70% confidence based on writer-overlap reasoning. Today's clean fire under similar writer conditions (3 distinct actors active in the flatten window) means the simple model is wrong. **Either the wisp writes don't reach hq from the rigs we observed** (hello-world vs Day-31's co_shipping — rig-specific routing matters), **or the race needs a finer collision than "any writer during 30s."**

2. **G2 drift is accelerating, not stabilizing.** Day-32 baseline hypothesis (b) was "Day-30 binary upgrade reordered cooldown-due-order dispatch; new fire-time is the new baseline, not a continuing trajectory." Three data points now: 08:30:38 → 08:36:12 (Δ +5m34s) → 08:48:35 (Δ +12m23s). Each interval is roughly double the previous. If the supervisor restart at 17:51 PT 5/22 is a confounder, the post-restart drift trajectory is steeper than pre-restart. The "drift bounded" hypothesis needs revisiting on Day-34.

3. **A clean fire is itself useful test infrastructure.** The 30.3s success-path run is the first observed post-#2316 successful compact of hq. Confirms the full preflight → flatten → verify cycle works end-to-end. The two failure-day runs (Day-31 marker, Day-32 short-circuit) didn't prove the success path existed; today does.

### What the day actually produced

1. **Falsification of the Day-32 reproduction claim.** The "structurally reproducible on busy hq" model is no longer load-bearing. mc-jhsp8y reverts to "evidence record, needs continued soak" — not a candidate for fix-shape design yet.

2. **First successful post-#2316 hq compact observation.** Proves the success path is intact; quarantine is genuinely an exception, not the modal outcome.

3. **G2 trajectory data flips from "post-upgrade baseline" to "active drift."** Day-34 needs to either (a) confirm drift continues (window breached by ~09:00 PT) or (b) confirm stabilization (next fire within 08:40–08:55).

4. **Note appended to `mc-jhsp8y`** with today's evidence + rescinded acceptance criteria.

### Process lessons captured

1. **Modal predictions of ~70% should not be treated as decided outcomes.** Day-32 §7 mostly read as "the race is reproducible, here are the fix candidates" — language drifted from "the modal branch is reproduction" toward "reproduction is established." Today's falsification is exactly what a 30% non-modal probability looks like. Resist the temptation to advance fix-design language until evidence clears 80%+ across n≥3 independent observations.

2. **Concurrent-writer presence is necessary but not sufficient.** Today writers were active (hello-world/witness + controller + cache-reconcile) and the compact succeeded. The Day-32 "2 writers caused the race" narrative was a correlation in a sample of 1. Need to characterize *which* writes hit *which* db before reattempting the causal claim — `events.jsonl` actor field is rig-prefixed but doesn't tell us db-routing destination.

3. **Trajectory data needs three points before assuming bounded.** Day-32 G2 confirmed-with-1m24s-of-falsifier was the warning sign that was discounted. Today's third point makes the trajectory legible. Generalization: any "confirmed but barely" prediction should auto-promote falsifier-watch on the next iteration.

4. **Don't rescind acceptance criteria in a single update — flag the rescind in the bead note explicitly.** Today's `mc-jhsp8y` note rescinds Day-32's "n=2 = enough" and reverts to Day-31's "3+ clean fires." That kind of acceptance-criteria oscillation should be visible so a future reader doesn't latch onto the wrong revision.
