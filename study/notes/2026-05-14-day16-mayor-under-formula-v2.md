# Day 16 — full-mayor demo under formula_v2 = true

- **Plan authored:** 2026-05-13 (evening, after Day-15 closure)
- **Planned execution:** 2026-05-14 (Day-16)
- **Status:** Plan only; experiment not yet run

The natural successor to Day-9/10's paired control. Day-9 ran light-mayor as the orchestrator and disproved that the explicit nudge was load-bearing. Day-10 paired-controlled that conclusion. Both used light-mayor; full-mayor was explicitly deferred ("save full-mayor variant for a later day"). With formula_v2 now on after Day-15, the city is in a new operating regime — Day-16 is when we see what mayor decomposition looks like in that regime.

This is an **experiment day**, not a fix-the-thing day. The success metric is observation quality, not bug count.

---

## 1. Pre-flight: what we know going in

**City state (end of Day-15):**
- `[daemon] formula_v2 = true` in city.toml
- Supervisor PID 30730 running with 5 control-dispatcher sessions auto-injected (1 city + 4 rigs)
- dolt PID 33765 running, gc-managed config (port 58545, data dir `.beads/dolt`)
- All other agents in scaled/standby state (deacon was the only one running at end of Day-15)
- The 5 v2 formulas (mol-scoped-work, mol-review-quorum, mol-digest-generate, mol-refinery-patrol, mol-idea-to-plan, mol-dog-reaper, mol-dog-compactor) are now compilable

**Mayor configuration (confirmed pre-flight):**
- `.gc/system/packs/gastown/agents/mayor/agent.toml`: `scope = "city"`, `wake_mode = "fresh"`, `idle_timeout = "1h"`, `max_active_sessions = 1`. No `prompt_template` field.
- `.gc/system/packs/gastown/agents/mayor/prompt.template.md`: a custom template ("Mayor Context") with explicit Work Philosophy section ("Dispatch Liberally, Fix When Fast"). NOT using a built-in worker template.
- Open question for Step 1: does the formula_v2 prompt swap reach mayor at all, or is mayor's custom template loaded by convention regardless of the flag? Hypothesis: mayor's template is loaded directly (the prompt.template.md by-convention path); formula_v2's default-template swap only affects agents that have NO template file. Worth verifying.

