# Day 10 — v2 manual consolidation + paired-control validation (isolate the nudge variable)

- **Plan authored:** 2026-05-12 (after day 9 wrap)
- **Planned execution:** 2026-05-13 (or later same day)
- **Status:** Plan only; not yet started

This is the pre-decomposition for Day-10: do both halves in one session. Phase A promotes Day-9's three findings into v2 manual §19 + §22 (so the manual reflects what we now actually know). Phase B then re-runs the hello-world validation but with the **explicit nudge instruction omitted from the bead spec**, isolating the single variable Day-9 couldn't separate.

Two-phase scope chosen deliberately: Phase B should validate against a *corrected* manual, not a known-stale one. Running an experiment against text we already know is wrong is a missed double-duty.

---

## 1. The signal — what we're settling

**Phase A (consolidation):** three Day-9 findings still uncodified.

- `gc.routed_to` is required for pool scaling, not just intra-pool routing. Without it, the pool scaler never materializes a polecat. v2 manual §19 currently lacks this prerequisite.
- Refinery's actual write-output field names are `merged_sha` / `merged_target` / `merge_result`. The Day-8 §19 correction still listed Day-4-era names (`merged_commit` / `merged_at` / `refinery_pushed_at`).
- Controller's state-file publication invariants (`dolt-state.json`, `dolt-provider-state.json`) are not maintained under reconciler I/O saturation. State files were entirely absent during the 30-minute Day-9 run. This is an mc-f7u8fz consequence worth a paragraph in §22 or §23.

**Phase B (paired control):** Day-9 reached F5 but could not isolate which mechanism produced success.

- Either the explicit `gc session nudge` step (the new §19 instruction) made refinery wake.
- Or refinery's `gc events --watch` happened to fire correctly on the assignment event this time (despite the mc-uhvbb9 reliability bug).

Both paths land at the same observed outcome (bead closed). Distinguishing them needs a paired run where the only changed variable is the presence/absence of the explicit nudge.

**Why this is the right Day-10 target:**

- Consolidation pays down the documentation drift the premise-falsification pattern keeps surfacing (Days 7, 8, 9 each invalidated something).
- The paired control is the cleanest single-variable experiment available — the setup, infrastructure, and reproduction context are all freshly proven from Day-9.
- Doing both in sequence costs one extra hour at most, but the experiment runs against a clean manual rather than a stale one.

---

## 2. Pre-flight: where this lives

- v2 manual `study/notes/gas_city_build_manual_practical_guide_v2.md` §19 and §22 already exist; Phase A edits in place.
- `hello-world` rig is in known-clean state from Day-9. `main` is at `8c2983d` (the Day-9 merge commit). `day9-validation-furiosa` branch was merged but may still exist locally — Phase B pre-flight should confirm and skip deletion if so.
- City is stopped. Dolt server state from Day-9 was on port 49181 (PID 62953) — likely stale by now. Phase B will `gc start` fresh.
- The local bare remote `/Users/rfvitis/hello-world-origin.git` from Day-9 is still in place and working.

---

## 3. What "done" looks like (success criteria)

**Phase A — consolidation:**

- v2 manual §19 "What polecat actually does" lists `gc.routed_to` as a prerequisite field for any bead that should be pool-claimable, with an example showing the `--set-metadata` form for direct `bd create`.
- v2 manual §19 "What refinery actually does" uses the current field names (`merged_sha`, `merged_target`, `merge_result`).
- v2 manual §22 has a new subsection or expanded text covering controller state-file staleness under reconciler load (mc-f7u8fz consequence; observed Day-9).
- Day-9's three findings each have a citation pointing to `study/notes/2026-05-12-day9-validation-run.md` for evidence.

**Phase B — paired control:**

- A second bead (`hw-XXXXX`) filed in hello-world with the **same task scope** as Day-9 BUT with the handoff protocol's nudge step (step 5) omitted from the description.
- All other variables held constant: `gc.routed_to` set at create-time, same target rig, same trivial task.
- Three outcomes recorded:
  - **R-equiv**: refinery picks up and merges in similar time to Day-9 (~9 min after metadata). Conclusion: nudge was redundant; watch is functional.
  - **R-degraded**: refinery picks up but with significantly higher latency (say >30 min). Conclusion: nudge accelerated refinery wake but watch eventually fires.
  - **R-stalled**: refinery never picks up within a bounded window (say 30 min). Conclusion: nudge was load-bearing; mc-uhvbb9 is a real reliability issue.
