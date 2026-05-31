# Day 41 EOD — recovery-scout + PR #2638 adoption (watch/respond day, nothing destructive)

- **Day:** 41 (executed 2026-05-31). Plan: `study/notes/2026-05-31-day41-plan-dolt-incident-followup.md`; scout findings: `study/notes/2026-05-31-day41-schemadrift-scout-findings.md`.
- **Shape:** the planned watch/respond day held — two upstream items moved during the Day-39–40 incident blackout, a read-only recovery scout settled the recovery path, and a stale-review block on our own PR #2638 surfaced. **No destructive action; nothing built; `.dolt` untouched.**

## What happened

1. **dolt recovery — root cause RESOLVED upstream, recovery path settled.**
   - **dolt#11131** is **fixed in `v2.1.0`**; all 2.x releases <2.1.0 are being **recalled**. Root cause confirmed: schema-side encoding drift (`StringAddrEnc → StringAdaptiveEnc` on a `TEXT→LONGTEXT` ALTER that skipped the required row rewrite), *not* data corruption.
   - Read-only scout of branch `zachmu/schema-repair-tool` (via GitHub API, no clone/build/run): **2.1.0 alone does NOT recover my-city** — it only prevents *new* ALTERs from extending corruption. Existing damage needs the `schemadrift` tool, specifically **`migrate-adaptive`** (the `dolt_ignore` force-inline path), because wisps are dolt-ignored and `repair`/`recover-rows` both refuse ignored tables.
   - **G-a (keyless?) RESOLVED** (hub, read-only `SHOW CREATE TABLE` on the restored dir, no server/writes/symlink touch): `hq.wisps` has **`PRIMARY KEY (id)` → NOT keyless → `migrate-adaptive` viable**. Corrupted out-of-line columns = the **5 longtext bodies**: `description`, `design`, `acceptance_criteria`, `notes`, `close_reason`. The build-the-tool step is **dropped** (zero anti-plan #28 exposure).
   - **Strategic call: WAIT for a vetted dolt `schema-encoding-drift` release** before running any repair code on wisp data. Nothing is degrading; **mc-jhsp8y soak stays PAUSED** (anti-plan #30). Do NOT build the unvetted branch binary.

2. **PR #2638 (`fix(gc): warn before supervisor recycle during city init`) — approved + adopted, blocked only on a stale review.**
   - **julianknutsen** ran the **`/adopt-pr` Maintainer Adoption Review** (§24c) — decision approve; pushed fixups, rebased onto `main`, labeled `status/merge-queued`. **quad341** posted an **APPROVED** review ("Merging now") and **armed SQUASH auto-merge**. All CI green.
   - **But it won't merge:** **@sjarmak's 5/27 `CHANGES_REQUESTED`** (whose three points we addressed Day-37 in `344a03de9`) was never dismissed/re-reviewed, so `reviewDecision` computes to `CHANGES_REQUESTED` and branch protection holds the armed auto-merge → `mergeStateStatus: BLOCKED`. Purely mechanical, not substantive.
   - **Action:** posted a single factual ping to **quad341** (who armed auto-merge and may not realize the stale review is the block) — comment `4586910434`. One-and-done; **no further nudge**. Rechecked later: no maintainer response yet, still BLOCKED — expected latency.
   - **Nothing more is needed from us before merge.** The moment a maintainer dismisses sjarmak's review, it auto-merges.
   - Added #2638 to `upstream-engagement-tracker.md` (it had only ever lived in day-notes via [[mc-itt3xc]]).

3. **gascity#2814 — wait-only.** julianknutsen owns the floor; the fix premise shifted (the recall covers 2.0.7, so the correct guard is `ManagedMin → 2.1.0`, not a 2.0.8 block). §24 HOLD continues; no nudge, no competing PR (anti-plan #27).

4. **Housekeeping (all committed + pushed).**
   - **G4 config migration** (`e6cc996`): moved the gastown rig-import defaults from `pack.toml` `[defaults.rig.imports]` (layout the new gc rejects) → `city.toml`.
   - Lockfiles tracked (`packs.lock`, `skills-lock.json`); `.agents/` (local skills) + `MULTI_ACCOUNT_SETUP.md` (personal account topology/emails/SSH layout — opsec) **gitignored** (`2263da3`).

## Verdicts

- **Recovery is no longer blocked by an unknown** — only by a deliberate wait for a vetted dolt release. The plan is fully specified (backup → `check` → `migrate-adaptive` on the 5 columns, under auth).
- **PR #2638 is effectively landed pending one maintainer click** — adoption + approval + armed auto-merge; the only gap is a stale third-party review.
- **Day-41 was correctly a watch/respond day** — the right move on every thread was to read, settle the path, and hold; no destructive or speculative action taken.

## State at close

- **Working tree clean; `HEAD == origin/main`** (pushed through `2263da3`). 9 commits landed this session.
- All cities on dolt **2.0.4**; my-city controller **down by design** (awaiting recovery); **2.0.4 symlink is a FRAGILE manual override** — do NOT `brew link`/`brew upgrade`/`gc upgrade` (anti-plan #28).
- Backups: `.beads/dolt.backup-20260530T1129-pre-reset` (5.7G), `.beads/dolt.BROKEN-postsurgery-20260530` (forensics).
- **bd writes still blocked** by the wisp corruption → no bead mutations possible (mc-jhsp8y note + tracking bead remain DEFERRED).
- Memory: [[project_dolt208_wisp_corruption_soak_paused]]. ADR: `study/notes/adr/0003-dolt-2.0.8-wisp-corruption-recovery.md`.

## Two external watch-triggers for Day-42+

1. **PR #2638 merges** → close bead [[mc-itt3xc]]; move #2638 to the tracker's **Closed / merged items** section; note the new §24c variant (adopt + armed auto-merge stalled by an un-dismissed prior `CHANGES_REQUESTED`).
2. **A vetted dolt `schema-encoding-drift` release ships** → start recovery: back up `.dolt` → `check` (read-only) → `migrate-adaptive` on the 5 longtext columns, with explicit auth (anti-plan #29) + verified backup in hand → on success, resume mc-jhsp8y, append the deferred bead notes, file the tracking bead.

## Day-42 resume prompt

> Day-42 (watch/respond). Two external triggers gate everything: (1) has **PR #2638** merged? `gh pr view 2638 --repo gastownhall/gascity --json state,mergedAt` — if MERGED, close mc-itt3xc + move it to the tracker's Closed section; if still OPEN/BLOCKED on sjarmak's stale review, leave it (one-and-done, no second nudge). (2) Has a **vetted dolt release** with `schema-encoding-drift` shipped? `gh release list --repo dolthub/dolt` — if yes, this is the recovery green-light (backup → check → migrate-adaptive on the 5 longtext cols, under explicit auth). Otherwise: my-city recovery + mc-jhsp8y stay parked, gascity#2814 stays §24 wait-only, and there's no local action — confirm the 2.0.4 guard still holds and stand down.
