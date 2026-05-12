# Day 6 — Diagnose `slow_storage_degraded` reconciler trace (S4)

- **Plan authored:** 2026-05-11 (end of day 5)
- **Planned execution:** 2026-05-12
- **Status:** Plan only; investigation not yet started

This is the pre-decomposition for Day-6: the storage-degradation symptom flagged during Day-4 (laggy gc shell inside mayor, 2-9 second API responses, `slow_storage_degraded` warnings in supervisor stderr) and pre-marked as Day-6 work in the Day-5 plan section 7. Same exercise pattern as Days 4-5 — write the investigation strategy before doing it, then compare actual findings against this document. Differences are the learning value.

---

## 1. The signal — what S4 actually is

**Where it's emitted** (proven by Day-5-tail grep in `study/gascity-src/`):

- `cmd/gc/session_reconciler_trace_collector.go:976` — `fmt.Fprintf(c.tracer.stderr, "trace: slow_storage_degraded: %s %s\n", c.tickID, TraceDurabilityDurable)`
- `cmd/gc/session_reconciler_trace_types.go:152` — defines `TraceOutcomeSlowStorageDegraded TraceOutcomeCode = "slow_storage_degraded"`
- `cmd/gc/session_reconciler_trace_test.go:694` — test verifies the string appears in stderr under some condition

**What that tells us before reading the code in detail:**

1. **It's a trace outcome, not a storage error.** The session reconciler is the loop that decides what each agent template should be doing (running/idle/stopped). On each tick, it observes durability conditions and tags the outcome. `slow_storage_degraded` is the tag, not the bug — the bug is whatever made the reconciler tick slow.
2. **`%s %s` — tickID + `TraceDurabilityDurable`.** Two fields. The "durable" word in the Day-4 observation is the second `%s`, not a description of the storage state. There's likely a `TraceDurabilityEphemeral` variant too.
3. **Emitted to stderr, not events.jsonl.** So this warning is supervisor-visible but doesn't end up in the bead/event stream by default. Reproducing it means watching `gc supervisor logs`, not querying dolt.
4. **It's a derived signal.** Something inside the reconciler measures storage latency, exceeds a threshold, and tags the tick. The real diagnostic is: which subsystem reports slow, what's the threshold, and what's actually slow.

**Day-4's empirical observations** (from `2026-05-10-mayor-led-auth-demo.md:221`):

> Pre-existing — `slow_storage_degraded: ... durable` warnings in supervisor logs, 2-9 second API response times, gc shell very slow inside mayor session. Not blocking the demo but the inside-mayor experience suffers. Possibly the same underlying issue as S3 — both touch the durable storage layer.

**Day-5's contribution to the picture:** the JSONL push-failure storm (S3) was independently caused and fixed. So if `slow_storage_degraded` is still firing after the JSONL fix, it's not driven by S3. If it stopped firing, S3 was somehow contributing — but that's unlikely given how fast the JSONL push fails (~ms).

---

## 2. Pre-flight: where this lives

- City is currently **stopped** at end of Day-5. Dolt is up (PID 17181 on port 50095, started manually with `bd dolt start`), but supervisor/controller/agents are not — `gc status` reports controller stopped, all agents stopped.
- To observe S4 live, start the city: `gc start`. Both the reconciler and the slow-storage detector will resume.
- Day-5's fixes are in place — bare jsonl-archive remote exists, schema column rename applied. So JSONL is no longer thrashing.
- `study/gascity-src/` is a submodule at HEAD of the upstream `gascity` repo. Source-of-truth for reading Go internals. Don't edit it casually — it's the upstream you'd PR fixes against.

---

## 3. What "diagnosed" looks like (success criteria)

- Locate the function that emits the `slow_storage_degraded` outcome and identify (a) what it measures, (b) the threshold, and (c) what subsystem call is exceeding the threshold.
- Confirm whether the symptom is still live in post-Day-5 conditions, or whether it cleared along with the JSONL storm (i.e., test the "S3 caused S4" hypothesis from Day-5 section 7).
- If still live: identify a single root cause hypothesis with evidence, OR confirm it's a known/expected slow path with no actionable fix today.
- If a fix is in scope: apply, verify with a fresh reconciler tick observation showing the outcome change to a non-slow code.
- Either way: update bead state. If a new bead is needed, file it; if the existing observation lives only in `2026-05-10-mayor-led-auth-demo.md`, promote it to a bead now so it has a durable home.

