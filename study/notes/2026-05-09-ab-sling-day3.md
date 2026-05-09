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
gc agent show co_store/gastown.polecat | grep -i provider     # expect: codex
gc agent show co_shipping/gastown.polecat | grep -i provider  # expect: claude
```

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

_To fill in after firing the two commands._

### Run A — co_store / codex

- Bead ID:
- Convoy ID:
- Session ID:
- Resolved provider (from `gc agent show`):
- Time to claim:
- Time to close:
- Output (`co_store/notes/voice_check.md`):

```

```

### Run B — co_shipping / claude

- Bead ID:
- Convoy ID:
- Session ID:
- Resolved provider (from `gc agent show`):
- Time to claim:
- Time to close:
- Output (`co_shipping/notes/voice_check.md`):

```

```

### Diff

```

```

### Observations

- Routing patch confirmed (codex vs claude)?
- Voice differences observed:
- Anything that broke / surprised:
- Promote any of this procedure into v2 manual?

---

## Next step after this runs

If the procedure holds up, promote the validated bits into v2 manual as a new section (e.g. `§ 19. Running an A/B between rigs`). Keep this file as the dated session log of the first run.