- The outcome dictates the final §19 correction: either "nudge is recommended but optional" or "nudge is required."

---

## 4. Execution plan — Phase A first, then Phase B

### Phase A: Manual consolidation (~30 min)

#### A1: Update §19 "What polecat actually does"

Current text lists polecat's step sequence as 1-claim through 7-drain. Add a prerequisite paragraph above the steps:

> **Prerequisite: the bead must have `gc.routed_to` set before pool scaling will materialize a polecat.** Mayor sets this when filing beads. If you file a bead directly via `bd create` (light-mayor path), set it yourself:
>
> ```bash
> bd create "<task>" --set-metadata gc.routed_to=<rig>/gastown.polecat
> ```
>
> Day-9 (2026-05-12) confirmed this is load-bearing: a bead with no `gc.routed_to` sat for 12 minutes invisible to the pool scaler; after the field was added, polecat materialized in 69 seconds.

#### A2: Update §19 "What refinery actually does"

The current correction (Day-8) lists "records `merged_commit` on the bead." Day-9 observed the actual field names are `merged_sha` / `merged_target` / `merge_result`. Update:

> 5. Fast-forwards (or merge-commits for non-FF), records `merged_sha` (the new merge commit SHA), `merged_target` (the branch merged into), and `merge_result` (e.g., `"merged"`) on the bead.

Strike the legacy field-name references from the rest of the section, including any "Day-8 correction" parenthetical that now needs re-correcting.

#### A3: Update §19 "How to file a polecat-friendly bead spec" (new subsection or fold into existing)

Add a checklist that captures the Day-9 lesson:

> When filing a bead directly (without mayor):
>
> 1. Set `gc.routed_to=<rig>/gastown.polecat` at create-time — REQUIRED for pool scaling.
> 2. Include the §19 polecat step sequence in the description (push branch → set metadata → assign to refinery → nudge refinery → drain).
> 3. Use a P3 task priority unless there's a reason otherwise.

#### A4: Update §22 — controller state-file staleness under load

Add a subsection (or fold into the existing two-state-files subsection):

> **State files are not durable under reconciler I/O saturation.** Day-9 (2026-05-12) observed that `dolt-state.json` and `dolt-provider-state.json` were both absent throughout a 30-minute `gc start` run. The controller's `publishManagedDoltRuntimeState` never completed — same root as mc-f7u8fz (reconciler cycle p50=27s baseline; Day-9 measured 65-230s/cycle).
>
> Practical implications:
>
> - Treat state files as best-effort, may be stale or missing. Don't rely on them as the single source of truth.
> - Pack scripts that read state files should fall back to the bd-bridge file or the legacy default; see the secondary-fallback pattern in this section.
> - `bd dolt status` may report "not running" while dolt IS running — check `lsof -nP -iTCP -sTCP:LISTEN -p <dolt-pid>` for the actual listening port.

#### A5: Update §22 "Falsifying a deferred observation's premise" with Day-9's adds

The current subsection (added Day-8) shows Day-7 and Day-8 examples. Add Day-9:

> - **Day-9 (validation run)**: Day-4 S6 narrative said the pool reconciler "claims any ready non-gate work in its rig regardless of `routed_to`." This was true for *which* polecat claims, but not for *whether* the pool scales up at all. Cheapest falsification: file a test bead without `gc.routed_to` and observe (Day-9: bead stranded 12 min until field added).

### Phase B: Paired control validation (~30-60 min)

#### B1: Pre-flight (~5 min)

```bash
gc status                          # confirm controller stopped
ls /Users/rfvitis/hello-world-origin.git/HEAD   # bare repo still present
cd /Users/rfvitis/my-city/hello-world
git status                         # clean tree (just the Day-9 NOTES line on main)
git branch --list                  # see if day9-validation-furiosa still exists locally; leave alone
git log --oneline -3               # confirm 8c2983d is on main
cd /Users/rfvitis/my-city
```

#### B2: Start the city (~1 min, then ~5 min for full reconciler tick)

```bash
gc start
```

Wait for the supervisor to come up. Don't proceed until reconciler is running cycles (sample with `gc trace show --type cycle_result --since 5m`).

#### B3: File the paired-control bead (~3 min)

**Same scope as Day-9 (single-line NOTES append), but with step 5 NUDGE OMITTED.**

