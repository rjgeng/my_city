# Day 13 — Orders: tour the city's autopilot

- **Plan authored:** 2026-05-12 (after Day-12 wrap)
- **Planned execution:** 2026-05-13 (or later same day)
- **Status:** Plan only; tour not yet started

This is the pre-decomposition for Day-13: shift fully back to escort-mode learning. After 6 days of investigation (5/6/8/10), 4 days of action (7/9/11/12), and the v2 manual now 25 sections deep, Day-13 explores **a new primitive the user has only seen from outside**: orders.

Per the gascity-src AGENTS.md classification: orders are *"formulas with gate conditions on Event Bus"* — i.e., the scheduling layer on top of the formula primitive. They're what the city runs **on its own**, without any human or agent kicking them off. Day-9's events.jsonl during the gc-start window showed dozens of `order.fired` / `order.completed` events for things like `gate-sweep`, `mol-dog-jsonl`, `orphan-sweep`, `prune-branches`, `digest-generate`, `dolt-health`, `beads-health`. That's the autopilot.

The goal of Day-13: open the hood and explain how that autopilot actually works.

---

## 1. The signal — what orders are

From gascity-src `AGENTS.md`:

> **Formulas & Molecules** — Formula = TOML parsed by Config. Molecule = root bead + child step beads in Task Store. Wisps = ephemeral molecules. **Orders = formulas with gate conditions on Event Bus.**

So an order is a formula (TOML config) plus a scheduling/triggering mechanism that lives on the event bus. Each order fires on some schedule (probably interval or cron-shaped), runs its formula, and emits events back to the bus.

Observable evidence from Day-9's events.jsonl during a single hour:

- `order.fired` / `order.completed` pairs for ~10 distinct order types
- Subjects formatted as `<order-name>:rig:<rig-name>` (e.g., `gate-sweep:rig:hello-world`) — orders are rig-scoped
- Some orders failed (`order.failed: digest-generate:rig:hello-world` was seen in Day-9 logs)
- Cadence appears to be every few minutes, but the exact schedule isn't visible from events alone — we need the order definitions to know

**Open questions Day-13 should answer:**

1. Where do order definitions live on disk? (Probably TOML files in pack directories.)
2. How does an order's schedule get expressed? (Cron string? Interval seconds? Event-trigger predicate?)
3. Who runs orders? (Controller? A dedicated dispatcher? An agent?)
4. What's the failure recovery model? (Retry? Skip? Escalate?)
5. How are results consumed downstream? (Gate transitions? Side-effects only? Both?)
6. What's the full catalog of orders running in *this* city?
7. What problem does each order in the catalog solve?

---

## 2. Pre-flight: where this lives

- **Order definitions probably live in** `.gc/system/packs/<pack-name>/orders/` or similar — to be confirmed in Step 1.
- **Runtime records** are in `.gc/events.jsonl` (the same file we mined for Day-8 / Day-12).
- **`gc order ...` CLI commands** — to be discovered via `gc help`. Likely subcommands: `list`, `show`, `fire`, `disable`.
- **Go-level orchestration** in `study/gascity-src/` somewhere — search for "order" terms in `cmd/gc/` and `internal/`.
- City does NOT need to be running for this. Definitions are static on disk; runtime evidence is in the historical event log. Pure read-only exploration.

---

## 3. What "done" looks like (success criteria)

**Knowledge milestones:**

- Catalog: a complete list of orders running in `my-city` (across all packs and rigs), with a one-line description of each.
- Mechanism: a clear paragraph explaining (a) how a schedule is expressed, (b) who fires it, (c) how it ends.
- One worked example: a single order chosen as the "canonical" example, with its TOML definition, schedule, last few firing events, and purpose all explained.
- Failure model: one paragraph explaining what happens when an order errors out — recovery, escalation, or just-log-and-skip.

**Manual artifact:**

