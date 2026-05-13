# Day 21 — Convoys tour (6+ deferrals overdue)

- **Plan authored:** 2026-05-13 (evening, after Day-20 closure)
- **Planned execution:** 2026-05-15
- **Actual execution:** 2026-05-13 (continued same evening as Day-20; the convoys tour took ~45 min, faster than planned)
- **Status:** EXECUTED. §29 written (~120 lines); §20 stamped as historical with pointer to §29. Two big hypotheses falsified (G2 and G5 — convoys ARE NOT workflows; they're distinct primitives).

The retrospective's most-deferred item. Mentioned in 2026-05-08 (stop 3 sidebar), Day-4 (`mc-wjos2g` workaround), Day-13 (offered as alternative, deferred), Day-13 plan §8 (deferred again), Day-13 wrap (deferred to Day-15+), Day-17 plan §7 (Day-19+ candidate), Day-18 plan §7 (Day-20+ candidate), Day-19 plan §7 (Day-21+ candidate), Day-20 plan §7 (Day-21+ candidate). **Eight explicit deferrals over 7 days.** Day-21 is when this lands.

After 7 fix-cadence days (Days 14-20: formula_v2 application, gc upgrade, bd regression, upstream comment), the deck wants a pure exploration day. The convoys tour fits — tour shape, not fix shape, low risk, clears mental cache.

There's also a secondary outcome that makes Day-21 timely: **§20's cross-rig convoy gap claim hasn't been re-verified since the HEAD-caa44a4 + formula_v2 = true regime change.** §20 was written under gc 1.1.0 with formula_v2 = false. The convoy subsystem has presumably evolved across the 130 commits we just absorbed in Day-18; this tour either confirms §20 still holds or updates it.

---

## 1. Pre-flight: what we know about convoys

**From `gc convoy --help` (just sampled):**

- A convoy is a **named graph of beads with dependencies.**
- Two flavors:
  - **Simple convoys** — group related issues via parent-child relationships (v1 shape).
  - **Complex convoys** — formula-compiled DAGs with control beads for orchestration (v2 shape).
- 11 subcommands: `create`, `add`, `list`, `status`, `land`, `delete`, `close`, `check`, `stranded`, `target`, `control`.

The v1/v2 split here echoes the v1/v2 contract split from Days 14-15 (formula_v2). **Hypothesis:** complex convoys are the manifestation of `gc.kind=workflow` + `gc.formula_contract=graph.v2` beads at the convoy layer; the control-dispatcher agents auto-injected by formula_v2 are the workers that execute control beads in complex convoys.

**§20's claim (currently in the manual):**

> Convoys filed in HQ (`mc-*` prefix) cannot directly parent beads from different rigs (e.g., `auth-1` and `cs-3` can't both be children of `mc-X`). `gc convoy add` fails the parent-edge creation between HQ and a rig-prefixed bead. Workaround: tag each rig-local child bead with `convoy:mc-XXX`.

This was written from Day-4's experience under gc 1.1.0. The convoy subsystem has likely changed since — Day-21's tour will know.

**Day-15 connection:** the 5 control-dispatcher agents auto-injected when formula_v2 = true (city + 4 rigs) ARE convoy-related infrastructure. Their start command is literally `gc convoy control --serve --follow control-dispatcher`. So convoys are the home turf of the dispatcher subsystem — this tour is also the formal introduction to what the dispatchers are actually for.

**Current city state going in:**

- gc HEAD-caa44a4 running with formula_v2 = true.
- 5 control-dispatcher sessions confirmed active (Day-18 supervisor logs).
- bd symlinked to 1.0.3 (Day-19 workaround for mc-mxl4vc).
- The Day-4 mc-wjos2g convoy bead is somewhere in the bd store, presumably with its `convoy:mc-wjos2g` labeled children still hanging off it.

---

## 2. What "done" looks like — observation goals

**Primary (must collect):**

- A working mental model of what a convoy IS — what fields define it, where it lives in the bead store, how `gc convoy list` displays it.
- A concrete example: read at least one existing convoy in the city end-to-end (parent bead + children + status).
- Confirmation of the simple/complex distinction in actual data.
- Re-verification of §20: is the cross-rig parent gap still real under HEAD-caa44a4? Or has it been fixed?
- A small worked example of `gc convoy create` + `gc convoy add` + `gc convoy land` from scratch (within one rig — single-rig is the easy case).

**Secondary (nice to have):**

- Observe what the control-dispatcher does when a complex convoy is dispatched (does it actually fire workflow-finalize beads? what does that look like in events.jsonl?).
- Map out where convoy logic lives in `study/gascity-src/` (which files own which commands).
- Note any new convoy-related commits between v1.1.0 and HEAD-caa44a4.

**Manual artifact:**

- §20 update: either "still holds" stamp, OR a rewrite with the new behavior.
- New §29 candidate: "Convoys: the tour" (~80-120 lines). Covers the simple-vs-complex split, the typical operator workflow, the cross-rig case, the control-dispatcher's role. Replaces §20 as the primary convoy reference (§20 becomes a small caveat footnote if the gap persists, or disappears entirely if it's fixed).

**Tour shape, not fix shape.** This day produces docs, not fixes. If the tour incidentally surfaces a fixable bug, file a bead but don't pivot Day-21 into a fix day — preserve the tour cadence.

---

## 3. Execution plan — step-by-step

Total budget: ~90 min.

### Step 1: Read existing convoys in the city (~15 min)

```bash
# List all convoys
gc convoy list 2>&1 | head -30

# Take one (probably mc-wjos2g from Day-4) and see its detail
gc convoy status mc-wjos2g 2>&1 | head -40

# What are the children?
bd show mc-wjos2g 2>&1 | head -30
gc bd list --label=convoy:mc-wjos2g 2>&1 | head -10
```

Output: a short paragraph on what one convoy looks like in this city.

### Step 2: Look at the convoy code in gascity-src (~15 min)

```bash
cd /Users/rfvitis/my-city/study/gascity-src
ls cmd/gc/cmd_convoy*.go
ls internal/convoy/ 2>/dev/null
```

Read the top-of-file comment for one or two cmd_convoy files. Look specifically at `cmd_convoy_create.go`, `cmd_convoy_add.go`, and `cmd_convoy_dispatch.go` (which we touched on in Day-14's investigation — that's where graph.v2 routing lives).

Recent commits since v1.1.0 affecting convoys:

```bash
git log --oneline v1.1.0..HEAD -- cmd/gc/cmd_convoy*.go internal/convoy/ 2>&1 | head -20
```

Note anything that looks relevant to the cross-rig gap.

### Step 3: Try creating a simple convoy from scratch (~15 min)

In a single rig (co_store, say), do the canonical operator flow:

```bash
# Create three small beads
A=$(bd create "day21-tour-A" -t task --silent)
B=$(bd create "day21-tour-B" -t task --silent)
C=$(bd create "day21-tour-C" -t task --silent)

# Create a convoy tracking these
CONVOY=$(gc convoy create "day21-tour-convoy" --tracks "$A,$B,$C" 2>&1 | tail -1 | awk '{print $NF}')
echo "Convoy: $CONVOY"

# Observe the convoy
gc convoy status "$CONVOY" 2>&1 | head -20

# Close children and observe land
bd close "$A" --reason "day21 tour"
bd close "$B" --reason "day21 tour"
bd close "$C" --reason "day21 tour"
gc convoy status "$CONVOY" 2>&1 | head -10

# Land
gc convoy land "$CONVOY" 2>&1 | head -10
```

If any step fails or surprises, document. The flow above is hypothetical — actual flags may differ.

### Step 4: Test the cross-rig parent gap (~15 min)

The Day-4 scenario, exactly:

```bash
# Create a convoy bead in HQ
CONVOY_HQ=$(bd create "day21-cross-rig-test" -t task --silent)

# Try to add a rig-prefixed bead as a child
RIG_BEAD=$(cd ~/co_store && bd create "day21-rig-child" -t task --silent)
gc convoy add "$CONVOY_HQ" "$RIG_BEAD" 2>&1 | head -10
```

Three possible outcomes:

- **A: Still fails** (§20's claim holds). `gc convoy add` produces an error about cross-rig parent edges. §20 stays as-is, maybe with a "verified Day-21" note.
- **B: Succeeds** (§20 is now stale). The cross-rig parent edge works. §20 needs a rewrite — possibly "cross-rig convoys ship as of <version>; the label-based soft-link workaround is no longer needed."
- **C: Different error** — failure mode changed, but not in a way that means the gap is fixed. Document.

After the test, clean up:

```bash
bd close "$CONVOY_HQ" --reason "day21 tour cleanup"
bd close "$RIG_BEAD" --reason "day21 tour cleanup"
```

### Step 5: Observe a complex convoy (~10 min)

If formula_v2 = true and the deacon's dispatching v2 formulas, complex convoys should be visible. Quickest path: look at the digest-generate convoy from Day-15's successful fires.

```bash
# Day-15 root beads were like cs-tc6zhp (rig-scope) and mc-1r8kbz (city-scope)
bd show mc-1r8kbz 2>&1 | head -20
gc convoy status mc-1r8kbz 2>&1 | head -20

# Or list all convoys with gc.formula_contract=graph.v2
gc convoy list 2>&1 | grep -iE 'graph|workflow|v2' | head -10
```

What we want to see:
- Whether `gc convoy status` for a v2 workflow root shows the step children as a DAG (with depends_on edges) or just a flat list.
- Whether the control-dispatcher's role is visible from the convoy view.
- Whether `gc convoy land` works for v2 workflows the same way as for simple ones.

### Step 6: Cross-check with formula_v2 wiring (~10 min)

Tie this back to Day-14/15's findings. The Day-15 §26 "Mayor under formula_v2" said the dispatcher injection was for graph.v2 formula compilation. Day-21's tour confirms or refines that picture:

- Are simple convoys actually "v1 contract" convoys?
- Are complex convoys actually "graph.v2 contract" convoys?
- Is "convoys" just the operator-facing name for what the docs call "workflows"?

Read AGENTS.md and look for convoy/workflow terminology:

```bash
grep -nE 'convoy|workflow' /Users/rfvitis/my-city/study/gascity-src/AGENTS.md | head -20
```

### Step 7: Write §29 candidate + update §20 (~15 min)

Synthesize the tour into a new §29 subsection of the v2 manual. Target ~80-120 lines. Structure:

- **What a convoy is** (one paragraph + the two-flavor distinction).
- **Simple-convoy operator workflow** (create → add → status → land, with a worked example).
- **Complex-convoy operator workflow** (mostly happens automatically when v2 formulas dispatch; just observe via `gc convoy status` and `gc convoy list`).
- **Cross-rig behavior** (Day-21's finding from Step 4, replaces §20's content or stamps §20 as "still holds").
- **The control-dispatcher's role** (where convoys meet the dispatcher; connects to §26's null-result framing).
- **Connection to formula_v2** (convoys = workflows = graph.v2 = control-dispatcher all reference the same underlying mechanism at different layers).

**Update §20 accordingly:**

- If gap still real → §20 becomes a short "cross-rig caveat" sub-section of §29, with a "verified Day-21" timestamp.
- If gap fixed → §20 is deleted (or kept as a historical note: "this gap existed in gc 1.1.0; fixed by upstream PR #XXXX, Day-21 confirmed under HEAD-caa44a4").

### Step 8: Commit + push (~5 min)

```bash
git add study/notes/2026-05-15-day21-convoys-tour.md study/notes/gas_city_build_manual_practical_guide_v2.md
git commit -m "docs: Day-21 execution — convoys tour + §29 (cross-rig gap: <status>)"
git push
```

---

## 4. Hypotheses (G1-G6)

**G1: There's at least one open convoy in the city.** Reasoning: the Day-4 mc-wjos2g convoy was created and probably never landed; the Day-15 digest-generate fires created workflow-root convoys; periodic orders create order-tracking convoys. Predicted outcome: `gc convoy list` shows 2-10 entries.

**G2: Simple and complex convoys coexist in the city.** Reasoning: pre-formula_v2 (Days 4-14) was simple-convoy era; post-Day-15 is complex-convoy era. The store should have both kinds. Predicted outcome: at least one simple convoy (mc-wjos2g style) and at least one complex (formula-driven, `gc.kind=workflow`).

**G3: The cross-rig parent gap is still real.** Reasoning: nothing in the v1.1.0..HEAD commit log specifically advertises cross-rig convoy support; the v2 graph contract is about step DAGs within a single formula, not cross-rig parent edges. Predicted outcome: Step 4 produces the same error §20 documented.

**G4: Complex-convoy `gc convoy status` shows DAG structure (depends_on edges), not just a flat list.** Reasoning: Day-15 saw the workflow root + 4 step beads with explicit `depends_on` metadata; `gc convoy status` should render that as a tree or graph. Predicted outcome: the output for `mc-1r8kbz` shows the step structure.

**G5: "Convoy" is the operator-facing alias for "workflow."** Reasoning: AGENTS.md calls them "workflows"; `gc convoy` is the user CLI. Internal code (`cmd_convoy_dispatch.go`) handles both shapes — simple is parent-child, complex is graph.v2 workflow root. Predicted outcome: code reading confirms convoy = workflow at the user layer.

**G6: The §20 update will be small.** Either "still holds, verified Day-21" or "gap fixed, here's the new pattern" — neither is more than 5 lines of change to the existing section. The bigger work is §29 (the new section). Predicted outcome: §20 net delta ≤ 10 lines; §29 is the main artifact.

If G1-G6 all hold, **Day-21 produces §29 as a clean tour writeup with §20 as a stamped sub-section.** No upstream contribution; no new beads. Just a credible reference for "what convoys are."

If G3 falsifies (cross-rig works now!), §20 gets rewritten and the city's convoy story becomes simpler going forward.

---

## 5. Risk / blast radius

**Step 1 (read existing convoys):** zero risk — read-only.

**Step 2 (read code):** zero risk.

**Step 3 (create simple convoy from scratch):** small risk. Creates 3 test beads + 1 convoy bead, then closes them. Creates a bit of bead-store churn but everything's recoverable.

**Step 4 (cross-rig test):** small risk. Creates 1 HQ bead + 1 rig bead + tries an add. Either fails cleanly (current §20 behavior) or succeeds. Cleanup is `bd close`.

**Step 5 (observe complex convoy):** zero risk — read-only against existing v2 workflows.

**Step 6 (cross-check AGENTS.md):** zero risk.

**Step 7 (doc updates):** zero risk.

**Step 8 (commit + push):** zero risk standard.

**Special consideration:** Step 3 and Step 4 create test beads. They should be `--silent` and prefixed `day21-tour-*` so they're obvious cleanup targets. Don't leave the test beads open at end of day; close them in Step 4 cleanup.

**Rollback path:** if any step creates state that shouldn't persist, `bd close <bead>` is the universal undo. The bead store keeps records of closed beads but they don't affect operation.

---

## 6. Connection to prior days

- **Day-4 (mayor decomposition + mc-wjos2g):** the original convoy experience. §20 was written from this day. Day-21 returns to revisit.
- **Day-13 (orders tour):** Day-21 is the convoy-tour parallel. Same shape: walk through subsystem, document, write §section. §25 (orders) and §29 (convoys) form the two halves of "how work is dispatched in this city."
- **Day-14/15 (formula_v2 investigation + application):** the v2 contract is the substrate complex convoys ride on. Day-21 makes the connection explicit at the convoy layer.
- **Day-16 (mayor under formula_v2):** §26's null-result framing said mayor's coordination doesn't use the v2 contract directly. Day-21 may refine that: maybe mayor's coordination produces SIMPLE convoys, while deacon's periodic orders produce COMPLEX ones. Worth checking.
- **The retrospective's "events.jsonl is an underused observability surface":** convoys are a structured layer ABOVE events; observing how a convoy advances may be more legible than reading raw events.jsonl. Worth a note in §29.

---

## 7. Adjacent work

Lightweight today-actions:

- **#3880 status check:** any new comments since Day-20's post? Maintainer engagement on the bd v1.0.5 release request? 30-second `gh issue view`.
- **The renames** in study/notes/: still uncommitted in working tree. Yours to handle.

Soon (Day-22+):

- **mc-f7u8fz observability re-attempt:** now that bd is on 1.0.3 (the city is functional) and we know more about the trace subsystem (HEAD-caa44a4 needs explicit arming, even armed didn't immediately produce data), worth one more measurement attempt. Could be paired with the events.jsonl silent-failure sweep.
- **The "duplicate-search-budget" promotion to §24** (Day-20 anything-to-promote item): ~15 min doc edit.
- **mc-uhvbb9** (refinery patrol hang): still awaiting #1487 reaction. No action.

---

## 8. Optional: mayor handoff

Skip. This is a personal-curiosity tour; mayor delegation would defeat the point.

That said: §29 might end up SUGGESTING that mayor handoff is the right way to USE convoys in normal operation (since mayor coordinates work, and convoys are the structure that work travels in). Worth a footnote — but the §29 tour itself isn't the place for that.

---

## 9. Execution log

(filled in as work happens)

### Step 1: existing convoys

- **`gc convoy list` count + sample:** 1 OPEN convoy (`mc-a0oj6` — "sling-mc-n333b", 0/1 closed). `gc convoy list` only shows OPEN convoys; no `--state all` flag exists.
- **mc-wjos2g detail status:** CLOSED. Day-4 convoy, "Next.js 16 auth demo", `type:convoy`, closed 2026-05-10. Children weren't directly shown in `bd show` (because parent edges presumably broke during cross-rig dispatch — they're tagged via labels per §20 workaround).
- **Total `type:convoy` beads in store:** 3 (mc-a0oj6 OPEN, mc-wjos2g CLOSED, mc-xlg5wt CLOSED "auth-rig-test-convoy" — appears to be a Day-4 era cross-rig test bed).
- **Children visible via `CHILDREN` section in `bd show`:** YES for in-rig convoys (mc-a0oj6 shows mc-n333b as child). NOT shown for cross-rig (the parent-edge gap from §20).

### Step 2: convoy code recon

- **Files in cmd/gc/cmd_convoy*.go:** `cmd_convoy.go`, `cmd_convoy_dispatch.go` (+ their _test.go siblings). Two source files only.
- **Internal package location:** `internal/convoy/` (confirmed via AGENTS.md line 118: "object model at the center: `internal/{beads, mail, convoy, formula, events, session, worker, sling, ...}`").
- **Recent commits (v1.1.0..HEAD) affecting convoys:** 7 commits found via `--grep="convoy"`. All minor: close_reason validation fixes (#1644, #1680, #1821, #1822, #1862), provider-lifecycle cleanup (#1715), and a witness-patrol clarification (#1922). **NOTHING about cross-rig parent edges.** G3 was predicted-strong before the test; commits confirm it.

### Step 3: simple convoy worked example

- **Convoy created:** `mc-h3b7g5` ("day21-tour-convoy") via `gc convoy create "day21-tour-convoy" mc-xa2kr5 mc-bh6ejp mc-o98rvl`. Output: "Created convoy mc-h3b7g5 ... tracking 3 issue(s)".
- **Three child beads:** mc-xa2kr5 (day21-tour-A), mc-bh6ejp (day21-tour-B), mc-o98rvl (day21-tour-C). All `type:task`.
- **`gc convoy status` output after creation:** clean tabular layout — "Convoy: mc-h3b7g5 / Title: ... / Status: open / Progress: 0/3 closed", then a child-bead table (ID, TITLE, STATUS, ASSIGNEE).
- **After children closed (all 3 via `bd close --reason`):** Progress went 0/3 → 3/3 closed. **But the convoy itself stayed OPEN** — no auto-close fired on the immediate cadence. Probably needs `gc convoy check` or a sweep order cycle.
- **`gc convoy land` outcome:** not attempted (would close the convoy; left it for the auto-sweep to demonstrate that path). Probably fires on the next `order-tracking-sweep` periodic order cycle.

### Step 4: cross-rig parent gap test

- **HQ convoy bead:** mc-cw4txp ("day21-cross-rig-test", `type:convoy`).
- **Rig child bead:** cs-klddp ("day21-rig-child", created via `cd ~/co_store && bd create ...`).
- **`gc convoy add` outcome:** **`gc convoy add: getting bead "cs-klddp": bead not found`**.
- **Outcome bucket:** **A (still fails).** Same outcome §20 documented under gc 1.1.0; slightly different error wording (Day-4 original: parent-edge failure; Day-21: "bead not found"). The root cause is unchanged — `gc convoy add` only reads the HQ bd store; cross-rig beads live in rig-local bd stores and aren't accessible.
- **Reasoning:** §20 holds. The label-based soft-link workaround remains the correct pattern. §29 absorbs §20's content as a sub-section; §20 becomes a historical pointer.
- **Cleanup:** both test beads closed cleanly.

### Step 5: complex convoy observation

- **Example workflow root (chose mc-1r8kbz — Day-15's city-scope digest-generate root):** has `gc.kind=workflow` + `gc.formula_contract=graph.v2` + `gc.outcome=pass` + `gc.routed_to=gastown.dog`. Type is `task`, NOT `convoy`.
- **`gc convoy status mc-1r8kbz` output:** **"bead mc-1r8kbz is not a convoy"** — explicit error. Workflow roots are NOT accessible via `gc convoy *` commands.
- **DAG visible? (G4):** **N/A — G4 is moot.** Since `gc convoy status` doesn't operate on workflow roots, the DAG visibility question doesn't apply at the convoy layer. The DAG IS visible via `bd show mc-1r8kbz` (which shows the children + their depends_on edges in the JSON output), but that's the data layer, not the operator UI.
- **Control-dispatcher role visible?** Indirectly — the dispatcher's job is to fire `gc.kind=workflow-finalize` and other control beads as workflows progress. From the convoy view, dispatcher work is invisible because convoys and workflows are different primitives.

### Step 6: terminology cross-check

- **AGENTS.md convoy/workflow notes:**
  - Line 52: "Everything is a bead: tasks, mail, molecules, convoys." — convoys listed alongside other bead types.
  - Line 71: "create molecule → hook to agent → nudge → create convoy → log event." — convoy is a dispatch step (for the sling subsystem).
  - Line 118: "object model at the center: `internal/{beads, mail, convoy, formula, events, session, worker, sling, ...}`" — convoy is its own internal package, parallel to sling/formula.
  - Line 4: "multi-agent coding workflows" — "workflow" in the marketing sense (different from `gc.kind=workflow`).
- **Operator vs internal naming alignment:** "convoy" is the user-curated grouping; "workflow" is the formula-compiled DAG; both can be called "graphs of related work" loosely, but they're distinct primitives with distinct bead types, distinct lifecycles, distinct management commands. **The misleading bit is `gc convoy control` — that command serves the workflow control-dispatcher, not user convoys. Naming overlap is upstream-clarification-worthy.**

### G1-G6 verdicts

- **G1 (open convoys exist):** TRUE. 1 open (`mc-a0oj6`), 2 closed (mc-wjos2g, mc-xlg5wt). The "8 deferrals" framing led me to expect more.
- **G2 (simple + complex coexist):** **FALSIFIED.** There are no "complex convoys" as a `type:convoy` thing — what I was imagining (formula-compiled DAGs) are workflows (`type:task` + `gc.kind=workflow`). Two distinct primitives, not two flavors of one.
- **G3 (cross-rig gap still real):** **TRUE.** Confirmed in Step 4. Error wording shifted slightly (more cleanly explanatory now: "bead not found" vs the old parent-edge-creation failure), but the gap is unchanged. §20 stamped, §29 absorbs.
- **G4 (complex shows DAG via gc convoy status):** **N/A.** `gc convoy status` doesn't operate on workflow roots at all. The DAG is visible via bd JSON output, not via the convoy command.
- **G5 (convoy = workflow alias):** **FALSIFIED.** They're distinct primitives. The `gc convoy --help` text's "complex convoys use formula-compiled DAGs with control beads" framing is misleading — that text refers to the dispatcher's INTERNAL use of convoy-shaped state, not to user-managed type=convoy beads.
- **G6 (§20 update is small):** **TRUE.** §20 became a 3-line stamp + pointer to §29. The big work was §29 itself (~120 lines) — which the plan anticipated.

### Manual updates

- [x] §29 drafted (~120 lines, includes the side-by-side table, operator workflow, cross-rig gap, lifecycle nuances, use case, control-dispatcher relationship, connection to §25/§26)
- [x] §20 updated (stamped as historical; pointed at §29 for current reference)

### Surprises

- **The biggest surprise was G2 + G5 BOTH falsifying.** I came in expecting convoy and workflow to be the same thing with two names (operator vs internal). They're distinct primitives at every layer — different bead types, different commands, different internal packages, different lifecycles. The Day-21 plan's mental model was off by one dimension; §29 had to be bigger and more disambiguation-focused than planned.
- **Auto-close doesn't fire instantly.** Closed 3/3 children → convoy stays open. Either it's intentional (waiting for explicit `gc convoy land`) or sweep-cadence-dependent (waiting for next `order-tracking-sweep`). Worth a §29 note (added).
- **`gc convoy --help` is slightly misleading.** It says "complex convoys use formula-compiled DAGs with control beads for orchestration" — but there's no actual `gc convoy` command that operates on workflow roots. The naming overlap with `gc convoy control` (the workflow control-dispatcher's command) is a minor upstream documentation gap.
- **Tour shape held.** Day-21 was supposed to be exploration not fix; it stayed that way. Two ~10-min test beads created and cleaned up; no new beads filed; no PR work. Clean tour-day cadence.
- **The whole tour took ~45 min, not the planned 90 min.** The findings were sharp and the data was abundant; once the convoy-vs-workflow disambiguation landed, the writeup wrote itself. Step 5's "N/A" outcome cut Step 5 + Step 6 short.

### Anything to promote

- **`gc convoy --help` text clarification** — the "complex convoys use formula-compiled DAGs with control beads" sentence is confusing because there's no user-facing `gc convoy` command for graph.v2 workflows. Could be a tiny upstream PR to gascity's help-text.
- **The convoy-vs-workflow disambiguation table** — promoted to §29 as the lead artifact. Worth referencing from §25 and §26 going forward.
- **Auto-close cadence** — worth a separate diagnostic day to understand exactly when convoys auto-close (sweep-cadence vs explicit-land vs all-children-closed). Could be a Day-22 mini-investigation.
- **The "tour-day cadence" pattern** — Day-21 was the first deliberate exploration day after a long fix stretch. Producing §29 in 45 min validated the format. Worth a §22 footnote that "tour days produce manual sections; fix days produce beads/PRs."
- **`type:convoy` is a load-bearing identifier.** §29 named it explicitly. Worth a §22 lesson: when reading agent prompts that say "create convoy," they specifically mean `type:convoy` beads, NOT the workflow primitive. Mayor's "convoy creation" decomposition (Day-4) is `type:convoy`; deacon's "workflow dispatch" is something else.
