# Day 41 — dolt 2.0.8 incident follow-up (watch/respond day)

- **Plan authored:** 2026-05-30 (Day-39–40 incident EOD)
- **Planned execution:** 2026-05-31 (slips with the plan per day-numbering convention); EXECUTED 2026-05-31 — findings in `2026-05-31-day41-schemadrift-scout-findings.md`
- **Shape:** NOT the original "read the mc-jhsp8y soak fire" — that soak is **PAUSED** by the dolt 2.0.8 wisp corruption (see ADR-0003). Day-41 is a watch/respond day on the two upstream items + (optional) recovery-feasibility scouting. my-city's controller stays down until the data plane is rebuilt.

## Pre-flight (read state, mutate nothing)
- `gh issue view 2814 --repo gastownhall/gascity` — timeline since 2026-05-30T20:40Z: any julianknutsen comment / linked branch / fix PR?
- `gh issue view 11131 --repo dolthub/dolt` — any maintainer triage/label/comment? (dolthub cadence unknown.)
- Verify the guard holds: `dolt version` still **2.0.4** (symlink intact); all city dolt servers still 2.0.4 (`dolt_version()` per port). Do NOT `brew link`/`brew upgrade`/`gc upgrade`.

## G1 (load-bearing) — gascity #2814 (P0, julianknutsen self-assigned)
Branch on his response:
- **A — he opened a fix PR:** VERIFY, don't duplicate. Does it (1) block the bad `20260528`/2.0.8 engine, (2) keep the 2.0.7 floor, (3) point operators at a pre-regression downgrade (2.0.7=`20260526` confirmed safe, or 2.0.4)? If a gap, comment with the engine-date evidence. Cross-link dolt#11131.
- **B — he greenlit the offer / asked for it / went quiet in a way that invites the PR:** SEND the prepared fix. Branch `fix/block-known-bad-dolt-2.0.8`; guard in `internal/doltversion/doltversion.go` (known-bad block on the `20260528` engine / 2.0.8, fail closed → dolt#11131, floor preserved); read CONTRIBUTING + PR template; rebase fork to origin/main; `make check` (the build may rebuild dolt — **verify `dolt version` is still 2.0.4 afterward**, don't let it re-link 2.0.8); **STOP and show diff + PR body before `gh pr create`** (standing rule). No @-mentions, no force-push during review.
- **C — silence:** §24 wait-only. No nudge (P0 + self-assigned = give it room). Re-check EOD.

## G2 (ambient) — dolt #11131 (root cause)
- Watch for triage/response. If they ask for the corrupted data dir → offer `.beads/dolt.BROKEN-postsurgery-20260530` privately. If a bisect would help → narrow the engine regression in the `20260526 → 20260528` window (2.0.7 good, 2.0.8 bad — tight range).

## G3 (optional, INVESTIGATE-only) — my-city recovery feasibility
- Now that **2.0.7 is confirmed pre-regression**, scout (read-only) whether a beads-native wisp-federation rebuild is viable on a good engine — e.g. `bd bootstrap` semantics for missing nonlocal tables, or resetting the wisp-migration ledger then re-migrating under 2.0.4. The Day-39 dolt-level drop+re-migrate dead-ended on the nonlocal-federation ledger wall; do NOT retry destructively. Any execution needs explicit auth + the verified 5.7G backup. Likely outcome: still blocked → "wait for fixed dolt / beads guidance."

## G4 (optional, bounded) — my-llm-wiki config migration
- `pack.toml [defaults.rig.imports]` → `city.toml` (the new gc rejects the old layout; surfaced when `gc restart` validated all cities). Low-risk, mirrors my-city's pending change. Do only if time + user OK; it's a different city.

## Anti-plans (continue from Day-38 #23–#26)
- **#27** — no competing #2814 PR while julianknutsen is assigned; send only on greenlight/stall (§24 hold).
- **#28** — no `brew link`/`brew upgrade`/`gc upgrade` of dolt (re-exposes 2.0.8); if any build runs, verify dolt stays 2.0.4.
- **#29** — no destructive my-city wisp recovery (drop/reset/re-migrate) without explicit auth + verified backup; the nonlocal-federation path already dead-ended once.
- **#30** — do NOT resume or close mc-jhsp8y on any basis until the wisp data plane is actually rebuilt (it is paused, not failed).

## Modal (~70%)
Engaged P0 maintainer → Branch A or B on #2814 within the day; soak stays paused regardless. Deferred indefinitely: tracking bead (bd writes blocked until my-city recovers), rig-expansion chat.