**What's still unknown (Day-16 will surface):**
- Does mayor's session under formula_v2 produce graph.v2 workflow root beads (`gc.kind=workflow`, `gc.formula_contract=graph.v2`) for its dispatches?
- Does the control-dispatcher participate in mayor's cross-rig orchestration, or is it only for explicit v2 formulas?
- Do polecats (mayor's normal dispatch targets) use the default template (and therefore swap to graph-worker.md)? Or do they have custom templates too?
- Has the Day-4 cross-rig convoy gap (mc-wjos2g, soft-link via `convoy:mc-XXX` label) changed at all under v2?

---

## 2. What "done" looks like

**Primary observation goals (must collect):**
- A full mayor session transcript end-to-end on a multi-rig coding task.
- A complete events.jsonl extract of every bead created during the mayor session, with `gc.kind` + `gc.formula_contract` metadata visible.
- The full chain of agent handoffs (mayor → polecat → refinery → witness) recorded with timestamps.
- Cross-rig handoff behavior: did mayor produce a convoy bead, a soft-link label, both, neither? What did the dispatcher do (if anything)?
- Comparison with Day-4's full-mayor run on the same axis (decomposition style + cross-rig dynamics).

**Secondary observation goals (nice to have):**
- Latency profile: total mayor session duration, per-rig sub-task duration. Compare to Day-9/10 light-mayor numbers.
- The other 6 v2 formulas — do any of them get invoked at all during the day? (mol-scoped-work and mol-review-quorum are particular candidates since they sound coordination-relevant.)
- The slow_storage_degraded warning rate under the new (heavier) workload — should be similar to baseline if Day-6's "misnamed budget warning" framing is correct.

**Manual artifact:**
- v2 manual §26 candidate: "Full-mayor orchestration under graph.v2." Target ~50-80 lines covering what changes vs. v1, when full-mayor is appropriate vs. light-mayor, and any new pitfalls. Defer the section number; could be §26 or an §17/§19 cross-reference if shorter.

**Stretch outcomes:**
- If the run surfaces an upstream bug (latent for ~10 days), document for a potential second-PR candidate.
- If the run surfaces a config skew the user has but the pack maintainers fixed (similar to Day-15's formula_v2 = false), file a bead.

---

## 3. The task to give mayor

This is the only real design decision in the plan: what task does mayor decompose?

**Option A — rerun Day-4's task (CRUD across rigs).** Pros: directly comparable to Day-4. Cons: stale; codebase has moved since.

**Option B — new task: "add a /health endpoint to co_store, co_shipping, and co_auth; have co_auth provide a token-validation function the others call."** Pros: exercises three rigs, has a clear review surface (the auth dependency), can be smoke-tested in one HTTP request. Cons: not directly comparable to prior runs.

**Option C — coordination-pure task: "audit the four rigs for which still have a placeholder README and file a bead per missing one."** Pros: zero code-writing risk; purely exercises mayor's coordination logic + bead creation + per-rig dispatch. Cons: less realistic; doesn't exercise the convoy / cross-rig handoff strongly.

**Option D — let mayor pick its own task.** Pros: maximally autonomous; revealing of mayor's "what's most important right now?" judgment. Cons: hardest to evaluate; you'd have no reference scope.

**Recommendation: Option B.** Concrete enough to evaluate, multi-rig enough to exercise convoys + dispatcher, has a natural review beat that exercises mol-review-quorum if mayor reaches for it. Roughly 60-90 minutes wall-clock for mayor + workers to complete. Falls back to Option C if Option B turns out to take too long.

Decide before Step 2.

---

## 4. Execution plan — step-by-step

Total budget: ~2-3 hours wall-clock (lots of observation; the mayor itself runs unattended).

### Step 1: Verify pre-flight assumptions (~10 min)

```bash
# City still up from Day-15?
ps -p 30730 -o pid,stat,etime 2>&1   # supervisor
ps -p 33765 -o pid,stat,etime 2>&1   # dolt
gc supervisor logs 2>&1 | tail -10   # any errors overnight?

# Mayor's template loading path — does formula_v2 affect it?
# Run: gc prime --agent mayor --strict 2>&1 | head -20
# Look at the rendered prompt's first ~20 lines. If it starts with "# Mayor Context"
# (from prompt.template.md), the custom template is loaded by convention.
# If it starts with "# Graph Worker", the flag override kicked in.

# Verify the 5 control-dispatcher sessions are still tracked
gc status 2>&1 | grep -i dispatcher
# (Note: gc status may hang per Day-15 finding. Fall back to:
#  pgrep -lf "control-dispatcher" | head -10
#  tmux list-sessions 2>&1 | grep control-dispatcher | head -10)
```

Outputs to record:
- Mayor's effective prompt template (custom or graph-worker.md fallback)
- Dispatcher session state
- Any overnight surprises in supervisor logs

If anything looks wrong, stop and diagnose. Day-15's flip is fresh enough that latent issues might surface only after first overnight.

### Step 2: Brief mayor (~10 min)

Open a mayor session:
```bash
gc agent wake gastown.mayor
# Wait for the session to appear in tmux
tmux attach-session -t <session-name>
```

Compose the task brief in the mayor's chat. Use Option B (or whichever was picked). Be specific about the success criteria — what mayor should consider "done" — but leave the decomposition to mayor.

Example brief (Option B):
> Coordinate adding a `/health` endpoint to `co_store`, `co_shipping`, and `co_auth`. `co_auth` provides a token-validation helper that `co_store` and `co_shipping` import. Smoke test: `curl :<port>/health` returns 200 with a JSON body including `auth_status=ok` when the auth helper is reachable. Open beads, dispatch, review. Then STOP — don't keep going past the smoke test.

Note the timestamp when the brief is sent. Then **do not interact with the mayor again** until either (a) mayor mails you with "done", (b) mayor sends a `gc mail send mayor/` escalation, or (c) ~90 minutes have passed.

### Step 3: Passive observation (~90 min)

While mayor runs, stream events:
```bash
F=/Users/rfvitis/my-city/.gc/events.jsonl
tail -f "$F" | grep -E 'bead\.(created|updated|closed)|order\.|session\.' | tee /tmp/day16-events.log
```

Watch for:
- New beads with `gc.kind=workflow` (mayor producing v2 workflow roots, which would be NEW behavior)
- Cross-rig beads (e.g., `cs-XXX` beads created from mayor's session — mayor lives at HQ, so a bead in a rig-prefixed namespace is a cross-rig dispatch)
- control-dispatcher activity (beads assigned to `<rig>--control-dispatcher`)
- Any `order.failed` events (the dispatcher's start-up logic could fail under load)
- mol-review-quorum or mol-scoped-work invocations (these would be new — never observed before)

Take notes; this is the day's data.

### Step 4: Triage if mayor stalls (~15 min, contingent)

If at any point mayor seems stuck:
- Read its current prompt session: `tmux capture-pane -p -t <session>` 
- Look in events.jsonl for the last 5 minutes
- Check if a polecat has open work that's not closing

If mayor genuinely stalls (no events for 10+ min and no escalation mail), the controlled-failure path is to send a single nudge: `gc mail send mayor -s "status?" -m "What's blocking?"`. Document it; this is a behavior to note.

If after 10 min more there's still no progress, gracefully stop the experiment. Note where it stalled. That's data too.

### Step 5: Collect results (~20 min)

After mayor finishes (or stalls cleanly):
```bash
# Extract all beads created during mayor's session window
T0="<timestamp from Step 2>"
T1="<now>"

# Beads created
grep 'bead.created' "$F" | jq -c "select(.ts >= \"$T0\" and .ts <= \"$T1\")" > /tmp/day16-beads-created.jsonl

# Beads closed
grep 'bead.closed' "$F" | jq -c "select(.ts >= \"$T0\" and .ts <= \"$T1\")" > /tmp/day16-beads-closed.jsonl

# Workflow roots specifically
jq -c 'select(.payload.metadata."gc.kind" == "workflow")' < /tmp/day16-beads-created.jsonl > /tmp/day16-workflow-roots.jsonl

# Per-rig per-agent breakdown
jq -c '.payload.assignee // .payload.routed_to // empty' < /tmp/day16-beads-created.jsonl | sort | uniq -c | sort -rn
```

Save the working files to `/tmp/` (transient — they're already in events.jsonl).

### Step 6: Compare to Day-4 + Day-9/10 (~30 min)

Open the three reference points side by side:
- Day-4 execution note (full-mayor under v1)
- Day-9 execution note (light-mayor under v1)
- Day-10 paired control (light-mayor under v1, validating Day-9)

For each, compare:
| Axis | Day-4 (v1 full) | Day-9/10 (v1 light) | Day-16 (v2 full) |
|---|---|---|---|
| Total wall-clock |  |  |  |
| Beads created |  |  |  |
| Workflow roots (gc.kind=workflow) |  |  |  |
| Cross-rig handoffs |  |  |  |
| Dispatcher activity |  |  |  |
| Convoy bead OR soft-link |  |  |  |
| Mayor's decomposition style |  |  |  |
| Escalations / blockers |  |  |  |

The compare table goes into §9 (execution log). The narrative of what's different goes into the §26 candidate.

### Step 7: Document (~30 min)

Write the §26 candidate inline as a new subsection of v2 manual. Target 50-80 lines. Cover:
- What changes under v2 for full-mayor vs v1.
- When full-mayor is appropriate vs light-mayor (with v2 may shift the answer).
- New pitfalls or new affordances (e.g., if control-dispatcher participates in cross-rig handoff, that resolves Day-4's mc-wjos2g — note it).
- A short verdict on the experiment's hypotheses (Hs from §5).

Don't extend the manual by more than ~80 lines this day. If §26 wants to grow, defer.

### Step 8: Commit + push (~10 min)

```bash
git add city.toml study/notes/2026-05-14-day16-mayor-under-formula-v2.md study/notes/gas_city_build_manual_practical_guide_v2.md
git commit -m "docs: Day-16 execution — mayor under formula_v2 = true"
git push
```

If a bead got filed (e.g., a fresh observation worth tracking), include the bd update on its own commit boundary.

---

## 5. Hypotheses (G1-G7)

**G1: Mayor's prompt is NOT affected by formula_v2.** Mayor has a custom `prompt.template.md` discovered by convention; the formula_v2 prompt-swap only affects agents whose `PromptTemplate` field is empty AND who don't have a convention-discovered template. Mayor falls into neither bucket. **Predicted outcome:** Step 1's `gc prime --agent mayor` shows the "# Mayor Context" header from `prompt.template.md`, not "# Graph Worker".

**G2: Polecats DO use the default template** (and therefore swap to graph-worker.md). Predicted because polecats are dispatched ad-hoc into a pool and don't have a `prompt.template.md` in their agent dir (need to verify; if they DO, G2 falsifies). **Predicted outcome:** when mayor dispatches to a polecat, the polecat's first claim/close behavior follows the bead-graph pattern (outcome metadata, continuation-group affinity) rather than the molecule walk pattern.

**G3: Mayor produces graph.v2 workflow roots when it creates work that has internal step dependencies.** Day-4's mayor used `bd mol create` / `bd mol create-children` (v1 molecule); under v2, mayor *could* keep using molecules or it *could* use the new workflow form. The prompt template doesn't tell us — the user prompt's "Dispatch Liberally" guidance is shape-agnostic. **Predicted outcome:** mayor stays on molecules (no behavior change at the user-prompt level). v2-specific shapes only show up for formulas that explicitly declare `contract = "graph.v2"`.

**G4: The control-dispatcher does NOT participate in mayor's coordination of normal coding work.** It only fires for `gc.kind=check|fanout|retry-eval|scope-check|workflow-finalize` beads, which are produced by v2-formula compilation, not by mayor's ad-hoc bead creation. **Predicted outcome:** during Step 5, control-dispatcher assignments appear zero times unless mayor explicitly dispatches a v2 formula via `gc sling`.

**G5: Day-4's cross-rig convoy gap (mc-wjos2g) is UNCHANGED under v2.** The convoy mechanism (mayor produces a convoy bead, child beads carry a `convoy:mc-XXX` label) is orthogonal to formula_v2. No code path in the dispatcher injection or graph-worker prompt touches it. **Predicted outcome:** if mayor's task crosses rigs, mayor still produces the soft-link label workaround, not a real cross-rig convoy parent-child relationship.

**G6: mol-scoped-work and/or mol-review-quorum get invoked at some point.** These two are the v2 formulas most likely to be reached from mayor's coordination logic (they sound coordination-relevant by name). **Predicted outcome:** at least one of these fires during Day-16's session. If neither does, the other 6 v2 formulas might just be inert in this city.

**G7: The full-mayor session wall-clock is 2-3× the light-mayor case from Day-9/10**, mostly because full-mayor reads more docs and dispatches more agents. NOT because of formula_v2.

If G1, G3, G4, G5 all hold (predicted), then the **honest summary of Day-16** is: formula_v2 didn't actually change mayor's behavior much; the experiment confirms that v2 affects the deacon/dispatcher path, not the human-prompt-driven coordination path. That's a valuable null result, not a disappointment.

If any of G1, G3, G4, G5 falsifies, the §26 candidate grows materially.

---

## 6. Risk / blast radius

**Step 2 (briefing mayor):** mayor's session is full-write on its own work_dir + bead store. Risk: mayor might create beads it can't close, or might escalate / mail noisily. Mitigation: budget = 90 min; gracefully stop at the budget.

**Step 3 (passive observation):** zero risk; read-only.

**Step 4 (triage if stuck):** the nudge is a deliberate intervention to test recovery. Worst case, mayor responds with "I was thinking" — that's data. There's no rollback consideration; the experiment is read-mostly.

**The biggest non-obvious risk:** mayor might surface a real upstream bug (latent for ~10 days, finally exposed by formula_v2 = true). If it does, the experiment morphs into a fix-the-thing day. Don't try to do both; document the bug, stop the experiment cleanly, and decide whether Day-16 is "experiment" or "bug-day" based on which surface is more valuable.

**Rollback path:** none needed. If the experiment goes badly, kill the mayor session (`gc agent suspend gastown.mayor`), document the failure mode, move on. Day-15's config change stays.

---

## 7. Connection to prior days

- **Day-4 (full-mayor under v1):** direct comparison. Day-16's compare-table in Step 6 references Day-4 as the v1 full-mayor baseline.
- **Day-9 / Day-10 (light-mayor paired control under v1):** the *control* arm. Day-16 doesn't re-run the control; it relies on those notes as the reference point.
- **Day-13 / 14 (orders + formula_v2 investigation):** Day-16 is the first chance to see whether the §25 catalog's order entries actually fire under realistic load (vs. the synthetic single-fire of digest-generate on Day-15).
- **Day-15 (formula_v2 = true applied):** Day-16 is the first non-trivial use of the new regime. The "wake-budget false-negative" surprise from Day-15 is relevant — Step 1 should not hang waiting for `gc status` to confirm dispatcher state.

---

## 8. Optional / mayor handoff

**This IS the mayor day.** No handoff is meaningful in the usual sense (Day-9/10 sense of "mayor coordinates the work and we observe"). The user is the *observer*, mayor is the *actor*.

The one piece of explicit coordination: the brief in Step 2 should follow the Day-13 chat-log lesson — be precise about the success criteria (smoke test format), but explicitly end with "Then STOP." per the Day-4 finding (mayor sometimes over-interprets open-ended briefs). The "Then STOP." discipline is the mayor's positive-cousin pattern surfaced in the Day-14 retrospective.

---

## 9. Execution log

(filled in as work happens)

### Pre-flight outcomes (Step 1)

- Supervisor + dolt still up:
- Mayor's effective prompt template (custom or graph-worker.md fallback):
- 5 control-dispatcher sessions tracked:
- Overnight surprises in supervisor logs:

### Mayor briefed (Step 2)

- Task option selected:
- Brief sent timestamp:

### Observation window (Step 3-4)

- New workflow roots (`gc.kind=workflow`):
- Cross-rig beads (rig-prefixed in mayor's namespace):
- control-dispatcher assignments observed:
- order.failed events:
- mol-scoped-work / mol-review-quorum invocations:
- Mayor stall / nudge episodes:

### Results (Step 5)

- Total wall-clock:
- Beads created:
- Beads closed:
- Workflow roots created:
- Per-rig per-agent breakdown:

### G1-G7 verdicts

- G1 (mayor template NOT affected by flag):
- G2 (polecats DO use default template → swap to graph-worker):
- G3 (mayor produces v2 workflow roots):
- G4 (control-dispatcher participates / doesn't):
- G5 (Day-4 cross-rig convoy gap unchanged):
- G6 (mol-scoped-work / mol-review-quorum invoked):
- G7 (wall-clock 2-3× light-mayor):

### Compare table (Day-4 / Day-9-10 / Day-16)

(filled in during Step 6)

### v2 manual §26 candidate added

- [ ] Subsection drafted
- [ ] Compare with v1 full-mayor (Day-4)
- [ ] When full-mayor vs light-mayor under v2
- [ ] New pitfalls / new affordances

### Surprises

(things this plan got wrong, or new things surfaced)

### Anything to promote (beyond §26)

(filled in after the experiment)