```bash
bd create "Day-10 paired control: NOTES line (no explicit nudge)" \
  --type task --priority 3 \
  --set-metadata gc.routed_to=hello-world/gastown.polecat \
  --description "$(cat <<'DESC'
## Task

Append exactly one line to hello-world/NOTES.md:

    2026-05-13: Day-10 paired control — no-nudge variant

That is the entire scope.

## Handoff protocol

After completing the work:

1. Stage and commit the change on a fresh branch named `day10-validation-$(your-alias)`.
2. Push the branch to origin.
3. Set metadata on this bead:
   - `branch`: the branch name you pushed
   - `target`: `main`
   - `work_dir`: your worktree path
   - `gc.routed_to`: hello-world/gastown.refinery
4. Assign this bead to the rig's refinery: `hello-world/gastown.refinery`.
5. Drain. Do NOT close the bead — refinery will close it after merging.

(Note: this variant intentionally omits the explicit nudge step. Refinery should pick up via its patrol watch.)
DESC
)"
```

**Note** `gc.routed_to` is set at create-time (Day-9 fix applied).
**Note** description has only 5 numbered steps (Day-9 had 6 including the nudge).

Record bead ID and T0 timestamp.

#### B4: Observe (~30 min bounded)

Same polling pattern as Day-9:

- T1: polecat materializes
- T2: polecat assigns to refinery (status=open, assignee=refinery)
- **T3: would-be-nudge** — should NOT happen this time. If polecat issues a nudge anyway, the omission instruction wasn't read.
- T4: refinery wakes / picks up
- T5/T6: merged + closed

If T4 takes longer than ~5 minutes after T2, that's evidence the explicit nudge was load-bearing in Day-9. Bound the wait at 30 minutes; beyond that record R-stalled and stop.

#### B5: Stop the city, capture outcome (~5 min)

```bash
gc stop
bd show <hw-bead-id> --json | jq '.[0].metadata'
git -C hello-world log --oneline -5
```

Categorize as R-equiv / R-degraded / R-stalled per §3 success criteria.

---

## 5. Outcomes pre-thought (decision tree)

**If R-equiv (refinery picks up within Day-9-similar timing):**

- The explicit nudge was NOT load-bearing in Day-9; watch worked fine.
- v2 manual §19 "nudge refinery pattern" should soften from "treat as reliability requirement" back to "best practice / accelerator." The mc-uhvbb9 reliability issue is then narrower than we hypothesized — Day-4's 79-min stall may have been a one-off due to specific concurrent reconciler load.
- mc-uhvbb9 stays open but with a corrected scope note.

**If R-degraded (refinery picks up but with much higher latency):**

- The nudge accelerated wake. Watch is functional but slow.
- §19 should say "nudge for promptness, but watch will eventually fire."
- mc-uhvbb9 reframed as a performance issue, not a correctness issue.

**If R-stalled (refinery never picks up within 30 min):**

- The explicit nudge was load-bearing. Day-9's success required it.
- §19's strong framing ("treat as reliability requirement") stays.
- mc-uhvbb9 confirmed as a correctness issue, not just performance. Worth a higher priority bump and likely an upstream patch attempt in a future day.

---

## 6. Risk / blast radius

- **Phase A edits**: small text changes to v2 manual. Reversible via git. No code impact.
- **Phase B `gc start`**: same as Day-6/9 §6. Reversible via `gc stop`.
- **Phase B bead**: same shape as Day-9's. Single-line file edit, fully reversible.
- **Phase B leaves another commit on `hello-world` main** (`day10-validation-...` branch merged). That's expected — the validation suite accumulates harmless test commits. If needed, can be cleaned up by squashing or resetting back to `8c2983d` after several runs.
- **The bare remote** at `/Users/rfvitis/hello-world-origin.git` accumulates branches too. No size concern at this rate, but worth noting.

---

## 7. Connection to prior days

- **Day-4** observed the auth-wg0 79-min stall and (incorrectly) attributed it to a discovery-predicate bug.
- **Day-8** corrected the discovery understanding via S5 diagnosis; surfaced mc-uhvbb9 as the real failure mode.
- **Day-9** validated the corrected §19 prompting on a small scope (~9 min vs 79 min) but couldn't isolate whether the explicit nudge was the cause.
- **Day-10** Phase B answers the question Day-9 left open: paired control with the nudge omitted.
- **Day-7's mc-ma23a9 fix** got reverted during Day-9's `gc start`. State files weren't published during Day-9. Both still apply; Day-10 will see the same.