- New v2 manual section: **§25 "Orders: the city's autopilot"** with subsections for (a) what an order is, (b) catalog of orders in this city, (c) lifecycle (fire → run → complete/fail → next-tick), (d) schedule expression, (e) reading order events from `.gc/events.jsonl`, (f) `gc order` CLI commands and their use cases.

**No bead, no PR, no upstream engagement today.** Pure understanding. The deliverable is the §25 section.

---

## 4. Execution plan — read-only tour, narrated step-by-step

Day-13 is escort mode. Each step is preceded by an explanation of *what we're about to look at and why*. No risky actions.

### Step 1: Locate order definitions on disk (~10 min)

```bash
# Probable layout: pack dirs have orders/ subdirs with TOML files
find /Users/rfvitis/my-city/.gc/system/packs -type d -name orders 2>/dev/null
find /Users/rfvitis/my-city/.gc/system/packs -name "*.toml" -path "*/orders/*" | head -20
# Also check whether orders are stored elsewhere — e.g., in the bd database
bd list --type=order --flat 2>&1 | head -20    # if "order" is a recognized type
```

Output: a complete map of where order definitions live. Likely answer: pack-bound TOML files in `<pack>/orders/<name>.toml`, but verify.

### Step 2: Discover `gc order` CLI surface (~5 min)

```bash
gc help 2>&1 | grep -i order
gc order --help 2>&1 | head -30   # if the subcommand exists
gc orders --help 2>&1 | head -30  # alternate spelling
```

Output: list of available subcommands and what each does. Will inform Steps 4-5.

### Step 3: Profile the order traffic in events.jsonl (~10 min)

Mine the event log to characterize order rates:

```bash
F=/Users/rfvitis/my-city/.gc/events.jsonl
echo "=== order.fired by name (top 20) ==="
grep '"type":"order.fired"' "$F" | python3 -c "
import json, sys
from collections import Counter
names = Counter()
for line in sys.stdin:
    try: ev = json.loads(line)
    except: continue
    subj = ev.get('subject','')
    # subj format: '<order-name>:rig:<rig-name>'
    name = subj.split(':rig:')[0]
    names[name] += 1
for n,c in names.most_common(20): print(f'  {c:5} {n}')
"
echo "=== order.failed (all-time) ==="
grep '"type":"order.failed"' "$F" | python3 -c "
import json, sys
for line in sys.stdin:
    try: ev = json.loads(line)
    except: continue
    print(f\"{ev['ts'][:19]} {ev.get('subject','')} {ev.get('message','')[:60]}\")
" | head -10
```

Output: which orders run most, which have ever failed, what their cadence looks like.

### Step 4: Pick one order as the worked example (~5 min)

Use Step 3's data to pick a representative order. Good candidates:

- **`mol-dog-jsonl`** — we already know this one from Day-5 (the JSONL push-failure storm). Closes a learning loop: we know what its symptom looked like; now understand its definition and intended cadence.
- **`gate-sweep`** — sounds central to the convoy/gate machinery, ran frequently in Day-9 events. Good for understanding the gate side of orders.
- **`mol-dog-compactor`** — the dolt compaction order that Day-6 plan §5 mentioned. Relevant to the unresolved `mc-f7u8fz` reconciler I/O question.

**Recommend:** `mol-dog-jsonl`. Closes the Day-5 loop and we have plenty of failure-mode data already.

### Step 5: Read the chosen order's definition end-to-end (~20 min)

```bash
ORDER_FILE=<path-from-Step-1>
cat "$ORDER_FILE"
```

Expected fields (hypothesis, refine after reading):

- `name` / `id` — what this order is called
- `formula` — which molecule formula it executes
- `schedule` — how often it fires (interval seconds, cron string, or event predicate)
- `cooldown` — minimum gap between firings
- `gates` — what conditions must be true before firing
- `on_failure` — what happens if the formula errors out
- `scope` — `rig` vs `city` vs other

For each field that surfaces, write a one-line note explaining what it does. If the field references another file (e.g., a referenced formula or a script), follow the chain one level deep.

### Step 6: Trace one execution of the chosen order through events.jsonl (~15 min)

