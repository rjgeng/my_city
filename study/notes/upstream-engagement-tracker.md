# Upstream Engagement Tracker

A living tracker for all upstream issues, PRs, and contributions to `gastownhall/*` repos. Update inline as state changes; commit each meaningful update.

**Last updated:** 2026-05-31 (Day-41 — **dolthub/dolt#11131 RESOLVED**: root cause confirmed (schema-side encoding drift, *not* data corruption), **fixed in dolt v2.1.0**; all 2.x <2.1.0 being **recalled**; agent-produced, dolthub-unvetted repair tool on branch `zachmu/schema-repair-tool`. **gascity#2814**: julianknutsen posted an upstream-escalation status (matches dolt root cause); the PR offer is still unaddressed → **§24 HOLD continues**, and the premise shifted — the recall covers 2.0.7 too, so the correct guard is `ManagedMin → 2.1.0`, not a 2.0.8 block. Recovery scout (read-only): **2.1.0 alone does NOT recover my-city**; `migrate-adaptive` (the `dolt_ignore` force-inline path) is required — full assessment in `study/notes/2026-05-31-day41-schemadrift-scout-findings.md`. **mc-jhsp8y soak still PAUSED.** PR #2136 still §24a wait-only.)

**Prior update:** 2026-05-30 (Day-39 PM — **gascity#2814 triaged `priority/p0`** by maintainer julianknutsen ~32 min after filing. Two upstream bug issues filed for the dolt 2.0.8 wisp-corruption regression: **dolthub/dolt#11131** (root cause; first filing on a non-gastownhall repo) + **gastownhall/gascity#2814** (consumer; pin dolt 2.0.4, now **P0**), cross-linked. **mc-jhsp8y soak PAUSED** — the same corruption bricked my-city's controller; full recovery record in `study/notes/adr/0003-dolt-2.0.8-wisp-corruption-recovery.md`. PR #2136 still §24a wait-only.)

**Scope note (Day-39):** tracker now spans `dolthub/dolt` as well, since the root-cause defect that hit gascity lives in the bundled dolt engine.

**Static rules:** see `upstream-engagement-playbook.md` (`§24` = post-engagement protocols — §24a APPROVED stall, §24b REVIEWING stall, §24c `/adopt-pr` adoption; future sections append-only).

---

## Counters

| Metric | Value |
|---|---|
| Total engagements | 8 (4 PRs + 2 issue comments + 2 filed bug issues) |
| PRs opened | 4 |
| PRs merged | 3 (#2037, #2316, #2088) |
| PRs awaiting maintainer | 1 (#2136) |
| Issues commented (downstream-symptom data) | 2 (#1487 ✅ resolved by upstream PR #2127, beads-#3880 still OPEN) |
| Bug issues filed (authored) | 2 (dolthub/dolt#11131 root cause — **RESOLVED in dolt v2.1.0, Day-41** + gastownhall/gascity#2814 consumer, OPEN/P0 — Day-39 dolt-2.0.8 wisp corruption) |
| Engagement cadence | ~1 per 3.8 days (since Day-11) |
| Local-only beads (linked to upstream items) | 4 active (mc-w9iua4 → #2136 awaiting upstream; mc-mxl4vc awaiting beads v1.0.5; mc-4m2da1 awaiting city-upgrade soak post-#2316 merge; mc-jhsp8y in-flatten race exposed Day-31 — soak for race-frequency characterization) |
| Repos touched | 3 (gascity, beads, dolt) |

---

## Active items

### Issue #11131 (dolthub/dolt) — `Dolt 2.0.8: adaptive out-of-line TEXT written via migration is unreadable — "invalid hash length: 19" (regression vs 2.0.4)`

- **Repo:** `dolthub/dolt` (⚠️ **first non-gastownhall repo** — the defect is in the bundled dolt engine, not gascity)
- **URL:** https://github.com/dolthub/dolt/issues/11131
- **State:** **RESOLVED** — filed 2026-05-30; **fixed in dolt `v2.1.0`** (released 2026-05-31); all 2.x releases prior to 2.1.0 being **recalled**.
- **Day filed:** Day-39 (2026-05-30); **Day resolved:** Day-41 (2026-05-31)
- **Type:** bug **issue**, not a PR — the defect is in the dolt engine; we cannot PR a fix, so this is a root-cause report (+ private data-dir / bisect offer).
- **Bead lineage:** ADR-0003 (recovery record); [[mc-jhsp8y]] soak **PAUSED** by this corruption; dedicated tracking bead **DEFERRED** (bd writes blocked by the same bug).
- **Companion:** gascity#2814 (consumer-side; cross-linked both ways).
- **Last action by us:** filed + title tightened (rjgeng, 2026-05-30); posted a **control-finding comment** (gastownhall-logs: same 2.0.8 + same migration, only inline values → unaffected; isolates the bug to the out-of-line path) — https://github.com/dolthub/dolt/issues/11131#issuecomment-4584582261. **Day-41: no further action by us — dolthub resolved it without needing our data dir.**
- **Maintainer activity (Day-41, 2026-05-31):** reltuk + zachmu **confirmed the repro and root cause** — schema corruption, *not* data: `TEXT→LONGTEXT` ALTER skipped a required row rewrite because the storage *encoding* changed (`StringAddrEnc → StringAdaptiveEnc`) even though SQL-type widening looked rewrite-free. **zachmu: fixed in `v2.1.0` (releasing now); all 2.x <2.1.0 recalled.** Schema-repair tooling (`dolt admin schema-encoding-drift` — check/repair/recover-rows/migrate-adaptive) shipped on branch `zachmu/schema-repair-tool` — explicitly *agent-produced, not yet fully vetted, not in any public release; back up `.dolt` first*. timsehn flagged our exact case: wisps are dolt-ignored, so the self-service `dolt reset` route does NOT apply → the tool is required.

**What it reports:** dolt 2.0.8 (go-mysql-server `20260528`) wrote on-disk adaptive `longtext` values in `hq.wisps` that no engine can read back — every decode panics `invalid hash length: 19` (`AdaptiveValue.convertToTextStorage` → `hash.New`: a 19-byte buffer where a 20-byte out-of-line hash is expected). The writer can't read its own output and 2.0.4 can't either → write-side corruption, regression vs 2.0.4.

**Dup-search (Day-39):** negative in dolthub/dolt + go-mysql-server. Related-not-dup: dolt **#11095** (TextStorage `REGEXP_REPLACE` panic, closed 2026-05-22 — same `val.TextStorage` subsystem, just before the `20260528` build).

**Repro:** **NEGATIVE in pure dolt 2.0.8** (insert→1 MB, `INSERT…SELECT`, `ALTER ADD COLUMN`, cross-version read all clean). Trigger narrowed to beads' nonlocal-table migration write path. Offered the corrupted data dir privately + a `20260519→20260528` bisect.

**Next action (recovery is now a LOCAL track — the upstream issue is resolved):**
- [x] ~~Watch for maintainer triage~~ — resolved Day-41 (fixed in 2.1.0).
- [ ] **G-a (gating UNKNOWN): is `hq.wisps` keyless?** `migrate-adaptive` refuses keyless tables — if so, none of the 3 write paths work → need direct dolthub guidance. Determine via the tool's own `check` (never panics), not a raw `SELECT`.
- [ ] **Decide** *wait-for-vetted-release* vs. *run the branch tool* under gates G-b (2.1.0+branch binary built without disturbing the 2.0.4 guard symlink), G-c (explicit auth + verified 5.7G backup), G-d (accept the unvetted tool on postgres-tier wisp data). Recommendation leans wait-for-vetted-release / dolthub sign-off.
- [ ] Once wisps recovered → resume the mc-jhsp8y soak; append the deferred bead notes; file the tracking bead.

**Risk / watch:** the resolution is clean, but execution risk has shifted to *recovery*: the repair tool is dolthub-unvetted, and the keyless question (G-a) could block all three write paths. Do NOT run any write path without G-a resolved + auth + verified backup (anti-plans #28/#29).

---

### Issue #2814 (gastownhall/gascity) — `Bundled dolt 2.0.8 corrupts hq.wisps on upgrade → city bricks; pin to 2.0.4`

- **Repo:** `gastownhall/gascity`
- **URL:** https://github.com/gastownhall/gascity/issues/2814
- **State:** OPEN — filed 2026-05-30; **triaged `priority/p0` + `kind/bug`** by maintainer **julianknutsen** at **2026-05-30T20:40:04Z** (~32 min after filing; `status/needs-triage` bot label cleared; no comment).
- **Day filed:** Day-39 (2026-05-30)
- **Triage signal:** a trusted maintainer (same one who adopted PR #2316) reached **P0** in ~32 min with no pushback — strong validation that the report landed as serious. P0 rationale (self-evident, not stated): silent data corruption × unrecoverable × triggered by routine `gc upgrade` × full city outage × ships to all users via the bundled-dep bump.
- **Type:** bug **issue** (consumer-side; asks to pin/revert the bundled dolt).
- **Bead lineage:** ADR-0003; [[mc-jhsp8y]] soak **PAUSED**; tracking bead **DEFERRED**.
- **Companion:** dolt#11131 (root cause; linked in the body).
- **Last action by us:** filed + body backfilled (rjgeng, 2026-05-30); **§24 HOLD on PR escalation** — julianknutsen self-assigned, so instead of racing a competing PR, posted the drift diagnosis + a PR offer: https://github.com/gastownhall/gascity/issues/2814#issuecomment-4584822321
- **Drift diagnosis (offered, not yet a PR):** `internal/doltversion/doltversion.go` `ManagedMin = "2.0.7"` is a **floor** (`CheckFinalMinimum` rejects only pre-release + below-min), so 2.0.8 ≥ 2.0.7 floats through; installed version comes from Homebrew `depends_on "dolt"` (latest). Engine builds: 2.0.4=`20260519` (good), 2.0.7=`20260526` (**pre-regression, intended pin safe**), 2.0.8=`20260528` (bad). **Minimal fix:** known-bad block on the `20260528`/2.0.8 engine, keep the floor. PR prepared in concept only — NOT branched/built (hold).

**What it reports:** the Day-38 `gc upgrade` (HEAD-fad5d3f→8d6d6bb) pulled bundled dolt 2.0.4→2.0.8; the next wisp nonlocal-table migration under 2.0.8 corrupted `hq.wisps` (unreadable adaptive TEXT), bricking the controller (snapshot load → wisp search → panic) and blocking bd writes. Unrecoverable by dolt downgrade or surgery (wisp tables are nonlocal/federated). **Recommendation:** pin/revert bundled dolt to 2.0.4 until dolt#11131 lands; flags the 2.0.7-pinned-but-2.0.8-shipped discrepancy; suggests a pre-migration backup + a post-write decode preflight.

**Dup-search (Day-39):** negative in gastownhall/gascity (#2615 managed-dolt heap, #2735 headless-city — both unrelated).

**Day-41 maintainer activity (2026-05-31):** julianknutsen posted an **upstream-escalation status** comment (matches dolt's confirmed root cause; links the dolt#11131 repro + introduction-trace comments). He did **NOT** address rjgeng's PR offer → §24 HOLD continues; **no nudge, no competing PR** (anti-plan #27). **No comment posted by us today** — he owns the floor and already knows about 2.1.0/recall.

**Premise shift (Day-41):** the prepared "block known-bad 2.0.8, keep the 2.0.7 floor" PR is now **partly OBE** — dolt is recalling *everything* <2.1.0, including 2.0.7. The correct guard is `ManagedMin → 2.1.0` (once the Homebrew formula ships it), not a narrow 2.0.8 block. Owner sets the floor; we hold.

**Next action:**
- [x] ~~Watch for maintainer triage~~ — done: **P0** by julianknutsen 2026-05-30T20:40Z.
- [x] ~~Posted drift diagnosis + PR offer~~ (2026-05-30; §24 hold since julianknutsen self-assigned).
- [x] ~~Await julianknutsen's response~~ — Day-41: he posted escalation status (did not address the PR offer). **Still HOLD.**
- [ ] If he greenlights / stalls → send the floor-bump PR (now `ManagedMin → 2.1.0`, not a 2.0.8 block; body refs #2814 + dolt#11131, STOP-before-`pr create`). If he ships his own floor bump → verify it lands on 2.1.0 + cross-link.
- [ ] Track when the gascity Homebrew formula / bundled-dep bump moves to dolt 2.1.0 (the recall makes this likely imminent).

**Risk / watch:** low — concrete consumer ask, clear root cause now fixed upstream. Main remaining question is whether the maintainer bumps the floor to 2.1.0 himself or invites the PR.

---

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
