# Upstream Engagement Tracker

A living tracker for all upstream issues, PRs, and contributions to `gastownhall/*` repos. Update inline as state changes; commit each meaningful update.

**Last updated:** 2026-05-22 (Day-32 AM — **PR #2088 merged by quad341 Day-30 evening** (2026-05-20T18:45:45Z, 2h32m after the `status/reviewing` label → §24b *direct-merge* variant, first observed); PR #2136 unchanged since Day-27 nudge (day 4 of post-nudge silence, §24a continues); mc-jhsp8y soak continuing — next compactor fire ~08:29 PT today is the n=2 discriminator)

**Static rules:** see `upstream-engagement-playbook.md` (`§24` = post-engagement protocols — §24a APPROVED stall, §24b REVIEWING stall, §24c `/adopt-pr` adoption; future sections append-only).

---

## Counters

| Metric | Value |
|---|---|
| Total engagements | 6 (4 PRs + 2 issue comments) |
| PRs opened | 4 |
| PRs merged | 3 (#2037, #2316, #2088) |
| PRs awaiting maintainer | 1 (#2136) |
| Issues commented (downstream-symptom data) | 2 (#1487 ✅ resolved by upstream PR #2127, beads-#3880 still OPEN) |
| Engagement cadence | ~1 per 3.8 days (since Day-11) |
| Local-only beads (linked to upstream items) | 4 active (mc-w9iua4 → #2136 awaiting upstream; mc-mxl4vc awaiting beads v1.0.5; mc-4m2da1 awaiting city-upgrade soak post-#2316 merge; mc-jhsp8y in-flatten race exposed Day-31 — soak for race-frequency characterization) |
| Repos touched | 2 (gascity, beads) |

---

## Active items

### PR #2136 — `fix(maintenance): retry mol-dog-jsonl push on concurrent ref-update race`

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/pull/2136
- **State:** OPEN, CI green (74 SUCCESS + 22 SKIPPED — skipped are path-filtered, expected for bash-only change), mergeable=UNKNOWN (transient GitHub state, not a real conflict)
- **Day filed:** Day-24 (2026-05-14, ~25 min after open)
- **Size:** +38 -2 (single bash file: `examples/gastown/packs/maintenance/assets/scripts/jsonl-export.sh`)
- **Activity:** Created 2026-05-14T22:13Z; Copilot review posted at 2026-05-14T22:19Z (benign summary, no actionable asks). **Content-idle ~16h as of Day-25 read — within 1.5× cadence threshold.** **Day-27 (2026-05-18T11:03:58Z): nudge posted by rjgeng** ("Friendly bump — any thoughts on this?") at ~93h content-idle, past 1.5× cadence threshold.
- **Bead lineage:** mc-w9iua4 (P3 BUG, OPEN in HQ — updated 2026-05-15 with Day-25 soak result)
- **Last action by us:** Day-27 nudge comment 2026-05-18T11:03:58Z (https://github.com/gastownhall/gascity/pull/2136#issuecomment-4477023113); per protocol, no further nudge after this one — let it ride.
- **Day-25 update (canonical 24h mark):** baseline rate 3 mol-dog-jsonl exit-1 / 343 fires = **0.87%**. Cross-rig: HQ + co_store + co_shipping. PR fix should drop this to near-zero. Real validation needs upstream merge + city upgrade + post-install soak. At upper edge of the "1-3 failures" decision bucket — one more failure in a comparable window triggers "reconsider fix shape" branch.
- **Day-26 check (2026-05-16 EOD):** still OPEN/MERGEABLE, `updatedAt` 2026-05-14T22:28Z (unchanged since open). Zero comments ever. Content-idle ~48h — at the threshold for a "ready when you are" nudge on Day-27 if still silent.
- **Day-27 check (2026-05-18 AM):** still no maintainer activity; content-idle ~93h. **Nudge sent** — G3 satisfied per Day-27 plan.
- **Day-32 check (2026-05-22 AM):** unchanged — `updatedAt` still 2026-05-18T11:03:58Z, day 4 of post-nudge silence. CI re-verified: 74 SUCCESS + 22 SKIPPED, MERGEABLE, zero reviewers requested, only copilot-bot has ever commented. **§24a wait-only continues; DO NOT nudge.** Compare to #2088 trajectory: that one took 4.5 days post-APPROVAL before §24b label-then-merge — but #2136 has no APPROVAL yet (csells-style peer signal absent), so the comparable window is wider.

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

### Issue #3880 (beads repo) — `Server mode: repeated 'auto-import ... into empty database' on every update`

- **Repo:** `gastownhall/beads` (NOT gascity — this caused earlier API confusion)
- **URL:** https://github.com/gastownhall/beads/issues/3880
- **State:** OPEN
- **Day commented:** Day-19/20 era
- **Bead lineage:** mc-mxl4vc (P2 BUG, OPEN in HQ — waiting on bd v1.0.5)
- **Last action by us:** posted root-cause analysis pointing at `cmd/bd/auto_import_upgrade.go`

**What we did:** identified the regression in bd 1.0.4 (vs 1.0.3) — `maybeAutoImportJSONL` mis-detects empty DB and triggers a 4.6MB JSONL re-import that times out at 2 min. Workaround in city: symlink `/usr/local/bin/bd → bd 1.0.3`.

**Upstream release status (verified Day-24):** beads latest release is **v1.0.4** (2026-05-09, the broken one). **v1.0.5 NOT yet shipped.** Workaround stands.

**Day-27 PM verification (2026-05-18):** confirmed unchanged — #3880 OPEN (no activity since 5/13), beads still v1.0.4 latest. Skip re-check until ~Day-30.

**Next action:**
- [ ] **Monitor weekly.** Check `gh release list --repo gastownhall/beads` on each tour-day.
- [ ] When v1.0.5 ships: plan city upgrade per mc-mxl4vc body's next-steps; validate the empty-DB guard works; close mc-mxl4vc.

**Risk:** Low. Workaround is stable. Deadline pressure: none.

---

## Pre-upstream watch list

Items that are LOCAL beads only — not yet upstream, but could become upstream contributions after investigation. Listed here so they don't get lost.

### mc-jhsp8y — `mol-dog-compactor: in-flatten race window on hq exposed post-#2316 — first quarantine marker 2026-05-21`

- **Local bead only** — Day-31 diagnose-day artifact. Filed 2026-05-21 during first post-upgrade soak observation.
- **Surface:** identical to mc-1zccc2 (`order.failed exit status 1`). **Different abort path.** Pre-#2316: preflight `head_commit` re-check (old run.sh:962-968). Post-#2316: post-flatten value-hash check (new run.sh:1538-1540, `verify_counts_saw_gain=1` branch).
- **Causal separation:** old preflight race mitigated by #2316; newly-visible flatten-time race exposed safely through quarantine. Not a regression of #2316 — it's the next layer.
- **Evidence artifact (DO NOT DELETE):** `.gc/runtime/packs/dolt/compact-quarantine/hq` — first observed quarantine marker of this kind. Primary diagnostic input; controller drops subprocess stderr so this file is the only structured trace of what happened.
- **Lineage:** mc-1zccc2 (original diagnosis) → mc-4m2da1 (preflight-fix design, partial scope merged in #2316) → **mc-jhsp8y (in-flatten race, exposed by #2316)**.
- **Acceptance:** 3+ more daily data points (5/22, 5/23, 5/24) to confirm in-flatten race repeats with similar frequency, then decide fix shape, OR non-repeat in which case downgrade and close.
- **Candidate fix shapes (NOT decisions today):**
  - Outer retry-with-backoff wrapping the whole probe + flatten + verify cycle for `hq` specifically (the originally-proposed-in-mc-4m2da1-but-not-merged flatten-cycle retry).
  - Pause `hq` writers during compact (likely intrusive).
  - Dolt-native locking primitives if available.
- **Next:** Day-32 = read 5/22 compactor fire (expected 08:30–08:50 PT given today's +16m drift). Three branches: same reason → race confirmed reproducible; different reason → wider scope; no fire / exit-0 → write-spike-dependent, downgrade.
- **Becomes upstream when:** in-flatten race characterized + fix shape decided → file upstream PR.
- **Plan reference:** `study/notes/2026-05-21-day31-first-soak-observation.md`

### mc-1zccc2 — `mol-dog-compactor exit 1 — two consecutive daily runs failed (5/14, 5/15)`

- **Local bead only** — no upstream item yet (fix is upstream as PR #2316; bead stays OPEN pending Day-31+ soak resolution via [[mc-jhsp8y]])
- **Surface:** different from mc-w9iua4. Compactor does dolt history flattening, not git push. Distinct root cause.
- **Pattern:** daily order, ~08:00 PT drifting +1-2min/day. **6 consecutive exit-1 failures observed** (5/14, 5/15, 5/16, 5/17 23s, 5/18 2m47s, 5/19 2m17s). Variable duration suggests race window depends on hq's contemporaneous write load.
- **Day-31 (2026-05-21) soak result:** first post-upgrade fire at 08:30:38 PT (+16m past predicted window). Failed via the NEW post-#2316 quarantine path, NOT the old preflight race. `.gc/runtime/packs/dolt/compact-quarantine/hq` marker captured the reason: `post-flatten value hash changed with row-count increase`. PR #2316's preflight retry succeeded; safety net activated as designed. Confirmed: old preflight race IS fixed. New in-flatten race exposed → captured in mc-jhsp8y.
- **Next:** wait on [[mc-jhsp8y]] soak (Day-32+); mc-1zccc2 closes when in-flatten race is either characterized + fix shipped, OR confirmed one-off after 3+ clean fires.
- **Becomes upstream when:** see [[mc-jhsp8y]] for the in-flatten race follow-up. The preflight race this bead originally diagnosed IS resolved.

---

## Closed / merged items

### PR #2088 — `docs(convoy): clarify --help text re: workflows vs convoys` ✅

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/pull/2088
- **State:** **MERGED** by quad341 on 2026-05-20T18:45:45Z (11:45 PT) via merge commit `a652a26e`
- **Day filed:** Day-22 (2026-05-13)
- **Day merged:** Day-30 (2026-05-20)
- **Cycle time:** opened 2026-05-13T20:36Z → merged 2026-05-20T18:45:45Z (~166h / 6.9 days)
- **Final size:** +12 -6 (post-rebase final state; in-PR working tree was larger pre-rebase)
- **Bead lineage:** none — surfaced organically during Day-22 sweep

**What it did:** removed the misleading "Simple/Complex convoys" framing from `cmd_convoy.go` `Long:` description; added an explicit disambiguation paragraph stating convoys ≠ workflows.

**Merge path:** **§24b direct-merge variant** — first observed instance. Trajectory: csells `CONTRIBUTOR` APPROVED 2026-05-16T00:01Z on post-rebase HEAD `ca41269` (§24a entered — APPROVED-but-no-write-access stall). Sat for ~4.5 days. On 2026-05-20T16:13:41Z (Day-30 09:13 PT), write-access maintainer `quad341` applied `status/reviewing` label without a review body → §24a transitioned to §24b. **2h32m later, the same maintainer direct-merged the PR** at 18:45:45Z without posting a review. No nudges sent during the §24b window (anti-plan held). Distinct from the §24c `/adopt-pr` automated-review path used on #2316: §24b direct-merge skips review-body entirely on the maintainer's authority, suitable for low-risk docs-only changes.

**Status:** done, shipped. Third contribution to land upstream. **Reference proof point for the §24b direct-merge variant** of post-engagement stall resolution.

---

### PR #2316 — `fix(dolt): retry preflight when HEAD races on busy DBs in gc dolt compact` ✅

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/pull/2316
- **State:** **MERGED** by julianknutsen on 2026-05-20T14:54:23Z (07:54 PT) via merge commit `1462317e`
- **Day filed:** Day-26 (2026-05-17, ~14:33 PT)
- **Day merged:** Day-29 (2026-05-20)
- **Cycle time:** opened 2026-05-17T21:24Z → merged 2026-05-20T14:54:23Z (~65h)
- **Size:** +57 -10 (original contributor) + +102 -8 (maintainer fixup, per Adoption Review)
- **Bead lineage:** mc-1zccc2 (diagnosis) → mc-4m2da1 (fix bead, soak-pending post-merge)

**What it did:** wrapped the pre-flatten preflight gather + post-preflight HEAD comparison in a 3-attempt retry loop with jittered sleep, fixing the `mol-dog-compactor` exit-1 failures on busy `hq`. Maintainer fixup added stricter HEAD-probe error handling, tightened `awk srand()` integer format, and added test coverage for one-time HEAD movement, continuously moving HEAD, and verify-time HEAD probe failures.

**Merge path:** **`/adopt-pr` workflow.** julianknutsen committed a `fixup!` directly to the PR branch at 2026-05-20T12:53Z (no review body), second-rebased at 14:41Z to resolve a latest-base conflict ("without changing the reviewed patch"), posted a templated Maintainer Adoption Review at 14:46Z (approve; 3 findings categorized + resolved; 2 non-gating follow-up invitations), labeled `status/merge-ready` → `status/merge-queued`, and merged at 14:54Z. Contributor-side action across the whole sequence: a single thank-you comment at 06:20 PT.

**`/adopt-pr` observation → canonized as §24c on Day-30 (2026-05-20):** automated/templated adoption pathway with explicit review/adoption phases. Footer: "_Adopted via `/adopt-pr` workflow. Original contributor commits preserved._" Adoption Review categorizes findings against "claude" and "synthesis" reviewer entities — suggests AI reviewers in workflow's review pass. Day-29 close-out deferred canonization (n=1 direct); Day-30 pre-flight check (`git log --grep="adopt-pr"`) revealed n=6 visible instances (5 historical 2026-04-19 to 2026-05-05 + #2316). See `upstream-engagement-playbook.md` §24c for full protocol.

**Two non-gating follow-up invitations** (file as beads first; convert to PRs only after city-upgrade soak completes):
- Clarify retry comment: "3 total attempts; only retries HEAD movement, not transient probe failures."
- Add narrow test for top-of-loop HEAD refresh failure on retry attempt 2.

**Status:** done, shipped. Second contribution to land upstream. mc-4m2da1 stays OPEN pending city-upgrade + 24h post-install soak (Day-30 modal shape).

**Day-31 soak result (2026-05-21):** first post-upgrade fire at 08:30:38 PT, +16m past predicted 08:14–08:18 window. **Preflight retry succeeded** (would have failed under old code) — confirms #2316's fix works for the race it was scoped to. Subsequent flatten exposed a deeper race that was previously masked by the old preflight abort; the post-flatten value-hash safety net (also part of #2316) caught it cleanly with quarantine marker `.gc/runtime/packs/dolt/compact-quarantine/hq` (`post-flatten value hash changed with row-count increase`). Net: #2316 was correctly scoped; the new failure mode is captured in [[mc-jhsp8y]] for follow-up. **No regression, no hot-fix PR.**

---

### PR #2037 — `fix(packs): fallback to dolt-provider-state.json` ✅

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/pull/2037
- **State:** **MERGED** by sjarmak on 2026-05-13 (commit `e1cee04`)
- **Day filed:** Day-11 (2026-05-12)
- **Size:** 21 lines across 2 shell scripts
- **Bead lineage:** mc-ma23a9 (closed)
- **Cycle time:** opened 2026-05-12 → merged 2026-05-13T01:46Z (~32h)

**What it did:** fixed jsonl-export.sh state-file fallback path — when primary state file is missing, fall back to `dolt-provider-state.json` instead of failing.

**Status:** done, shipped. First contribution to land upstream. Reference proof point for the "honesty-first PR body + clean make check" pattern (candidate for a future playbook section; not §24 — that covers post-engagement protocols, not PR-authoring).

---

### Issue #1487 — `bug: gc events HTTP API on :8372 returns context-deadline-exceeded intermittently under load` ✅

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/issues/1487
- **State:** **CLOSED** by quad341 on 2026-05-16T12:10:35Z via merge of PR #2127 (commit `2d0e7c78`)
- **Day commented:** Day-12 era (rjgeng comment 2026-05-12T21:36Z, supportive of A3Ackerman's diagnosis)
- **Bead lineage:** none — supportive contribution
- **Fix PR:** **#2127** — `fix: bound events multiplexer provider fan-out` by julianknutsen, merged by quad341 2026-05-16T12:10:33Z (+386 -21 across `internal/events/multiplexer.go` + new `multiplexer_test.go`)

**What the fix did:** bounded events multiplexer provider fan-out so slow providers do not block healthy providers; preserved partial results and attached healthy event watchers when another provider stalls; added regression tests for ListAll, ListTail, LatestCursor, and Watch. **A3Ackerman's multiplexer-fan-out diagnosis was correct** — fix aligned with that direction.

**Status:** done, shipped. Anecdote for a future playbook section on supportive-comment engagement (not §24 — that covers post-engagement protocols on our own PRs, not supportive-comments on someone else's work): comments on someone else's issue don't drive the fix but are preserved in the closed thread and confirm we tracked the right diagnostic path independently. Detected stale during Day-27 PR-watch (tracker still listed OPEN until 2026-05-18).

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
