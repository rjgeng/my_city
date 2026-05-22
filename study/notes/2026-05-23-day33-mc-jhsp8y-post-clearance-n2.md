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
- **gc supervisor:** PID 767, alive since 2026-05-21 04:12 AM (~50h continuous at Day-33 AM).

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

### Step A: pre-fire clearance (pending — execute 5/23 ~07:00–08:25 PT)

### Step 1: morning read (pending — execute 5/23 ~08:35 PT)

### Step 2: 5/23 compactor fire observation (pending — window 08:30–08:50 PT per G2)

### Step 3: branch selection per §3 matrix (pending)

### Step 4: standard watches (#2136, beads release, bead list — pending)

### Step 5: EOD recheck + tracker / bead updates (pending)

### Step 6: Day-34 punt (pending)

---

### G1–G4 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
