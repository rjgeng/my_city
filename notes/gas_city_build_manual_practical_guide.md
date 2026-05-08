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

```text
~/my-city
  ├── co_store
  │     └── Codex provider
  │
  └── co_shipping
        └── Claude Code provider override
```

---

# 3. Install Versions

Verified working versions:

```bash
bd version
# bd version 1.0.3 (Homebrew)

gc version
# 1.0.0

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

This became the main debugging issue.

Do NOT rely on inherited broken .beads stores.

Correct process:

## co\_store

```bash
cd ~/co_store
rm -rf .beads
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

## co\_shipping

```bash
cd ~/co_shipping
rm -rf .beads
bd init --prefix ship
```

Verify:

```bash
bd create "Test co_shipping bead"
bd list
```

---

# 7. Gas City-Compatible Beads Config

Critical discovery:

Gas City required BOTH keys:

```yaml
issue_prefix:
issue-prefix:
```

Working config example:

## \~/co\_store/.beads/config.yaml

```yaml
issue_prefix: cs
issue-prefix: cs
dolt.auto-start: false
gc.endpoint_origin: inherited_city
gc.endpoint_status: verified
```

## \~/co\_shipping/.beads/config.yaml

```yaml
issue_prefix: ship
issue-prefix: ship
dolt.auto-start: false
gc.endpoint_origin: inherited_city
gc.endpoint_status: verified
```

Without both keys:

```text
bd create
```

failed with:

```text
issue_prefix config is missing
```

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

# 9. Claude Override for One Rig

Edit:

```bash
~/my-city/city.toml
```

Final working config:

```toml
[workspace]
provider = "codex"

[[rigs]]
name = "co_store"

[[rigs]]
name = "co_shipping"
prefix = "ship"

[[rigs.patches]]
agent = "polecat"
provider = "claude"
```

Meaning:

```text
co_store      → Codex
co_shipping   → Claude Code
```

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

Important discovery:

Gas City can get stuck during:

```text
Adopting sessions...
```

Correct recovery:

```bash
cd ~/my-city

gc stop /Users/rfvitis/my-city
gc start /Users/rfvitis/my-city
```

Eventually the supervisor reclaimed ownership.

Desired state:

```text
Controller: supervisor-managed
```

---

# 13. Successful Final Dispatch

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

And agents finally started:

```text
9/20 agents running
```

Including:

```text
gastown.mayor running
co_shipping/gastown.furiosa running
```

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

Provider topology was also correct from the beginning:

```toml
[workspace]
provider = "codex"

[[rigs.patches]]
agent = "polecat"
provider = "claude"
```

Meaning:

```text
Workspace default → Codex
Specific experiment → Claude for co_shipping polecat only
```

This is a legitimate scoped multi-provider pattern, not a misconfiguration.

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
