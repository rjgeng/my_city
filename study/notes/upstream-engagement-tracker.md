# Upstream Engagement Tracker

A living tracker for all upstream issues, PRs, and contributions to `gastownhall/*` repos. Update inline as state changes; commit each meaningful update.

**Last updated:** 2026-05-15 (Day-25 — canonical 24h soak re-read + nudge posted on PR #2088)

---

## Counters

| Metric | Value |
|---|---|
| Total engagements | 5 (3 PRs + 2 issue comments) |
| PRs opened | 3 |
| PRs merged | 1 (#2037) |
| PRs awaiting maintainer | 2 (#2088, #2136) |
| Issues commented (downstream-symptom data) | 2 (#1487, beads-#3880) |
| Engagement cadence | ~1 per 4.4 days (since Day-11) |
| Local-only beads (linked to upstream items) | 2 active (mc-w9iua4, mc-mxl4vc) + 1 new (mc-1zccc2, separate surface) |
| Repos touched | 2 (gascity, beads) |

---

## Active items

### PR #2088 — `docs(convoy): clarify --help text re: workflows vs convoys`

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/pull/2088
- **State:** OPEN, all CI passing, mergeable, 1 review request pending
- **Day filed:** Day-22 (2026-05-13)
- **Size:** +110 -15
- **Activity:** Created 2026-05-13T20:36Z; addressed Copilot feedback 2026-05-13T21:02Z; **nudge posted 2026-05-15T21:25Z UTC** (single-line per tracker protocol)
- **Bead lineage:** none — surfaced organically during Day-22 sweep
- **Last action by us:** posted single-line nudge: *"Friendly ping — any thoughts on this when you get a chance? Happy to revise anything that needs revision."* → https://github.com/gastownhall/gascity/pull/2088#issuecomment-4463768343
- **Day-25 update:** nudge posted; per protocol DO NOT nudge again. Wait it out.

**What it does:** removes the misleading "Simple/Complex convoys" framing from `cmd_convoy.go` `Long:` description; adds an explicit disambiguation paragraph stating convoys ≠ workflows.

**Maintainer cadence context:** recent merged PRs in this repo took 0-1 day from create to merge (8 of 8 sampled). #2088 is past that band but not by much.

**Next action:**
- [ ] **Wait until 2026-05-15 PM (~48h mark).** If still content-idle, leave a polite single-line "any thoughts on this?" comment.
- [ ] If review comes in: address inline, push to same branch (per §24 playbook).

**Risk:** Low. PR is small, CI green, content quality verified. Worst case: stays open longer than typical, eventually merges or gets superseded.

---

### PR #2136 — `fix(maintenance): retry mol-dog-jsonl push on concurrent ref-update race`

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/pull/2136
- **State:** OPEN, CI green (74 SUCCESS + 22 SKIPPED — skipped are path-filtered, expected for bash-only change), mergeable=UNKNOWN (transient GitHub state, not a real conflict)
- **Day filed:** Day-24 (2026-05-14, ~25 min after open)
- **Size:** +38 -2 (single bash file: `examples/gastown/packs/maintenance/assets/scripts/jsonl-export.sh`)
- **Activity:** Created 2026-05-14T22:13Z; Copilot review posted at 2026-05-14T22:19Z (benign summary, no actionable asks). **Content-idle ~16h as of Day-25 read — within 1.5× cadence threshold.**
- **Bead lineage:** mc-w9iua4 (P3 BUG, OPEN in HQ — updated 2026-05-15 with Day-25 soak result)
- **Last action by us:** opened the PR; nothing since
- **Day-25 update (canonical 24h mark):** baseline rate 3 mol-dog-jsonl exit-1 / 343 fires = **0.87%**. Cross-rig: HQ + co_store + co_shipping. PR fix should drop this to near-zero. Real validation needs upstream merge + city upgrade + post-install soak. At upper edge of the "1-3 failures" decision bucket — one more failure in a comparable window triggers "reconsider fix shape" branch.

**What it does:** wraps the single-shot `git push origin main` in `push_archive_main()` with a 3-attempt retry loop, 1-5s jittered sleep, re-fetch + re-rebase between attempts. Preserves `consecutive_push_failures` / `MAX_PUSH_FAILURES` escalation semantic.

**Quality concerns from the dig (worth pre-empting if maintainer asks):**

| Concern | Detail | Suggested response if asked |
|---|---|---|
| **`awk srand()` is novel** | My commit introduced the FIRST `awk srand()` pattern in this repo. Bash `$RANDOM` is more conventional. | Offer to switch to `sleep $((1 + RANDOM % 5))` if reviewers prefer; both are functionally equivalent. |
| **`for push_attempt in 1 2 3`** | Style is acceptable but the codebase doesn't have a standard idiom (no other 3-attempt retry patterns exist to mirror). | Stand by current shape; explain in comment. |
| **No new unit test** | PR body explicitly offers to add one. The race is hard to test deterministically (it's a contention condition on a local bare repo). | Offer to add a "advanceArchiveRemoteMain twice in quick succession" test if reviewers prefer. |
| **`set_pending_archive_push` interaction** | The retry loop succeeds-or-fails inside `push_archive_main()`. The function's return-1 path (after all 3 attempts fail) flows into the existing escalation logic. Not strictly tested with new code. | Unit test would also cover this. |

**Next action:**
- [ ] **Wait 24h** (until 2026-05-15 PM) for maintainer review.
- [ ] If review requests changes: address inline. Most likely ask: switch `awk` to `$RANDOM`; OR add a unit test.
- [ ] If silent at 48h: leave a brief "ready when you are" comment.
- [ ] If merged + city upgrades: validate with another 24h post-install soak; close mc-w9iua4 if 0 failures.

**Risk:** Low-medium. Functional correctness is solid. Style might draw a "switch to $RANDOM" nit. Worst case: maintainer asks for unit test, +30min to add.

---

### Issue #1487 — `bug: gc events HTTP API on :8372 returns context-deadline-exceeded intermittently under load`

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/issues/1487
- **State:** OPEN
- **Day commented:** ~Day-12 era (rjgeng comment 2026-05-12)
- **Bead lineage:** none — supportive contribution to A3Ackerman's diagnosis
- **Last action by us:** posted a downstream-symptom data point comment

**What we did:** added evidence supporting A3Ackerman's multiplexer-fan-out diagnosis from the client side. Not our issue; not waiting on us.

**Next action:**
- [ ] **No action.** Monitor for thread movement; if maintainer acts, mention success on a future PR.

**Risk:** None. Comment is preserved; thread is dormant.

---

### Issue #3880 (beads repo) — `Server mode: repeated 'auto-import ... into empty database' on every update`

- **Repo:** `gastownhall/beads` (NOT gascity — this caused earlier API confusion)
- **URL:** https://github.com/gastownhall/beads/issues/3880
- **State:** OPEN
- **Day commented:** Day-19/20 era
- **Bead lineage:** mc-mxl4vc (P2 BUG, OPEN in HQ — waiting on bd v1.0.5)
- **Last action by us:** posted root-cause analysis pointing at `cmd/bd/auto_import_upgrade.go`

**What we did:** identified the regression in bd 1.0.4 (vs 1.0.3) — `maybeAutoImportJSONL` mis-detects empty DB and triggers a 4.6MB JSONL re-import that times out at 2 min. Workaround in city: symlink `/usr/local/bin/bd → bd 1.0.3`.

**Upstream release status (verified Day-24):** beads latest release is **v1.0.4** (2026-05-09, the broken one). **v1.0.5 NOT yet shipped.** Workaround stands.

**Next action:**
- [ ] **Monitor weekly.** Check `gh release list --repo gastownhall/beads` on each tour-day.
- [ ] When v1.0.5 ships: plan city upgrade per mc-mxl4vc body's next-steps; validate the empty-DB guard works; close mc-mxl4vc.

**Risk:** Low. Workaround is stable. Deadline pressure: none.

---

## Pre-upstream watch list

Items that are LOCAL beads only — not yet upstream, but could become upstream contributions after investigation. Listed here so they don't get lost.

### mc-1zccc2 — `mol-dog-compactor exit 1 — two consecutive daily runs failed (5/14, 5/15)`

- **Local bead only** — no upstream item yet
- **Surface:** different from mc-w9iua4. Compactor does dolt history flattening, not git push. Distinct root cause.
- **Pattern:** daily order, ~08:00 PT, exit-1 on last 2 fires (5/14 + 5/15)
- **Next:** Day-26 trace-arm `gastown.deacon` at ~07:55 PT to capture next 08:00 fire's stderr
- **Becomes upstream when:** root cause is identified + fix shape is clear

---

## Closed / merged items

### PR #2037 — `fix(packs): fallback to dolt-provider-state.json` ✅

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/pull/2037
- **State:** **MERGED** by sjarmak on 2026-05-13 (commit `e1cee04`)
- **Day filed:** Day-11 (2026-05-12)
- **Size:** 21 lines across 2 shell scripts
- **Bead lineage:** mc-ma23a9 (closed)
- **Cycle time:** opened 2026-05-12 → merged 2026-05-13T01:46Z (~32h)

**What it did:** fixed jsonl-export.sh state-file fallback path — when primary state file is missing, fall back to `dolt-provider-state.json` instead of failing.

**Status:** done, shipped. First contribution to land upstream. Reference proof point for §24's "honesty-first PR body + clean make check" pattern.

---

## Maintenance protocol

When a PR or issue state changes:

1. Update the per-item section's **State**, **Activity**, and **Last action by us** fields
2. Update the **Counters** table at the top
3. Update the **Last updated:** timestamp
4. Move closed/merged items to the **Closed / merged items** section
5. Commit with message `docs: upstream-tracker — <item> <new-state> (<short why>)`

When opening a new PR/issue:

1. Add a new sub-section under **Active items**, matching the existing template
2. Link it to its bead lineage (or mark `none — organically surfaced`)
3. Update **Counters**

When considering a nudge:

1. Check maintainer cadence on the repo (`gh pr list --state merged --limit 10` and look at create→merge gaps)
2. Wait at least 1.5× the typical cadence before nudging
3. Single-line nudges only ("any thoughts on this?" / "ready when you are")
4. Do not nudge twice — second silence = let it ride, work other things

---

## Recurring questions for review-day

When this file is opened on a tour-day or read-day:

- [ ] Has any **state** changed since last check?
- [ ] Is any **next action** overdue per its stated trigger?
- [ ] Has any **upstream release** shipped that affects an item? (esp. beads v1.0.5 for #3880)
- [ ] Are there any new beads in HQ that should become upstream PRs? (cross-reference `bd list --status open` for `[BUG]` or `upstream-candidate`-labeled beads)