Pick a recent firing (`order.fired` event), find its `order.completed` (or `failed`) pair, and read all intervening events with the same subject or trace-id. This shows the order's actual runtime behavior — what it touched, what it produced, how long it took.

```bash
# Pick a recent firing
grep '"type":"order.fired"' "$F" | grep "<order-name>" | tail -3
# For the most recent one, get the time window
# Then dump all events in the window
```

Output: a step-by-step trace of one real order execution.

### Step 7: Draft v2 manual §25 (~30 min)

Based on Steps 1-6's findings, write the new section. Subsections:

- **What an order is** — definition + relationship to formulas, molecules, wisps, the event bus.
- **Catalog of orders in this city** — table of name, formula, scope, purpose, observed cadence.
- **Lifecycle** — fire → run → complete/fail → next-tick.
- **Schedule expression** — whatever Step 5 revealed: cron? interval? cooldown? event-triggered?
- **Reading order events** — `grep '"type":"order.fired"' .gc/events.jsonl` patterns, `gc trace`-style introspection if available.
- **`gc order` CLI** — what Step 2 found, with examples.
- **Failure model** — what Step 5's `on_failure` field plus historical `order.failed` events together show.

The Day-5 JSONL push storm (mc-vj3hjk) becomes a natural worked example in the failure-model subsection: an order that kept firing successfully but did no useful work because its underlying script silently fell back.

---

## 5. Things to look for (anticipated learnings to validate or falsify)

Pre-thought hypotheses, ranked by my prior guesses:

**H1: Orders are run by the controller, not by an agent.** The events.jsonl `actor` field on `order.fired` was `controller` in Day-12's data. So the controller is the order dispatcher. Verify in Step 6.

**H2: Schedules are interval-shaped (every N seconds/minutes), not cron-shaped.** Cron expressions are rare in Go-internal scheduling. More likely there's an interval + cooldown model. Verify in Step 5.

**H3: Order failures escalate to mayor via mail.** Day-5's mc-vj3hjk was a wisp-escalator message to mayor's inbox, generated by an order that kept failing. There's probably a generic "if `order.failed` then escalate" wiring. Verify in Steps 5-6.

**H4: There's a `gc orders list` (or similar) command** that gives the catalog without us scraping events.jsonl. Verify in Step 2.

**H5: The "rig:" suffix on order subjects means orders are duplicated per rig.** Day-12 saw `gate-sweep:rig:hello-world` AND we'd expect `gate-sweep:rig:co_store`, etc. So a single order definition fans out across rigs. Verify in Step 3.

If H1-H5 all check out cleanly, Day-13 is a pure tour. If any falsify, there's a §22-style premise-correction note to write.

---

## 6. Risk / blast radius

Zero. All steps are read-only:

- File listings, `cat`, `grep`
- `bd list --type=order` (read-only)
- `gc help`, `gc order --help` (read-only CLI introspection)
- Events.jsonl mining (read-only)
- v2 manual edit (gitignored notes file at most → committed locally, not pushed to upstream)

City does NOT need to be running. No agents spawned. No beads created. No upstream PRs or issues filed.

---

## 7. Connection to prior days

- **Day-5 (`mc-vj3hjk`)** was triggered by `mol-dog-jsonl`'s repeated failures. Day-13 reads that order's definition for the first time — closes the loop.
- **Day-6** mentioned `mol-dog-compactor` as a fix candidate for reconciler I/O pressure. Day-13 examines whether it's currently scheduled and what it does.
- **Day-7's pack-script fix** affected scripts that orders invoke (`dolt-target.sh`, `runtime.sh`). Day-13 sees the calling-context for those scripts.
- **Day-9's `gc start`** produced dozens of order events visible in events.jsonl. Day-13 interprets what those events meant.
- **Day-12's upstream surfaces** are passive (PR #2037, comment on #1487). Day-13 doesn't touch them.

---

## 8. Adjacent work to fold in

Lightweight today-actions:

