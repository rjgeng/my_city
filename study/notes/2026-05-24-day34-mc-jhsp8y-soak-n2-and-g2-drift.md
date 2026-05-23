# Day 34 — mc-jhsp8y soak continuation + G2 drift discriminator

- **Plan authored:** 2026-05-23 PM (end of Day-33; inherited from Day-33 §6 Step 6 punt)
- **Planned execution:** 2026-05-24
- **Status:** Plan stamped. Morning read goes into §6 Step 1 on execution.

Day-34 is a **narrower observation day** than Day-33. No state mutation needed (quarantine dir is already empty post-Day-33 clean fire). One load-bearing G1 — does the n=2 clean fire happen? — plus a **G2 promoted from ambient to discriminating watch** because Day-33's drift trajectory is accelerating, not bounded.

---

## 0. Process note

Day-33 closed with EOD writeup (§6 + verdicts + surprises + lessons) in `study/notes/2026-05-23-day33-mc-jhsp8y-post-clearance-n2.md` and `bd note` appended to mc-jhsp8y. Day-33 anti-plan: "lock the prediction before changing state" — N/A today since no state changes (empty quarantine dir is the natural state).

---

## 1. Pre-flight context

**State going into Day-34 (Day-33 EOD, 2026-05-23):**

- **mc-jhsp8y:** OPEN, evidence-record stage. Day-33 update appended. Acceptance criteria **rescinded back to Day-31 original**: 3+ clean fires to downgrade to "Day-31 one-off," OR a recurrence-with-same-reason marker to confirm reproducibility (with the new condition identified). Day-33 = n=1 clean post-#2316.
- **Quarantine dir:** **EMPTY.** Day-31 marker cleared Day-33 06:59 PT, archived to `/tmp/mc-jhsp8y-day31-marker-archived-20260523-0659.txt`. No Step A needed today.
- **mc-1zccc2 + mc-4m2da1:** OPEN, awaiting mc-jhsp8y resolution.
- **mc-iho25h + mc-z92fpi:** `hold-until-soak`, soak still active (mc-jhsp8y unresolved).
- **mc-w9iua4:** OPEN, blocked on PR #2136.
- **PR #2136:** OPEN, MERGEABLE, `updatedAt=2026-05-18T11:03:58Z`. Day 6 of post-Day-27-nudge silence by Day-34 AM. Wait-only per §24a.
- **PR #2088:** MERGED Day-30, stable through Day-33. No watch unless reverted.
- **PR #2316:** MERGED Day-29. No watch.
- **Issue #3880 / beads release:** v1.0.4 still latest (~15d by Day-34 AM). mc-mxl4vc still blocked.
- **`gc` binary:** HEAD-fad5d3f (Day-30 upgrade, holds).
- **gc supervisor:** PID 800, alive since 2026-05-22 17:51 PT. **At Day-34 fire (~08:50 PT 5/24) this will be ~38h continuous; at Day-35 fire ~62h continuous — only if user does not sleep the laptop or restart between.** Anti-plan #15 below makes this load-bearing.

**Carry-forward Day-33 lessons (relevant subset):**

1. Modal predictions ~70% are not decided outcomes. Anchor language to actual observation, not predicted modal branch.
2. Concurrent-writer presence is necessary but not sufficient. Don't reattempt the causal claim until characterized by db-routing destination.
3. Any "confirmed but barely" prediction (G2 Day-33) auto-promotes falsifier-watch the next iteration. **This is why G2 is load-bearing today, not ambient.**
4. Flag acceptance-criteria oscillations explicitly in bead notes. Done in Day-33's note.
5. **Pull the longer events.jsonl history (including `.gc/events.jsonl.archive-*.gz`) before extrapolating any trajectory.** Day-33's "drift is accelerating" framing was an over-extrapolation off 2 post-upgrade intervals; the 8-day pre-upgrade history (5/13–5/20: 08:02 → 08:14, ~1-2 min/day) flips the read — what looks like sustained acceleration may be transient post-restart re-anchoring of the cooldown clock. Archive-aware before claim, always.
6. **CRITICAL (Day-33 post-EOD reframe): the three fires used to compute G2's "drift trajectory" each happened on a different supervisor state.** Day-31 fire (08:30:38): supervisor uptime unknown. Day-32 fire (08:36:12): supervisor uptime unknown. Day-33 fire (08:48:35): supervisor uptime ~14h45m (PID 800, restart at 5/22 17:51 PT, probably a wake-from-sleep). What I framed in Day-33 EOD as "drift accelerating" is **confounded with supervisor-age-at-fire**. The Day-33 EOD writeup (commit 16753da) overstates G2 because of this confound; cleanest fix is to leave that record as-written (it reflects what was known Saturday evening) and capture the reframe here + in Day-34 EOD. **Day-34/Day-35 are now an experimental design: same-supervisor data points at ~38h and ~62h uptime to disentangle supervisor age from any other variable.** This is the only way out of the confound short of forcing a controlled restart, which is more invasive.

---

## 2. Execution sequence

