# Gas City + Gastown Multi-Rig Setup & Recovery Guide

Date: 2026-05-08

Purpose: This guide documents the full working setup process for:

- Gas City
- Gastown
- Multiple rigs
- Codex + Claude mixed providers
- Beads recovery/debugging
- Supervisor/session recovery

This serves as a future recovery and reference manual.

---

# 1. Architecture Mental Model

Hierarchy:

```text
Gas City
  = runtime/controller/supervisor

Gastown
  = multi-agent workflow pack

Rigs
  = attached repos/projects

Beads
  = task graph / ticket database

Dolt
  = database engine behind Beads
```

Practical hierarchy:

```text
Dolt < Beads < Gastown < Gas City
```

---

# 2. Working Final Topology

Current (since 2026-05-09 inversion — see §9):

```text
~/my-city
  ├── co_store
  │     └── polecat: Codex (scoped patch)
  │     └── all other agents: Claude (workspace default)
  │
  └── co_shipping
        └── all agents: Claude (workspace default)
```

---

# 3. Install Versions

Verified working versions:

```bash
bd version
# bd version 1.0.3 (Homebrew)

gc version
# 1.1.0

codex --version
# codex-cli 0.128.0

claude --version
# Claude Code 2.1.131
```

---

# 4. Create City

```bash
gc init ~/my-city
```

Selections:

```text
Template: gastown
Agent: Codex CLI
```

Important: Even if installer prints:

```text
Installing hooks (Claude Code)
```

that does NOT mean Claude became the default provider.

The city provider is determined by:

```toml
[workspace]
provider = "codex"
```

---

# 5. Create Rigs

## co\_store

```bash
mkdir -p ~/co_store
cd ~/co_store
git init
```

## co\_shipping

```bash
mkdir -p ~/co_shipping
cd ~/co_shipping
git init
```

---

# 6. Initialize Beads Properly (Critical)

For a brand-new rig (no `.beads/` yet), the right command is just `bd init --prefix <p>`. Don't pre-empt it with `rm -rf .beads` — there's nothing to remove, and the habit teaches you to reach for the destructive option first.

## Standard process (fresh rig)

### co\_store

```bash
cd ~/co_store
bd init --prefix cs
```

Answers:

```text
Change role? → n
Enable auto-export? → n
```

Verify:

```bash
bd create "Test co_store bead"
bd list
```

### co\_shipping

```bash
cd ~/co_shipping
bd init --prefix ship
```

Verify:

```bash
bd create "Test co_shipping bead"
bd list
```

## Recovery (existing `.beads/` is broken)

If a rig already has a `.beads/` and it's corrupted or otherwise broken, follow bd's own guidance — back up first, then re-init in place. `bd init` will refuse to overwrite an existing store and tell you exactly what to do:

```bash
cd ~/<rig>
bd export > backup.jsonl   # back up first
bd init --force --prefix <p>   # re-init in place
bd import < backup.jsonl   # restore beads if you want them back
```

`rm -rf .beads && bd init --prefix <p>` is the **last-resort** form — use it only when `bd export` itself fails (database file is unreadable, lockfile is wedged, etc.). It throws away history irrecoverably; prefer the export → `--force` path above.

---

# 7. Gas City-Compatible Beads Config

The canonical key is **`issue_prefix`** (snake_case). That's the one bd reads:

```bash
$ bd config get issue_prefix
cs
$ bd config get issue-prefix
(not set)
```

Earlier guidance in this manual recommended writing both `issue_prefix` and `issue-prefix` side by side. That was a workaround for a transient bd 1.0.3 behavior we hit during initial setup; it isn't a Gas City requirement. The dash form is unread by `bd config` and can be safely omitted from new rigs (and removed from existing ones during cleanup).

Working config example:

## \~/co\_store/.beads/config.yaml

```yaml
issue_prefix: cs
dolt.auto-start: false
gc.endpoint_origin: inherited_city
gc.endpoint_status: verified
types.custom: molecule,convoy,message,event,gate,merge-request,agent,role,rig,session,spec,convergence
```

## \~/co\_shipping/.beads/config.yaml

```yaml
issue_prefix: ship
dolt.auto-start: false
gc.endpoint_origin: inherited_city
gc.endpoint_status: verified
types.custom: molecule,convoy,message,event,gate,merge-request,agent,role,rig,session,spec,convergence
```

