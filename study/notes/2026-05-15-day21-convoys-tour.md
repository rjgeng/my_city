# Day 21 — Convoys tour (6+ deferrals overdue)

- **Plan authored:** 2026-05-13 (evening, after Day-20 closure)
- **Planned execution:** 2026-05-15
- **Status:** Plan only

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

- `gc convoy list` count + sample:
- mc-wjos2g detail status:
- Children visible via label query:

### Step 2: convoy code recon

- Files in cmd/gc/cmd_convoy*.go:
- Internal package location:
- Recent commits (v1.1.0..HEAD) affecting convoys:

### Step 3: simple convoy worked example

- Convoy created:
- Three child beads:
- `gc convoy status` output after creation:
- After children closed:
- `gc convoy land` outcome:

### Step 4: cross-rig parent gap test

- HQ convoy bead:
- Rig child bead:
- `gc convoy add` outcome:
- **Outcome bucket:** A (still fails) / B (succeeds) / C (different error):
- Reasoning:

### Step 5: complex convoy observation

- Example workflow root (cs-tc6zhp or mc-1r8kbz):
- `gc convoy status` output:
- DAG visible? (G4):
- Control-dispatcher role visible?

### Step 6: terminology cross-check

- AGENTS.md convoy/workflow notes:
- Operator vs internal naming alignment:

### G1-G6 verdicts

- G1 (open convoys exist): 
- G2 (simple + complex coexist):
- G3 (cross-rig gap still real):
- G4 (complex shows DAG):
- G5 (convoy = workflow alias):
- G6 (§20 update is small):

### Manual updates

- [ ] §29 drafted (~80-120 lines)
- [ ] §20 updated (stamp or rewrite)

### Surprises

(things this plan got wrong, or new things surfaced)

### Anything to promote

(filled in after the day)
