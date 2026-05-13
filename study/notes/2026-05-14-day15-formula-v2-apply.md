# Day 15 — apply Premise A: enable [daemon] formula_v2 and verify digest-generate

- **Plan authored:** 2026-05-13 (Day-14 PM, after investigation closure)
- **Planned execution:** 2026-05-14 (executed early — 2026-05-13 evening, after the Day-14 retrospective)
- **Bead:** mc-kh9qdv (created Day-14, closed Day-15)
- **Status:** EXECUTED 2026-05-13. 5/5 digest-generate success, zero failures, bead closed, §25 resolution sub-block added.

Day-14 stopped at Premise C (file bead, document only) after Step 3 surfaced two non-obvious side effects of enabling `formula_v2`. The Day-14 PM investigation closure read both worker prompts in full and audited the dispatcher injection concretely. Both consequences are now understood, the city is stopped (safe state for the flip), and Premise A is ready to apply.

This plan is the focused execution: edit one TOML line, start the city, verify digest-generate succeeds, document the resolution.

---

## 1. Pre-flight: where we left off

**City state (as of 2026-05-13 evening):**
- Controller: stopped
- All agents: stopped
- Dolt server: bd-managed dolt running on port 51344 (PID was 57722 at end of Day-14; may have been recycled overnight)
- 5 commits ahead of origin/main (Day-14 plan + PR #2037 merge note + Day-14 execution)
- Bead mc-kh9qdv: open, P2, decision-deferred, full investigation notes attached

**Known facts going into Day-15:**
- The flag lives in `city.toml` lines 35-39 (NOT `.gc/site.toml`, which is the rig-listing file)
- 7 formulas across 4 packs declare `graph.v2`; mol-digest-generate is the only one wired as a periodic order (visible failure surface)
- Enabling the flag has two coupled effects: (a) default-template agents switch from `pool-worker.md` to `graph-worker.md`; (b) 5 always-on `control-dispatcher` agents + named sessions get auto-injected (1 city + 1 per rig × 4 rigs)
- Flipping the flag while the city is stopped is safe from both angles — no in-progress agents to experience prompt-model change, and the dispatcher sessions show up cleanly at next `gc start`

---

## 2. What "done" looks like

**Phase A (apply + immediate verify), ~30 min:**
- `city.toml` has `formula_v2 = true` under `[daemon]`.
- `gc start` succeeds; `gc status` shows the 5 new control-dispatcher sessions.
- `gc order run digest-generate` (or wait for first cooldown fire) produces an `order.completed` event in events.jsonl with NO `order.failed` event between fire and completion.
- bead mc-kh9qdv updated with the resolution and closed.

**Phase B (cleanup + manual update), ~15 min:**
- v2 manual §25 appendix gets a short "Resolution" sub-block after the Day-14 worked example, noting the fix applied and the verification outcome.
- Commit covering: city.toml change, §25 update, bead closure note.
- 5 commits + this one pushed to origin/main.

**Stretch outcomes (optional, only if Phase A is clean):**
- Audit the other 6 newly-unblocked formulas to confirm none are wired as orders. (If any are, observe their first fires for any non-flag failure modes.)
- Convoys tour (the long-deferred §8 candidate from Day-14).

---

## 3. Execution plan — step-by-step

### Step 1: Verify city/dolt state before any change (~3 min)

```bash
cd /Users/rfvitis/my-city
gc status            # expect: Controller stopped, all agents stopped
bd dolt status       # expect: running on some port; if not, bd dolt start
git status           # expect: clean, 5 ahead of origin/main
```

If anything looks unexpected (a stray running agent, a dirty tree, an orphan dolt), pause and investigate. The day-14 wrap-up notes the orphan-dolt-from-shell-crash pattern — same diagnosis: `pgrep -lf 'dolt sql-server'`, graceful SIGTERM, re-`bd dolt start`.

### Step 2: Edit city.toml (~2 min)

Add `formula_v2 = true` to the `[daemon]` block.

Current state (lines 35-39):

```toml
[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
```

Desired state:

```toml
[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
formula_v2 = true
```

One line added at the end of the block. Atomic edit; no other changes to city.toml.

### Step 3: Verify config parses cleanly (~3 min)

```bash
gc doctor 2>&1 | head -40
```

`gc doctor` runs all config-resolution and semantic checks. Expected: clean output OR new warnings related to the dispatcher injection (5 new agents that don't have provider overrides — should default cleanly to workspace.provider = "claude", but confirm in output).

If `gc doctor` complains about anything other than the dispatcher agents, STOP and diagnose before starting the city.

### Step 4: Start the city (~5 min including settle)

```bash
gc start
sleep 10   # let the reconciler do its first cycle
gc status
```

Expected `gc status` output: the previous agent list (gastown.{dog,boot,deacon,mayor}, polecat/refinery/witness/etc per rig) PLUS 5 new `control-dispatcher` entries (1 city-scoped, 4 rig-scoped). The dispatcher sessions should be in `running` state because their `Mode = "always"`.

If start fails or any dispatcher session crashes immediately, capture logs:

```bash
gc logs --since=5m
tail -50 .gc/runtime/control-dispatcher-trace.log
```

### Step 5: Fire digest-generate manually (~2 min) + verify (~3 min)

Bypass the 24h cooldown to trigger an immediate fire:

```bash
gc order run digest-generate
sleep 30   # give the formula time to compile, dispatch, and run through its steps
F=/Users/rfvitis/my-city/.gc/events.jsonl
tail -30 "$F" | grep digest-generate
```

**Success signal:** an `order.completed` event for digest-generate with NO `order.failed` event between fire and completion. The deacon will also create a `type:order-run` bead and a `type:digest` bead.

**Possible failures:**
- *Same error message* ("contract graph.v2 but formula_v2 is disabled"): the edit didn't take effect. Did `gc start` actually pick up the new config? `gc reload` and retry.
- *Different formula-load error*: a downstream issue in mol-digest-generate's step definitions. Diagnose in a follow-up bead; don't roll back the flag.
- *Formula loads but step execution fails*: the formula's actual work (collecting rig data, mailing mayor) hit a runtime issue. Diagnose separately; the contract fix is still good.

### Step 6: Update bead and close (~5 min)

```bash
bd update mc-kh9qdv --append-notes "Resolved Day-15. Premise A applied: formula_v2 = true added to city.toml [daemon] block. gc start succeeded with 5 new control-dispatcher sessions. digest-generate verification fire at <timestamp> produced order.completed. Closing."
bd close mc-kh9qdv --reason "Premise A applied and verified; digest-generate now completes successfully"
```

### Step 7: Update v2 manual §25 appendix (~10 min)

Append a short "Resolution" sub-block to the existing Day-14 worked example in §25 (the `### Worked example: digest-generate and the formula_v2 kill switch` subsection added Day-14). Cover:

- The fix applied (one line in `[daemon]`).
- The two side effects in retrospect: 5 control-dispatcher sessions visible in `gc status`, default-template agents now using `graph-worker.md`.
- The verification outcome (`order.completed` for digest-generate, no rollback needed).
- One sentence on the lesson: the §22 "verify premises before fixing" pattern extends to verifying the *fix's* blast radius, not just the bug's root cause. Day-14 stopped at that verification; Day-15 acted on it.

Target: ~15-20 added lines. NOT a new section.

### Step 8: Commit + push (~5 min)

```bash
git add city.toml study/notes/gas_city_build_manual_practical_guide_v2.md
git commit -m "config: enable [daemon] formula_v2 + Day-15 resolution (closes mc-kh9qdv)"
git pull --rebase
git push
git status   # expect: up to date with origin
```

Six commits land on origin (the five from Day-14 plus the Day-15 resolution).

---

## 4. Risk / blast radius / rollback

**Phase A risks:**
- `gc start` could fail to start one of the control-dispatcher sessions (rig-scoped sessions need rig dirs to exist; they do, per §15 of the manual). Risk: low.
- The dispatcher's trace log could trip the fsnotify watcher (unlikely — comment on `ControlDispatcherStartCommand` says it's specifically placed under `.gc/runtime/` to avoid this).
- A latent bug in graph-worker.md or the dispatcher could surface only when v2 formulas actually run. We won't know until Step 5 fires digest-generate.

**Rollback path (if Phase A goes badly):**

```bash
# 1. Stop the city
gc stop

# 2. Revert city.toml
git checkout -- city.toml   # OR manually remove the formula_v2 = true line

# 3. Restart
gc start
```

The flag is config-level reversible (`injectControlDispatcherAgents` early-returns on `!FormulaV2`). After rollback, dispatcher agents disappear from resolved config; named-session beads may persist in the DB but are harmless. digest-generate goes back to its 17/17 failure mode.

**What rollback does NOT undo:**
- Any new `type:digest` bead created by a successful run.
- Any beads created by the other 6 newly-unblocked v2 formulas if they happened to fire.
- Mayor's inbox state if digest-generate succeeded and mailed the digest.

If the Phase A failure is a hard error (city won't start at all), the rollback is fast. If it's a soft regression (city runs but some agent misbehaves under the new prompt), the rollback decision is harder — could be a graph-worker prompt issue, not a flag-flip issue per se. In that case, document the failure mode in mc-kh9qdv and decide whether to roll back or fix forward.

---

## 5. Hypotheses (pre-thought, to validate or falsify)

**G1: `gc start` brings up all 5 dispatcher sessions cleanly.** Reasoning: the agents are auto-injected by config resolution (not user-defined), the start command is deterministic SDK code, `MaxActiveSessions=1` is bounded, and the trace log path is explicitly fsnotify-safe. If G1 falsifies, the failure mode informs §25 appendix more than G1 succeeding.

**G2: digest-generate's first fire after the flip succeeds end-to-end.** This requires the formula to load AND its steps to actually execute (rig listing, bd queries, git log calls, mayor mail send). If only the load succeeds and step execution fails for an unrelated reason, that's a separate bug — not a Day-15 failure. The contract fix is still successful.

**G3: The other 6 v2-declaring formulas don't fire spontaneously.** Reasoning: they're not configured as periodic orders in `city.toml` (only digest-generate is in the orders list per Day-13). Verify by checking `.gc/system/packs/*/orders/` — only digest-generate.toml should reference any of the 7. If G3 falsifies, observe the other fires as bonus signal (one of them might surface its own non-contract issue).

**G4: Pool agents that don't have explicit prompt_templates DO swap to graph-worker.md.** Risk: maybe most production agents in this city DO have explicit prompts (look in pack TOMLs), in which case the prompt-swap concern was overblown. Quick post-flip check: `grep -r prompt_template .gc/system/packs/ | wc -l` vs total agent count. If most agents have explicit prompts, the prompt-swap side effect is essentially irrelevant for this city.

**G5: The five dispatcher agents show up in `gc status` with `running` state within 30 seconds of `gc start`.** Reasoning: `Mode = "always"` named sessions are reconciler-driven; the reconciler's first patrol cycle is 30s by default (per the `patrol_interval = "30s"` in the current `[daemon]` block).

---

## 6. Connection to prior days

- **Day-13 (orders tour):** Day-15 closes the finding Day-13 surfaced incidentally (the 17/17 digest-generate failures).
- **Day-14 (investigation + STOP):** Day-15 is the action-half. Day-14's "verify the fix's blast radius before applying" pattern paid off — the prompt swap and dispatcher injection would have been surprises mid-flip if we'd just YOLO'd Premise A on Day-14.
- **§22 (debugging pack scripts):** Day-15 demonstrates the §22 pattern at a different layer (config flag rather than script behavior). The "verify premises" rule extends symmetrically: verify the *bug's* premises AND the *fix's* premises.
- **mc-vj3hjk (exec-flavored worked example):** §25's existing worked example. Day-14 paired it with digest-generate (formula-flavored); Day-15 completes the pair by showing the formula-flavored case to resolution.

---

## 7. Adjacent work

- **PR #2037 follow-through:** none. PR merged Day-13. No further action.
- **mc-uhvbb9 (refinery patrol watch hang):** Day-15 surfaces a potential coincidence — `mol-refinery-patrol` is one of the 7 formulas being unblocked. If the flag flip is clean, observe whether the refinery patrol's behavior changes at all. Probably not (the formula loads under v1 contract today because... wait, does it? It declares graph.v2, so it SHOULD have been failing too. Let me check). Actually — if mol-refinery-patrol is declared as graph.v2 and the flag is off, then refinery patrol has been failing-to-load this whole time, just silently. That would re-frame mc-uhvbb9 substantially. **Worth a quick check in Day-15 Step 1** before deciding the day's scope.
- **Convoys tour:** still deferred. After Day-15, the triad (orders + gates + convoys) is one tour away from complete §25/§26 coverage.

---

## 8. Optional: mayor handoff

Skip. Same reasoning as Day-14: this is a small surgical operation, mayor orchestration adds overhead.

---

## 9. Execution log

(filled in as work happens)

### Pre-flight outcomes (Step 1)

- **City state:** Controller appeared "stopped" but an orphan supervisor (PID 787, `/usr/local/bin/gc supervisor run`) had survived the prior shell crash and was holding port 8372. `gc status` and `gc doctor` both hung against it. Same orphan-from-shell-crash pattern as Day-14's dolt cleanup. Resolved with graceful SIGTERM.
- **Dolt state:** bd-managed dolt running on 51344 (PID 57722). The gc-managed dolt-config.yaml expected port 58545. Stopped bd-dolt first so `gc start` could spin up its own dolt against the same data dir.
- **Git state:** Clean, 0 ahead of origin/main (everything from Days 14/15-plan already pushed). Submodule pointer drift still uncommitted (status quo since Day-7).
- **mc-uhvbb9 cross-check:** mol-refinery-patrol is NOT wired as a periodic order (only digest-generate.toml exists in `gastown/orders/`). The 373 refinery-patrol mentions in events.jsonl turned out to be 211 `bead.updated` + 87 `bead.created` + 75 `bead.closed` — all bead-mentions, **zero `order.failed`**. Refinery-patrol fires through a different dispatch path; flag flip doesn't directly affect it. mc-uhvbb9 framing unchanged.

### Apply (Step 2)

- **city.toml edit applied:** one line added to `[daemon]` block: `formula_v2 = true`.
- **gc doctor output:** N/A — `gc doctor` hung (same root cause as `gc status` hang, see Step 1). Skipped; `gc start` validates config implicitly.

### Start (Step 4)

- **gc start result:** Reported FAILURE ("city did not become ready under supervisor; check 'gc supervisor logs' for details"). This was a **false negative** — see Surprises below. Supervisor PID 30730 and dolt PID 33765 both spawned and were healthy.
- **gc status — 5 new dispatcher sessions visible?** YES. `gc supervisor logs` showed all 5 enqueued in wave 0 (4 with `outcome=deferred_by_wake_budget` initially, then `outcome=start_enqueued` once budget freed): `control-dispatcher`, `co_auth/control-dispatcher`, `co_store/control-dispatcher`, `co_shipping/control-dispatcher`, `hello-world/control-dispatcher`. (`gc status` itself was intermittently hanging on its `/v0/city/.../events/stream` call; supervisor logs were the reliable observation surface.)

### Verify (Step 5)

- **digest-generate fire timestamp:** manual `gc order run digest-generate` was issued at 2026-05-13T15:09:24Z but actually the deacon had already periodic-fired digest-generate 5× within the first ~5 min of city uptime (08:03Z–08:05Z local / 15:03Z–15:05Z UTC).
- **events.jsonl outcome:** 5× `order.completed` (3 rig-scoped: hello-world 08:03:55Z, co_auth 08:04:34Z, co_store 08:05:02Z, plus 2 more), **zero `order.failed`** post-flip. The 17/17 failure pattern is fully broken.
- **Graph-v2 workflow shape observed:** Root bead `cs-tc6zhp` (rig co_store example) created with `gc.kind=workflow` + `gc.formula_contract=graph.v2`. Four step beads (`cs-9tyorz`/determine-period, `cs-s0txu8`/collect-data, `cs-7e7x5r`/generate-and-send, `cs-ejaw2v`/workflow-finalize) with explicit `depends_on` deps wiring them as a DAG. `gastown.dog-2` (now running under `graph-worker.md`) closed `mc-xy0cte` (determine-period) at 08:08:02Z with a substantive `close_reason`: "Determined daily range: SINCE=2026-05-12T00:00:00Z UNTIL=2026-05-13T00:00:00Z. Recorded as comment on root bead mc-1r8kbz for downstream steps." The workflow-finalize bead `cs-ejaw2v` was correctly assigned to `co_store--control-dispatcher` — auto-injection working as designed.
- **type:digest bead created?** Not verified directly (would need to query bd for type=digest beads); will check in a follow-up.
- **mayor inbox received digest?** Not verified directly; mayor was deferred by wake-budget at the time of the first fires.

### G1-G5 verdicts

- **G1 (5 dispatcher sessions start cleanly):** TRUE. Initial wake budget deferred them, but all 5 came up over the next minute. No crash, no error log.
- **G2 (digest-generate succeeds end-to-end first try):** TRUE for first FIRE. The formula loaded, the workflow expanded into the bead graph, the dog claimed and closed the first step with a real close_reason. Whether the *full* end-to-end (mailing mayor + archiving) ran to completion would require checking the workflow-finalize bead's eventual state; the `order.completed` event at 08:05:02Z says the workflow controller considers it complete.
- **G3 (other 6 v2 formulas don't fire spontaneously):** PARTIALLY VALIDATED. Only digest-generate had `order.completed` events — no other v2 formula fired as a periodic order (none of the other 6 are wired as orders in `gastown/orders/`). However, they MAY be invoked by other paths (e.g., refinery-patrol fires via the refinery agent's own logic). Not exhaustively audited.
- **G4 (prompt-swap affects N agents — verify N):** N not directly verified. The dog pool clearly swapped to graph-worker (visible from the close_reason format and the fact that the workflow advanced). A full count would require grepping pack TOMLs for `prompt_template = ...`. Deferred.
- **G5 (dispatcher sessions running within 30s of start):** FALSIFIED — took longer than 30s due to wake-budget queuing. They all came up within ~60s.

### Bead closure

- **mc-kh9qdv closed:** YES at 2026-05-13T~15:14Z with close_reason "Premise A applied (formula_v2 = true); digest-generate 5/5 success post-flip; control-dispatcher injection working as designed". Full investigation notes already appended Day-14.
- **§25 resolution sub-block added:** YES. ~25 lines appended to the existing `### Worked example: digest-generate and the formula_v2 kill switch` subsection. Covers Premise A application, all-5 dispatcher injection visible in supervisor logs, 5/5 success, workflow graph shape observed, dog pool's graph-worker behavior. Also documents the two operational surprises (orphan cleanup + gc start false negative) and proposes a §22 sub-pattern extension.
- **Commit hash:** filled in at commit time
- **Pushed:** filled in at push time

### Surprises

- **Orphan-controller-from-shell-crash is a real pattern.** Day-14 exposed orphan dolt; Day-15 exposed orphan supervisor. Both came from the same shell crash. Together they paint the picture: when the shell dies, **all** long-lived gc-spawned processes (supervisor, dolt, possibly more) survive as orphans. Cleanup needs to be systematic: `pgrep -lf "gc supervisor\|dolt sql-server" | <SIGTERM all>` before any `gc start` after a shell crash. Worth a §22 footnote or a small `gc doctor --fix` extension.
- **`gc start`'s exit status is unreliable** when the wake-budget is small. It reported "did not become ready" but the city WAS coming up — just gradually. The supervisor logs are the source of truth. Phrase for §13: "trust `gc supervisor logs` over `gc start` exit status when initial wake-budget queuing is involved."
- **`gc status` and `gc doctor` hang intermittently** even after the city is up. Possibly related to the `/v0/city/.../events/stream` endpoint, which takes ~5s per call in normal operation. The supervisor logs are again more reliable for observability.
- **The plan's Phase A time estimate (~30 min) was met,** but only because the orphan cleanups happened to be familiar from Day-14. A first-time encounter would have taken much longer. The orphan-controller pattern adds ~15 min that the plan didn't account for.
- **The 5/5 success is also the rate at which periodic dispatch RECOVERS.** The deacon doesn't wait 24h after a successful run; it caught up by firing for every rig within the first 5 minutes of uptime. This is consistent with §25's lifecycle finding (cooldown advances regardless of failure) — once the formula compiles, the backlog drains immediately.

### Anything to promote (beyond §25 resolution)

- **§22 Step 1.5b** ("falsify the FIX's premises, not just the bug's") — Day-14's deferred decision turned out to be exactly the right call; promoting this pattern to a permanent §22 sub-step would short-circuit the next "verify the fix's blast radius" investigation.
- **Orphan-cleanup playbook** — a small subsection in §22 (or §13) covering: `pgrep` the gc-spawned processes, graceful SIGTERM, verify port 8372 free + data-dir locks released, then `gc start`. Reusable for any future shell-crash recovery.
- **The wake-budget false-negative observation** — worth a one-line addition to §13's `gc start` description ("watch supervisor logs; exit status is not reliable when wake-budget is non-trivial").
- **G3 stretch:** audit which of the other 6 v2 formulas actually get invoked at all in this city. If some are dead code (declared but never dispatched), worth noting.
