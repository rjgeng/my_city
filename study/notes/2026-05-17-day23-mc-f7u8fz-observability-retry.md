# Day 23 — mc-f7u8fz observability retry under clean-state HEAD-caa44a4

- **Plan authored:** 2026-05-13 (evening, after Phase-1 retrospective)
- **Planned execution:** 2026-05-17
- **Status:** Plan only

Phase-1 retrospective named mc-f7u8fz as the only open thread in our hands. Day-19's measurement attempt was blocked by the bd 1.0.4 regression (couldn't even close mc-2ntb2p, let alone measure reconciler cycles). Day-22 confirmed the city is now in a clean operating regime: 0 failures over 12+ hours, bd 1.0.3 symlink stable, supervisor PID 13654 alive since Day-18.

Day-23 retries the measurement under these clean conditions. Three possible outcomes (carry-over from Day-19's plan):

- **A (fixed):** the 130-commit upstream gap reduced cycle latency to acceptable range. mc-f7u8fz closes as "upgrade-as-fix" — a clean §27 worked example.
- **B (improved partially):** cycle latency reduced but still elevated. Close mc-f7u8fz with narrower scope; possibly file a follow-on bead.
- **C (persists):** the bug is real, post-upgrade. Begin code reading for the PR shape; potentially the next upstream contribution.

This is a **fix-day shape** (per Day-22's tour-vs-fix-vs-sweep framing) — falsification-first investigation aimed at decision branching.

---

## 1. Pre-flight: what the retrospective tells us

**Phase 1 state at Day-23 start:**

- gc HEAD-caa44a4 binary; formula_v2 = true; 5 control-dispatcher sessions running
- bd 1.0.3 symlink (`/usr/local/bin/bd → /usr/local/Cellar/beads/1.0.3/bin/bd`) — workaround for mc-mxl4vc, stable
- 0 `order.failed` events in events.jsonl since 2026-05-13T11:08 PT (~24+ hours by Day-23)
- Open beads: mc-mxl4vc (waiting bd v1.0.5), mc-uhvbb9 (waiting #1487), mc-f7u8fz (this day's target)
- PR #2088 OPEN, awaiting csells

**The retrospective's specific guidance for Day-23:**

> "Day-23: mc-f7u8fz observability retry. The city is functional and quiet (bd 1.0.3 symlink, 0 failures/12hr). Trace subsystem still requires explicit arming but may now produce data over a longer window. Fresh measurement attempt. If still blocked, fall back to supervisor.log timestamp-mining."

**Day-19's findings to carry forward:**

- Pre-upgrade gc 1.1.0 baseline (segment from supervisor 30730): cycle_result p50 = **129s, p95 = 237s, max = 442s, min = 61s**. 5× worse than Day-6's original 27s baseline.
- HEAD-caa44a4's trace subsystem differs from gc 1.1.0: no more `always_on` baseline writing; explicit arming required via `gc trace start --template <T> --for <duration>`.
- Day-19's arming attempt (5min on `gastown.deacon` + `control-dispatcher`) produced **zero new trace records** during the arm window. Either arm-budget isn't enough, the supervisor needs warmup, or HEAD-caa44a4 has a different trace pipeline that needs investigation.

---

## 2. What "done" looks like

**Primary outcomes (one of three):**

| Branch | Done state | §section impact |
|---|---|---|
| **A — fixed** | Median no-op tick under 5s. mc-f7u8fz closed with "upgrade-as-fix" reason. §27 gets a third worked example. | §27 grows |
| **B — improved** | Median 5-30s (better than 129s pre-upgrade, but not fully fixed). New narrower bead with the specific remaining concern. | §22 gets a "partial-fix follow-on" note |
| **C — persists** | Median > 30s. Code-reading for PR shape begins. mc-f7u8fz stays open with measurement evidence. | Likely a Day-24+ PR opportunity |

**Secondary: trace subsystem characterization.** Day-19 left the question "does HEAD-caa44a4's trace pipeline actually write data when armed?" unanswered. Day-23 needs to resolve this regardless of branch — either by getting trace data flowing OR by switching to alternate observability (supervisor.log timestamps, dolt query timing, manual cycle observation).

**Manual artifact:** §23 (Reconciler Diagnostics via `gc trace`) needs an update on the HEAD-caa44a4 changes to the trace subsystem. Probably ~20-40 added lines.

---

## 3. Execution plan

Total budget: ~90 min (fix-day shape, allowing for code-reading if Branch C).

### Step 1: Verify clean operating state + bead status (~5 min)

```bash
gc version    # HEAD-caa44a4
gc supervisor logs 2>&1 | tail -10    # any new errors?
gc convoy list    # mc-h3b7g5 should be GONE (auto-closed Day-22); any others?
grep -c '"type":"order.failed"' /Users/rfvitis/my-city/.gc/events.jsonl
# (count vs Day-22's 38 — should be unchanged if no new failures)

bd show mc-f7u8fz 2>&1 | head -10    # confirm still OPEN
```

Document any state drift from Day-22.

### Step 2: Arm tracing with a longer window + active workload (~15 min)

Day-19 tried 5-min arms on two templates; got zero data. Try:

```bash
# Arm at the detail level on multiple templates for 30 min
gc trace start --template gastown.deacon --for 30m --level detail
gc trace start --template control-dispatcher --for 30m --level detail
gc trace start --template gastown.dog --for 30m --level detail

# Verify arms are active
gc trace status

# Wait at least 2 full patrol_intervals (60s each)
sleep 120

# Now check for new trace records
find /Users/rfvitis/my-city/.gc/runtime/session-reconciler-trace/segments -name "*.jsonl" -newer city.toml
```

If any new segment appears → trace pipeline works. Proceed to Step 3.

If still nothing → trace subsystem has been refactored in HEAD-caa44a4 in ways §23 doesn't capture. Move to alternate observability (Step 4).

### Step 3a: If trace data flows — mine cycle latency (~15 min)

```bash
LATEST=$(find /Users/rfvitis/my-city/.gc/runtime/session-reconciler-trace/segments -name "*.jsonl" -newer city.toml | head -1)

jq -c 'select(.record_type == "cycle_result")' "$LATEST" \
  | jq -s 'sort_by(.duration_ms) | {
      n: length,
      p50: .[length/2 | floor].duration_ms,
      p95: .[length*95/100 | floor].duration_ms,
      max: .[length-1].duration_ms,
      min: .[0].duration_ms
    }'

# Compare to Day-19's pre-upgrade baseline (p50=129s)
# and Day-6's original baseline (p50=27s)
```

**Branch decision based on p50:**
- p50 < 5s → A (fixed)
- p50 in [5s, 30s] → B (improved)
- p50 ≥ 30s → C (persists)

### Step 3b: If trace data DOESN'T flow — alternate observability (~25 min)

Two fallback approaches:

**Approach 1: supervisor.log timestamp-mining**

```bash
# Look for the reconciler's per-tick markers in supervisor.log
gc supervisor logs 2>&1 | grep -E "session lifecycle|patrol|cycle" | head -30

# If individual tick boundaries are loggable, compute deltas between consecutive ticks
# This gives a rough proxy for cycle duration
```

**Approach 2: synthetic workload + wall-clock observation**

```bash
# Fire a few orders + observe how fast they get tracking-bead created
date
gc order run mol-dog-jsonl
sleep 5
grep 'order:mol-dog-jsonl' .gc/events.jsonl | tail -3
# Compute delta between dispatch time and tracking-bead creation time
```

Both approaches give rougher data than the trace subsystem but might be sufficient for branch determination.

### Step 4: Update §23 with HEAD-caa44a4 changes (~10 min)

Regardless of branch:

- Document that `trace_source: always_on` baseline mode was removed in HEAD-caa44a4 (Day-19 finding).
- Document that explicit arming via `gc trace start --template <T> --for <D>` is required.
- Document any new behavior surfaced by Day-23 (e.g., arming doesn't produce data without active workload? requires --level detail?).

### Step 5: Branch-specific action (~30 min)

**If Branch A (fixed):**
- Close mc-f7u8fz with reason: "Upgrade-as-fix validated; HEAD-caa44a4's reconciler reduced cycle p50 from 129s to <5s. §27 worked example."
- Add §27 worked example #3 ("mc-f7u8fz: upgrade-as-fix at the reconciler layer").
- Done.

**If Branch B (improved):**
- Update mc-f7u8fz with new measurements + close it.
- File a NEW narrower bead (e.g., "reconciler cycle p50 still elevated at <new value>; bounded scope is <specific hot path>").
- Add §22 footnote on partial-fix patterns.

**If Branch C (persists):**
- Read reconciler hot path (see Day-19 plan's Step 3 for the code-reading playbook):
  ```bash
  cd /Users/rfvitis/my-city/study/gascity-src
  ls cmd/gc/session_reconciler*.go
  grep -n 'func.*Cycle\|func.*Tick\|func.*reconcileOnce' cmd/gc/session_reconciler*.go
  git log --oneline v1.1.0..HEAD -- cmd/gc/session_reconciler*.go | head -20
  ```
- Identify the slow section.
- Decide PR vs further-investigation Day-24.

### Step 6: Document + commit + push (~10 min)

Day-23 execution log, §23 update, branch-specific manual content, single commit + push.

---

## 4. Hypotheses (G1-G5)

**G1: Trace data WILL flow this time** with a longer arm window + multiple templates. Reasoning: Day-19's 5-min arm was tight, may have expired before any cycle hit a traced template. 30-min arm + 3 templates covers more ground. **Predicted outcome:** Step 2 produces a new segment file with cycle_result records.

**G2: The cycle p50 has IMPROVED significantly** under HEAD-caa44a4. Reasoning: 130 commits past v1.1.0 include several reconciler fixes (#2023, #2034 mentioned in Day-19's commit log review). The Day-19 baseline of p50=129s was pathological — even partial fixes should push it down. **Predicted outcome:** p50 lands in [10s, 50s] range.

**G3: The §section impact is small.** Whether Branch A or B, the §section update is ~20-40 lines. Only Branch C produces a substantive new section (and even then, it's the PR work that's the artifact). **Predicted outcome:** Day-23's main work is a §23 update + a closed/updated bead, not new sections.

**G4: If Branch A or B, mc-f7u8fz closes today.** It's been open since Day-6 (12 days). A clean close completes Phase 1's "longest-open-bead" thread. **Predicted outcome:** mc-f7u8fz CLOSED status by end of Day-23.

**G5: The Day-22 baseline (0 order.failed events / 12hr) holds through Day-23.** No new regressions surface during the measurement period. **Predicted outcome:** events.jsonl `order.failed` count unchanged.

If G1-G5 all hold, Day-23 is a clean ~60-min fix-day producing a closed bead + small §23 update + zero new beads.

If G1 falsifies (no trace data), Day-23 morphs into a trace-subsystem-investigation day — could overflow to 2+ hours. Worth accepting that risk because the trace subsystem is itself worth understanding.

---

## 5. Risk / blast radius

**Step 1 (verify):** zero risk — pure reads.

**Step 2 (arm tracing):** zero risk. `gc trace start` doesn't modify city state beyond writing to arms.json; arms expire automatically.

**Step 3a (mine data):** zero risk — pure reads.

**Step 3b (alternate observability):** small risk for Approach 2 if `gc order run` triggers the city. Mol-dog-jsonl is currently working fine; firing it is normal operation. Mitigation: don't fire unfamiliar orders.

**Step 4 (manual update):** zero risk.

**Step 5 (branch action):** zero risk for A and B (bead state changes are reversible). Branch C's code-reading is zero-risk read-only; any PR shape is Day-24+ work.

**Step 6 (commit + push):** zero risk standard.

**Rollback path:** all changes are documentation + bead state. Nothing requires gc restart or city stop.

---

## 6. Connection to prior days

- **Day-6 (S4 finding):** the bead's origin. p50=27s was the original baseline. Day-23 is the closure attempt 12 days later.
- **Day-9 (validation run):** measured 65-230s under load; documented the "compounded" trajectory.
- **Day-15 era pre-upgrade segment:** Day-19's mining showed p50=129s — confirming Day-9's worse-than-Day-6 reality.
- **Day-17 (§27 embed-vs-fs):** if Branch A, Day-23 becomes §27's third worked example (PR #1848 reception was #1, day-15 SCRUB_FILTER fix was #2, this is #3 — all upgrade-as-fix patterns).
- **Day-19 (Day-19 plan was supposed to be this):** Day-23 picks up exactly where Day-19 pivoted away. The bd 1.0.4 regression is no longer the blocker.
- **Day-22 (sweep):** establishes the clean baseline against which Day-23 measures. If new `order.failed` events appear, Day-22's "0 failures/12hr" baseline gets recalibrated.
- **Phase-1 retrospective:** named Day-23 as the only "in our hands" thread. Day-23 either closes it or escalates it to a Day-24+ PR target.

---

## 7. Adjacent work

Lightweight:

- **PR #2088 status check:** any movement from csells or auto-triage relabeling? ~30 sec.
- **mc-mxl4vc release watch:** `gh issue view 3870 --repo gastownhall/beads` — has bd v1.0.5 cut? Unlikely (Day-20 was less than 24 hours ago). ~15 sec.

Soon (Day-24+):

- **Mayor handoff experiment redux** (Phase-1 retrospective Day-24 candidate). With §29's convoy disambiguation, mayor's explicit convoy creation may produce a different result than Day-16's null.
- **Mail subsystem tour** (Phase-1 retrospective candidate). After convoys (§29) and orders (§25), mail is the next user-curated dispatch primitive worth its own §section.
- **The renames + .beads/config.yaml** still pending in user's working tree. Yours.

---

## 8. Optional: mayor handoff

Skip. mc-f7u8fz is a §22-style falsification investigation; mayor delegation doesn't add value here. (Phase-1 retrospective noted the consistent pattern: "decisions get checked; explorations get delegated" — this is an exploration, but the kind I do directly, not via mayor.)

---

## 9. Execution log

(filled in as work happens)

### Step 1: state verify

- gc version:
- Supervisor uptime:
- New convoys since Day-22:
- order.failed count delta:
- mc-f7u8fz state:

### Step 2: arm tracing

- Arms successfully registered:
- `gc trace status` output:
- Wait duration:
- New segment files since arms:
- G1 verdict (trace data flows):

### Step 3a OR 3b: measurement

- Approach used (3a / 3b):
- Records mined:
- p50 / p95 / max / min:
- Comparison to Day-6 baseline (27s) and Day-19 pre-upgrade (129s):
- Branch determined (A / B / C):

### Step 4: §23 update

- HEAD-caa44a4 trace changes documented:
- New behavior surfaced:

### Step 5: branch action

- (A) mc-f7u8fz closed reason:
- (B) New narrower bead ID:
- (C) Reconciler hot-path findings:

### G1-G5 verdicts

- G1 (trace data flows):
- G2 (p50 improved significantly):
- G3 (§section impact small):
- G4 (mc-f7u8fz closes today):
- G5 (Day-22 baseline holds):

### Surprises

(things this plan got wrong, or new things surfaced)

### Anything to promote

(filled in after the day)
