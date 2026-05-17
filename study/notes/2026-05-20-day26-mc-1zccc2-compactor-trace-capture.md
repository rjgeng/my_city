# Day 26 — mc-1zccc2 compactor trace capture (predicted 08:00 PT fire)

- **Plan authored:** 2026-05-15 (Day-25 evening, immediately after canonical soak read closed)
- **Planned execution:** 2026-05-20
- **Earliest sensible execution:** 2026-05-16 — must arm BEFORE the predicted ~08:00 PT compactor fire window
- **Status:** Plan only.

Day-25 surfaced **`mc-1zccc2`** — `mol-dog-compactor` exit-1 on two consecutive daily runs (5/14 + 5/15, both ~08:04 PT). Pattern strongly suggests a deterministic, reproducible bug. Day-26 captures the actual stderr from the next predicted fire to identify which step exits 1.

This is a **diagnostic-day shape** — narrow scope, time-sensitive (must arm before the predicted fire), pure observation. No code changes.

---

## 1. Pre-flight context

**State going in:**

- mc-1zccc2 OPEN, P3 BUG, daily-order pattern documented
- Compactor fires daily ~08:00 PT (drifts +1 min/day: 08:02 → 08:02 → 08:03 over recent days)
- Last 2 fires (5/14 + 5/15) both exited 1 at ~08:04 PT (~80s after fire)
- Distinct surface from mc-w9iua4 (compactor doesn't push to git; does dolt history flattening)
- gc HEAD-caa44a4 + bd 1.0.3, supervisor stable (PID 782 since 5/14 morning)

**Key Day-24/25 lessons applied:**

1. **Template naming:** `gastown.dog` doesn't exist. Dogs run inside `gastown.deacon`. Arm that template.
2. **Trace flows without arming under HEAD-caa44a4** — but per-template detail level isn't on by default. Arm explicitly to get the per-step trace records.
3. **Events.jsonl direct grep beats `gc events --since`** for any historical query.
4. **jq parenthesization:** `select((.subject | startswith("...")) and (.ts >= "..."))`, NOT `select(.subject | startswith("...") and (.ts >= "..."))`.
5. **Burst pattern is a myth** for mol-dog-jsonl. For compactor, the daily pattern IS real — single fire per day.

**Predicted next fire:** 2026-05-16 between 08:03 and 08:05 PT (extrapolating the 1-min/day drift).

---

## 2. What "done" looks like

**Primary outcome (one of three branches):**

| Branch | Done state | Next action |
|---|---|---|
| **A — captured + diagnosed** | Trace records show which step of mol-dog-compactor exits 1 with what stderr. Root cause classified (dolt-side / script-side / config-side). | If fix shape clear: write fix; possibly open PR. If escalation needed: file upstream issue or comment on existing bug. |
| **B — fire missed (arm timing wrong)** | Arm window didn't cover the actual fire (started too late, or fire drifted >5 min). | Re-arm tomorrow with widened window (~07:45-08:30 PT). Day-26 ends with a "missed, rearm queued" note. |
| **C — captured but trace doesn't show stderr** | Fire happened in window; trace records exist; but stderr from the failing step isn't in the captured records. | Fall back to direct dolt observation: query dolt for state changes around 08:04 PT; check supervisor.log; check segment files manually for stderr-like content. |

**Secondary outcomes regardless of branch:**

- Update mc-1zccc2 with whatever was learned (or with the "couldn't capture" note)
- Update runbook-soak-pr-review.md with any new lessons (e.g., "for daily-cadence orders, arm window must cover fire + ~5min slop on each side")

---

## 3. Execution plan

Total budget: **~2 hours** active work, with a critical pre-fire arm window (~07:45 PT).

### Step 1: Pre-flight (~07:30 PT, ~5 min)

```bash
cd /Users/rfvitis/my-city
date
gc version
bd show mc-1zccc2 2>&1 | head -5
gc trace status 2>&1
grep -c '"type":"order.failed"' .gc/events.jsonl   # baseline
```

Confirm:
- gc still HEAD-caa44a4
- mc-1zccc2 still OPEN
- No active arms (or note any existing ones)
- Capture pre-arm event count

### Step 2: Arm trace BEFORE the predicted fire (~07:45 PT, ~5 min)

```bash
# 45-min window: 07:45 PT → 08:30 PT, covers fire + slop on both sides
gc trace start --template gastown.deacon --for 45m

# Verify arm registered
gc trace status

# Record arm timestamp for later correlation
echo "Arm started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /tmp/day26-marker.txt
```

**Why 45 min:** observed fires at 08:02 (5/13), 08:02 (5/14), 08:03 (5/15) — drift of ~1 min/day. A 07:45-08:30 window covers (i) the predicted 08:04 fire, (ii) the ~80s exec window before exit-1 at ~08:05, (iii) ~25 min slop on each side for safety.

### Step 3: Wait + observe (~08:00-08:10 PT, passive)

Don't poll; the harness will notify when interesting events arrive. Optional checks:

```bash
# Live tail trace records as they arrive (during the wait)
gc trace tail --template gastown.deacon --since 5m
```

If the user is around: leave it running; report when the fire happens.

### Step 4: Identify the failure (~08:15 PT after fire, ~15 min)

```bash
# Did the order fire as predicted?
gc events --type order.fired --since 1h 2>/dev/null \
  | jq -r 'select(.subject == "mol-dog-compactor")'

# Did it fail?
gc events --type order.failed --since 1h 2>/dev/null \
  | jq -r 'select(.subject == "mol-dog-compactor")'
```

If both fire + fail observed:

```bash
# Dump deacon's session activity around the failure window
TODAY=$(date +%Y/%m/%d)
LATEST_SEGMENT=$(find .gc/runtime/session-reconciler-trace/segments/$TODAY -name "*.jsonl" | sort | tail -1)

# Look for stderr-like content + cycle records around the failure ts
grep -E "compactor|dolt|exit|error|stderr|fail" "$LATEST_SEGMENT" | head -30

# Get the cycle around 08:04 PT (= UTC 15:04)
TS_LOWER="2026-05-16T15:00:00"
TS_UPPER="2026-05-16T15:10:00"
jq -c "select(.ts >= \"$TS_LOWER\" and .ts <= \"$TS_UPPER\")" "$LATEST_SEGMENT" \
  | head -50
```

Look for: which step of the compactor formula exited 1, what stderr looks like, whether dolt had an error or git had an error or the script aborted on its own assertion.

### Step 5: Stop arm (or let expire) + classify finding (~10 min)

```bash
gc trace stop --template gastown.deacon  # or just let auto-expire
```

Classify the failure cause into one of:

- **Dolt-side:** dolt query/command returns nonzero (e.g., compaction-specific lock, transaction conflict, schema issue)
- **Script-side:** the formula's bash script has a logic error (e.g., assumption about dolt output that's no longer true)
- **Config-side:** `formula_v2 = true` enabled the order but the formula's contract uses something that's not supported (similar to the pre-Day-15 contract error, but at runtime not load-time)
- **External:** something else in the environment blocked it (network, permissions, disk)

