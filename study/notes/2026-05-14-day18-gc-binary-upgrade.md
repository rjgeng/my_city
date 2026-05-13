# Day 18 — gc binary upgrade (HEAD-caa44a4)

- **Plan:** abbreviated (Day-17's §27 finding pre-specified the fix shape; no separate plan file)
- **Executed:** 2026-05-13 10:00-10:10 PT
- **Status:** EXECUTED. Binary upgraded; SCRUB_FILTER bug resolved at the source.

## What this day did

Day-17 surfaced that gc binary 1.1.0 embeds pre-PR-#1848 pack content. Manual edits to `.gc/system/packs/` get reverted on next order dispatch. The only persistent fix is a binary upgrade. Day-18 executed that upgrade.

## Recon

- `brew info gascity` showed stable 1.1.0 only; no newer bottled release.
- Submodule at `study/gascity-src` is at `v1.1.0-238-gcaa44a40` — 238 commits past v1.1.0, includes PR #1848.
- `brew install --HEAD gascity` is the supported path for upstream-main builds.

## Execution

| Step | Action | Outcome |
|---|---|---|
| 1 | Stop the city | `gc stop` hung; SIGTERM to PID 30730 didn't kill (3+ min); `launchctl unload com.gascity.supervisor.plist` was required to disable auto-restart; SIGKILL finished the supervisor |
| 2 | `brew uninstall gascity` | Removed 1.1.0 + 3 unneeded deps (flock, jq, oniguruma autoremoved) |
| 3 | `brew install --HEAD gascity` | Built from upstream main `caa44a40` in 37 seconds; new install at `/usr/local/Cellar/gascity/HEAD-caa44a4/` |
| 4 | Verify embed | `strings /usr/local/Cellar/gascity/HEAD-caa44a4/bin/gc \| grep SCRUB_FILTER` shows `WHERE issue_type NOT IN ...` — PR #1848 in embed ✓ |
| 5 | `gc start` | Supervisor spawned (PID 13654); pack re-materialized; city pack `jsonl-export.sh` line 637 now has `WHERE issue_type` |
| 6 | Verify no more errors | Dolt log post-10:00 PT: zero `column "type" not found` errors over 60+ seconds (last one was 09:54:10 PT pre-upgrade) |

## Validation of §27's theory

Day-17's §27 ("Pack content in the gc binary: embed vs filesystem reconciliation") predicted exactly this outcome:

- Old binary's embed → buggy pack
- New binary's embed → fixed pack
- `gc start` re-materializes pack from new embed
- The bug stops happening

All four predictions held. §27 is empirically grounded now.

## bd close attempt (deferred)

`bd close mc-2ntb2p` was attempted multiple times during Day-18 but hung repeatedly. Root cause appears to be dolt contention — the just-restarted supervisor was hammering bd queries (control-dispatcher polling, periodic order dispatch creating order-tracking beads, etc.) and bd close commands timed out waiting on dolt. Will close mc-2ntb2p in the next session when bd is responsive.

The fix itself is verified working; the bead-state-update is a documentation lag, not a functional gap.

## Surprises

- **`gc stop` hung again** (third time this session — Day-15, Day-17, Day-18). The intermittent hang on gc client commands is becoming a pattern worth flagging. Maybe a §22 footnote.
- **SIGTERM didn't kill the supervisor** after 3+ minutes. Either it was waiting on agents to drain (claude sessions don't respond fast to drain signal), or there's a deadlock. SIGKILL succeeded immediately but raises the question of why graceful didn't work.
- **launchd auto-restart was required to be explicitly disabled.** `launchctl unload ~/Library/LaunchAgents/com.gascity.supervisor.plist` is the recipe. After SIGKILL of supervisor, a new one (PID 67178) immediately took over port 8372 — launchd respawned it. Until the plist was unloaded, every supervisor kill restarted. Worth documenting in §13.
- **Homebrew `brew install --HEAD` rebuilt 4 dependencies** that had been autoremoved during uninstall. Build time was ~37s for gc, plus a few seconds for the deps. Acceptable.
- **The new binary is 74.4MB vs 1.1.0's 72.9MB.** Reasonable growth for +238 commits.
- **bd close hangs during supervisor activity** — when the supervisor is doing reconciler work (firing periodic orders, polling control-dispatcher), bd CLI gets queued behind dolt writes and times out. Not a permanent block, but a real annoyance during high-supervisor-activity windows.

## Anything to promote

- **§22 footnote on `gc stop` reliability** — three sessions now where `gc stop` hung; SIGTERM didn't kill supervisor; launchctl unload was needed. Worth documenting as "the supervisor-shutdown escalation ladder: gc stop → SIGTERM → launchctl unload + SIGKILL." Possibly already adjacent to §13's reload-vs-restart triage.
- **§27 addition: the upgrade path** — Day-18 is the worked example for "how to actually upgrade gc." Two-step process: launchctl unload (defeat auto-restart), then `brew install --HEAD`. Could be added as a short subsection in §27.
- **Closing-bead-while-supervisor-busy gap** — bd close hanging during reconciler activity is a UX pain. Maybe `bd close` should set a longer timeout or use a separate dolt connection. Could be an upstream discussion candidate.

## Connection to prior days

- Day-7 PR #2037 (first upstream contribution) — Day-18 is the **first time the city benefited from upstream advances** (130 commits including PR #1848 and 237 others now run live). The full upstream-contribute-then-receive cycle is closed.
- Day-15 (formula_v2 = true applied) — same shape: a config/binary-level change that ripples through the city after restart. Day-18 confirms the pattern.
- Day-16 (mayor under v2, null result) — mayor's "ephemeral fix" claim is now historically explained: pack content lives in binary; manual `.gc/system/packs/` edits are by-design ephemeral.
- Day-17 (mayor's claim investigation) — §27 was Day-17's main artifact. Day-18 validated it experimentally.