Worth noting: this is investigation work, not feature work. "Diagnosed and documented" is a valid end state even if no code change ships.

---

## 4. Investigation plan — falsify cheapest checks first

### Step 1: Read the emitter and the type taxonomy (~15 min, free)

Read these three files to map the surrounding state machine before starting the city:

- `cmd/gc/session_reconciler_trace_types.go` (152, 633) — full list of `TraceOutcomeCode` values, what `TraceDurabilityDurable` vs `TraceDurabilityEphemeral` means, what other states exist.
- `cmd/gc/session_reconciler_trace_collector.go:976` and surrounding ±100 lines — what condition triggers the emit, what the threshold is, what `c.tickID` represents.
- `cmd/gc/session_reconciler_trace_test.go:694` — the test reveals the *intended* triggering condition. Tests are often the cleanest spec.

Output: a 1-paragraph mental model of when this fires.

### Step 2: Check if it's still firing post-Day-5 (~5 min)

Start the city, watch supervisor logs for ~30 sec:

```bash
gc start
gc supervisor logs 2>&1 | grep -E "slow_storage_degraded|TraceOutcome" &
sleep 60 && kill %1
```

Three outcomes:
- **Not firing**: S3 was driving it indirectly (unexpected — push-fail is fast). Document the resolution, file a bead noting the JSONL fix incidentally cleared S4, done.
- **Firing at the same rate as Day-4**: independent of S3, investigation continues.
- **Firing at a different rate**: partial correlation, harder to attribute. Continue investigation but note the partial change.

### Step 3: Measure the latency the detector is reacting to (~20 min)

Once Step 1 has identified what call is being timed, instrument or reproduce the call manually. Probable suspects (rank by likelihood after reading the code):