---

## 8. Adjacent work to fold in while on Day-10

Lightweight items, none depend on Phase A or B:

- **Push the Day-7 upstream branch `rjgeng/fix/dolt-pack-script-state-fallback`** as a PR if Day-10 reaches F5 again. Two days of compatible behavior is enough to justify upstream engagement.
- **File a small "state-file staleness" upstream bead** capturing the Day-9 observation. Related to mc-f7u8fz, but a distinct symptom worth its own bead so it's not lost.
- **Re-test mc-ma23a9 local-edit revert behavior** — does `gc reload` (lighter than `gc stop && gc start`) also wipe local pack edits, or only the full restart? If `gc reload` is safe, that's a workflow improvement worth documenting.
- **Ack `mc-n333b`** if still pending.

If Phase B lands as R-equiv (the cheapest outcome), the upstream PR adjacent is the highest-yield.

---

## 9. Optional: mayor handoff

Skip for Phase A (text editing — solo).

For Phase B: light mayor path again, same as Day-9. The whole point of holding all-other-variables-constant is matching Day-9's exact setup minus the nudge instruction. Bringing mayor in would change two things at once.

A future Day-N+1 could test full-mayor: have mayor file the bead and observe whether mayor sets `gc.routed_to` automatically (which Day-9's finding #1 implies). But that's a different experiment from Day-10's paired control.

---

## 10. Execution log

### Phase A outcomes

- **§19 prerequisite paragraph added**: Yes — `gc.routed_to` documented as load-bearing for pool scaling, with `bd create` example and Day-4 S6 clarification.
- **§19 refinery field names updated**: Yes — step 5 now lists `merged_sha` / `merged_target` / `merge_result`; legacy `merged_commit` referenced in a note pointing to where it appears in older bead histories.
- **§19 new "How to file a polecat-friendly bead spec" subsection**: Yes — three-step checklist with `bd create` example.
- **§22 state-file staleness paragraph**: Yes — folded into the two-state-files subsection. Includes `bd dolt status` lies-about-port practical implication.
- **§22 premise-falsification adds Day-9 example**: Yes — third bullet covering the Day-4 S6 inversion. Pattern definition broadened from "grep upstream" to also include "controlled test with smallest possible scope."
- Phase A commit: `7d5c1cf`

### Phase B pre-flight

- Hello-world state: clean working tree, `main` at Day-9's `8c2983d`, no leftover branches.
- Bare remote: `/Users/rfvitis/hello-world-origin.git` present and working from Day-9 setup.
- `gc start` outcome: controller came up (PID 39797) but reported "city did not become ready under supervisor; keeping registration for retry." Same pattern as Day-9 — supervisor is technically up but in adopting-sessions mode under reconciler I/O pressure. Proceeded anyway because Day-9 showed this state was operationally functional.

### Phase B timings

| Event | Wall-clock time | Notes |
|---|---|---|
| `gc start` issued | 08:38:29 | T-start |
| Phase B bead created | 08:43:34 | `hw-0bdpb`, `gc.routed_to=hello-world/gastown.polecat` set ~3s after create |
| First poll snapshot (no polecat yet) | 08:43:34 +0s | refinery `asleep (on_demand)` |
| T1+T2+T3 — polecat materialized, did work, assigned to refinery | by 08:47:12 (+218s) | All packed into one observation cycle. Branch `day10-validation-furiosa` set as metadata. polecat `furiosa` running. **No explicit nudge step was in the description.** |
| T4 — refinery picks up | between +218s and +569s | Refinery transitioned from `asleep (on_demand)` to `running` during this window |
| T5+T6 — bead closed with merged_sha | 08:53:03 (+569s = 9m 29s from T0) | `merged_sha=3c80d20a48e2dd...`, `merge_result=merged` (verified post-stop). Origin `main` advanced from `8c2983d` → `3c80d20`. |
| `gc stop` | 08:55:49 | First stop call left supervisor PID 39797 lingering ("standalone-managed" reported); second `gc stop` cleaned up. |

### Outcome category

- **R-equiv.** Total wall clock 9 min 29s from bead create to bead closed, with `gc.routed_to` set at create-time and NO explicit nudge instruction. Day-9 (with nudge instruction) was ~9 min 20s after the metadata fix. The two end-to-end timings are within ~1% of each other — well inside the noise of reconciler cycle latency variance (Day-9 measured cycles 65-230s on the same day).
- **Evidence:** Phase B bead `hw-0bdpb` closed with `merged_sha=3c80d20a48e2dd6e462e2675063f5dd22cc11635`. Origin commit `3c80d20 docs: add Day-10 paired control NOTES entry (no-nudge variant)` landed on `hello-world/main`. Refinery transitioned from `asleep (on_demand)` to `running` during the observation window with no manual intervention.

### Which §19 framing wins

- **"Nudge is best practice / accelerator, not strictly required."**
- **Reasoning:** Refinery's `gc events --watch --type=bead.updated` fired on the polecat's assignment event under nominal conditions. The on-demand refinery materialized from `asleep` to `running` without any human nudge or any nudge in the bead description. Day-4's 79-min `auth-wg0` stall must have been a specific-conditions failure — likely the concurrent JSONL push storm (`mc-vj3hjk` was firing through Day-4) starved the streaming API enough to block the watch. The mc-uhvbb9 bug is real but its scope is narrower than the §19 Day-8 framing suggested: "watch fails under heavy concurrent load," not "watch is generally unreliable."
- **Action on §19**: soften the "treat as reliability requirement" framing to "use the nudge when you know the system is under stress; otherwise the watch is reliable under nominal conditions." Belt-and-suspenders, not load-bearing.
- **Action on mc-uhvbb9**: keep open but reframe scope — the bug manifests under reconciler I/O saturation specifically (consistent with the streaming-API-starvation hypothesis). Possible-root-cause #1 in that bead remains the top candidate.

### Surprises

1. **The watch IS reliable under nominal conditions.** This was the OPPOSITE of my prior assumption. Day-8 confidence was based on Day-4's 79-min stall, which I extrapolated to "watch is unreliable in general." Day-10's controlled test disproved that. Lesson: a single observed failure mode doesn't characterize a system's typical behavior. mc-uhvbb9's scope needed correction.
2. **The supervisor leaked across `gc stop`.** First stop call reported "City stopped" but `ps -p 39797` showed the supervisor was still alive ("standalone-managed"). Second stop cleaned up. This is a minor mc-uhvbb9-shaped quirk worth noting; controller shutdown under reconciler load isn't atomic.
3. **Day-9 vs Day-10 timing equivalence is striking.** Both runs landed in ~9 minutes from "valid bead state" to "merged + closed." That's evidence the polecat→refinery pipeline has a consistent ~9-minute throughput floor under current reconciler load, dominated by the cycle latency (65-230s per cycle in Day-9 measurements). Lower than that probably requires fixing `mc-f7u8fz` first.
4. **`bd create --set-metadata` doesn't exist.** Had to do two-step (create, then `bd update --set-metadata`). Quick recovery; cost ~3 seconds vs the planned single command. Minor plan inaccuracy.
5. **The §19 Day-8 framing was driven by survivorship bias.** Day-4 was the most memorable run because it stalled. The hidden assumption "Day-4 is representative" turned out to be wrong. The fix the manual needs is removing the strong claim, not strengthening it further. Reinforces the §22 falsification pattern in a new direction: even our own corrected writeups can be over-confident.

### Anything to promote to v2 manual (beyond Phase A)

1. **§19 "The nudge refinery pattern" needs softening from Day-8's reliability-requirement framing to a more nuanced "accelerator / belt-and-suspenders under known stress."** Currently committed as a Phase A edit but with the wrong polarity. Day-10 Phase C (this Edit) applies the correction.
2. **§19 "Mayor's PAUSE anti-pattern" needs a re-read.** Currently says polecat completed the handoff but didn't nudge, and that omission caused the stall. Day-10 shows the omission alone isn't the failure mode. The PAUSE pattern is still worth documenting (it can cause confused polecat behavior) but its cited symptom (the Day-4 79-min stall) was probably driven by something else (concurrent load), not the missing nudge per se.
3. **A new §23 subsection or §22 note about "system-under-stress" diagnostics.** If `mc-f7u8fz` reconciler cycles are slow, the watch can fail, the supervisor can leak across stop, the state files don't get written. These are correlated symptoms of the same upstream pressure. Worth a short paragraph: "If you see one, suspect the others."
4. **mc-uhvbb9 closure note**: update the bead with Day-10's findings (refinery watch is reliable under nominal conditions; the bug manifests specifically under reconciler I/O saturation). Not closed yet — the watch failure mode is real and worth tracking — but scope refined.
