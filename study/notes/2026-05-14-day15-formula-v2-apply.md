# Day 15 — apply Premise A: enable [daemon] formula_v2 and verify digest-generate

- **Plan authored:** 2026-05-13 (Day-14 PM, after investigation closure)
- **Planned execution:** 2026-05-14
- **Bead:** mc-kh9qdv (created Day-14, full notes appended)
- **Status:** Plan only; flag flip not yet applied

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

- City state:
- Dolt state:
- Git state:
- mc-uhvbb9 cross-check (does mol-refinery-patrol currently fail-to-load too?):

### Apply (Step 2)

- city.toml edit applied:
- gc doctor output:

### Start (Step 4)

- gc start result:
- gc status — 5 new dispatcher sessions visible?

### Verify (Step 5)

- digest-generate fire timestamp:
- events.jsonl outcome (order.completed or another order.failed?):
- type:digest bead created?
- mayor inbox received digest?

### G1-G5 verdicts

- G1 (5 dispatcher sessions start cleanly):
- G2 (digest-generate succeeds end-to-end first try):
- G3 (other 6 v2 formulas don't fire spontaneously):
- G4 (prompt-swap affects N agents — verify N):
- G5 (dispatcher sessions running within 30s of start):

### Bead closure

- mc-kh9qdv closed:
- §25 resolution sub-block added:
- Commit hash:
- Pushed:

### Surprises

(things this plan got wrong, or new things surfaced)