### Step 1 — Morning read (5/24 ~09:00 PT — tightened from initial ~09:15)

```bash
date; gc version; ps -o pid,etime,command -p 800

# Today's compactor events — fire window 08:30–09:15 PT (tightened per longer-history analysis)
grep -E '"type":"order\.(fired|completed|failed)"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-24T00:00:00")) | "\(.ts)  \(.type)  \(.message // "-")"'

# Quarantine state — did a marker appear today?
ls -la .gc/runtime/packs/dolt/compact-quarantine/
for f in .gc/runtime/packs/dolt/compact-quarantine/*; do
  [ -f "$f" ] && echo "=== $(basename $f) ===" && cat "$f" && echo
done

# pending-gc state
ls -la .gc/runtime/packs/dolt/compact-pending-gc/ 2>/dev/null

# Concurrent-writer ledger during the actual flatten window (substitute fire-time when known)
# Example pattern — adjust regex to today's fire-time HH:MM range:
# grep -E '"ts":"2026-05-24T08:[45]' .gc/events.jsonl | jq -r 'select(.type | test("bead\\.|order\\.")) | "\(.ts)  \(.type)  \(.actor // "-")  \(.subject // "-")"' | head -40

# Standard ambient watches
gh pr view 2136 --repo gastownhall/gascity --json state,updatedAt,labels | jq '{state, updatedAt, labels: [.labels[].name]}'
gh release list --repo gastownhall/beads --limit 3
bd list 2>/dev/null | grep -E 'mc-(jhsp8y|1zccc2|4m2da1|w9iua4|mxl4vc|z92fpi|iho25h)'
```

### Step 2 — Branch selection per §3 matrix

### Step 3 — EOD recheck + tracker / bead updates

### Step 4 — Day-35 punt

---

## 3. Decision matrix (3 G1 branches × 4 G2 branches; G2 reframed as supervisor-age discriminator per Day-33 post-EOD lesson #6)

| G1 fire outcome | Branch | Budget | Action |
|---|---|---:|---|
| **Clean fire (no marker, exit-0)** | **(a) Modal — soak progressing** | 30–45 min | Update mc-jhsp8y: n=2 clean. One more clean fire (Day-35) hits the 3+ threshold for downgrade. No fix-shape bead yet. |
| Marker w/ same reason as Day-31 (`row-count increase`) | (b) Race recurs sporadically | 60–90 min | Update mc-jhsp8y: characterized as sporadic. Investigate Day-33 vs Day-34 writer differences to identify the additional condition. Open db-routing investigation sub-bead (read-only research, not fix). |
| Marker w/ different reason | (c) Wider scope | 60–90 min | Update mc-jhsp8y: append variant. Reconsider whether multiple safety-net code paths are racing. |
| No fire by 10:00 PT | "No fire" | 60–120 min | Diagnose dispatcher. Possibly separate bead. Distinct from G2 drift. |

