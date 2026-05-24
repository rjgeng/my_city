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
- **gc supervisor:** ~~PID 800 since 2026-05-22 17:51 PT~~ → **PID 30349 since 2026-05-24 ~04:33 PT** (~4h uptime at Day-34 fire). Anti-plan #15 was **VIOLATED** at 04:33 PT by a `gc init` invocation on a separate 4g-city outside my-city — that command restarts the shared supervisor process across ALL registered cities, not just the target city. Day-34 fire will land on a near-fresh supervisor instead of the planned ~38h. G2 experimental design is broken for today; reset baseline begins now.

**Carry-forward Day-33 lessons (relevant subset):**

1. Modal predictions ~70% are not decided outcomes. Anchor language to actual observation, not predicted modal branch.
2. Concurrent-writer presence is necessary but not sufficient. Don't reattempt the causal claim until characterized by db-routing destination.
3. Any "confirmed but barely" prediction (G2 Day-33) auto-promotes falsifier-watch the next iteration. **This is why G2 is load-bearing today, not ambient.**
4. Flag acceptance-criteria oscillations explicitly in bead notes. Done in Day-33's note.
5. **Pull the longer events.jsonl history (including `.gc/events.jsonl.archive-*.gz`) before extrapolating any trajectory.** Day-33's "drift is accelerating" framing was an over-extrapolation off 2 post-upgrade intervals; the 8-day pre-upgrade history (5/13–5/20: 08:02 → 08:14, ~1-2 min/day) flips the read — what looks like sustained acceleration may be transient post-restart re-anchoring of the cooldown clock. Archive-aware before claim, always.
6. **CRITICAL (Day-33 post-EOD reframe): the three fires used to compute G2's "drift trajectory" each happened on a different supervisor state.** Day-31 fire (08:30:38): supervisor uptime unknown. Day-32 fire (08:36:12): supervisor uptime unknown. Day-33 fire (08:48:35): supervisor uptime ~14h45m (PID 800, restart at 5/22 17:51 PT, probably a wake-from-sleep). What I framed in Day-33 EOD as "drift accelerating" is **confounded with supervisor-age-at-fire**. The Day-33 EOD writeup (commit 16753da) overstates G2 because of this confound; cleanest fix is to leave that record as-written (it reflects what was known Saturday evening) and capture the reframe here + in Day-34 EOD. **Day-34/Day-35 were planned as an experimental design: same-supervisor data points at ~38h and ~62h uptime to disentangle supervisor age from any other variable.** This is the only way out of the confound short of forcing a controlled restart, which is more invasive.

