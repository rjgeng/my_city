# Day 3 — A/B sling: codex (co_store) vs claude (co_shipping)

**Date:** 2026-05-09
**Status:** Plan, not yet run

## Goal

Run identical input through both polecat pools and:

1. Validate the per-rig provider patch fires correctly — `co_store/gastown.polecat` runs on **codex** (workspace default), `co_shipping/gastown.polecat` runs on **claude** (scoped patch in `city.toml`).
2. Observe the implementer voice difference on apples-to-apples output.
3. Confirm the auto-convoy + bead lifecycle behaves end-to-end (file → route → claim → close → convoy auto-close).

## Pre-flight

```bash
cd ~/my-city
gc status                       # supervisor up, polecat pools listed
cat city.toml                   # source of truth for provider routing
```

Confirm in `city.toml`:

- `[workspace] provider = "codex"` — workspace default
- `[[rigs]] name = "co_store"` has no `[[rigs.patches]]` block → polecat inherits codex
- `[[rigs]] name = "co_shipping"` has `[[rigs.patches]] agent = "polecat" provider = "claude"` → polecat overridden to claude for this rig only

(`gc agent show` does not exist — `gc agent` only has `add`, `resume`, `suspend`. The resolved-config view is `gc config show`, but for the simple "did I configure routing right?" question, reading `city.toml` directly is fastest.)

Both rigs are git-clean as of plan time (verified 2026-05-09). Target file `notes/voice_check.md` does not exist in either rig — no clobber risk.

## Task text (identical for both rigs)

> Create a file at `notes/voice_check.md` with exactly four lines:
> line 1 = the rig's name,
> line 2 = a one-sentence placeholder purpose for this rig,
> line 3 = a single example shell command someone might run inside this rig,
> line 4 = the date `2026-05-09`.
> Then close the bead.

Why these four lines: L1 forces the polecat to read its rig context; L2 leaves room for voice; L3 is a small craft check; L4 catches invented dates.

## The two sling calls

```bash
cd ~/my-city

# A: codex polecat in co_store
gc sling co_store/gastown.polecat \
  "Create notes/voice_check.md with exactly four lines: line 1 the rig's name, line 2 a one-sentence placeholder purpose, line 3 one example shell command someone might run in this rig, line 4 the date 2026-05-09. Then close the bead."

# B: claude polecat in co_shipping (provider patch should route here)
gc sling co_shipping/gastown.polecat \
  "Create notes/voice_check.md with exactly four lines: line 1 the rig's name, line 2 a one-sentence placeholder purpose, line 3 one example shell command someone might run in this rig, line 4 the date 2026-05-09. Then close the bead."
```

Each call should print three lines like:

```
Created cs-XXX                              # or ship-XXX
Auto-convoy cs-YYY                          # or ship-YYY
Slung cs-XXX → co_store/gastown.polecat     # or co_shipping/gastown.polecat
```

## Watch while they run

```bash
gc status                                   # polecats spinning up
gc session list                             # find live session IDs
gc session peek <session-id> --lines 30     # observe each implementer's voice

cd ~/co_store    && bd list --status open   # work bead + convoy bead visible
cd ~/co_shipping && bd list --status open
```

## Verify the routing patch fired

Two independent signals — both should agree:

1. **Provider banner via `gc session peek`** — codex prompts and claude prompts look different in the terminal.
2. **Resolved provider** — `gc agent show co_shipping/gastown.polecat` should print `provider: claude`; `gc agent show co_store/gastown.polecat` should print `provider: codex`.

## Compare outputs after both close

```bash
diff /Users/rfvitis/co_store/notes/voice_check.md \
     /Users/rfvitis/co_shipping/notes/voice_check.md
```

Also confirm convoys auto-closed:

```bash
cd ~/co_store    && gc convoy list
cd ~/co_shipping && gc convoy list
# both convoys should be absent from the open list (auto-closed when child bead closed)
```

## Risks / fallbacks