- **Daily check on PR #2037 + comment on #1487 status.** Once per day per Day-11 §4 Step 3. Passive observation only.
- **If a Day-13 finding surfaces a real bug** (e.g., a misconfigured order, a script-order mismatch), file it in HQ as a P3 bead. Don't engage upstream same-day.

Soon (Day-14+):

- If Day-13's tour surfaces interesting questions about a specific order (e.g., "why is `mol-dog-compactor` not running often enough to prevent the reconciler I/O issues?"), Day-14 could go deeper into that one.
- Alternative Day-14: the **convoys tour** the user declined today, now informed by orders knowledge (since orders and convoys both rely on gates).

---

## 9. Optional: mayor handoff

Skip. This is a personal learning tour. Mayor orchestration would only obscure direct observation.

---

## 10. Execution log

Executed 2026-05-12, same session as plan authoring. All six investigation steps + §25 drafted in one pass.

### Pre-flight outcomes

- **Order definition layout (Step 1):** flat TOML files at `.gc/system/packs/<pack>/orders/<name>.toml`. 19 orders across 4 packs — core (1), gastown (1), maintenance (9), dolt (8). All 7 event-bus order names seen in Day-9 logs are present on disk. `bd` has no `order` type — beads is the wrong registry.
- **`gc order` CLI surface (Step 2):** six subcommands — `list`, `show`, `check`, `history`, `run`, `sweep-tracking`. `list` is the canonical catalog (matches Step 1's filesystem walk and adds trigger/interval/rig/target columns). `history` reads from beads (city-up only); `check` evaluates live triggers. `gc order help` prose announces 5 trigger flavors (`cooldown / cron / condition / event / manual`).
- **Order traffic profile (Step 3 top-N by name):** Across 2026-05-07 to 2026-05-12 (~8% wall-clock uptime): gate-sweep 5890, order-tracking-sweep 4199, beads-health 1871, dolt-health 1793, cross-rig-deps 1340, orphan-sweep 1323, spawn-storm-detect 1314, mol-dog-jsonl 517, mol-dog-reaper 277, wisp-compact 148, dolt-remotes-patrol 128, prune-branches 45, dolt-gc-nudge 36, digest-generate 17, mol-dog-compactor 4, mol-dog-backup 2, mol-dog-doctor 1, mol-dog-phantom-db 1. Total order events: 37,811 fired+completed+failed. 62 failures, 11 of which were the 2026-05-12T08:55-08:57 shutdown-burst cancellations.

### Worked example

- **Chosen order:** `mol-dog-jsonl` (per plan §4 Step 4 recommendation; closes Day-5 mc-vj3hjk loop).
- **Definition file path:** `.gc/system/packs/maintenance/orders/mol-dog-jsonl.toml`.
- **Fields in the TOML:** only four — `description`, `exec` (script path), `trigger = "cooldown"`, `interval = "15m"`. No `formula`, no `gates`, no `on_failure`, no `scope`, no `pool`.
- **Schedule expression:** `cooldown` trigger with `interval = "15m"`. The script invoked is `$PACK_DIR/assets/scripts/jsonl-export.sh` (719 lines) — runs inline in controller process.
- **Most recent firing trace (Step 6 summary):** Pair on 2026-05-12 — fire at 08:41:23.492, completion at 08:44:28.229 (~3m05s wall), both `actor=controller`, `subject=mol-dog-jsonl:rig:co_auth`. **Zero intermediate events** emitted by the order itself; the 930 events observed in the 3-minute window were concurrent activity from other orders (gate-sweep 6×, order-tracking-sweep 3×, orphan-sweep 1×) plus rig-local bead operations.

### H1-H5 verdicts

- **H1 (controller dispatches orders):** **CONFIRMED.** 100% of 37,811 order events have `actor=controller`. No agent ever fires an order.
- **H2 (interval schedules, not cron):** **PARTIALLY FALSIFIED.** 18/19 orders use cooldown, but `mol-dog-stale-db` uses cron `0 */4 * * *`. The trigger menu also includes `condition`, `event`, `manual` — 5 flavors total, not 1. Mental model "all interval" was wrong in principle.
- **H3 (failures escalate to mayor via mail):** **CONFIRMED with structural correction.** Escalation IS per-exec-script logic (e.g., jsonl-export.sh:329-333 fires `gc mail send mayor/` after 3 consecutive failures), NOT a unified order-layer policy. The order layer has no `on_failure` field. This is a §22-style premise correction promoted to §25.
- **H4 (`gc orders list` exists):** **CONFIRMED.** Singular: `gc order list`.
- **H5 (orders fan out per-rig):** **CONFIRMED with per-order nuance.** Maintenance pack orders + `digest-generate` fan out across all 5 rigs (6 catalog rows each — 1 city-scope + 5 rig-scope). Dolt mol-dogs and core `beads-health` are city-scope only.

### v2 manual §25 added

- [x] What an order is — bifurcation into exec / formula flavors; controller as sole dispatcher
- [x] Catalog of orders in this city — table by pack, with cadence + 5-day fire counts
- [x] Lifecycle — fire → run → complete/fail → next-tick, with the "no intermediate events" observation
- [x] Schedule expression — five trigger flavors per help text, 18/19 cooldown in practice
- [x] Reading order events — three surfaces (events.jsonl / gc order history / gc order check), each with limits; "fourth lens = side effects" added
- [x] `gc order` CLI — six subcommands with use cases
- [x] Failure model (with mc-vj3hjk as worked example) — full reconstruction of the Day-5 escalation chain in light of §25's mental model

Section added at v2 manual lines 1225-1419 (194 lines).

### Surprises

Things this plan got wrong, or new things surfaced:

1. **Orders bifurcate into exec / formula flavors.** Plan implicitly assumed all orders were formula-flavored ("formulas with gate conditions on Event Bus" from AGENTS.md). Reality: 14 exec + 5 formula. Exec orders run inline in the controller — no wisp, no agent, no chat history. This is the single most useful new mental model from Day-13.
2. **The TOML field set for a real exec order is much sparser than the plan's hypothesized field list.** mol-dog-jsonl.toml has only 4 keys; the plan listed 7 expected fields (`name`, `formula`, `schedule`, `cooldown`, `gates`, `on_failure`, `scope`) — 5 of which don't exist for exec orders. Scope and failure handling are implicit.
3. **The event bus is intentionally outline-only.** No intermediate events during a run. For exec orders, the work product lives entirely in side effects (state files, git commits, mail sent by the script). This wasn't in the plan's mental model.
4. **`gc order history` requires Dolt running.** Plan assumed events.jsonl + bead history were both passive-readable. In practice, history is city-up only; events.jsonl is the city-down fallback.
5. **`digest-generate` apparent 100% failure rate** (17 fired / 17 failed across 5 days). Surfaced incidentally; not investigated today. Real candidate for Day-14+ bead filing.

### Anything to promote to v2 manual (beyond §25)

Nothing additional today. §25 absorbed every insight cleanly:

- The exec / formula bifurcation lives in §25 "What an order is."
- The per-exec-script escalation pattern (and its premise correction against H3) lives in §25 "Failure model."
- The "three observability surfaces, each with limits" table lives in §25 "Reading order events."
- The fourth-lens-is-side-effects mental model is in the same subsection.

§24 (upstreaming) and §22 (debugging pack scripts) are the natural cross-references — neither needed an amendment based on Day-13 findings.

### Items deferred to Day-14+

- **`digest-generate` 100%-fail anomaly.** Diagnose root cause; consider filing as a P3 bead if it's a real bug, or write up as a §22-style premise correction if it's a misconfiguration on our side.
- **Convoys tour.** The Day-13 plan deferred the convoys tour the user had declined earlier. Day-13 surfaced that orders and convoys both rely on gates — convoys tour is now better-informed.
- **Sample one mol-dog-jsonl state file** (`.gc/runtime/packs/maintenance/jsonl-export-state.json` or similar) to round out the "side effects = the work product" observation with a concrete example. Low priority.