7. **CRITICAL (added Day-34 pre-fire): `gc init` (and likely other `gc cities` / `gc upgrade` operations) restarts the supervisor process across ALL registered cities, not just the target city.** Discovered at 04:33 PT 5/24: user ran `gc init` for a separate 4g-city; PID 800 (my-city's supervisor) died, replaced by PID 30349. Anti-plan #15 was therefore not strict enough — it must cover any `gc` command in any directory that could touch the supervisor lifecycle, not just commands inside my-city. **Generalization for future plans: any `gc supervisor *`, `gc init`, `gc cities *`, `gc upgrade`, or `gc dashboard restart` — anywhere on the machine — is equivalent to a controlled restart of every city's supervisor.** Treat them as global-scope mutations.

---

## 2. Execution sequence

### Step 1 — Morning read (5/24 ~09:00 PT — tightened from initial ~09:15)

```bash
date; gc version; ps -o pid,etime,command -p 30349  # NB: supervisor restarted 04:33 PT 5/24; PID was 800

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

## 3. Decision matrix (3 G1 branches; G2 demoted to ambient — design broken by 04:33 PT supervisor restart, see carry-forward lesson #7)

| G1 fire outcome | Branch | Budget | Action |
|---|---|---:|---|
| **Clean fire (no marker, exit-0)** | **(a) Modal — soak progressing** | 30–45 min | Update mc-jhsp8y: n=2 clean. One more clean fire (Day-35) hits the 3+ threshold for downgrade. No fix-shape bead yet. |
| Marker w/ same reason as Day-31 (`row-count increase`) | (b) Race recurs sporadically | 60–90 min | Update mc-jhsp8y: characterized as sporadic. Investigate Day-33 vs Day-34 writer differences to identify the additional condition. Open db-routing investigation sub-bead (read-only research, not fix). |
| Marker w/ different reason | (c) Wider scope | 60–90 min | Update mc-jhsp8y: append variant. Reconsider whether multiple safety-net code paths are racing. |
| No fire by 10:00 PT | "No fire" | 60–120 min | Diagnose dispatcher. Possibly separate bead. Distinct from G2 drift. |

**G2 table removed.** The supervisor-age discriminator design required ~38h continuous uptime at Day-34 fire; the 04:33 PT restart leaves ~4h at fire time, which lands in the same fresh-wake regime as the contaminated Day-31/32/33 data points. **G2 is demoted to ambient observation only** — record the fire time, but it carries no discriminating weight against the planned hypotheses today.

**Reset experimental design:** new supervisor PID 30349 becomes the new "day 0." Same-supervisor 3-point sequence now lands at:
- Day-34 fire (~08:50 PT 5/24): ~4h uptime (today)
- Day-35 fire (~08:50 PT 5/25): ~28h uptime
- Day-36 fire (~08:50 PT 5/26): ~52h uptime

The disentanglement still works, but the timeline shifts back ~1 day. Requires extending anti-plan #15 enforcement through Day-36 instead of Day-35.

**Modal expectation:** G1 = (a) clean, ~55%. G2 = informational only, no priors today.

---

## 4. Falsifiable predictions

**G1 and G2 are BOTH load-bearing today** (G2 promoted from Day-33's ambient — per Day-33 lesson #3).

- **G1 (n=2 clean continuation):**
  - *Field:* On Day-34 (5/24), `mol-dog-compactor` fires once and `order.completed` (exit-0). No new file in `.gc/runtime/packs/dolt/compact-quarantine/`.
  - *Generator:* Day-33 demonstrated the success path works post-#2316; the simple "busy hq → race" hypothesis is weakened. Default expectation is clean fire unless a sporadic condition (specific writer overlap on hq path) triggers.
  - *Falsifier:* marker appears (branch (b) or (c)).

- **G2 (DEMOTED to ambient — design broken by 04:33 PT supervisor restart):**
  - *Status:* Anti-plan #15 was violated at 04:33 PT by a `gc init` for 4g-city (the command restarts the supervisor across ALL registered cities). PID 800 → PID 30349. Today's fire will land at ~4h supervisor uptime, in the same fresh-wake regime as Day-31/32/33 — cannot discriminate the H1/H2/H3 hypotheses without a clean same-supervisor multi-day sequence.
  - *Field today:* Record `mol-dog-compactor` fire time as informational data only. No prior commitments.
  - *Restart plan:* The same-supervisor experiment is rebaselined. Day-34 (~4h), Day-35 (~28h), Day-36 (~52h) becomes the new 3-point design IF anti-plan #15 (now generalized per carry-forward lesson #7) holds through 2026-05-26 fire window.
  - *Falsifier (for the restart plan):* any further `gc supervisor`, `gc init`, `gc cities`, `gc upgrade`, or laptop sleep between now and Day-36 fire → restart the experiment again.

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
15. **LOAD-BEARING (GENERALIZED after the 04:33 PT 5/24 violation): do not sleep the laptop, restart `gc`, reboot, OR invoke ANY of the following `gc` commands in ANY directory on the machine, between now and Day-36 fire (~5/26 08:50 PT):**
    - `gc supervisor *` (start/stop/restart/reload)
    - `gc init` (initializing any new city)
    - `gc cities *` (add/remove/modify)
    - `gc upgrade` (binary swap)
    - `gc dashboard restart`
    - Killing/restarting any `gc supervisor run` or `dolt-server` process
    - Any operation that touches `/usr/local/bin/gc` (binary replacement)

    **Original timeline (Day-34 + Day-35) is invalidated.** New timeline: Day-34 (~4h supervisor uptime, today), Day-35 (~28h), Day-36 (~52h). The supervisor restart at 04:33 PT happened because `gc init` is a global-scope mutation, not city-scoped — discovered the hard way (carry-forward lesson #7). Closing the lid is the most common accidental violation; running `gc init` in another directory is now also on the list.

    Step 1 morning read MUST start by checking `ps -o pid,etime,command -p 30349` (new supervisor PID) to verify the precondition. If PID 30349 is gone or etime is reset, the rebaseline is broken again — restart the experiment for Day-37.

---

## 6. Execution log

### Step 1: morning read (DONE 09:23 PT, +8m past fire window close)

`gc version` HEAD-fad5d3f. Supervisor PID 30349 etime 04:49:47 (continuous since 04:33:35 PT today, post-`gc init` restart). Fire happened in window — see Step 2.

### Step 2: branch selection per §3 matrix (DONE — Branch (b))

Matched **Branch (b) — "marker w/ same reason as Day-31."** Predicted ~25%; happened.

- `order.fired` 2026-05-24T08:52:40.918494-07:00 (within 08:30–09:15 window ✓; +4m05s from Day-33)
- `order.failed exit status 1` 2026-05-24T08:53:31.313297-07:00 (51s elapsed; between Day-31's 89s and Day-33's 30.3s)
- Quarantine marker created 2026-05-24T08:53:22 PT on `hq`, reason: `post-flatten value hash changed with row-count increase` — **identical** to Day-31.

Action per matrix: "Update mc-jhsp8y: characterized as sporadic. Investigate Day-33 vs Day-34 writer differences..." — done in §6 Step 3 below. Routing investigation deferred to Day-35 per anti-plan #14 (investigation follows characterization).

### Step 3: EOD recheck + tracker / bead updates (DONE)

- **Marker** archived to `/tmp/mc-jhsp8y-day34-marker-archived-20260524-0949.txt` and cleared per anti-plan #13. Day-35 starts with empty quarantine dir.
- **mc-jhsp8y note** appended via `bd note --file` — captures n=2 recurrence, identical reason, and the sharpened writer-signature hypothesis (see §Surprises below).
- **mc-w9iua4 CLOSED** — PR #2136 merged 2026-05-24T10:57:29Z (~03:57 PT 5/24), day 6 of post-Day-27-nudge silence. §24a wait-only protocol vindicated. Closing note cites the merge.
- **upstream-engagement-tracker.md**: no update this commit (PR #2136 merge belongs in next tracker pass).

### Step 4: Day-35 punt (DONE)

Day-35 plan stamped: `study/notes/2026-05-25-day35-mc-jhsp8y-writer-signature-test.md`. Single load-bearing hypothesis (writer-signature discriminator). See §6 Step 4 of Day-35 plan for details.

---

### G1–G4 verdicts (EOD)

- **G1 — falsified (in the marker direction).** Predicted ~55% clean continuation. Actual: Branch (b) marker, same reason as Day-31. The race recurs. The "weakened writer hypothesis" framing from Day-33 turns out to need only sharpening, not abandonment — writers matter, but timing-within-flatten matters more than raw presence.

- **G2 — demoted/ambient as planned.** Fire at 08:52:40 PT (+4m05s from Day-33). Modest forward drift, NOT the doubling that the contaminated 3-point trajectory suggested. But supervisor was ~4h up (post-04:33 restart), so today's data doesn't disentangle supervisor-age from anything else — same regime as Day-31/32/33 fresh-wake. No G2 conclusion possible today; resets begin tomorrow.

- **G3 — confirmed.** v1.0.4 still latest (15d). mc-mxl4vc still blocked.

- **G4 — FALSIFIED in the good direction.** Predicted "PR #2136 stays OPEN, no maintainer activity." Actual: MERGED ~03:57 PT 5/24. Maintainer acted on day 6 of nudge silence, validating §24a wait-only. mc-w9iua4 closed as a direct consequence.

### Surprises

1. **Writer-signature discriminator found.** Comparing Day-33 (clean) vs Day-34 (marker) writer ledgers reveals the missing variable from Day-32's "writer-overlap" hypothesis: it's not raw writer count, it's **whether a hq-writing scheduled order fires INSIDE the compactor's flatten window**. Day-33 had writers but no concurrent order-on-hq. Day-34 had `mol-dog-doctor` fire at 08:53:08 (28s into the 51s compactor flatten), creating 5 bead events on hq (mc-4hlg9b create + 4 updates at 08:53:29). Witnesses and controller wisps alone are insufficient; an order-fire mid-flatten is the new candidate trigger. This is the Day-35 test.

2. **PR #2136 merge.** Six days of nudge silence ended with a clean merge. The model "silence is meaningful" (§24a) was wrong — silence was meaningful in the *reviewer's* timezone (maintainer ack just took 6 days). Updated heuristic for future PRs: §24a's "wait-only after the nudge" pattern works, but don't read silence as "rejected" — read it as "in queue."

3. **G2 demotion was correct preparation.** Yesterday's pre-fire patch removed G2 as load-bearing in time. Without that, today's writeup would have spent budget trying to interpret a ~4h-uptime data point against a planned ~38h baseline. The 04:33 PT mistake (gc init) was actually well-handled at the planning layer.

### What the day actually produced

1. **mc-jhsp8y refined**: n=2 recurrence + writer-signature hypothesis. From "evidence record" to "characterized candidate" — still not fix-ready, but the next test (Day-35 routing/timing) is now concrete.

2. **mc-w9iua4 closed**: clean end-to-end on the diagnose→bead→PR→merge pipeline. Started Day-19 (post-Day-23 jsonl push triage), shipped Day-24 (#2136 opened), merged Day-34. ~10 day cycle.

3. **PR-watch closure**: down to v1.0.5 release watch (G3) and any mc-jhsp8y derivative work. PR queue is empty.

4. **Day-35 plan stamped** with a single load-bearing hypothesis (writer-signature discriminator). Narrower than Day-34 even, by design.

### Process lessons captured

1. **Sharpen, don't abandon, hypotheses on inconvenient data.** Day-33's clean fire was treated as falsifying the Day-32 writer-overlap hypothesis; today's data shows the original was just under-specified. The fix is to sharpen ("writers IN flatten" vs "writers anywhere") rather than retreat. When n=2 evidence is "yes/no/yes," look for the discriminating variable across the difference, not for a different model.

2. **Demote, don't keep load-bearing.** Yesterday's pre-fire memory + plan patch (demoting G2 after the supervisor restart) was the right move. Cost: a few minutes of editing. Benefit: today's EOD didn't have to retrofit a doomed prediction. Generalization: when a precondition fails, patch the plan before the test, not after.

3. **§24a wait-only is sound — but reframe "silence."** Don't interpret 6+ days of PR silence as "rejected" or "stale" — interpret as "still in queue." The "nudge once then wait" protocol works; the failure mode would be re-nudging and burning maintainer goodwill, not under-nudging.

4. **Bead lifecycle visibility.** mc-w9iua4's 10-day life (Day-19 → Day-34) is now a complete reference case for "what a successful diagnose→PR cycle looks like in this city." Worth flagging for future onboarding / wiki-ingest as a paired unit with the existing §24a playbook entries.