- **Cost:** real provider tokens on both sides; trivial task = trivial bill.
- **Adoption hang** (yesterday's pattern): if a polecat session never starts, `gc stop ~/my-city && gc start ~/my-city` (v2 manual §12).
- **`invalid issue type: convoy`**: missing `types.custom` line on the rig's `.beads/config.yaml`; run `gc doctor --fix --verbose` (v2 manual §11).
- **Cross-rig misroute** by mistake: `--force` is *not* set, so cross-rig routing will warn — read the warning, don't paper over it.

---

## Results

Run on 2026-05-09 starting ~08:30 PDT.

### Run A — co_store / codex

- Bead ID: `cs-x79qv`
- Convoy ID: `cs-o4bxk` (auto-closed when bead closed)
- Polecat session ID: first attempt `mc-kfn0i` (blocked on codex usage limit, abandoned by `gc restart`); second attempt `mc-nqkq7` (succeeded after rate-limit reset at ~08:24)
- Resolved provider: `codex` — verified by peek showing `gpt-5.5 xhigh · ~/my-city/.gc/worktrees/co_store/polecats/gastown.furiosa` model line
- Implementation worktree: `.gc/worktrees/co_store/polecats/gastown.furiosa/worktrees/cs-x79qv` (nested worktree-of-worktree)
- Merged to main: commit `66e87d6 docs: add voice check note (cs-x79qv)`
- Output (`~/co_store/notes/voice_check.md`):

```
co_store
This rig is a placeholder for co_store work.
bd ready
2026-05-09
```

### Run B — co_shipping / claude

- Bead ID: `ship-6a2kf`
- Convoy ID: `ship-79tis` (auto-closed when bead closed)
- Polecat session: spawned briefly (no name retained — went idle after implementation, supervisor shut it down)
- Resolved provider: `claude` — verified by claude-CLI banner in peek and the polecat's worktree path
- Implementation worktree: `.gc/worktrees/co_shipping/polecats/gastown.furiosa` (single-level worktree)
- Merged to main: commit `6279453 ship-6a2kf: add notes/voice_check.md` at `2026-05-09T15:34:45Z` (UTC)
- Output (`~/co_shipping/notes/voice_check.md`):

```
co_shipping
Placeholder rig notes for voice and tooling checks before real work begins.
gc bd ready
2026-05-09
```

### Diff

```diff
- co_store
- This rig is a placeholder for co_store work.
- bd ready
+ co_shipping
+ Placeholder rig notes for voice and tooling checks before real work begins.
+ gc bd ready
  2026-05-09
```

### Observations

- **Routing patch confirmed.** Both providers fired in the rigs they were patched to: codex polecat in co_store (verified by model line `gpt-5.5 xhigh`); claude polecat in co_shipping (verified by claude-CLI session banner and the worktree path). The per-rig `[[rigs.patches]] agent = "polecat" provider = "..."` mechanism works as designed.

- **Voice differences:**
  - L2 (purpose): codex was terser and more generic ("a placeholder for co_store work"); claude was slightly more polished and self-referential ("Placeholder rig notes for voice and tooling checks before real work begins").
  - L3 (example shell command) was the most interesting differential: **codex produced bare `bd ready`; claude produced `gc bd ready`**. The gastown idiom is the `gc bd …` wrapped form (per `gc --help` and v2 manual §14). Claude inferred the rig-aware idiom; codex used the bare tool. Inferred: claude has more context on the gastown wrapping convention from its training/prompt; codex defaulted to the upstream `bd` CLI.
  - Worktree topology differed unexpectedly: codex created a *nested* worktree-of-worktree at `co_store/polecats/gastown.furiosa/worktrees/cs-x79qv`; claude wrote directly inside `co_shipping/polecats/gastown.furiosa`. May reflect provider differences in how the polecat prompt template handles the per-bead worktree, or just timing of pool reuse.

- **Surprises that broke flow:**
  - Original runbook used `gc agent show` for pre-flight provider verification — that subcommand does not exist (`gc agent` only has `add`, `resume`, `suspend`). Patched the runbook to use `cat city.toml` instead.
  - Codex hit a ChatGPT usage limit ("try again at 8:24 AM") immediately on spawn — A's first attempt (`mc-kfn0i`) sat in a stuck-retry loop for ~30 min producing nothing.
  - **Architectural insight uncovered:** the provider patch only overrides the **polecat** (implementer); the **refinery** (merge processor) inherits the workspace `provider` setting. So even on co_shipping (claude polecat), the merge step couldn't complete because the workspace was on codex and the codex limit had been hit. **One stuck provider stalls the entire merge pipeline of every rig**, regardless of polecat patches.
  - This insight prompted the workspace switch from `codex` → `claude` mid-session (with an inverted patch on co_store/polecat → codex preserving the A/B intent). After the switch, B's pending merge completed within seconds; A's first polecat session was abandoned by `gc restart` and a fresh `mc-nqkq7` polecat completed cleanly after codex's rate-limit reset.

- **Promote into v2 manual?** Three additions worth promoting:
  1. New section: "Provider patches scope only the patched agent — refinery inherits the workspace default." (Adds nuance to v2 §9.)
  2. Codex/ChatGPT usage limits as a city-wide stall risk; mitigation = workspace on the higher-headroom provider.
  3. Document the supervisor adoption sequence we hit: `gc reload` rejected when controller is busy → escalate to `gc restart` (drops sessions, leaves city in standalone) → escalate to `gc stop && gc start` (reattaches to supervisor). The whole chain matches v2 §12 in spirit; worth pinning the order explicitly.

### Reference: provider-topology change made during this run

Updated `city.toml` from:
```toml
[workspace] provider = "codex"
[[rigs]] name = "co_shipping"
[[rigs.patches]] agent = "polecat" provider = "claude"
```
to (inverted A/B):
```toml
[workspace] provider = "claude"
[[rigs]] name = "co_store"
[[rigs.patches]] agent = "polecat" provider = "codex"
```
Rationale: claude (Max Pro) has substantially more headroom than ChatGPT Plus's codex; using the more reliable provider as the workspace default removes the city-wide stall risk while preserving the codex/claude polecat A/B (just with codex now scoped to co_store instead of claude scoped to co_shipping).

---

## Next step after this runs

If the procedure holds up, promote the validated bits into v2 manual as a new section (e.g. `§ 19. Running an A/B between rigs`). Keep this file as the dated session log of the first run.