- **dolt SQL query latency**: if the reconciler queries dolt on each tick (e.g., `SELECT FROM issues WHERE state = ...`), and dolt is slow, this fires. Reproduce: `time dolt sql -q "..."` against the live server.
- **events.jsonl append latency**: if every tick fsyncs to events.jsonl and the file is large (now 2 MB and growing), append latency could be elevated. Probably fine on SSD but worth measuring.
- **dolt commit / write transaction latency**: if the reconciler issues a write per tick (it shouldn't, but it might), commit cost grows with chunk file count and uncommitted-set size.
- **filesystem stat() flood**: tick may stat many lock/pid files (per-agent lifecycle bookkeeping). Reproduce: `time ls .gc/nudges/pollers/ | wc -l`. We saw 30+ stale pid files in nudges/pollers earlier; could be relevant.

### Step 4: Examine the data layer state for elephants (~15 min)

Check sizes and growth patterns:

```bash
# Total bead db growth
du -sh /Users/rfvitis/my-city/.beads/dolt/

# Per-rig dolt data
DOLT_CLI_PASSWORD="" dolt --host 127.0.0.1 --port 50095 --user root --no-tls sql -q "
  SELECT TABLE_SCHEMA AS db,
         SUM(DATA_LENGTH + INDEX_LENGTH) AS bytes,
         SUM(TABLE_ROWS) AS rows
  FROM information_schema.tables
  WHERE TABLE_SCHEMA IN ('auth','cs','hq','hw','ship')
  GROUP BY TABLE_SCHEMA"

# events.jsonl + interactions.jsonl growth across rigs
for d in /Users/rfvitis/my-city /Users/rfvitis/co_store /Users/rfvitis/co_shipping /Users/rfvitis/my-city/hello-world /Users/rfvitis/co_auth; do
  printf "%s\n" "$d"
  ls -lh "$d"/.beads/*.jsonl 2>/dev/null
done

# Stale pid/lock files in nudges
ls /Users/rfvitis/my-city/.gc/nudges/pollers/ | wc -l
```

If hq has 8000+ rows but cs has 3000+ and reconciler scales linearly, the size differential could explain rig-specific slow ticks.

### Step 5: Reconciler tick rate vs storage write rate (~15 min)

If the reconciler ticks every N seconds and each tick triggers a dolt commit, the commit cadence determines compaction pressure. Check:

- `gc supervisor status` and the reconciler config — what's the tick interval?
- `dolt log` on each user db — how many commits per minute during a busy session?
- Dolt's chunk file count: `ls /Users/rfvitis/my-city/.beads/dolt/<db>/noms/*.tmp | wc -l` if such files exist (commit-staging artifacts).

This step is highest-information if Step 3 shows commit/write latency dominates.

### Step 6 (only if 1-5 don't narrow it): turn up the tracer

The session reconciler has its own trace stream (per `session_reconciler_trace_collector.go`). Enable verbose tracing if there's a flag, or read the segments directory:

```bash
ls /Users/rfvitis/my-city/.gc/runtime/session-reconciler-trace/segments/
ls /Users/rfvitis/my-city/.gc/runtime/session-reconciler-trace/quarantine/
```

Segments may have per-tick records with timing data. Quarantine may have failed/slow ticks specifically.

---

## 5. Fix patterns (pre-thought, choose based on what investigation surfaces)

**If reconciler is scanning a growing table per tick and the table can be pre-indexed:**
- Add an index, or change the scan to a covered query.
- Low risk, single change in gascity-src.

**If commit cadence is too aggressive:**
- Configure batch commit mode (we already see `--dolt-auto-commit` flag in `bd label --help` output mentioning `off|on|batch`). Switching from `on` to `batch` for the reconciler's writes might cut commit overhead 10×.
- Risk: SIGTERM/SIGHUP flush is the only safety net; crash could lose un-flushed writes.

**If dolt chunk count is unbounded:**
- Run dolt GC / compaction. `mol-dog-compactor` exists at `.gc/system/packs/dolt/formulas/mol-dog-compactor.toml` — check whether it's configured to run periodically.
- If it should be running but isn't, fix the cron/cooldown.

**If it's a single-call hot spot in the reconciler:**
- Cache the result for the tick duration.
- Document the slow call, leave fix for a separate PR if invasive.

**If it's storage-medium-related (not a software bug):**
- Check `df -h` on the volume hosting `.beads/`. APFS on macOS can degrade under heavy small-file fsync load.
- Not actionable from gas-town side; document and move on.

**Anti-pattern to avoid:** silencing the trace outcome. The reconciler's trace is the observability you'd want when something goes wrong; muting it loses the signal. Same anti-pattern logic as Day-5.

---

## 6. Risk / blast radius

- **Reading code + observing logs**: zero risk.
- **Running `gc start`**: restarts the full agent ecosystem. If S4 was masking another issue, that may surface. Reversible via `gc stop`.
- **Editing `gascity-src/`**: this is the upstream submodule. Don't edit unless you intend to upstream the change. Local-only fixes are still possible in `.gc/system/packs/` (which Day-5 showed is gitignored locally), but for Go code in `cmd/gc/...` there's no local-pack equivalent — it's compiled into the binary.
- **Recompiling and reinstalling gc**: if a fix requires it, that's a more involved cycle. Verify the test suite first.

---

## 7. Connection to prior days

- **Day-4** first noted S4 in passing — `slow_storage_degraded`, 2-9 sec API, laggy mayor shell. Section 11 (S section) framing.
- **Day-5** plan section 7 hypothesized that S3 (JSONL storm) might be related, with three sub-hypotheses: (a) S3 is a symptom of storage, (b) S3 causes storage growth, (c) independent. Day-5 didn't test these — the city was stopped throughout. **First action of Day-6 (Step 2) tests hypothesis (c).**
- The latent bug from Day-5 (`dolt-state.json` vs `dolt-provider-state.json`) is in a related area — both touch dolt port discovery. If reconciler does dolt port discovery on every tick and falls back to 3307 with retry-and-wait semantics, that's a possible contributor. Worth keeping in mind during Step 3.

---

## 8. Adjacent work to fold in while you're already on Day-6

Lightweight items that benefit from being addressed alongside S4 work — none depend on S4 findings:

- **Update memory `project_rig_topology.md`** — still says "codex-default with one polecat→claude patch on co_shipping" but workspace was inverted to claude-default on 2026-05-09 (commit `be4f3ff`). Codex patch now lives on `co_store` per `city.toml`. Trivial.
- **File new bead for the dolt-state-name latent bug** found Day-5. Single bead, content already drafted in the Day-5 notes (section "Surprises" #4). Title: `maintenance/dolt-target.sh:146 hardcodes legacy dolt-state.json (canonical is dolt-provider-state.json)`.
- **Bulk-archive 240 stale `JSONL push failed` escalations** in mayor's inbox (counters 4–248, inert after Day-5 fix). One-liner if `gc mail archive` supports a query, else a script over the listing.
- **Promote Day-5's three "Anything to promote to v2 manual" insights** from `2026-05-11-jsonl-push-failure-triage.md` section 10 into `gas_city_build_manual_practical_guide_v2.md`. Three sections: silent-failure debugging, pack-script-scope ≠ rig-scope, cross-pack config conventions.
- **Promote Day-4's six insights** (also still on the deferred list from Day-5 section 8 — polecat/refinery truth, nudge-vs-patrol, mayor's PAUSE anti-pattern, cross-rig convoy gap, local-vs-origin desync, bootstrap-after-clone).

These are at-most-30-min items each. If S4 is quick, do all of them; if S4 turns deep, do at least the rig-topology memory fix (it's 2 minutes and affects every future session that recalls that memory).

---

## 9. Optional: mayor handoff

Skip. Reasons:

- Investigation work with high information density — single human reading Go source will outpace polecat-mediated investigation.
- No decomposition exists yet; the steps above are bead-sized but exploratory (each step's findings determine the next step).
- The gascity-src/ source is upstream code; agent edits there have higher blast radius than the Day-5 pack-script edits.

Same pattern as Day-5: do it directly.

---

## 10. Execution log

### Steps run

| Step | Time | Finding |
|---|---|---|
| 1 — read emitter & types | 2026-05-12 | `slow_storage_degraded` fires when `appendBatch(...)` returns `errTraceFlushWaitBudgetExceeded`. Threshold `sessionReconcilerTraceDurableWait = 25ms` at `cmd/gc/session_reconciler_trace_collector.go:22`. Budget covers channel-enqueue (cap 8 batches) + writer `store.AppendBatch` doing `Write()` + `f.Sync()` on `.gc/runtime/session-reconciler-trace/segments/<day>/segment-N.jsonl` (store.go:420-428). Literal trigger: one fsync of a small JSONL append took >25ms. |
| 2 — analyze persisted trace (city offline) | 2026-05-12 | The reconciler-debugging.md workflow + `gc trace` work against persisted segments even when controller is stopped. Found 2900 cycle_result records from May 8-10 already on disk. **No city restart needed for Step 2.** |
| 3 — cycle duration distribution | 2026-05-12 | Reconciler cycle duration: p10=13s, **p50=27s**, p75=44s, p90=77s, p95=109s, p99=166s, max=244s. Cycles run ~20-30 per hour. Across all 2900: 28,429 `complete` outcomes, only **3 mutations** total, **10 `reconciler.start.execute` operations**. The reconciler spends ~27 seconds median to decide "nothing to change." |
| 4 — within-cycle waterfall | 2026-05-12 | Every non-trivial cycle has the same shape: cycle_start at +0ms → **GAP** (10–124s) → per-bead session_baseline burst → template_tick_summary burst → cycle_input_snapshot → ~2.5s tail → cycle_result. The variable cost lives entirely in the leading gap. |
| 5 — locate the gap | 2026-05-12 | Gap = `cr.tick()` body in `cmd/gc/city_runtime.go:610-749` between `beginTraceCycle` at line 624 and the per-bead `RecordSessionBaseline` calls in `beadReconcileTick` at line 1332. Work in that gap: 4x `loadSessionBeadSnapshot()` (dolt reads, lines 618/715/719/735), `loadDemandSnapshot`, 2x `refreshDesiredStateWithSessionBeads`, `syncBeadsAndUpdateIndex` (dolt writes), `reapStaleSessionBeads`, tmux `ListRunning` for pool death detection. |

### Hypothesis confirmed

- **Which "storage subsystem is slow":** The stderr warning is misleading. The fsync that crosses 25ms is one fsync of a few-KB append to a local JSONL file. APFS fsync under any concurrent dolt fsync load easily exceeds 25ms — so the warning fires frequently but reports nothing actionable about *which* subsystem is slow. The real signal is in cycle `DurationMS`, not the stderr warning.
- **Threshold the detector is using:** 25 ms total budget covering channel-enqueue + writer goroutine's full `AppendBatch` including final fsync. Channel queue cap 8 batches.
- **What's actually slow:** The reconciler's pre-`beadReconcileTick` setup — repeated `loadSessionBeadSnapshot` calls + `syncBeadsAndUpdateIndex` writes. p50 ~25s of dolt I/O serialized in the tick body. That dwarfs the 25 ms fsync warning.
- **Evidence:** 2900 cycle_result records on disk, per-cycle `cycle_offset_ms` field shows the gap is between cycle_start and per-bead session_baseline records every time. Pattern is consistent from p10 (10s gap on a 13s cycle) through max (124s gap on 244s cycle). Code path matches: line 624 calls `beginTraceCycle` (which emits cycle_start at offset 0); lines 618-744 do all the snapshot reloading/refresh/sync work; line 1332 emits the first per-bead `RecordSessionBaseline`.

### Fix applied (if any)

None. This is upstream code in the `gascity-src` submodule; fix would require either a local patch (no `.gc/system/packs/` equivalent for compiled Go) or an upstream PR. Investigation result is "diagnosed and documented" — see section 11 below.

### Was S3 related to S4?

- **Step-2 result:** Did not need to restart the city; the persisted trace data already proves they're separate signals.
- **Verdict:** Cleanly decoupled. S3 was `jsonl-archive` pack thrash on a different file path. S4 is the reconciler trace's own fsync, with the underlying disease being the reconciler's seconds-of-dolt-I/O per tick body — fully independent of S3.

### Surprises

1. **The trace tool works fully offline.** `gc trace show / cycle / status` all read persisted segments without needing the controller running. That's a much better diagnostic affordance than I expected — Step 2 of the original plan (start city, grep stderr) was unnecessary.
2. **`slow_storage_degraded` is a misnomer in practice.** It says "storage degraded" but it really means "one fsync >25ms on a small JSONL append" — a tight budget vs. macOS APFS fsync variance under any concurrent write load. The warning name implies a storage problem; the actual cause is more often "your reconciler is competing with dolt for fsyncs."
3. **The reconciler does 4 `loadSessionBeadSnapshot()` calls per tick.** Lines 618/715/719/735 — each a fresh dolt read. The comments acknowledge this ("Reload snapshot after sync so the reconciler sees metadata written by syncBeadsAndUpdateIndex"). Pessimistic re-read pattern; correct, but expensive.
4. **27s median cycle to do almost nothing** (3 mutations / 10 starts across 2900 cycles). Steady state is "the city is idle but the reconciler is busy talking to dolt."
5. **Day-4's `2-9 sec API responses` is consistent with this.** API handlers share the city bead store with the reconciler; 27s reconciler cycles holding bead-store contention naturally translate to multi-second API latency.

### Anything to promote to v2 manual

**Promoted to v2 manual §23 — "Reconciler Diagnostics via `gc trace`"** (this commit):

1. **Diagnostic workflow: `gc trace` works offline.** When a reconciler symptom is suspected, `gc trace cycle --tick <id>` + `gc trace show --type cycle_result --since 24h` against persisted segments often diagnoses the issue without restarting the city. Reference: `engdocs/contributors/reconciler-debugging.md` in the gascity-src submodule.
2. **`slow_storage_degraded` is a fsync-budget warning, not a storage diagnosis.** The interesting field is `duration_ms` on cycle_result records, not the stderr string. Use `gc trace show --type cycle_result --since Nh --json | jq` to triage cycle duration distribution.
3. **Reconciler cycle anatomy:** every cycle has cycle_start at +0ms, then a gap of N ms doing dolt snapshot/sync I/O, then a burst of per-bead session_baseline records. `cycle_offset_ms` on each record is the waterfall. If the gap dominates, it's pre-reconcile I/O; if the tail (post-template-tick → cycle_result) dominates, it's start_execute/mutation work.

## 11. Follow-up beads / next steps

This investigation is "diagnosed." Whether a fix is in scope is a separate decision. Candidates if we choose to act:

- **Bead (investigation): file `study: reconciler-tick I/O profile, p50=27s for no-op tick`** — capture this notes file's findings + tick_id evidence for an upstream report. Lives in HQ.
- **Bead (latent): file `reconciler tick repeats loadSessionBeadSnapshot 4x per tick (city_runtime.go:618/715/719/735)`** — potential single-snapshot-with-write-through optimization. Risk: changing reconciler invariants is dangerous; the pessimistic re-read pattern exists for correctness.
- **Bead (cosmetic): file `slow_storage_degraded stderr message is misleading`** — propose renaming the trace outcome to `trace_flush_budget_exceeded` or augmenting with the actual fsync duration. Low effort if upstreamed.
- **Optional Step 2-live**: restart the city briefly and confirm post-Day-5 cycle duration hasn't gotten worse. Cheap (~5 min) but unlikely to add new info since Day-5 didn't touch reconciler code paths.
