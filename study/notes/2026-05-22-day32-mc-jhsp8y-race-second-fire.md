# Day 32 — mc-jhsp8y second fire (in-flatten race repeat-or-not)

- **Plan authored:** 2026-05-21 PM (end of Day-31; inherited from Day-31 §6 Step 6 punt)
- **Planned execution:** 2026-05-22
- **Status:** Plan stamped. AM read goes into §6 Step 1 on execution.

Day-32 is the **second post-upgrade compactor observation day**, designed to characterize the in-flatten race that mc-jhsp8y captured from Day-31's quarantine marker. One data point is not a pattern; today's 5/22 fire is the discriminator.

---

## 0. Process note

Day-31 closed cleanly (commit `3f83944`), with a full §6 Step 6 punt that this plan is the expansion of. No plan-file gap this cycle.

---

## 1. Pre-flight context

**State going into Day-32 (Day-31 EOD, 2026-05-21):**

- **mc-jhsp8y** (in-flatten race on hq): **OPEN.** First quarantine marker captured 5/21 08:31:51 PT. Reason: `post-flatten value hash changed with row-count increase`. Acceptance: 3+ more daily fires to confirm reproducibility, OR non-repeat → downgrade.
- **mc-1zccc2** (original diagnosis bead): **OPEN**, redirected — preflight race confirmed FIXED by #2316. Closes when mc-jhsp8y resolves.
- **mc-4m2da1** (preflight-fix design bead): **OPEN**, partial-scope merged in #2316; flatten-cycle retry portion was speculative when written, now justified by mc-jhsp8y data.
- **PR #2316:** MERGED Day-29. Day-31 confirmed preflight retry works; safety net activates cleanly. No regression.
- **PR #2088** (convoy docs): **MERGED Day-30 evening** (2026-05-20T18:45:45Z by quad341, §24b direct-merge variant). Closed-loop verification due Day-32 AM.
- **PR #2136** (mol-dog-jsonl push race): OPEN, MERGEABLE, last update 2026-05-18T11:03:58Z. Day 6 post-Day-27-nudge. Wait-only.
- **Issue #3880 (beads):** v1.0.4 still latest (~13d old by Day-32). mc-mxl4vc blocked.
- **mc-z92fpi, mc-iho25h:** still OPEN with `hold-until-soak` labels. 24h post-upgrade soak window now satisfied (Day-30 09:53 PT + 24h = Day-31 09:53 PT), so labels are eligible to unlatch — but anti-plan #9 from Day-31 said don't unlatch on a single data point; today's fire is the second.
- **`gc` binary:** HEAD-fad5d3f (Day-30 upgrade, holds).
- **Quarantine marker preserved:** `.gc/runtime/packs/dolt/compact-quarantine/hq` — DO NOT delete, primary evidence for mc-jhsp8y.

**Carry-forward Day-31 lessons:**

1. **Help-text verbs need layer-disambiguation** ("replaces / supersedes" — ask interface vs. implementation before drawing structural conclusions).
2. **First-time safety-net activations are high-leverage observation events.** If a NEW artifact appears today (different quarantine reason, new file, new event type), treat it as primary diagnostic input over logs.
3. **End-of-day plan stamps go stale by morning for active PRs.** Morning read confirms #2088 didn't flip back, #2136 didn't move, beads release didn't ship.
4. **Drift prediction needs upgrade-shift hypothesis** — today's fire timing is the discriminator.

---

## 2. Morning read

```bash
date; gc version

# 5/22 compactor fire watch — same template as Day-31, but with full event capture
grep -E '"type":"order\.(fired|completed|failed)"' .gc/events.jsonl \
  | jq -r '"\(.ts)  \(.type)  \(.subject // .message)"' \
  | grep 'mol-dog-compactor' \
  | tail -5

# Quarantine state — did a NEW marker appear? what reason?
ls -la .gc/runtime/packs/dolt/compact-quarantine/
for f in .gc/runtime/packs/dolt/compact-quarantine/*; do
  echo "=== $f ==="; cat "$f"
done

# pending-gc state — did the failed run leave anything queued?
ls -la .gc/runtime/packs/dolt/compact-pending-gc/

# Order-due / next-fire snapshot
gc order check 2>&1 | grep mol-dog-compactor
gc order history mol-dog-compactor 2>&1 | head -3

# PR + release state
for pr in 2088 2136; do
  gh pr view $pr --repo gastownhall/gascity \
    --json state,mergedAt,reviewDecision,updatedAt,labels \
    | jq '{state, mergedAt, reviewDecision, updatedAt, labels: [.labels[].name]}'
done
gh release list --repo gastownhall/beads --limit 3

# Watched beads
bd list | grep -E 'mc-(jhsp8y|1zccc2|4m2da1|w9iua4|mxl4vc|z92fpi|iho25h)'
```