| G2 fire-time outcome (supervisor ~38h up) | Branch | Action |
|---|---|---|
| 08:47–08:53 PT (Δ ±3m from Day-33's 08:48:35) | **(α) Supervisor-age stabilization — modal** | At ~38h uptime the dispatcher has fully settled past whatever post-wake transient affected Day-33's 08:48:35. Same-supervisor fire-time is approximately constant; the apparent "drift" across Day-31/32/33 was a supervisor-age artifact. Day-35 (~62h) is the confirmation point. |
| 08:30–08:47 PT (Δ -18m to -2m) | (β) Pre-wake equilibrium re-asserts | Same-supervisor fires gravitate back toward the pre-wake dispatch slot. Day-31's 08:30:38 may be the true equilibrium and the post-wake fires were the perturbation. |
| 08:53–09:15 PT (Δ +5m to +27m) | (γ) Drift is real, supervisor-state-independent | The trajectory survives controlled supervisor age. Drift is a cooldown-due-order math property, not a wake transient. Day-35 needed to characterize bounded vs. unbounded under same-state. |
| Outside 08:30–09:15 PT, or no fire by 09:30 | (δ) Dispatcher regression or marker block | Diagnose. If marker appeared (G1 branch (b)/(c)) and short-circuited compact, this duplicates Day-32's branch (d) shape — fire time may still be informative even if compact didn't complete. |

**Modal expectation:** G1 = (a) clean, ~55%. G2 priors (revised under the supervisor-age frame): (α) stabilization, ~50%; (β) pre-wake re-assert, ~15%; (γ) supervisor-state-independent drift, ~25%; (δ) regression, ~10%. Joint modal: clean fire at ~08:47–08:53 PT.

---

## 4. Falsifiable predictions

**G1 and G2 are BOTH load-bearing today** (G2 promoted from Day-33's ambient — per Day-33 lesson #3).

- **G1 (n=2 clean continuation):**
  - *Field:* On Day-34 (5/24), `mol-dog-compactor` fires once and `order.completed` (exit-0). No new file in `.gc/runtime/packs/dolt/compact-quarantine/`.
  - *Generator:* Day-33 demonstrated the success path works post-#2316; the simple "busy hq → race" hypothesis is weakened. Default expectation is clean fire unless a sporadic condition (specific writer overlap on hq path) triggers.
  - *Falsifier:* marker appears (branch (b) or (c)).

- **G2 (supervisor-age discriminator — reframed from drift trajectory):**
  - *Field:* Fire-time lands within 08:30–09:15 PT, with supervisor PID 800 ~38h continuous at fire time (precondition: no laptop sleep or `gc restart` between Day-33 EOD and Day-34 fire — anti-plan #15). Discriminating outcomes:
    - **(H1) Supervisor-age stabilization** — fire at 08:47–08:53 PT (Δ ±3m from Day-33). The apparent "drift" across Day-31/32/33 was supervisor-age-at-fire confound; same-supervisor fire-time is approximately constant. ~50% prior.
    - **(H2) Pre-wake equilibrium re-asserts** — fire at 08:30–08:47 PT. Long uptime gravitates fire-time back toward the pre-wake dispatch slot. ~15% prior.
    - **(H3) Drift is supervisor-state-independent** — fire at 08:53–09:15 PT (Δ +5-27m). The trajectory survives controlled supervisor age, so drift is a cooldown-due-order math property. ~25% prior.
  - *Generator (reframed):* Day-33 EOD's "drift trajectory" framing was confounded because Day-31, Day-32, and Day-33 fires each happened on a different supervisor state (uptime unknown for the first two; ~14h45m for Day-33). The 3-point progression mixes "drift" with "supervisor age at fire." Day-34 (~38h) + Day-35 (~62h) under controlled supervisor state will disentangle this. **The question for today is not "does drift continue?" — it is "does fire-time stabilize when the dispatcher has time to fully settle past wake-from-sleep?"**
  - *Falsifier:* Fire outside 08:30–09:15 PT → (H4) dispatcher regression (~10% prior, branch (δ)). Also falsified if anti-plan #15 is violated (supervisor restart between EOD and fire) — in that case G2 is untestable, mark "no data."

- **G3 (beads release — ambient):**
  - *Field:* v1.0.4 stays latest. mc-mxl4vc remains blocked.
  - *Falsifier:* v1.0.5 ships → mc-mxl4vc city-upgrade (auxiliary work +30–60 min).

- **G4 (#2136 — ambient):**
  - *Field:* PR #2136 stays OPEN, no maintainer activity, day 6 of post-Day-27-nudge silence.
  - *Falsifier:* any maintainer action.

---

## 5. Anti-plans

**Inherited (still apply):**

1. Don't re-arm `gastown.deacon`.
2. Don't open new PRs.
3. Don't preemptively rebase #2136.
4. Don't nudge #2136 (§24a wait-only).
5. Local-time prefix when greping `events.jsonl`.
6. Watch-day must produce an artifact.
7. Verb layer-disambiguation before structural conclusions.
8. No flatten-cycle-retry PR (design bead only, after fix-shape decision).
9. Don't unlatch `hold-until-soak` labels — soak still active.
10. Preserve the archived Day-31 marker in `/tmp`.
11. No fix-shape design today even if branch (b) confirms recurrence — that's a separate diagnose-day after n=3 evidence.

**New for Day-34:**

12. **Don't characterize the drift as bounded OR unbounded on a single Day-34 data point.** G2 needs Day-34 + Day-35 to discriminate. Today's job is to record the fourth point, not to conclude.
13. **If branch (b) fires (marker recurrence), don't preserve the Day-34 marker for the same reason Day-32 needed Day-31's preserved.** A single recurrence after one clean fire is not enough to re-justify "manual-clear-only is the operational burden" framing. Clear it normally as part of next-day cycle planning, archive to /tmp like Day-33 did, move on.
14. **Don't widen scope to writer-routing investigation today.** If G1 = (a) clean, soak continues mechanically. If G1 = (b) marker, the routing investigation is Day-35 work — anti-plan #11-equivalent: investigation follows characterization, not the other way around.
15. **LOAD-BEARING: do not sleep the laptop, restart `gc`, or reboot between now (Day-33 EOD) and Day-35 fire (~5/25 08:50 PT).** The Day-34 and Day-35 fires are an experimental design — same-supervisor data points at ~38h and ~62h uptime — that disentangles the supervisor-age confound discovered post-Day-33-EOD (carry-forward lesson #6). Closing the lid is the most common accidental violation. If the supervisor PID changes between now and Day-35, G2 reverts to untestable and the disentanglement needs a fresh ~62h continuous run, costing 2+ more days. Step 1 morning read MUST start by checking `ps -o pid,etime,command -p 800` to verify the precondition before interpreting any fire data.

---

## 6. Execution log

### Step 1: morning read (pending — execute 5/24 ~09:15 PT)

### Step 2: branch selection per §3 matrix (pending)

### Step 3: EOD recheck + tracker / bead updates (pending)

### Step 4: Day-35 punt (pending)

---

### G1–G4 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
