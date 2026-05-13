# Day 19 — mc-f7u8fz reconciler no-op tick: re-measure under HEAD-caa44a4, then upstream

- **Plan authored:** 2026-05-13 (evening, after Day-18 closure)
- **Planned execution:** 2026-05-14
- **Actual execution:** 2026-05-13 (continued straight after Day-18)
- **Status:** EXECUTED. Pivoted: instead of measuring mc-f7u8fz, discovered a NEW regression (bd 1.0.4 + gc HEAD = broken bd writes), found root cause in `cmd/bd/auto_import_upgrade.go`, applied workaround (symlink to bd 1.0.3), filed `mc-mxl4vc`. mc-f7u8fz measurement deferred to a future day (post-upstream-fix).

The §22 retrospective called out mc-f7u8fz as "biggest remaining technical finding on the board." Day-6 diagnosed it (reconciler cycle p50 = 27s for a no-op tick); Day-9 saw it worsen under load (65-230s per cycle). It's been open 12 days. Day-18 upgraded gc binary by 238 commits — **the first question for Day-19 is whether mc-f7u8fz still reproduces.**

This is a §22 Step-1.5b day: falsify the bead's premise against the new binary *before* writing a single line of fix code. If the bug is gone, the day pivots to "document the lesson." If it persists, the day shifts to PR-shape investigation via the §24 playbook.

---

## 1. Pre-flight: what mc-f7u8fz was

**Original observation (Day-6, 2026-05-12):**
- `slow_storage_degraded` warnings in supervisor stderr → traced to `session_reconciler_trace_collector.go:976` (25ms fsync threshold; misnamed, not a storage diagnosis).
- Real finding: cycle latency itself. `cycle_result` records in `.gc/runtime/session-reconciler-trace/segments/` showed **p50 = 27 seconds** for ticks where nothing was happening (no agent state changes, no work to schedule).
- Diagnosed entirely from offline trace data (~2900 historical records). Did NOT require the city to be running.

**Day-9 follow-on (validation run):**
- Under fresh `gc start` load, cycle duration measured 65-230s per cycle — much worse than baseline.
- Same root cause as the state-file durability problems (per v2 manual §22): `publishManagedDoltRuntimeState` never completed in a 30-min run.

**The four candidate fix directions from Day-6 (per retrospective):**
- Not enumerated in the polished notes — they live in the chat logs. For Day-19 we don't need them; we need to (a) confirm reproducibility under HEAD-caa44a4, then (b) read the current code and decide independently.

**Why Day-19 is the right time:**
- The retrospective explicitly listed Day-19+ for this. PR #2037's playbook (§24) is muscle memory now.
- Day-18 upgraded gc to HEAD-caa44a4 = +238 commits past v1.1.0. The reconciler code probably moved in those commits. The bug may already be fixed.
- If the bug is fixed, Day-19 closes a 12-day-old bead with a clean falsification result — itself worth the §22 promotion exercise.

---

## 2. What "done" looks like

**The decision tree:**

```
Step 1: measure no-op tick latency on HEAD-caa44a4
  │
  ├── p50 < 5s  → mc-f7u8fz FIXED. Document the lesson, close bead. ~30 min total.
  │
  ├── p50 in [5s, 27s]  → improvement but not resolved. Investigate the partial
  │                       improvement; possibly file a follow-on bead with narrower
  │                       scope. ~90 min total.
  │
  └── p50 ≥ 27s  → bug persists. Move to Step 2 (code reading + PR shape).
                   ~3 hours including PR ship.
```

**Success criteria by branch:**

| Branch | Done state |
|---|---|
| **A (Fixed)** | mc-f7u8fz closed. §22 gets a short "Day-19 closure: upgrade-as-fix" footnote. The retrospective's predicted Day-19 PR doesn't ship — that's a *good* outcome. |
| **B (Improved)** | mc-f7u8fz updated with new measurements; possibly closed and a new narrower bead filed. §22 gets a "partial fix from upgrade" note. |
| **C (Persists)** | Read reconciler code, identify root cause hypothesis, decide PR vs further investigation, possibly ship PR #2 via §24 playbook. |

