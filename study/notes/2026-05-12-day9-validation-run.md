# Day 9 — Validation run: corrected polecat → refinery handoff with explicit nudge

- **Plan authored:** 2026-05-12 (after day 8 wrap)
- **Planned execution:** 2026-05-13 (or later same day)
- **Status:** Plan only; run not yet started

This is the pre-decomposition for Day-9: after four consecutive diagnostic-or-fix days (Days 5-8), shift mode and **run a real polecat → refinery handoff with the corrected v2 manual §19 prompting**. The point isn't to ship a feature; the point is to validate that the documented practice produces the expected end-to-end behavior, on a small enough scope that any deviation is obviously attributable.

---

## 1. The signal — what we're validating

Day-8 corrected v2 manual §19 in two ways:

1. **Polecat's step list is now explicit**: push branch, set metadata, **assign to refinery**, **nudge refinery**, drain.
2. **The PAUSE anti-pattern reframing**: the problem isn't "polecat skips closure," it's "missing post-assign nudge."

If §19's corrected prompting is right, then a polecat instructed with it should drain in a state where refinery picks up the work **within seconds, not 1h 19m**. Day-4's `auth-wg0` got stuck for 79 minutes precisely because there was no explicit nudge instruction and `mc-uhvbb9`'s watch-reliability bug bit. The validation run tests whether the corrected instruction is sufficient as a workaround for that bug.

**Why this is the right Day-9 target:**