---

## 3. Decision matrix (three branches on compactor fire outcome)

| Fire outcome | Branch | Budget | Action |
|---|---|---:|---|
| **(a) Same quarantine reason** — `value hash changed with row-count increase` | In-flatten race **confirmed reproducible** (2/2 fires under post-#2316 code). | 60–120 min | Update mc-jhsp8y: bump confidence, note 2nd marker. Start *designing* (not implementing) flatten-cycle retry. Draft design notes inline in bead. No PR today. |
| **(b) Different quarantine reason** (e.g., `value hash changed without row-count increase`, `value hash probe failed`, `value hash probe returned empty value`, `post-flatten INTEGRITY check failed`) | A **third** failure mode in the same safety-net family. Widen mc-jhsp8y scope. | 60–90 min | Update mc-jhsp8y: append new variant section. The fix design becomes broader (not just row-count-gain case). |
| **(c) No fire OR exit-0** | In-flatten race may be **write-spike-dependent** or one-off. Don't close mc-jhsp8y on one clean fire. | 30–45 min | Update mc-jhsp8y: note 5/22 clean, continue soaking. Anti-plan #9-equivalent: 3+ clean fires required before downgrade. |
| **No fire AT ALL by 09:30 PT** (drift/dispatch broken) | Distinct from (c) — a scheduling regression. | 60–120 min | Diagnose dispatcher: `gc order check` snapshot, dispatcher trace UTC window, supervisor PID continuity. Possibly separate bead. |
| **Beads v1.0.5 ships** (low probability) | Auxiliary work. | +30–60 min | mc-mxl4vc city-upgrade (symlink swap). |

**Modal reasoning:** Day-31's marker reason was specific (`row-count increase` branch). If the underlying race is structurally "hq receives writes during flatten" then (a) is modal (~60%), since that condition is daily-typical for hq. (b) ~20% if other code paths in the safety-net family also race. (c) ~15% if Day-31's spike was unusual. "No fire at all" ~5% — would surprise.

---

## 4. Falsifiable predictions (G1–G4)

- **G1 (compactor fire outcome):**
  - *Field:* On Day-32 (5/22), `mol-dog-compactor` fires once between 08:30–08:50 PT and writes a NEW quarantine marker file in `.gc/runtime/packs/dolt/compact-quarantine/` with reason matching Day-31's (`post-flatten value hash changed with row-count increase`). `order.failed exit status 1`.
  - *Generator:* hq's write rate during compact is structural (mail/beads/wisps/sessions all write during the same 1–2 minute window). The race is reproducible.
  - *Falsifier:* (b) different reason; (c) no quarantine + exit-0; or no fire by 09:30 PT.

- **G2 (drift discriminator):**
  - *Field:* Fire timestamp lands in 08:30–08:50 PT (post-upgrade dispatch-shift hypothesis).
  - *Generator:* Day-30 binary upgrade reordered the cooldown-due-order dispatch slot; the new effective fire-time is the new baseline, not a continuing drift trajectory.
  - *Falsifier:* lands ~09:00+ PT → geometric drift acceleration hypothesis (a) holds; needs deeper investigation. Lands ~08:14–08:18 → drift has reverted, also surprising.

- **G3 (beads release):**
  - *Field:* v1.0.4 stays latest. mc-mxl4vc remains blocked.
  - *Generator:* ~13d silence on v1.0.5; cadence is 10–15d but no public movement signal as of Day-31.
  - *Falsifier:* v1.0.5 ships → trigger mc-mxl4vc upgrade workflow.

- **G4 (#2088 closed-loop):**
  - *Field:* PR #2088 stays MERGED. No revert. No follow-up issues opened against it (`is:issue mentions 2088`). No new comments on the merged thread since Day-30.
  - *Generator:* §24b direct-merge variants are typically stable post-merge (maintainer didn't request changes; merge was clean).
  - *Falsifier:* Revert PR opened, or critical comment thread on #2088, or issue cross-referencing it as breaking something.

---

## 5. Anti-plans

**Inherited from Day-31 (still apply):**

1. **Don't re-arm `gastown.deacon`** — quarantine markers are the diagnosis vector now.
2. **Don't open new PRs** unless review on #2136 forces one.
3. **Don't preemptively rebase #2136** — let it ride.
4. **Don't nudge #2136** — Day-27 nudge spent, no new nudge today.
5. **Local-time prefix when greping events.jsonl** (Day-27 lesson).
6. **Watch-day must produce an artifact** (Day-29 anti-plan #7).
7. **`gc dolt --help` style verbs** ("replaces") need layer-disambiguation before structural conclusions (Day-31 lesson #1).

**New for Day-32:**

8. **Don't open a flatten-cycle-retry PR even if branch (a) fires.** Design notes inline in mc-jhsp8y body only. PR comes after 3+ data points + a design decision, not on day-2 of evidence. Anti-plan #8 from Day-31 stays in force.
9. **Don't unlatch `hold-until-soak` labels on mc-z92fpi / mc-iho25h yet.** 24h soak window is satisfied by clock, but the compactor soak is still active (mc-jhsp8y open). Re-evaluate after 3+ clean fires OR fix shipped.
10. **Don't delete or rotate the Day-31 quarantine marker.** It is the baseline-1 evidence; if Day-32 marker differs in reason, comparison requires both files intact. If a NEW marker appears today, preserve BOTH (Day-31 + Day-32) — they become evidence pair for mc-jhsp8y.

---

## 6. Execution log

### Step 1: morning read (DONE 08:36 PT)

Headline: fire happened on schedule but produced **no new quarantine marker.** The Day-31 marker blocked compaction entirely. n=1 remains.

### Step 2: 5/22 compactor fire observation (DONE)

- `order.fired` 2026-05-22T08:36:12.798815-07:00 (within predicted 08:30–08:50 window ✓; +6m later than Day-31's 08:30:38)
- `order.failed` 2026-05-22T08:36:28.876867-07:00 (16s elapsed vs. Day-31's 89s — early abort, not failure speed)
- Quarantine dir: UNCHANGED. Single file `hq` from 5/21 08:31:51 PT.
- Pending-gc dir: EMPTY.

Manual repro via `gc dolt compact` (same exec the order runs):

```
compact: db=hq integrity quarantine marker exists — manual intervention required before compaction or GC
compact: db=cs commits=355 below_threshold=2000 ... — skip
compact: db=ship commits=486 ... — skip
compact: db=hw commits=430 ... — skip
compact: db=auth commits=338 ... — skip
compact: 1 database(s) failed compaction
```

Source: `study/gascity-src/examples/dolt/commands/compact/run.sh:1124-1129` — `has_compact_marker` check fires before any flatten attempt.

### Step 3: branch selection per §3 matrix (UNANTICIPATED — Branch (d))

None of the four planned branches matched:

- (a) Same reason, new marker — NO (no new marker)
- (b) Different reason, new marker — NO (no new marker)
- (c) No fire / exit-0 — NO (fire happened, exit-1)
- "No fire by 09:30 PT" — NO (fire happened on time)

**New Branch (d): pre-existing quarantine marker blocks compact entirely.** The §3 matrix didn't model the persistent-state case. See §7 Surprises.

### Step 4: #2088 closed-loop verification (DONE — G4 ✓)

PR #2088: `state=MERGED, mergedAt=2026-05-20T18:45:45Z` (unchanged). No revert. No new comments on merged thread since Day-30 evening. No follow-up issues opened. §24b direct-merge variant proves stable post-merge.

### Step 5: EOD recheck + tracker / bead updates (DONE / IN PROGRESS)

- Tracker: updated this morning 08:00 PT before fire (commit `591a73b`). #2088 moved Active → Closed with §24b direct-merge writeup. #2136 Day-32 AM line appended.
- Day-32 EOD: this file, this section.
- `mc-jhsp8y` bead update: appended via `bd note` after this writeup commits.
- **Clearance decision (delete Day-31 marker yes/no): DEFERRED per user X.2 selection** — write up first, clear later.

### Step 6: Day-33 punt (PENDING — depends on clearance decision)

If user clears the Day-31 marker before 5/23 ~08:30 PT, Day-33's plan is straightforward: a single G1 ("new marker reproduces with same reason") plus the standard #2136 / #3880 / beads-release watches. If clearance is deferred further, Day-33 is a no-fire-data day — punt to Day-34, or use Day-33 as the design-bead authoring day for the fix-shape candidate from §7.

---

### G1–G4 verdicts (EOD)

- **G1** — **partially falsified.** Fire happened in the predicted window (G2 ✓) but did NOT write a new quarantine marker. The closest matrix branch was the falsifier "(c) no quarantine + exit-0," but that's technically wrong because exit-1 *did* fire. The generator hypothesis ("hq's write rate during compact is structural — the race is reproducible") remains untested by this run — the persistent Day-31 marker short-circuited the test. **The G1 prediction needs to be re-issued from a clean-marker starting state**, which is what Day-33 (post-clearance) would test.

- **G2** — **confirmed.** Fire at 08:36:12 PT is within the 08:30–08:50 PT window. Post-upgrade baseline hypothesis (b) holds. Geometric drift acceleration hypothesis (a) does not hold (would have predicted ~09:00+ PT). +6m later than Day-31's 08:30:38 but bounded.

- **G3** — **confirmed.** `gh release list --repo gastownhall/beads`: v1.0.4 still latest (2026-05-09T15:11:07Z, ~13d old). mc-mxl4vc still blocked.

- **G4** — **confirmed.** PR #2088 still MERGED. No revert. No follow-up issues opened against it. §24b direct-merge variant stable.

### Surprises

1. **Branch (d): pre-existing marker blocks compact entirely.** §3 matrix didn't model the persistent-state case. The compactor's safety-net design intentionally short-circuits on a pre-existing marker (run.sh:1124-1129). On busy DBs where the marker is likely to re-arm most days, this means the compactor sits non-functional until manual clearance — a known design facet, but not internalized in the Day-32 plan.

2. **The Day-31 "row-count increase" is concretely explained by 2 identified writers.** Walking back events.jsonl for the 08:30:38–08:31:51 PT 5/21 window:

   | Time (PT) | Actor | Action |
   |---|---|---|
   | 08:31:43 | `co_shipping/gastown.witness` | created bead `mc-wisp-6da7m2` |
   | 08:31:49 | `order:mol-dog-doctor` | created bead `mc-sjehxr` + 4 rapid updates |

   Both wrote new beads to hq during the compactor's 73-second flatten interval. The safety net's row-count gain detection corresponds to real, identifiable concurrent activity. Not corruption.

3. **`gc dolt compact` is the manual repro of the order.** Running it directly surfaced the full stderr (which the `order.failed` event doesn't capture — observability gap noted in mc-jhsp8y Day-31 description). This is the diagnostic shortcut for any future "compact failed" investigation.

### What the day actually produced

1. **Reframe of mc-jhsp8y**: from "an in-flatten race exposed post-#2316" to "the safety-net design has a hair-trigger on busy DBs + a manual-clear-only persistence policy." The detection layer is working as specced (lines 1536-1559 of `run.sh`, with the design comments at 1382-1387 anticipating exactly this scenario). The operational burden is the persistence policy, not the detection.

2. **Narrowed fix-surface candidates** (not for implementation today):

   a. **Branch the persistence policy on the value-hash variant.** "with row-count increase" (today's case, correlates with normal concurrent writes) → log + retry-with-backoff up to N attempts, persist marker only if N retries all fail. "without row-count increase" (corruption-class, doesn't correlate with normal activity) → persist marker, require human (current behavior).

   b. **Time-bound the marker.** Auto-clear after 24h if no further anomaly; preserve the artifact (move to archive) for post-hoc review.

   c. **Serialize hq writers during flatten.** More intrusive; not preferred.

3. **Updated acceptance criteria for mc-jhsp8y.** Original (Day-31): "3+ daily data points OR confirm one-off after 3+ clean fires." Updated (Day-32): **one more data point on Day-33** (after Day-31 marker is cleared) is sufficient if it reproduces the same reason — given today's design analysis, n=2 + the design read is enough to call the race structurally reproducible and open a fix-shape bead.

4. **#2088 housekeeping**: moved Active → Closed/merged in `upstream-engagement-tracker.md` with §24b direct-merge writeup (commit `591a73b`, 08:00 PT — pre-fire).

### Process lessons captured

1. **Decision matrices need an "inherited state" column.** Day-32's §3 matrix modeled the day's fire outcome but not the inherited disk state (persistent quarantine marker). Future plans involving a stateful safety net should explicitly enumerate "what's on disk from yesterday and how does it affect today's branches."

2. **`events.jsonl` is the authoritative concurrent-writer ledger.** `dolt.log` only captures warnings/errors (e.g., the `backup_export not found` noise); routine SQL writes don't appear. For concurrency-class diagnosis, grep `events.jsonl` by time window with the local-time prefix (Day-27 lesson reaffirmed).

3. **Reframing is the load-bearing artifact on diagnose-days.** Two days of evidence flipped mc-jhsp8y from "find and fix a race" to "design tradeoff with operational burden." That kind of update is what prevents premature implementation. Anti-plans #8 ("no flatten-cycle-retry PR on day-2") and #10 ("preserve Day-31 marker") both proved correct.

4. **The G1 prediction structure needs a clean starting state.** Today's G1 was structurally untestable because the post-Day-31 state pre-empted the test. Day-33's G1 (after clearance) is the actual test of the structural-reproducibility claim.