### Step 6: Decide next action (~15 min)

Based on Step 5 classification:

| Classification | Next action |
|---|---|
| Dolt-side | File upstream issue against `gastownhall/beads` or related dolt bug tracker. Note in mc-1zccc2 with link. |
| Script-side | Locate the script (`study/gascity-src/examples/dolt/commands/compact/`?). Identify the bug. If small fix: shape an upstream PR per §24 playbook. If complex: file upstream issue with reproduction. |
| Config-side | Check formula_v2 contract requirements against compactor's formula declaration. May be a downgrade (formula_v2 → formula_v1) or a contract update. |
| External | Less likely. If so, document and watch — may be transient. |

Update mc-1zccc2 with classification + next-action plan + supporting evidence.

### Step 7: Close out (~10 min)

- Append Day-26 result note to mc-1zccc2 via `bd update --append-notes`
- Fill in §6 (execution log) below
- If a §22/§23 lesson emerged, note it here for future tour-day fold-in
- Update upstream tracker if a new upstream item gets filed
- Commit + push

---

## 4. Anti-plans

- **Don't arm too early.** Arming at 06:00 PT for an 08:00 fire wastes the arm budget on idle time + may miss late drift. 45 min covering the predicted window is right.
- **Don't arm too narrow.** A 10-min arm tightly bracketing 08:00 PT could miss a 08:11 PT fire. 45 min has the margin.
- **Don't assume the fix.** mc-w9iua4 was push-race; mc-1zccc2 is a different surface entirely. Don't pattern-match to "must be a race" or "must be a config thing" before reading the actual stderr.
- **Don't expand scope.** Even if the trace surfaces info about other dogs/templates, focus on compactor today. File separate beads if needed.
- **Don't open an upstream PR Day-26.** Day-26 is diagnostic, not fix-ship. PR shaping is for a future fix-day.

---

## 5. G1-G3 predictions (falsifiable)

**G1: The compactor will fire between 08:00-08:10 PT 2026-05-16.** Reasoning: 3 prior fires at 08:02, 08:02, 08:03 PT with consistent +1 min/day drift. **Predicted outcome:** fire observed in 08:02-08:05 PT range.

**G2: The fire will exit 1.** Reasoning: 2 consecutive failures at 08:04 PT, no intervening config change, no other variable changed. **Predicted outcome:** order.failed at ~08:04 PT.

**G3: The trace will show the failing step + stderr.** Reasoning: gastown.deacon is where dogs run; arming detail level on that template should capture per-step output. **Predicted outcome:** Step 4's grep finds clear failure context within the trace records.

If all 3 hold → Branch A. If G1/G2 fail → Branch B. If G1/G2 hold but G3 fails → Branch C.

---

## 6. Execution log