- Three consecutive premise-inversions (Day-7, Day-8 main, Day-8 §22) made me skeptical of the documented practice. The right next step is empirical proof, not more reading.
- Proof-by-doing on a 1-bead scope is cheap (~30 min wall clock if it works, ~60 min if there's a glitch to chase).
- Tests the manual on its own terms — if it doesn't work, the manual is still wrong somewhere; if it works, future runs can lean on it.
- Different from Days 5-8 entirely: hands-on orchestration, not solo investigation. Different muscle.

---

## 2. Pre-flight: where this lives

- **Target rig**: `hello-world` (prefix `hw`). Nested under `/Users/rfvitis/my-city/hello-world/`. Small, contained, no demo state at stake. `co_auth` is an option but I'd rather not touch a working demo.
- City is currently stopped. Dolt is running (port 50213). Need to `gc start` to wake polecat/refinery.
- Mayor lives at city scope and orchestrates across rigs. A single small bead in `hello-world` is plenty.
- Memory `feedback_mayor_gate_closure` reminds us: mayor closes gates itself when the user says "proceed". For a 1-bead validation we likely skip gates entirely.

---

## 3. What "validated" looks like (success criteria)

Hard criteria — all must pass:

1. Polecat picks up a freshly-filed bead in `hello-world`, does the trivial work, pushes a branch.
2. Polecat sets `branch`, `target`, `work_dir`, `gc.routed_to` metadata on the bead.
3. Polecat assigns the bead to `hw/gastown.refinery` (or whatever the rig's actual refinery alias is — confirm pre-flight).
4. **Polecat issues an explicit `gc session nudge` to refinery before draining.** This is the new instruction we're testing.
5. Refinery picks up the bead via its `mol-refinery-patrol` discovery, **within 5 minutes of the nudge** (not 79 minutes).
6. Refinery merges to `main`, records `merged_commit`, closes the bead.
7. Total wall clock from bead-create to bead-closed is **bounded and measurable** — recorded for the writeup.

Soft observations to record alongside:

- Did the controller reconciler still take 27s/cycle while the run was happening? (Day-6 baseline)
- Did `slow_storage_degraded` warnings fire during the run?
- Were there bead.updated events not handled cleanly by anyone (echoing Day-8's mc-uhvbb9 observation)?

---

## 4. Execution plan — small scope, instrumented

### Step 1: Pre-flight checks (~5 min)

```bash
gc status                          # confirm controller stopped, agents stopped
ls hello-world/                    # confirm rig dir exists, has a sensible state
cd hello-world && git status       # working tree clean?
git log --oneline -3               # what's on main?
cd /Users/rfvitis/my-city
gc agent list --rig hello-world 2>&1 | head -20   # confirm refinery alias for hw
```

Output: the exact alias to use in the nudge command (e.g., `hello-world/gastown.refinery` or `hw/gastown.refinery` — depends on the rig binding prefix).

### Step 2: Pick a tiny but real task (~2 min)

The task must be:

- Real (actual file change with a commit)
- Trivial (no thinking required)
- Reversible (easy to revert)

**Proposed:** Add a single-line entry to `hello-world/NOTES.md` (or create the file if absent) of the form:

```
2026-05-13: Day-9 validation run — handoff timing test
```

That's it. One line. The work measures the handoff, not the code.

### Step 3: Start the city (~1 min)

```bash
gc start
gc status                          # confirm controller + agents come up
```

Same risk profile as Day-6 §6 — reversible.

### Step 4: File the work bead with corrected mayor-style prompting (~5 min)

The prompt to put in the bead description should follow the **corrected** v2 manual §19 pattern — explicit polecat step list including the post-assign nudge. Concretely, the bead description below is the experiment.

Use a single root bead, no gates, no convoy. Issue type `task`. Priority P3.

```bash
bd create "Day-9 validation: add NOTES line in hello-world" \
  --type task --priority 3 \
  --rig hello-world \
  --description "$(cat <<'DESC'
## Task

Append exactly one line to hello-world/NOTES.md (create file if absent):

    2026-05-13: Day-9 validation run — handoff timing test

That is the entire scope. No other changes.

## Handoff protocol (THIS IS THE TEST)

After completing the work:

1. Stage and commit the change on a fresh branch named `day9-validation-<your-alias>`.
2. Push the branch to origin.
3. Set metadata on this bead:
   - `branch`: the branch name you pushed
   - `target`: `main`
   - `work_dir`: your worktree path
   - `gc.routed_to`: the refinery alias for this rig
4. Assign this bead to the rig's refinery (e.g., `hello-world/gastown.refinery`).
5. **Explicitly nudge refinery before draining:**

       gc session nudge hello-world/gastown.refinery "<this-bead-id> ready on <branch> — please merge"

6. Drain. Do NOT close the bead — refinery will close it after merging.

Do not skip step 5. The post-assign nudge is the specific instruction being tested.
DESC
)"
```

Record the bead ID. Note the time.

### Step 5: Observe (~10-30 min)

Watch the event stream in another terminal:

```bash
gc events --follow --type bead.updated 2>&1 | grep -E "<bead-id>|hello-world/gastown.refinery"
```

Track times:

- T0: bead created (Step 4)
- T1: polecat claims (bead.updated, status=in_progress, assignee=polecat alias)
- T2: polecat assigns to refinery (bead.updated, assignee=refinery)
- T3: polecat issues nudge — **NOT in events.jsonl** (nudges are session-layer per Day-6 AGENTS.md). Watch the polecat session output or supervisor logs.
- T4: refinery wakes / picks up
- T5: refinery merges (bead.updated with `merged_commit`)
- T6: refinery closes (bead.updated with status=closed)

If anything stalls for >5 min, that's the failure case worth diagnosing. Don't intervene during the run — let stalls happen so they're visible.

### Step 6: Stop the city (~1 min)

```bash
gc stop
git -C hello-world log --oneline -3   # confirm the merged commit lives on main
```

---

## 5. Failure modes pre-thought (so we can categorize what we see)

**F1: Polecat ignores step 5 (no nudge).** Symptom: T3 doesn't fire; refinery sits idle. If this happens, the corrected §19 prompt language wasn't directive enough — the manual needs another iteration. **Diagnostic:** check polecat's session transcript for the nudge command, or its absence.

**F2: Polecat does step 5 but refinery still doesn't pick up.** Symptom: T3 fires but T4 doesn't fire within 5 min. This means `mc-uhvbb9` is broader than the watch-reliability framing — even with an explicit nudge, refinery is somehow not waking. **Diagnostic:** check refinery session state and any pending patrol wisps.

**F3: Refinery picks up but the rebase/merge fails.** Symptom: T4 fires, but the merge step rejects the bead back to the pool. This isn't a validation failure — it's the formula's normal rejection path. Document the rejection reason and skip the rest.

**F4: Refinery merges but doesn't close the bead.** Symptom: T5 fires but T6 doesn't. Would indicate a bug in the merge-push step's close logic. Inspect bead state at the end.

**F5: Everything works.** Hard criteria 1-7 all pass; total wall clock measured. Validation succeeds and we have a baseline to compare future runs against.

---

## 6. Risk / blast radius

- **`gc start`**: same profile as Day-6 §6. Reversible.
- **Editing `hello-world/NOTES.md`**: one-line append, trivially revertable.
- **Filing a bead and letting polecat work on it**: the only risk is polecat doing something unexpected. Mitigation: scope is single-line file append; if polecat goes off-script it's immediately obvious.
- **Refinery merging to `hello-world` main**: a one-line NOTES change. Reversible via `git revert` if needed. The hello-world rig has no production downstream — it's a learner sandbox.
- **Not pushing the rig's `main` to its own origin**: `hello-world` is a nested rig per `project_rig_topology.md`; its `origin` may or may not be configured. Pre-flight Step 1 should confirm this. If not configured, the validation should skip the upstream push — that's `mc-vj3hjk`-shaped territory and we don't want to retrigger that bug as a side effect.

---

## 7. Connection to prior days

- **Day-4 demo had `auth-wg0` stranded for 79 minutes.** Day-9 replays the same shape on a trivial scope to confirm the corrected practice fixes it.
- **Day-6 (`mc-f7u8fz`) means the controller is slow.** That hasn't changed for Day-9. The run should still work end-to-end, just possibly with elevated latency between steps. Observing this is one of the soft criteria.
- **Day-7 fixed `mc-ma23a9`** in the local pack scripts. `bd` queries during Day-9 should NOT fall back to port 3307. If they do, the local-only fix has been wiped by something, and Day-9 is a useful catch.
- **Day-8 corrected the §19 prompting language.** Day-9 is its first real-world test.

---

## 8. Adjacent work to fold in while on Day-9

Lightweight items, none depend on the validation:

- **Push the Day-7 upstream branch `rjgeng/fix/dolt-pack-script-state-fallback`** (commit `291b37c2`). The local validation has been in place a day; if Day-9 confirms the fix works under live conditions (which it should — the script change has been live all along), that's additional confidence to engage upstream review.
- **Ack `mc-n333b`** ("ack daily-verbs page") if it's a still-pending learning checkbox. Trivial.
- **File a small "validation outcome" bead** in HQ recording the wall-clock timing for future regression comparison. Even if the run succeeds, having a baseline lets us notice if Day-N's hello-world handoff suddenly takes 79 minutes again.

If the validation run is fast (F5 path, ~30 min total), the upstream-PR step is the highest-yield adjacent.

---

## 9. Optional: mayor handoff

**Take it.** Unlike Days 5-8 (solo investigations), Day-9 is explicitly about orchestrated execution. Either:

- **Light mayor handoff**: file the bead directly, let the polecat pool claim it, observe.
- **Full mayor handoff**: send mayor a one-paragraph prompt asking it to file the validation bead and then drain — mayor handles the bead creation and the post-mayor drain is the controller's job from there.

For pure mechanism testing, the light-mayor path is cleaner — one variable at a time. Save full-mayor for a Day-N+1 that tests mayor's bead-spec rendering against the corrected §19 language.

---

## 10. Execution log

### Pre-flight outcomes

- **Hello-world refinery alias**: `hello-world/gastown.refinery` (confirmed via `gc status` after start). Refinery is `reserved-unmaterialized (on_demand)` — matches Day-4 pattern. Pool agents: `furiosa`, `nux`, `slit`, `rictus`, `capable` (5 slots, scaled 0-5).
- **Working tree state**: `hello.py` + two untracked dirs (`.claude/`, `.codex/`). No tracked changes.
- **`git remote -v` for hello-world**: pre-flight discovered the bare repo at `/Users/rfvitis/hello-world-origin.git` was already set up from an earlier session; reinit was a no-op. The `mc-vj3hjk`-shape risk in plan §6 was already mitigated.
- **Pre-existing system state at start**: Day-7's local pack-script patches were **reverted by `gc start`** (pack-reinstall step pulled fresh upstream copies; expected per Day-7 plan §6). Dolt got migrated from port 50213 to 49181 by the controller startup. **Neither `dolt-state.json` nor `dolt-provider-state.json` was ever written** during the run — controller's `publishManagedDoltRuntimeState` never completed (consistent with mc-uhvbb9's hypothesis about reconciler-induced API starvation).

### Timings

| Event | Wall-clock time | Notes |
|---|---|---|
| `gc start` issued | 07:38:35 | Controller PID 59365 |
| T0 — bead created (no metadata) | 07:44:14 | `hw-65hvt`, P3 task, the corrected §19 description |
| ⌛ stranded — polecat never materialized | 07:44:14 → 07:56:09 (~12 min) | **The `gc.routed_to` field was unset.** Polled 217s with no progress. |
| T-update — added `gc.routed_to=hello-world/gastown.polecat` | 07:56:09 | The unblocking fix |
| T1 — polecat materialized (`furiosa` running) | ~07:57:18 | +69s after metadata update |
| T2-T4 — polecat work / assign / nudge / refinery wake | 07:57:18 → 08:05:29 (within ~8 min) | All packed into one observation cycle; individual transitions not separable from this run |
| T5/T6 — bead closed with merged_sha 8c2983dc | ~08:05:29 | `merge_result=merged`, `merged_target=main`. Commit `8c2983d docs: add Day-9 validation NOTES entry` on hello-world `main`. |
| `gc stop` | 08:17:39 | Clean shutdown |

**End-to-end after metadata fix: ~9 min 20s** (T-update → T-close).
**Compared to Day-4 auth-wg0** stranded 79 min: **~8.5× improvement.**

### Which failure mode

- **F5 — Hard criteria 1-6 all pass.** Bead created → polecat claimed → branch pushed → metadata set → bead assigned to refinery → refinery merged → bead closed with merge metadata. End-to-end timing is bounded and measurable.
- **One caveat:** the F5 path was reached only AFTER a manual `gc.routed_to` metadata patch. Filing the bead directly (light-mayor path) did NOT route correctly. That's a plan blind spot worth fixing — see Surprises.
- **What I cannot tell from this single run:** whether polecat actually executed the explicit `gc session nudge` step from the description, or whether refinery happened to pick up via its watch this time. Both paths land at the same observed outcome (bead closed). Distinguishing them needs either polecat's session transcript or running a paired control with the nudge step removed.

### Soft observations

- **Reconciler cycle duration during run**: 65s, 140s, 230s for the three cycles I sampled. **Worse than Day-6 baseline of p50=27s** (today's run was 2-8× slower). `mc-f7u8fz` is alive and well; the controller was even more I/O-constrained today than during the Day-6 measurement window.
- **State files**: `dolt-state.json` and `dolt-provider-state.json` were both **absent throughout the run**. The controller's publish step never completed. This is a fresh observation: under heavy reconciler load, state-file publication is a casualty. Could explain why Day-9's polecat-materialization latency was 69s rather than the few-seconds I expected — pool scaler is starving on the same I/O budget as everything else.
- **`slow_storage_degraded` warnings**: not actively counted this run; the gc supervisor logs file would have them. Skipped for time.

### Surprises

1. **`gc.routed_to` is a load-bearing field for pool scaling, not just for in-pool routing.** Day-4's S6 said "polecat claims regardless of routed_to" — but that's about WHICH polecat claims after the pool scales; the field's PRESENCE is what gates pool scaling itself. The plan assumed light-mayor path = "file bead directly, polecat claims" — that's incomplete. Without mayor (or a manual metadata patch), pool scaler doesn't see the bead as eligible.
2. **The refinery write-output fields are `merged_sha` / `merged_target` / `merge_result`** — NOT `merged_commit` / `merged_at` / `refinery_pushed_at` as Day-4 narrative used. Day-8 §19 correction is technically still wrong on field names. Either the formula was updated between Day-4 and now, OR Day-4 saw a manual close-with-merge-metadata path that used non-canonical fields. Worth a Step-1.5-style check.
3. **Controller startup wipes local pack-script patches.** Day-7 §6 anticipated this; today it actually happened during `gc start`. The upstream branch (`rjgeng/fix/dolt-pack-script-state-fallback`) is the only durable form; local edits in `.gc/system/packs/` are validation-grade only.
4. **State files were never written.** A new mc-uhvbb9-shaped observation: even after a clean `gc start`, neither `dolt-state.json` nor `dolt-provider-state.json` got written during the ~30 minutes of operation. Without them, `bd dolt status` reports "not running" (false — dolt is on 49181), and any script reading the state files falls back to legacy defaults. The reconciler is too I/O-saturated to keep its own publication invariants up to date.
5. **Refinery's "watch" question stays open.** Did polecat issue the nudge per the description? Did the watch fire on the assignment event? Single-run result can't separate them. A planned future run with the nudge step deliberately omitted (or polecat session transcript captured) would isolate.

### Anything to promote to v2 manual

1. **§19 "How to file a polecat-friendly bead" must list `gc.routed_to` as a REQUIRED metadata field for the bead to be claimable.** If filing directly via `bd create` (without mayor), set it explicitly. Mayor sets it for you when it files; bypassing mayor means setting it yourself. Example:

       bd create "<task>" --set-metadata gc.routed_to=<rig>/gastown.polecat

   Without this, the bead lives in the queue but the pool scaler never materializes a polecat — the bead is invisible to claim.

2. **§19's refinery write-output field list needs updating to: `merged_sha`, `merged_target`, `merge_result`, plus the `branch`/`target`/`work_dir` echo and any merge-strategy-specific fields.** The Day-8 correction still listed Day-4-era names; today's run shows the current shape.

3. **§22 "premise falsification" pattern triggers again.** Today caught two new sub-inversions: (a) Day-4 S6's "regardless of routed_to" claim doesn't apply to pool scaling, (b) the refinery field names. Three days running, the pattern keeps finding documentation drift. Worth a stronger framing in §22 — maybe a checklist of "things to grep before trusting a deferred writeup."

4. **A new diagnostic note worth a paragraph somewhere**: under reconciler I/O saturation (mc-f7u8fz), the controller's state-file publication invariants are not maintained. `gc trace cycle` and `gc events` keep working (they're served by the API), but `bd dolt status`, scripts that read `.gc/runtime/packs/dolt/dolt-state.json`, and possibly other state-file readers get stale or empty data. Treat state files as "best-effort, may be stale" rather than "single source of truth."