> Note: `types.custom` lists Gas City's twelve custom bead types (convoy, message, session, molecule, etc.). It's installed into each rig by `gc rig add` / `gc doctor --fix`; you don't author it by hand. If `bd create` reports `invalid issue type: convoy` or similar, the `types.custom` line is missing — run `gc doctor --fix --verbose` to repair it (see §11).

If `bd create` ever reports `issue_prefix config is missing`, the rig's `.beads/config.yaml` is missing the `issue_prefix` line entirely — set it (`bd config set issue_prefix <p>`) rather than re-adding the dash form.

---

# 8. Attach/Adopt Rigs

```bash
cd ~/my-city

gc rig add ~/co_store --adopt
gc rig add ~/co_shipping --adopt
```

If prefix collisions happen:

```bash
gc rig add ~/co_shipping --adopt --prefix ship
```

---

# 9. Per-Rig Provider Override

The workspace `provider` in `city.toml` is the city's default. To run one named agent in one rig on a different provider, add a `[[rigs.patches]]` block inside that rig.

Current working config (inverted on 2026-05-09 — see "Topology history" at end of section):

```toml
[workspace]
provider = "claude"

[[rigs]]
name = "co_store"
[[rigs.patches]]
agent = "polecat"
provider = "codex"

[[rigs]]
name = "co_shipping"
prefix = "ship"

[[rigs]]
name = "hello-world"
```

Resolved provider per agent:

```text
co_store/polecat    → codex     (scoped patch)
co_store/refinery   → claude    (inherits workspace)
co_store/witness    → claude    (inherits workspace)
co_shipping/*       → claude    (inherits workspace, no patch)
hello-world/*       → claude    (inherits workspace, no patch)
mayor, deacon, boot → claude    (city-scope, inherit workspace)
```

## Patch scope (important)

`[[rigs.patches]]` overrides **only the agent named in `agent = "..."`** — nothing else. The patch above with `agent = "polecat"` overrides the polecat in `co_store`. It does NOT cascade to that rig's refinery, witness, or any other agent. Every unpatched agent — refinery (merges), witness (status), mayor/deacon/boot (city-scope coordinators), dog (handoff) — inherits the workspace `provider`.

This means: **the workspace provider is the city's reliability floor.** If the workspace provider rate-limits or goes down:

- The merge pipeline goes down on every rig (refinery is workspace-default unless individually patched).
- The supervisor agents (mayor, deacon, boot) go down — coordination stalls.
- Every unpatched polecat goes down too.

A scoped polecat patch onto a different provider does NOT shield the rig from a workspace-provider outage. The rig's refinery still inherits the workspace default and the merge step still fails when the workspace provider does. We learned this the hard way on day 3 (see "Topology history" below).

Practical consequence: choose the workspace provider for **headroom and reliability**, not just preference. Use the per-rig patch for opt-in experiments — that's what we use the codex patch for now (running an A/B between codex and the rest of the city on claude).

## Topology history

Original setup (2026-05-07): workspace `codex`, scoped patch `co_shipping/polecat → claude`. The intent was to use codex (ChatGPT Plus) as the workspace floor and A/B claude on one rig's implementer.

Inverted on 2026-05-09 after a codex usage limit on the ChatGPT Plus tier stalled the **entire** merge pipeline — including the merge for `co_shipping/ship-6a2kf`, even though that rig's *polecat* was correctly running on claude. The refinery (co_shipping/refinery) was still on codex via workspace inheritance and couldn't process the merge until codex unblocked. Workspace was switched to claude (Max Pro headroom is materially higher), and the patch was moved to `co_store/polecat → codex` to preserve the codex/claude A/B intent with the more reliable provider as the workspace floor.

---

# 10. Major Failure Encountered

Symptoms:

```text
invalid issue type: convoy
invalid issue type: session
issue_prefix config is missing
```

Root cause:

- broken inherited Beads stores
- missing Gas City custom issue types
- corrupted prefix config

---

# 11. Critical Repair Command

THIS fixed the custom issue types:

```bash
cd ~/my-city
gc doctor --fix --verbose
```

Important success indicators:

```text
custom-types:city — all 12 required types registered
custom-types:co_store — fixed
custom-types:co_shipping — fixed
```

This repaired:

```text
convoy
session
```

issue types.

---

# 12. Controller Ownership Recovery

The supervisor or controller can wedge in two distinct ways:

1. **Adoption hang** — `gc start` prints `Adopting sessions...` and never returns.
2. **Reload refused** — `gc reload` returns `Reload request could not be accepted because the controller is busy`. This happens when the controller is locked on a stuck session (e.g. a polecat retrying against a rate-limited provider, or any session that can't make forward progress).

There's an escalation ladder. Use the lightest tool that works.

## Level 1 — `gc reload`

Picks up config changes (e.g. an edit to `city.toml`) without disturbing running sessions. Lightest disruption — sessions and conversational state survive.

```bash
cd ~/my-city
gc reload
```

If this prints `controller is busy`, the controller is wedged on something — escalate to level 2. Don't retry `gc reload` in a loop; the controller won't unstick on its own.

## Level 2 — `gc restart`

Stops all agent sessions and starts them again under the same controller. Drops the supervisor association — `gc status` afterwards will show `Controller: standalone-managed` rather than `supervisor-managed`. Beads, worktrees, and your code on disk all survive (gastown is bead-tracked, not session-tracked).

```bash
gc restart
```

What it kills: every active tmux session — mayor, deacon, boot, witnesses, refineries, dog, any in-flight polecats. Open beads will be re-discovered by the new sessions on startup and picked up where they left off.

If `gc status` now shows `standalone-managed`, escalate to level 3 to hand ownership back to the supervisor.

## Level 3 — `gc stop && gc start`

Full ownership cycle. Unregisters the city, then re-registers it and re-attaches to the machine-wide supervisor.

```bash
cd ~/my-city
gc stop /Users/rfvitis/my-city
gc start /Users/rfvitis/my-city
```

`gc stop` may itself fail with `reconcile queue is busy; try again shortly` — that's tolerable if `gc start` then succeeds, which usually happens because `gc stop` restores the registration on failure (so the city is in a consistent state for `gc start` to take it).

## Desired end state

```text
Controller: supervisor-managed
```

If `gc status` reports anything else after a full level-3 cycle, escalate to deacon (mail) or check `gc doctor --fix --verbose` (§11) — the controller may be in a state that needs surgical repair rather than a restart.

---

# 13. Successful Final Dispatch

Two terms appear here for the first time — define them before reading the example.

**`gc sling`** — Routes a unit of work to a session config or agent. The first argument is the target (an agent qualified name like `<rig>/<agent>`); the second is one of: an existing bead ID, a formula name (with `--formula`), or arbitrary task text (which `gc sling` auto-files as a task bead before routing). Source: `gc sling --help`.

**Auto-convoy** — When `gc sling` files a new bead, by default it also creates a `convoy`-typed bead and links the work bead to it as a parent-child relationship. A convoy is a container for related work; when all its child beads close, the convoy auto-closes too. This is the same convoy mechanism documented in Tutorial 06 (`study/gascity-src/docs/tutorials/06-beads.md` §"Convoys"). Pass `--no-convoy` to skip the wrapper. Pass `--owned` to mark the convoy as owned (it skips auto-close, and you land it explicitly with `gc convoy land <id>`).

## Claude rig

```bash
cd ~/my-city

gc sling co_shipping/gastown.polecat "Create a Claude rig README test"
```

Successful output:

```text
Created ship-zs4
Auto-convoy ship-4on
Slung ship-zs4 → co_shipping/gastown.polecat
```

Reading the output:

- `Created ship-zs4` — `gc sling` filed a new task bead in `co_shipping`'s store with prefix `ship`
- `Auto-convoy ship-4on` — and wrapped it in convoy `ship-4on` (the convoy is itself a bead, type `convoy`, and `ship-zs4`'s `ParentID` points at it)
- `Slung ship-zs4 → co_shipping/gastown.polecat` — set `metadata.gc.routed_to = co_shipping/gastown.polecat` on the bead so the polecat pool reconciler picks it up

And agents finally started:

```text
9/20 agents running
```

Including:

```text
gastown.mayor running
co_shipping/gastown.furiosa running
```

`9/20` is running / max-possible — the max counts every on-demand polecat slot across rigs, so single-digit running is normal at rest (deacon's "Idle Town Principle").

---

# 14. Core Commands

## Status

```bash
gc status
```

## Dispatch work

```bash
gc sling co_store/gastown.polecat "task"

gc sling co_shipping/gastown.polecat "task"
```

## Inspect beads

```bash
cd ~/co_store
bd list
bd show cs-xxx
```

## Repair city

```bash
gc doctor --fix --verbose
```

## Restart ownership

```bash
gc stop /Users/rfvitis/my-city
gc start /Users/rfvitis/my-city
```

---

# 15. Corrected Final Topology and Rig Layout

Important correction discovered after deeper inspection:

The sibling rig layout is VALID and intentional.

Final actual topology:

```text
~/my-city
    = Gas City runtime / orchestration workspace

~/co_store
    = external sibling rig (Codex default)

~/co_shipping
    = external sibling rig (Claude override for polecat)

~/my-city/hello-world
    = nested tutorial/demo rig
```

Important clarification:

Earlier debugging mistakenly assumed:

```text
co_store
co_shipping
```

were broken or homeless rigs because they were outside the city directory.

That conclusion was incorrect.

Gas City supports BOTH layouts:

## Nested rig layout

Example:

```text
~/my-city/hello-world
```

This is the tutorial/demo style.

## External sibling rig layout

Example:

```text
~/co_store
~/co_shipping
```

This is a valid professional multi-repo layout.

Advantages:

- independent git repositories
- independent remotes
- easier long-term scaling
- cleaner separation between runtime and repos
- rigs remain independently cloneable/shareable

The following files confirmed the sibling layout was correct:

```text
.gc/site.toml
.beads/routes.jsonl
city.toml
```

Routes correctly resolved:

```text
cs    → ../co_store
ship  → ../co_shipping
hw    → hello-world
```

Therefore:

```text
No rig path problem actually existed.
```

The real issues were:

- corrupted/incompatible .beads stores
- missing custom issue types
- controller/session reconciliation

NOT the sibling-rig architecture itself.

The scoped multi-provider pattern has been a legitimate configuration shape from the beginning — workspace default plus per-rig `[[rigs.patches]]` for one-rig experiments.

The original arrangement (2026-05-07) was workspace `codex` with `co_shipping/polecat → claude` patched. On 2026-05-09 it was inverted to workspace `claude` with `co_store/polecat → codex` patched, after a codex usage limit revealed that `[[rigs.patches]]` only covers the named agent — refinery and other unpatched agents still inherit the workspace default, so a workspace-provider outage takes down the merge pipeline city-wide regardless of any polecat patches. See §9 for the current `city.toml` and the architectural rationale.

Either direction of the pattern is correct. The choice of which provider sits at the workspace floor is governed by reliability and rate-limit headroom, not preference.

# 16. Final Understanding

Beads:

```text
low-level task database
```

Gastown:

```text
workflow + agents + orchestration logic
```

Gas City:

```text
runtime + supervisor + controller
```

Practical workflow:

```bash
gc sling ...
```

is preferred daily operation.

Use `bd` mostly for inspection/debugging/manual ticket operations.

---

# 17. Most Important Lessons

1. Plain Beads sanity test repo was critical.
2. Broken inherited .beads stores caused most failures.
3. `gc doctor --fix --verbose` repaired missing custom issue types.
4. Supervisor/session adoption can appear hung but eventually recover.
5. `gc sling` success requires:
   - valid Beads config
   - registered custom issue types
   - working supervisor ownership
   - valid rig adoption
6. Codex/Claude were never the real problem.
7. Most failures came from:

```text
Beads schema/config mismatch
```

not from LLM providers.

---

# 18. Daily Verbs Cheat-Sheet

Four commands cover ~95% of operating this city.

```text
gc sling          → file & dispatch
gc status         → observe
bd list           → inspect
gc doctor --fix   → repair
```

## gc sling — dispatch work

The owner's primary verb. Files a bead, wraps it in an auto-convoy, and routes it to the named agent pool.

```bash
gc sling <rig>/gastown.<agent> "task description"
```

Example (§13):

```bash
gc sling co_shipping/gastown.polecat "Create a Claude rig README test"
```

Output:

```text
Created ship-zs4
Auto-convoy ship-4on
Slung ship-zs4 → co_shipping/gastown.polecat
```

What happens under the hood:

- work bead (`ship-zs4`) filed in the rig's beads (type: task)
- convoy (`ship-4on`) filed as a coordination wrapper — one of the 12 gastown custom types
- `metadata.gc.routed_to = co_shipping/gastown.polecat` set on the bead
- pool reconciler spawns a polecat to claim it

Common targets:

```text
<rig>/gastown.polecat     # implementer (writes code)
<rig>/gastown.refinery    # merge processor (does not write code)
gastown.mayor             # city-scope coordinator (no rig prefix)
```

Use `gc sling` for new work. Use `bd update --set-metadata gc.routed_to=...` only to re-route an existing bead.

---

## gc status — see what the city is doing

Top-level dashboard. Run when adoption finishes, when a session feels stuck, or when you want to confirm the cast is up.

Expect (§13):

```text
9/20 agents running
gastown.mayor running
co_shipping/gastown.furiosa running
...
```

`9/20` = running / maximum-possible. The max counts all on-demand polecat slots; idle is normal (deacon's "Idle Town Principle").

If 0 running but you expect work:

1. open beads? — `bd list` in each rig
2. controller alive? — `gc cities` and `gc doctor`
3. adoption hung? — see §12

---

## bd list — inspect the ledger

Resolves to whichever rig's namespace your shell cwd points to (per `.beads/routes.jsonl`).

```bash
cd ~/co_store
bd list
```

Useful variants:

```bash
bd list --status open
bd list --json
bd show <id>
bd show <id> --json | jq '.[0].metadata'
```

Status glyphs:

```text
○ open   ◐ in_progress   ● blocked   ✓ closed   ❄ deferred
```

Use `bd list` to inspect, never to dispatch. Dispatch is `gc sling`'s job.

---

## gc doctor --fix --verbose — repair config drift

The recovery sledgehammer. Runs all doctor checks, applies safe automatic fixes, and prints what it did.

```bash
cd ~/my-city
gc doctor --fix --verbose
```

Repairs (§11):

- missing custom issue types per rig (the 12 gastown types: molecule, convoy, message, event, gate, merge-request, agent, role, rig, session, spec, convergence)
- prefix-config drift between `issue_prefix` and `issue-prefix`
- minor config-semantic problems

Does NOT repair:

- corrupt Dolt store → `bd export > backup.jsonl && bd init --force --prefix <p>`
- supervisor adoption hang → §12
- broken rig path bindings → edit `.gc/site.toml` or re-run `gc rig add .` from inside the rig

Try this first whenever anything misbehaves. Most config drift heals here.

---

## When to reach beyond the four

| Need | Verb |
|------|------|
| Restart the city | `gc stop <path> && gc start <path>` |
| Rebuild a corrupt store | `bd export > backup.jsonl && bd init --force --prefix <p>` |
| Add a new rig | `cd <repo> && gc rig add .` |
| Remove a rig | edit `city.toml` (and `.gc/site.toml` if needed), then `gc doctor` |

Keep this page bookmarked.

---

# 19. Polecat → Refinery Merge Workflow

The implicit handoff between polecat (work-producer) and refinery (work-merger) is the single most surprising thing in gas-town's daily operation. Misunderstanding it strands beads in `OPEN` state with their work already done.

## What polecat actually does

A polecat session in a rig:

1. Claims a ready non-gate bead from its rig's queue.
2. Does the work — checks out a branch, writes code, commits.
3. Writes NOTES on the bead documenting what shipped.
4. **Drains** — exits cleanly. Does *not* close the bead.

Polecat **never closes its own beads.** Earlier mental models where polecat marks work "done" were wrong.

## What refinery actually does

A refinery session in the same rig:

1. Patrols (slow cadence) or wakes on explicit nudge.
2. Discovers branches ahead of `main` with closure-ready metadata.
3. Fast-forwards (or merge-commits for non-FF), records `merged_commit` on the bead.
4. Closes the bead with full merge metadata.

So refinery does **both the merge and the close**. The polecat → refinery boundary is a clean producer/consumer split, but it's not visible in any individual bead — it's inferred from the branch state ahead of `main`.

## The "nudge refinery" pattern

Refinery's natural patrol cadence is slow (often >15 min between sweeps). When you've drained a polecat and want immediate merge:

```bash
gc session nudge co_auth/gastown.refinery "<bead-id> complete on <branch> — please merge"
```

This is the reliable trigger after polecat drains. Without it, completed work can sit unmerged for an entire patrol cycle.

## Mayor's `PAUSE for Gn` spec anti-pattern

If mayor writes a bead spec that says **"Then STOP. Gate Gn reviews this work…"**, polecat reads "STOP" literally and skips its own closure step. The branch lands, but the bead never enters refinery's discovery set. Work strands.

**Don't write:** `"Implement X. Then STOP and wait for auth-G2 review."`

**Write instead:** `"Implement X. Close the bead normally when work is committed. Downstream beads remain blocked until auth-G2 is closed by a reviewer."`

Polecat is doing exactly what mayor told it to. The fix is in mayor's prompting, not in polecat behavior.

---

# 20. Cross-Rig Convoy Gap

Convoys filed in HQ (`mc-*` prefix) cannot directly parent beads from different rigs (e.g., `auth-1` and `cs-3` can't both be children of `mc-X`). `gc convoy add` fails the parent-edge creation between HQ and a rig-prefixed bead.

**Workaround** (codified in memory `project_cross_rig_convoy.md`): use a label-based soft-link. Tag each rig-local child bead with `convoy:mc-XXX`:

```bash
gc bd label add auth-1 convoy:mc-wjos2g
gc bd label add cs-3   convoy:mc-wjos2g
```

The convoy bead lives in HQ; the children stay in their respective rigs. `gc convoy land` works fine on the HQ convoy despite the parent gap — the land operation doesn't require parent edges, only the convoy bead's own readiness.

Use the label-based soft-link pattern until first-class cross-rig convoys ship.

---

# 21. Local Rig Development After a Cascade

When you `git clone` a rig — or `git reset --hard origin/main` to recover from a long automated session — two things commonly go wrong before the demo will run.

## Local-repo vs origin desync

After polecat × refinery cascades, the local rig's `main` can be ahead of `origin/main`, behind, or diverged. The local repo is **not** trustworthy by default. Before running the demo:

```bash
cd ~/co_auth
git status
git log --oneline main origin/main | head -10
# if diverged or ahead, decide:
git reset --hard origin/main   # discard local-only commits
# or
git push                       # publish them
```

## Bootstrap after clone

Frameworks like Next.js + Prisma generate gitignored artifacts at install time. After a fresh clone (or hard-reset), those artifacts are absent and the app won't boot. Re-create them:

```bash
cd ~/co_auth
npm install
npx prisma generate            # regenerate the gitignored client
npx prisma migrate deploy      # apply migrations to a fresh dev.db
npm run dev
```

Polecats writing a demo's README should bake these steps into the bootstrap section. The README is **the** contract with a future cloner.

---

# 22. Debugging Pack Scripts and Cross-Pack Conventions

## Silent failure via `2>/dev/null`

Pack scripts swallow stderr to keep supervisor logs clean. When something legitimately breaks, the real error vanishes. The Day-5 JSONL triage spent its first investigation steps chasing a misleading symptom (`exported 0/3, failed: cs hq ship`) because the actual error (`fatal: 'origin' does not appear to be a git repository`) was swallowed by `2>/dev/null` on the offending `git push`.

**Diagnostic technique:** when a pack script reports a vague status (`push: failed`, `exported 0/N`), reproduce the underlying operation manually outside the script. Re-run the same `git push` or `dolt sql` directly with stderr visible:

```bash
# Instead of trusting "push: failed" from the script:
cd <archive-path>
git push origin main           # see the actual error
```

This single move cracked both Day-5 root causes within minutes once applied. If you can't make progress reading a script, run its core operation by hand.

## Pack-script scope ≠ rig scope

A pack script's output may contain rig-name-shaped tokens (`cs`, `hq`, `ship`) without the script actually being rig-scoped. `mol-dog-jsonl` iterates **dolt databases** (city-level construct), not rigs. The names happen to match because each rig owns one dolt database with the rig prefix.

**When debugging a script with a `failed: <list>` output**, check whether the list is rigs (from `gc.config.rigs`) or dolt databases (from `SHOW DATABASES`). They share names but have different lifecycles. The framing influences hypothesis ranking — Day-5's source bead `mc-vj3hjk` framed the issue as rig-local when the real cause was city-level.

## Cross-pack config name conventions

Different packs in `.gc/system/packs/` sometimes hardcode different filenames for shared runtime state. Day-5 example (now tracked as bead `mc-ma23a9`): `dolt-state.json` (used by `maintenance` and `dolt` packs) vs `dolt-provider-state.json` (canonical, written by `bd` pack).

**Cross-pack contract principle:** when a script reads runtime state owned by another pack, query the canonical path via a designated resolver (e.g., `gc dolt-state runtime-layout`) rather than hardcoding the filename. Hardcoded names drift; resolvers don't.

```bash
# Hardcoded — brittle:
STATE_FILE="$CITY/.gc/runtime/packs/dolt/dolt-state.json"

# Resolver-based — survives renames:
STATE_FILE=$(gc dolt-state runtime-layout | awk '/GC_DOLT_STATE_FILE/ {print $2}')
```

# 23. Reconciler Diagnostics via `gc trace`

When the controller feels slow, when the supervisor stderr emits `slow_storage_degraded` warnings, or when `gc shell` lags inside the mayor session, the first instinct is to grep supervisor logs. There's a better tool: `gc trace`. It reads persisted reconciler trace records from `.gc/runtime/session-reconciler-trace/segments/<day>/segment-N.jsonl`, and the relevant analysis is usually a one-shot query against historical data — no city restart, no live reproduction needed.

The upstream debug workflow lives at `study/gascity-src/engdocs/contributors/reconciler-debugging.md`. The points below are the practical takeaways from Day-6's investigation.

## `gc trace` works fully offline

The trace stream is local JSONL written by the controller as it runs. After the controller stops, the data stays on disk and `gc trace show / cycle / status` continue to read it. **Reproduction is rarely required to diagnose reconciler behavior** — just query the segments.

```bash
# Stream summary (head sequence, day directories, arms)
gc trace status

# All cycle_result records over the last 4 days, as JSON
gc trace show --type cycle_result --since 96h --json > /tmp/cycles.json

# Full record list for a specific tick (slow cycles you want to drill into)
gc trace cycle --tick <tick-id-from-cycle_result> --json > /tmp/cycle.json
```

The Day-6 diagnosis (filed as bead `mc-f7u8fz`) was completed entirely from offline trace data — 2900 historical cycle_result records were already on disk before the investigation started.

## `slow_storage_degraded` is a fsync-budget warning, not a storage diagnosis

The stderr line `trace: slow_storage_degraded: <tick-id> Durable` (emitted at `cmd/gc/session_reconciler_trace_collector.go:976`) fires when one `fsync` of a small JSONL append to `.gc/runtime/session-reconciler-trace/segments/...` exceeds **25 ms** (`sessionReconcilerTraceDurableWait = 25 * time.Millisecond` at collector.go:22). That budget is tight vs. macOS APFS `fsync` variance under any concurrent write load (especially dolt commits), so the warning fires noisily and reports nothing actionable about what is actually slow.

**Don't chase the warning. Chase the cycle.** The interesting field is `duration_ms` on `cycle_result` records — that's the real per-tick reconciler latency.

```bash
# Cycle latency distribution, p50/p95/max
gc trace show --type cycle_result --since 24h --json \
  | jq '[.[] | .duration_ms] | sort | length as $n |
        {p50: .[$n/2|floor], p95: .[$n*95/100|floor], p99: .[$n*99/100|floor], max: .[-1]}'
```

If `p50` is over a few hundred ms the reconciler is I/O-bound and `slow_storage_degraded` is a downstream symptom — fix the cycle, not the trace fsync.

## Reconciler cycle anatomy: `cycle_offset_ms` is the waterfall

Every record inside a cycle carries a `cycle_offset_ms` field — the milliseconds since `cycle_start`. Sorting the records of one cycle by that field reproduces the in-cycle waterfall and shows exactly where time was spent.

```bash
gc trace cycle --tick <tick-id> --json \
  | jq -r '.[] | "\(.cycle_offset_ms)ms\t\(.record_type)\t\(.site_code // "")\t\(.fields.reason_code // "")"' \
  | sort -n
```

The typical shape of a non-trivial cycle:

```
+0ms       cycle_start
+0ms       session_baseline   (open_count summary)
+0ms       batch_commit x N   (trace flush from previous cycle)
+Ngap ms   session_baseline   (per-bead burst — the real reconcile body starts here)
+Ngap ms   template_tick_summary x N
+dur ms    cycle_result       (cycle.finish)
```

**The cost almost always lives in the gap** between cycle_start (offset 0) and the per-bead session_baseline burst. That gap corresponds to `CityRuntime.tick()` body — repeated `loadSessionBeadSnapshot()` calls, `syncBeadsAndUpdateIndex` writes, tmux `ListRunning` probes, etc. If the gap dominates the cycle duration, the bottleneck is pre-`beadReconcileTick` I/O; if the tail (after `cycle_input_snapshot`) dominates, it's start/mutation work.

This single shape rule lets you classify a slow cycle in one look at its waterfall.
