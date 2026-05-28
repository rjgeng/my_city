# Day 37 EOD — mc-cqm9nl superseded; pre-impl plan-patch caught it

- **Day:** 37 (post-soak day 1; planned for 5/27, executed 5/28 due to slip)
- **Plan reference:** `study/notes/2026-05-27-day37-rig-expansion-chat-and-pr2638-watch.md`
- **Actual execution:** rig-expansion chat deferred (user prerogative); mc-cqm9nl kickoff started → pivoted to supersession + bead updates.

## What happened

Day-37 Step 4 (mc-cqm9nl implementation kickoff, scope-limited to scaffold + first test per anti-plan #22) opened `study/gascity-src/examples/dolt/commands/compact/run.sh` to locate the patch site (bead said lines 1536-1559 on 5/25 HEAD). The line numbers had drifted — file is now ~2000 lines vs. the bead-time ~1700 — so I grepped for `value hash changed`.

That grep returned an unexpected match: `db_hash_writer_race_detected` at line 1814, with a `defer_writer_race_after_flatten` call adjacent. `git log -S` on the symbol pointed at **PR #2564** (Masanori Iwata, merged 2026-05-25, JST evening) and **PR #2598** (Julian Knutsen follow-up, same day). Both fix the in-flatten race the mc-aep8yk Candidate A targeted, via a different mechanism.

## The supersession (mechanism comparison)

| | PR #2564 + #2598 (upstream, merged) | Candidate A (mc-cqm9nl, planned) |
|---|---|---|
| Race detection signal | HEAD-movement across three guard points | Failure-reason string parsing |
| Guard A | preflight HEAD vs. pre-reset HEAD | n/a |
| Guard B | flatten HEAD vs. post-verify HEAD | n/a |
| Guard C | flatten HEAD vs. pre/post db_value_hash probe HEAD | n/a |
| Recovery on race | pending-GC marker, return 0, next compactor cycle retries | in-run sleep backoff (30s/60s/120s) up to N=3, then persist marker |
| Conservatism on corruption | stable-HEAD gain+drift → still quarantines | same |
| Conservatism on other signals | row decrease / same-count drift / table-list change / probe failure → still quarantine | same |
| Test pinning the design choice | `WriterRaceGateUsesFlagNotReasonText` (gate on flags, not log text) | inverted — depends on parsing log text |

PR #2564's `WriterRaceGateUsesFlagNotReasonText` test is the load-bearing design statement: don't gate on log strings, gate on observed mechanism flags. That is exactly the brittle assumption Candidate A made.

## Coverage of our n=4 races

| Day | Marker reason | Doctor commit timing | PR #2564 guard that fires |
|---|---|---|---|
| 31 | value hash changed with row-count increase | during flatten window | Window A or B (depending on exact phase) |
| 34 | same | same | Window A or B |
| 35 | same | same | Window A or B |
| mc-jhsp8y / characterization | same | same | Window A or B |

All four cases land in the gain+hash-drift path with HEAD movement somewhere across the flatten window. PR #2564's gate covers all of them. No edge case in our n=4 falls outside the gate.

## Bead state changes

- **mc-aep8yk** (CLOSED) — post-close note appended: superseded by PR #2564 + #2598; mechanism comparison; coverage of n=4.
- **mc-cqm9nl** (was OPEN, now CLOSED) — closed as superseded; rationale + non-implications recorded.
- **mc-jhsp8y** (OPEN) — note appended: validation gate (acceptance #3) now blocked on `gc upgrade` to a binary containing PR #2564 + #2598; current `gc` is HEAD-fad5d3f which predates them. Re-soak template updated to capture `pending_gc_dir` markers alongside `quarantine_dir`.
- **mc-1zccc2 / mc-4m2da1 / mc-iho25h / mc-z92fpi** — unchanged (correctly gated on mc-jhsp8y).
- **mc-itt3xc** — unchanged (PR #2638 still in maintainer's court, ~24h since my response).

## Submodule bump

- `study/gascity-src` moved `344a03de9` → `0f50effe7` (latest `origin/main`).
- Bump is code-reference only; running gc binary is unchanged.
- Commit: `716be1a` (parent repo).

## What this is NOT

- **NOT a `gc upgrade`.** Machine-global op; deferred to a separate authorization. The race is still live for the running binary today.
- **NOT a close of mc-jhsp8y.** Implementation supersession ≠ empirical race resolution. mc-jhsp8y needs ≥3 clean fires post-upgrade per its own acceptance.
- **NOT a re-soak.** That happens after upgrade.
- **NOT a PR comment on #2638.** Orthogonal.
- **NOT a rig-expansion-chat outcome.** User explicitly deferred that chat to a later day.

## Process lessons captured

1. **Pre-impl reconnaissance is cheap and high-value.** ~30min of "verify the line numbers and re-grep" turned an N-hour implementation into a supersession close. Without that step we would have built parallel logic and then either shipped it (worse mechanism in our codebase) or thrown it out late (wasted hours + bead noise).
2. **Day-34 lesson #2 re-validated**: "demote, don't keep load-bearing — patch plans before tests." Today's plan said "implement Candidate A scaffold." Patching the plan instead of executing was the right move.
3. **Bead-cited line numbers decay fast on actively-maintained upstream code.** The bead-time line range (1536-1559) was already obsolete 3 days later. Future implementation beads on upstream code should cite **symbol names** (`db_value_hash`, `verify_counts`, `defer_writer_race_after_flatten`), not line numbers — symbols survive refactors.
4. **The 4-day soak (Day-31..36) was not wasted.** It produced the n=4 race characterization that lets us *verify* PR #2564 covers our cases without re-arguing the bug. The soak data is now the validation oracle for the upgraded binary.
5. **Maintainer activity on the same problem space is a real signal.** PR #2564 landed *during* our soak (Day-35 = 2026-05-25). A weekly upstream-PR scan during long experiments would have surfaced this earlier — at the cost of more interrupted soak. Tradeoff to think about, not a hard rule.

## Day-38 carry-forward

- **Primary**: authorize `gc upgrade` to a HEAD containing PR #2564 + #2598. Capture supervisor PID + version delta in a /tmp note (no plan-file ceremony).
- **Soak**: start a 3-day re-soak of mc-jhsp8y under the new binary; doctor cadence active on hq; watch `pending_gc_dir` and `quarantine_dir` separately.
- **Rig-expansion chat**: still pending — user has deferred. No nudge.
- **PR #2638**: ~24h since my response; anti-plan #1 (no nudge before 48h+) still holds. Re-check Day-38 EOD.
- **No new beads filed today.** Consciously avoiding fan-out.

## G2–G4 verdicts (Day-37 ambient predictions)

- **G2 (PR #2638 maintainer-response watch)**: field held. No maintainer activity past my 5/27 14:11Z reply. Modal expectation correct.
- **G3 (beads release watch)**: v1.0.4 still latest. mc-mxl4vc still blocked.
- **G4 (supervisor uptime)**: PID 30349 cycled at some point on 5/27 → new PID 786. Anti-plan #15 already lifted, so this is just a data point. No constraint violated.

## Surprises

1. **PR #2564 + #2598 existed.** The Day-36 EOD closure of mc-aep8yk + filing of mc-cqm9nl happened on 5/26, *one day after* upstream merged the fix. No part of Day-36 noticed. Lesson #5 above is the carry-forward.
2. **The fix is in a *better* layer than Candidate A picked.** Candidate A picked the persistence-policy layer (downstream of detection); PR #2564 picked the detection layer's race-signal gate (upstream of persistence). The detection-layer fix is strictly more compact and avoids parsing log strings.
3. **mc-aep8yk's design space (B/C/D/E) included a HEAD-stability-defer concept inside Candidate C** ("flatten-cycle retry") but framed as "more invasive" — yet PR #2564's actual implementation is comparable in diff size to Candidate A. The intuition that "smaller diff = simpler mechanism" doesn't always hold; the smaller diff sometimes hides a *less correct* layer choice.

## What the day actually produced

- Submodule bump commit `716be1a`.
- mc-aep8yk note (supersession evidence).
- mc-cqm9nl CLOSED (supersession rationale).
- mc-jhsp8y validation gate note (waiting on `gc upgrade`).
- This EOD note.
- One Day-34-lesson-#2 re-validation.
EOF