(filled in 2026-05-17 — Day-26 slipped one day; 5/16 arm window was missed, re-armed and executed 5/17)

### Step 1: pre-flight

- gc version: HEAD-caa44a4
- mc-1zccc2 state: OPEN (P3 BUG)
- Pre-arm timestamp: 2026-05-17T13:19:37Z (06:19 PT)
- Pre-arm order.failed count: 101

### Step 2: arm registered

- Arm timestamp: 2026-05-17T13:19:37Z
- Window: 2h30m, expires 2026-05-17T15:49:37Z (08:49 PT) — covers predicted 08:05 fire + ~45min slop
- Templates armed: gastown.deacon (detail level)

### Step 3: fire observation

- Predicted fire window: 08:00-08:10 PT
- Actual fire ts: ~08:04-08:06 PT (G1 hit — within predicted band)
- Actual failure ts (if any): immediate, same cycle (exit-1 in seconds, not minutes)
- Fire-to-fail interval: ≪1 minute (script-side abort, not dolt-execution-side timeout)

### Step 4: failure analysis

- Stderr captured (yes/no): **No via trace; Yes via manual repro**
- Stderr content: `compact: db=hq HEAD changed before flatten want_HEAD=<X> got_HEAD=<Y> — aborting before reset` (on local bundled gascity-src; upstream main post-#2225 produces the post-flatten value-hash variant)
- Failing step identified: `compact/run.sh:962-968` (on bundled version) / line 1227-1243 area (post-#2225 main) — check-then-act race on hq HEAD between preflight gather and DOLT_RESET
- Cycle tick_id: not captured (trace scope mismatch — see Step 7 lessons)

### Step 5: classification

- Bucket: **script-side** (check-then-act race in shell script, not dolt-side / config-side / external)
- Supporting evidence: 4 quiet DBs (cs, ship, hw, auth) compact fine on every run; only hq fails. hq is the busiest DB (mail/beads/wisps/sessions all commit constantly). The race window is between `head_commit "$db"` capture and `DOLT_RESET --soft + DOLT_COMMIT`. Same class as mc-w9iua4 push race (PR #2136).

### Step 6: decision

- Next action: fix bead filed + upstream PR opened (against the plan's "Day-26 = diagnostic only" anti-plan — user-authorized mid-day)
- Upstream item filed (URL): https://github.com/gastownhall/gascity/pull/2316 (`fix(dolt): retry preflight when HEAD races on busy DBs in gc dolt compact`)
- Fix bead: mc-4m2da1 (links mc-1zccc2 diagnosis → PR)

### G1-G3 verdicts

- G1 (fire happens 08:00-08:10 PT): **HIT** — fire observed in band (matched +1 min/day drift extrapolation)
- G2 (exits 1): **HIT** — order.failed observed, consistent with prior 2 daily runs
- G3 (trace shows stderr): **FALSIFIED** — `gastown.deacon` arm captured controller cycle events but not subprocess stderr. Trace template scope is controller cycles, not order subprocess output. **Branch C** outcome per §2 — fell back to manual repro for the stderr.

### Surprises

1. **Upstream main moved overnight (5/16 13:52 PT).** PR #2225 (julianknutsen) refactored `flatten_database()` and incidentally removed the pre-flatten HEAD-check that mc-4m2da1's fix shape was written against. Race still present post-#2225; symptom shifted from explicit "HEAD changed before flatten" abort → "value hash changed after flatten" quarantine. Same exit-1 outcome from order's POV.
2. **The Day-25 prediction of "Day-26 is diagnostic-only" held during the arm window but cracked during analysis.** Manual repro produced a fix shape so clean that we shipped the PR same-day (per user decision). The anti-plan was correct in principle but the diagnosis surfaced a low-effort fix.
3. **`gastown.deacon` trace template doesn't capture subprocess stderr.** The §27 observability gap. Was expected to capture per-step trace records from dogs running inside the deacon, but only got cycle-tick records.

### What the day actually produced

- mc-1zccc2 update: appended classification (script-side race), root cause (compact/run.sh check-then-act on hq HEAD), and §27 observability gap note. Acceptance criteria 1+2 met; 3 advanced via PR; 4 still pending.
- Upstream items filed: PR #2316 (gastownhall/gascity); fix bead mc-4m2da1 (HQ).
- Lessons captured (rolled into `study/notes/runbook-soak-pr-review.md` Lessons table):
  1. `gastown.deacon` trace template scope = controller cycles, NOT subprocess stderr. For order-dispatcher subprocess stderr, fall back to manual repro or wait for stderr-plumbing into events.jsonl.
  2. Diagnostic-day anti-plan ("don't open a PR Day-N") is a default, not a rule. If the diagnosis surfaces a low-effort fix matching a proven prior pattern (#2136 retry-with-backoff), shipping same-day is acceptable.
  3. Upstream-state freshness check: before writing a fix against a stale-bead's line reference, `git fetch origin main` and confirm the target structure is unchanged. Saved this PR from being filed against a phantom function shape.