**Housekeeping (any branch):**
- `bd close mc-2ntb2p` (Day-18's deferred close) — supervisor reconciler should be quieter at the start of the day, dolt responsive.
- Verify the city is in expected state (HEAD-caa44a4 binary, formula_v2 = true, etc.) before measurement.

---

## 3. Execution plan — falsification-first

Total budget: ~30 min if Branch A; ~3 hours if Branch C.

### Step 1: Verify city state + close mc-2ntb2p (~10 min)

```bash
gc version                  # should report HEAD-caa44a4
ps -p $(pgrep -f "gc supervisor") -o pid,stat,etime,command  # supervisor alive
gc status 2>&1 | head -20  # may hang per Day-18 pattern; fallback to pgrep + tmux + events.jsonl tail

# Deferred close from Day-18
bd close mc-2ntb2p --reason "gc binary upgraded HEAD-caa44a4; SCRUB_FILTER bug resolved; §27 validated"
bd show mc-2ntb2p          # verify CLOSED
```

If `bd close` hangs (Day-18 pattern), wait 60s and retry — supervisor reconciler thrash should have settled overnight. If it still hangs, fold it into Step 5's documentation.

### Step 2: Re-measure cycle latency under HEAD-caa44a4 (~10 min)

Day-6's mining approach worked offline. Use the same approach:

```bash
TRACE_DIR=.gc/runtime/session-reconciler-trace/segments
ls "$TRACE_DIR" | head -5
# Look for fresh segments from after the Day-18 gc start (10:02 PT)

# Mine cycle_result records since the upgrade:
find "$TRACE_DIR" -name "*.jsonl" -newer city.toml -exec cat {} \; \
  | jq -c 'select(.kind == "cycle_result")' \
  | head -50

# Compute p50/p95/max of duration_ms for no-op ticks
# (no-op = empty agent_actions or specific outcome code)
find "$TRACE_DIR" -name "*.jsonl" -newer city.toml -exec cat {} \; \
  | jq -c 'select(.kind == "cycle_result")' \
  | jq -s 'sort_by(.duration_ms) | {n: length, p50: .[length/2 | floor].duration_ms, p95: .[length*95/100 | floor].duration_ms, max: .[length-1].duration_ms}'
```

Also check supervisor logs for `slow_storage_degraded` rate:

```bash
gc supervisor logs 2>&1 | grep -c slow_storage_degraded
# Compare to Day-6 baseline rate (heavy)
```

**Branch decision:** read p50 value.

### Step 3: If Branch C (persists) — code reading (~45 min)

Read the current reconciler hot path with the new binary's source (submodule was advanced to caa44a4 on Day-17):

```bash
cd study/gascity-src
# Day-6's diagnostic pointed to these:
ls cmd/gc/session_reconciler_trace_*.go
ls cmd/gc/session_reconciler*.go

# Look for the cycle entry point + what runs per tick:
grep -n 'func.*Cycle\|func.*Tick\|func.*reconcileOnce' cmd/gc/session_reconciler*.go | head -10
```

What we want to find:
- The top of the per-tick loop.
- What runs on a no-op tick (no agent state changes).
- Where the time is spent: likely some serial fan-out, some I/O, some lock contention.
- Whether any recent commit (post-v1.1.0) addressed cycle duration.

Then look at recent reconciler-related commits:

```bash
git log --oneline v1.1.0..HEAD -- cmd/gc/session_reconciler*.go internal/session/ 2>&1 | head -30
```

If a recent commit closed mc-f7u8fz-shaped concerns without us noticing → Branch A retroactively.

### Step 4: If a code change is the fix — open PR #2 (~60 min)

Standard §24 playbook:

```bash
git checkout -b rjgeng/perf/reconciler-noop-tick
# Apply the fix
make check                    # quality gate
gh repo fork gastownhall/gascity --clone=false  # if not already done
git push -u fork rjgeng/perf/reconciler-noop-tick
gh pr create --repo gastownhall/gascity --base main \
  --title "perf(reconciler): <one-line summary>" \
  --body-file /tmp/pr-body.md
```

PR body must include:
- Symptom: cycle duration p50 = 27s for no-op ticks (with measurement).
- Discovery context: Day-6 offline trace mining, Day-9 live observation, Day-19 re-measurement under HEAD-caa44a4.
- Root cause: <whatever Step 3 surfaces>.
- Fix: minimal change.
- Testing: `make check` + before/after p50 numbers from the trace mining.
- Discovery context honest: this was found via the user's own diagnostic, not a stack-trace.

### Step 5: Document + commit + push (~15 min)

For all branches:
- Fill the §9 execution log with what was measured + the decision.
- v2 manual update:
  - Branch A → §22 footnote ("Day-19: mc-f7u8fz closed via Day-18 upgrade. Upgrade-as-fix is its own pattern.")
  - Branch B → §22 update ("partial fix observed; new narrower bead").
  - Branch C → §24 second worked example (the PR), §22 update ("PR landed via the same playbook").

For PR (Branch C):
- Reference the PR URL in the commit message.
- Note: this is the second contribution from this city — first one was PR #2037 (Day-7 fix to dolt-state.json filename fallback).

---

## 4. Hypotheses (G1-G6)

**G1: mc-f7u8fz is still reproducible under HEAD-caa44a4.** Reasoning: nothing in the v1.1.0 → caa44a4 commit log specifically suggests a reconciler-cycle-duration fix landed, and the issue Day-6 diagnosed is structural (serial fan-out, not a one-line bug). Predicted outcome: Step 2's p50 measurement is in [20s, 35s] range — similar to Day-6 baseline.

**G2: If G1 holds, the root cause is the *same* code path Day-6 identified.** That is, the reconciler still does serial fan-out over agents on each tick, and most of the 27s is in I/O-bound subroutines (bd queries, dolt commits, fsync waits). Predicted outcome: Step 3 reading shows the per-agent loop is still the hottest section.

**G3: There IS a commit in v1.1.0..HEAD addressing reconciler perf** — but maybe targeting a different angle (concurrency, caching, batching) that hasn't measurably moved p50. Worth grepping for explicitly. Predicted outcome: 0-2 commits matching `reconciler\|tick.duration\|fan.out` in the new commits range, none specifically labeled as fixing the bug.

**G4: If the fix is one-line-ish (Branch C, small fix), the PR ships within Day-19.** Same shape as PR #2037: small surgical fix + honest body + `make check` clean + sjarmak (or another maintainer) reviews quickly. Predicted outcome: PR opens by end of day; merge may take 1-3 days based on PR #2037 cadence.

**G5: If the fix is structural (Branch C, big change), Day-19 surfaces the PR shape but doesn't ship.** Reconciler concurrency rewrites are reviewer-heavy. Predicted outcome: PR is a draft or RFC issue; multiple review iterations expected; not a same-day land.

**G6: Branch A occurs.** The upgrade *did* fix it (perhaps via a commit that wasn't obviously labeled). Day-19 closes mc-f7u8fz, writes the lesson, and the planned PR doesn't ship. This is the cleanest outcome — closes a 12-day bead with zero contribution effort.

If G6 plays out, the §22 sub-pattern "upgrade-as-fix" gets a worked example: sometimes the answer to a long-standing bug is just to run `brew install --HEAD <thing>`.

---

## 5. Risk / blast radius

**Step 1 (verify + close bead):** zero risk. Read-only state checks; closing a bead is reversible (`bd update mc-2ntb2p --status open`).

**Step 2 (measure):** zero risk. Read-only mining of trace files.

**Step 3 (code reading):** zero risk. Submodule reads only; no edits to submodule.

**Step 4 (PR):** medium risk. Same profile as PR #2037 — small surgical contribution, public-facing. Mitigation: §24's honesty pattern; don't claim fixes that aren't verified.

**Step 5 (commit + push):** zero risk standard.

**Special consideration for reconciler PR:** unlike PR #2037's shell-script change, a reconciler fix is Go code in a hot path. `make check` is necessary but not sufficient — the change should also be validated by re-mining the trace data after applying. The PR body should include before/after p50 measurements. This is more rigor than PR #2037 needed.

**Rollback path:** if a PR introduces a regression, the maintainer rolls it back; the user's city is unaffected (city is at caa44a4, not at the PR's branch). Local-city impact is zero for any of this work.

---

## 6. Connection to prior days

- **Day-6 (S4 diagnosis):** the bug's origin. Day-19 is the action-half delayed 13 days.
- **Day-9 (validation run):** observed worse cycle duration under load. Day-19's measurements should distinguish: did the upgrade help the no-op case AND the load case, or just one?
- **Day-7 / 11 / 13 (PR #2037):** the playbook in §24. Day-19 either ships PR #2 using it, or doesn't.
- **§22 (debugging pack scripts):** Day-19's Step 1.5b ("re-validate against the current binary before fixing") extends the §22 falsification ritual. Worth a permanent §22 sub-bullet if Branch A or B plays out.
- **§27 (embed-vs-fs reconciliation):** Day-19 implicitly validates §27 again — the binary upgrade is the upgrade pathway, and we'll observe whether it carried in reconciler fixes too.
- **Day-14 retrospective:** Day-19 was explicitly on the predicted ladder. The retrospective will be re-evaluated next time after Day-19's outcome to see whether the prediction held.

---

## 7. Adjacent work

Lightweight:
- **Daily check on PR #2037** (merged) and **comment on #1487** (open): both resolved/no-op. Skip.
- **mc-uhvbb9** (refinery patrol hang): still awaiting reaction on #1487. No action.
- **Stash entries in `~/co_auth/.git`** (Day-4 leftover, retrospective noted): 30-second cleanup. Could fold in if time allows.

Soon (Day-20+):
- **Convoys tour** (5+ deferrals, retrospective's most-overdue item): natural Day-20 candidate after Day-19's contribution day.
- **events.jsonl silent-failure sweep** (deferred from Day-19's alternate path): could pair with the convoys tour for a longer Day-20.

---

## 8. Optional: mayor handoff

Skip. Same reasoning as Days 14/15/17/18 — this is a focused diagnostic + possible PR. Mayor orchestration would add overhead. The §22 falsification + §24 playbook are user-owned muscle now; mayor delegation isn't load-bearing.

If Day-19 turns into Branch C with a structural fix that requires architectural decisions, *then* mayor handoff might add value (architectural conversations benefit from explicit decomposition). But not for a measure-then-fix-or-close flow.

---

## 9. Execution log

(filled in as work happens)

### Pre-flight + housekeeping (Step 1)

- **`gc version`:** HEAD-caa44a4 ✓
- **Supervisor uptime:** PID 13654, 42:44 elapsed at start of Day-19
- **mc-2ntb2p close outcome:** Failed initially — bd close hung indefinitely. Closed AFTER discovering the bd 1.0.4 regression and switching the symlink to bd 1.0.3.

### Measurements (Step 2) — pre-upgrade segment only

- **Trace segments since upgrade:** 0 (the new supervisor isn't writing trace data).
- **cycle_result records mined (from pre-upgrade segment 2026/05/13/segment-000001.jsonl):** 47 records.
- **p50 / p95 / max duration_ms (pre-upgrade, gc 1.1.0, segment from supervisor 30730):**
  - p50 = 129,129 ms (~129s)
  - p95 = 237,387 ms (~237s)
  - max = 442,001 ms (~442s)
  - min = 61,247 ms (~61s)
  - **5× worse than Day-6's 27s baseline.** The bug compounded between Day-6 and Day-15.
- **Post-upgrade measurement:** UNAVAILABLE. HEAD-caa44a4's supervisor isn't writing trace data even after explicit `gc trace start --template gastown.deacon --for 5m` arming. head.json frozen at 16:54:50Z (supervisor 30730's death time). This is itself a Day-19 finding — the trace observability changed in HEAD.
- **slow_storage_degraded rate:** still firing in dolt log (Day-6's misnamed 25ms fsync warning).
- **mc-f7u8fz reproducibility status:** UNKNOWN. Cannot measure under HEAD-caa44a4 due to two blockers — trace subsystem change + bd-write regression.

### Branch decision — REVISED

- **Original branches (A/B/C) all required measurement** which wasn't possible.
- **Actual outcome:** Day-19 discovered a SEPARATE NEW regression (bd 1.0.4 + gc HEAD-caa44a4 = broken bd writes) that's bigger than mc-f7u8fz in immediate impact. Pivoted to investigating the new regression.
- **mc-f7u8fz status:** deferred to a future day when measurement is possible again (after upstream fix lands or after a different observability path is found).

### The pivot: bd 1.0.4 regression

**Symptom discovered in supervisor.log:** every periodic order dispatch (12 different orders in 45 min) times out with:

```
bd create: timed out after 2m0s: auto-importing 4619172 bytes from
/Users/rfvitis/my-city/.beads/issues.jsonl into empty database...
```

**Empirical regression confirmed:**

```bash
# bd 1.0.4 hangs:
bd create "test" -t task --silent    # >2min timeout

# bd 1.0.3 works:
/usr/local/Cellar/beads/1.0.3/bin/bd create "test" -t task --silent    # <20s success
```

Both binaries point at the same gc-managed dolt server (port 58545) and same data dir. Only difference is bd version.

**Root cause:** `cmd/bd/auto_import_upgrade.go` in bd 1.0.4. The function `maybeAutoImportJSONL` fires on every bd write — checks if database is "empty" and if `issues.jsonl` exists, then tries to migrate. Intended as a one-time upgrade helper for users coming from pre-0.56 (`.beads/dolt/`) to 1.0+ (`.beads/embeddeddolt/`). Misfires for this city because the data lives in `.beads/dolt/` (the pre-0.56 path) and bd 1.0.4's default `.beads/embeddeddolt/` is empty — so it thinks migration is needed every time, takes >2 min, never succeeds.

**The exact error string is on line 79 of the file:**
```go
fmt.Fprintf(os.Stderr, "auto-importing %d bytes from %s into empty database...\n", info.Size(), jsonlPath)
```

### Workaround applied

```bash
ln -sf /usr/local/Cellar/beads/1.0.3/bin/bd /usr/local/bin/bd
```

The city's supervisor invokes bd via this symlink. After switching, two deferred Day-18 closes succeeded: `mc-2ntb2p` (Day-17 pack-staleness bead) and `mc-l6sq0p` (Day-19 test bead). City's bd-write path restored.

### Bead filed

- **mc-mxl4vc** ("bd 1.0.4 regression: bd create hangs for 2+ min trying to auto-import empty database (works in 1.0.3)")
- **Priority:** P2
- **Labels:** bd-regression, upstream-pr-candidate
- **Status:** OPEN
- **Next step:** open upstream issue at `gastownhall/beads` first (confirm intent), then PR. Probably Day-20 work.

### G1-G6 verdicts (reframed)

- **G1 (mc-f7u8fz still reproducible):** UNMEASURABLE. Trace subsystem changed; bd writes broken.
- **G2 (same root cause as Day-6):** N/A — couldn't measure.
- **G3 (recent commits don't fix it):** N/A — couldn't validate.
- **G4 (Branch C ships same-day):** N/A — different regression discovered.
- **G5 (Branch C draft-only):** N/A.
- **G6 (Branch A: upgrade-as-fix):** STATUS UNKNOWN. The Day-15 pre-upgrade p50 of 129s suggests the bug was real and compounding. Whether HEAD-caa44a4 fixed it is now an open question.

### v2 manual update

- [x] §22 footnote candidate identified: bd version compatibility with gc HEAD; embed-vs-fs reconciliation pattern extended to bd-as-binary too. Deferring write to Day-20+ to bundle with the upstream PR work.
- [ ] §24 second worked example: TBD pending upstream PR shape.

### Surprises

- **The biggest surprise of Day-19 wasn't mc-f7u8fz.** Day-18's brew upgrade silently bumped bd (a transitive dependency) and bd 1.0.4 introduced a regression that broke every periodic order. The Day-18 victory ("§27 validated, SCRUB_FILTER fixed") was real but partial; the city was actually broken at a different layer.
- **The pre-upgrade Day-6 baseline (27s) was 5× too optimistic.** By Day-15 the cycle p50 had drifted to 129s. Whatever was driving the slowdown compounded over the 9-day window.
- **`gc trace status` lies about arms.** It reports `arms: null` while `arms.json` clearly has armed entries (including ones I just registered). Either the CLI doesn't read the file, or the supervisor reports its own in-memory state which differs from disk.
- **HEAD-caa44a4 doesn't auto-baseline trace.** v1.1.0 had `trace_source: always_on` mode that wrote cycle_result records for every cycle. HEAD requires explicit arming. Even after arming, no new data was written in the 5-min window — suggests deeper change to the trace pipeline.
- **The "third upstream bug pattern" framing.** PR #2037, PR #1848, and now mc-mxl4vc are all version-migration-related: things that worked before, broke during an upgrade, surfaced under operational stress. Worth a meta-note in §22 about migration as a recurring bug surface.

### Anything to promote

- **bd-version-compatibility-with-gc-HEAD** is a v2 manual §22 footnote candidate. Specifically: bd 1.0.4 has an auto-import bug that breaks writes; pin bd to 1.0.3 until upstream fix lands.
- **Trace subsystem change in HEAD** deserves a separate note — operators relying on `always_on` trace data will lose observability when upgrading to HEAD. Worth filing as an upstream issue separately from the bd regression.
- **The "third bug pattern" framing** (migration as a recurring source of upgrade-time breakage): worth a §22 footnote noting that 3 of 3 city-discovered bugs were migration-shaped.
- **The trace `arms: null` inconsistency**: probably a separate small bug in `gc trace status`. Could be a quick PR if the fix is one-line.
- **Decoupling: the city's resilience strategy** — the workaround (symlink to bd 1.0.3) showed how a 2-line operator fix restored the city after an upgrade-introduced regression. Worth a §22 pattern note: when an upgrade breaks something, the "downgrade ONE component, keep the rest" pattern is often available and effective.
