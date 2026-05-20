# Day 29 — PR-watch (modal) + §24 playbook note

- **Plan authored:** 2026-05-20 AM
- **Planned execution:** 2026-05-20
- **Status:** Plan stamped. AM read folded into §6 Step 1 below.

Day-29 is a **disciplined watch-day**. Day-28 closed with all three PRs and the beads release unmoved. Modal path is another PR-watch + 6th-fire observation; the Day-29 insight is **watch-day must still produce an artifact, not just passive refreshing.** That artifact is the §24 playbook note Day-28 deferred.

---

## 1. Pre-flight context

**State going in (Day-28 EOD, 2026-05-19 ~16:30 PT):**

- **PR #2316** (mc-1zccc2 fix): OPEN, `reviewDecision=""`. julianknutsen flipped `status/needs-review-auto` → `status/reviewing` at 2026-05-19T06:54:02Z. No review body in 9.5h+ at Day-28 EOD.
- **PR #2088** (convoy docs): OPEN, APPROVED by csells (CONTRIBUTOR, not write-access). 3+d post-approval idle at Day-28 EOD.
- **PR #2136** (mol-dog-jsonl push race): OPEN, single nudge 2026-05-18; let it ride.
- **Issue #3880 / beads release:** v1.0.4 still latest (10d silence on v1.0.5). mc-mxl4vc blocked.
- **mc-1zccc2, mc-4m2da1, mc-w9iua4, mc-mxl4vc:** all OPEN.

**Key Day-28 lessons rolling in:**

1. Falsifiability needs **two layers** — outward field AND underlying generator. State them both; classify as partial when they diverge.
2. Label-only timeline events sometimes bump `updatedAt`, sometimes don't. Morning-read includes an explicit timeline pull as backstop.
3. Auto-tracking-bead-per-failure is not invariant. Umbrella bead (mc-1zccc2) + events.jsonl are ground truth.
4. Mid-day Mayor restart resumed cleanly because plan + tracker were legible artifacts — propulsion principle pays off.

---

## 2. Morning read (same Day-28 template + timeline backstop)

```bash
date; gc version
for pr in 2088 2136 2316; do
  gh pr view $pr --repo gastownhall/gascity \
    --json state,reviewDecision,updatedAt,latestReviews \
    | jq '{state, reviewDecision, updatedAt}'
done
gh release list --repo gastownhall/beads --limit 3
bd list | grep -E 'mc-(1zccc2|4m2da1|w9iua4|mxl4vc|o5fhwm)'
grep '"type":"order.failed"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-20T07:00:00")) | .ts'
# Day-28 lesson #2 backstop:
gh api repos/gastownhall/gascity/issues/2316/timeline --paginate \
  | jq -r '.[] | select(.created_at >= "2026-05-19T22:00:00Z") | "\(.created_at) \(.event // "comment")"' \
  | tail -20
```

The snapshot picks the branch.

---

## 3. Decision matrix

| State read | Day-29 shape | Budget |
|---|---|---:|
| #2316 reviewed (any state) | Fix-day — pre-staged responses from Day-28 §3 findings 1-3; rebase only if explicitly asked | 60–120 min |
| #2316 merged (extreme luck) | City-upgrade pathway — bump local gascity ref, install, soak 24h, close mc-4m2da1 | 90 min + soak |
| #2136 reviewed | Fix-day on #2136 (most likely ask: `awk srand() → $RANDOM`) | 30–60 min |
| #2088 merged | Tracker move to closed; no further action | 10 min |
| Beads v1.0.5 released | mc-mxl4vc city-upgrade — symlink swap to bd 1.0.5, validate empty-DB guard | 60–90 min |
| **All idle + nothing released (modal, ~65%)** | **PR-watch + 6th-fire observation + §24 playbook note write** | 60–90 min |

**Modal reasoning:** #2316 `status/reviewing` is now ~21h stale at AM read (was 9.5h at Day-28 EOD). #2088 4d post-APPROVAL. v1.0.4 10d as latest. Inertia dominates.

**§24 playbook deliverable (modal branch):**

- **Subject:** protocol for stalled APPROVED-but-unmerged or REVIEWING-but-unsubmitted PRs against gastownhall maintainers.
- **Cases on file:** #2088 (APPROVED by non-write-access csells, 4+d idle), #2316 (REVIEWING label set by maintainer, 21h+ no body).
- **Placement decision deferred to execution** — likely new file `study/notes/upstream-engagement-playbook.md`, or §24-stamped subsection in `upstream-engagement-tracker.md`. Decide by reading what's already there.
- **Cannot ship vague.** Note must define: (a) what counts as "stalled," (b) when (if ever) to engage, (c) what to engage with, (d) when to stop tracking actively, (e) what NOT to do.

---

## 4. Falsifiable predictions (G1-G3, two-layer per Day-28 lesson #1)

- **G1 (field + generator):**
  - *Field:* PR #2316 stays OPEN with `reviewDecision=""` through 18:00 PT today.
  - *Generator:* the `status/reviewing` label reflects reviewer intent / state classification, not guaranteed active review execution timing. Therefore the label can sit indefinitely without a body landing, and absence of a body is not a rejection signal.
  - *Combined verdict rules:* both hold → SATISFIED; field holds + body lands → PARTIAL (generator still informative); body lands with merge/changes → FALSIFIED → branch B.
- **G2 (compactor fire):** 6th-consecutive `mol-dog-compactor` fire at **08:12–08:16 PT** (±2min, +1-2min/day drift continuing), exit-1, duration 23s–3min. Generator: `flatten_database()` HEAD race in production code; #2316 fix not deployed.
- **G3 (beads release):** stays at v1.0.4. Generator: 10-day silence with no public movement on the v1.0.5 milestone.

---

## 5. Anti-plans

1. **Don't re-arm `gastown.deacon`.** Day-26 confirmed subprocess stderr not captured.
2. **Don't open new PRs** unless review forces one.
3. **Don't preemptively rebase #2316** — wait for explicit ask.
4. **Don't nudge #2316** even past 24h `status/reviewing` stale. julianknutsen is the visible single maintainer and #2225's author; protocol-level wait holds.
5. **Don't second-nudge #2088.** Convert the deferred question into the §24 playbook artifact instead.
6. **Local-time prefix when greping events.jsonl** (`"2026-05-20T07:00:00"`), NOT UTC `Z`. Day-27 lesson.
7. **(New) Watch-day must produce an artifact.** If modal branch realizes, the §24 playbook note ships today. Don't let Day-30 inherit another deferred question.

---

## 6. Execution log

### Step 1: morning read (2026-05-20 03:50 PDT)

```
2026-05-20 03:50 PDT
```

PR states:

| PR | state | reviewDecision | updatedAt | delta vs Day-28 EOD |
|---|---|---|---|---|
| #2088 | OPEN | "" | 2026-05-16T00:01:45Z | unchanged |
| #2136 | OPEN | "" | 2026-05-18T11:03:58Z | unchanged |
| #2316 | OPEN | "" | 2026-05-19T06:54:02Z | unchanged (now ~21h stale on `status/reviewing`) |

Beads release: still v1.0.4. G3 holds.

Compactor fires today: none yet (fire predicted ~08:12-08:16 PT, currently 03:50 PT).

**Branch selection:** all three idle + no release → **modal branch A realized.** Day plan: PR-watch + 6th-fire observation + §24 playbook note write.

### Step 2: timeline backstop on #2316 (executed 04:15 PT)

Initial backstop with threshold `2026-05-19T22:00:00Z` (Day-28 EOD): **empty.** Sanity-check with lower threshold `2026-05-19T06:00:00Z` returned the Day-28 AM label flips at 06:12 / 06:54Z — confirms API call works, not silently failing. Read: `status/reviewing` was 22h+ stale with zero new activity. G1 generator gaining support at this point.

### Step 3: §24 playbook note (shipped 05:30–05:55 PT)

- **Tracker scan:** `§24` referenced 4× in `upstream-engagement-tracker.md` (lines 47, 112, 171, 186) but never defined. Phantom anchor.
- **Placement decision:** new file `study/notes/upstream-engagement-playbook.md` (Option A from in-session decision matrix; B = inline tracker subsection, C = extend "Maintenance protocol" both rejected — static policy and dynamic state rot when mixed).
- **§-numbering convention:** kept literal (already cited 4×; renaming = extra churn). New file preamble notes sections are append-only with expected gaps.
- **Scope of §24:** two sub-cases unified under "post-engagement stall." §24a = APPROVED by non-write-access reviewer, no merge action (ref #2088, 4d post-approval). §24b = `status/reviewing`-equivalent label set, no body submitted (ref #2316, 22h+ stale).
- **Core principle codified:** *once a maintainer has engaged, do not actively manage the engagement from our side. Acknowledgement is the contract; the maintainer owns the next step.*
- **Two loose `§24` refs** at tracker lines 173 / 186 disclaimed — they're about adjacent patterns (honesty-first PR body authoring; supportive-comment engagement), not the post-engagement stall protocol §24 defines. Marked as candidates for future playbook sections.

**Commits:**

- `af5cf3d` — `docs: add upstream-engagement-playbook §24 — post-engagement stall protocol`
- `20bd790` — `docs: tracker — link to playbook + disclaim loose §24 refs`

**Anti-plan #7 satisfied.** Watch-day produced a durable artifact.

### Step 3b — UNANTICIPATED: #2316 plan deviation (executed 05:59–06:20 PT)

Mid-morning recheck of #2316 at 05:59 PT found **major state change since AM read.**

**State delta:**

- `updatedAt`: `2026-05-19T06:54:02Z` → `2026-05-20T12:53:24Z` (~6 min before our check).
- New timeline event: `2026-05-20T12:53:24Z head_ref_force_pushed julianknutsen`.
- New PR HEAD: `01b2737c` (was `ffa66a04`). julianknutsen committed a `fixup!`-named commit directly on top of our commit and force-pushed it to our branch (he has write access on the repo).
- **No review body submitted.** `latestReviews` still contains only the errored Copilot bot review from 2026-05-17.

**Diff parse (`2ba1ee26..01b2737c`):**

| File | Change | Notable |
|---|---|---|
| `run.sh` | Algorithm header comment expanded | Adds "require HEAD to remain stable across a bounded retry loop" |
| `run.sh` | Inline comment in `flatten_database()` candidly acknowledges residual sub-ms race + quarantine as safety net | **Matches Day-28 §3 Finding 3 sub-point 1 verbatim** — we predicted exactly this acknowledgement |
| `run.sh` | Stricter HEAD-probe error handling | Replaces silent `\|\| true` with explicit return-1 on probe failure or empty HEAD probe result. Real defensive improvement we hadn't pre-staged. |
| `run.sh` | `awk srand()` format tightened | `"%.2f", 1+rand()*4` → `"%d", 1+rand()*5`. Kept `awk`, didn't swap to `$RANDOM`. **Day-28 §3 Finding 3 sub-point 2 predicted the nit; didn't predict he'd fix it himself rather than ask.** |
| `dog_exec_scripts_test.go` | Rewrote his own `TestCompactScriptCompactsWhenHeadChangesBeforeFlatten` (originally from #2225) | New name + semantics: `TestCompactScriptAbortsWhenHeadKeepsMovingAcrossPreflightRetries`. Flipped from "tolerate moving HEAD" → "abort after bounded retries" |
| `dog_exec_scripts_test.go` | Added `TestCompactScriptRetriesPreflightWhenHeadStabilizes` | Happy-path retry coverage |
| `dog_exec_scripts_test.go` | Added `TestCompactScriptFailsWhenPreflightHeadVerifyProbeFails` | Proves probe-failure not mis-reported as HEAD movement |

**G1 verdict (final):** **FALSIFIED in an unusual shape.**

- *Field layer:* #2316 still OPEN, `reviewDecision=""` — literally both still hold. He didn't submit a review, so `reviewDecision` stays empty.
- *Generator layer:* "label reflects reviewer intent/state classification, not guaranteed active review execution timing" — also still informative; the label sat 22h+ before he acted.
- *But:* the predicted **Branch B trigger** (review body lands → fix-day with pre-staged responses) was bypassed entirely. He skipped the review-body step and just made the changes himself.
- *Net classification:* G1 falsified because the underlying assumption ("PR sits because reviewer hasn't found execution time") was wrong — execution time existed; he simply chose a different action than the model anticipated.

**Action taken (06:20:14 PT):** posted single-line thank-you comment per §24 spirit (acknowledge without requesting, no further work surfaced):

> "Thanks for the fixup — the stricter HEAD-probe error path and the additional retry/probe-failure test coverage are real improvements. Looks good on my end; ready to merge whenever you are."

Posted as `rjgeng` via `gh pr comment 2316`. Comment ID `4498806241`. URL: https://github.com/gastownhall/gascity/pull/2316#issuecomment-4498806241

**Anti-actions held:**

1. **Did NOT force-push to squash the `fixup!`** — GitHub's "Squash and merge" handles collapse at merge time. Force-pushing mid-review would be the exact behavior §24b anti-rule #2 warns about (even though that rule was written about us-the-contributor, the spirit applies symmetrically here).
2. **Did NOT raise the PR-body factual error** (Day-28 §3 Finding 1 — body claimed #2225 "removed the prior HEAD-check"; verified false against pre-#2225 source). He saw the body; chose not to raise it. Dropping from our side too.
3. **Did NOT review-grade his test rewrite analytically.** Comment stayed neutral — mentioned two concrete improvements, didn't critique the test-semantics flip or attempt to "approve" his code.
4. **Did NOT ask "should I do anything?"** in the comment. Re-opens the door, which was the entire failure mode §24's core principle is structured to prevent.

**Process lesson (candidate for EOD close-out → future playbook addition):**

Maintainer-direct-commit is a **third post-engagement state** that §24 doesn't currently cover. The §24 sub-cases are:

- §24a: APPROVED + idle (waiting for write-access merge action)
- §24b: REVIEWING acknowledged + no body submitted (waiting for review)
- **§24c-candidate:** maintainer commits a fixup directly to our branch (waiting for merge of his version)

§24c shifts the contract: the maintainer has made the changes themselves. Our acknowledgement + non-interference is the same as §24b, but the response template differs (thank-you for *his contribution*, not "ready when you are" on *our work*). Note for a future playbook section after at least one more observation of this pattern (one data point isn't a pattern).

**Pattern signal worth capturing:** the conditions that enabled §24c here likely include — small surgical diff (~80 lines), maintainer with deep ownership of the affected function (julianknutsen wrote #2225), trusted contributor record (PR #2037 already merged), and a `priority/p1` auto-tag that probably nudged maintainer queue priority. These together may have made "just make the changes" cheaper than "round-trip review." Worth re-observing before generalizing.

### Step 4: 6th-fire observation (executed 08:19 PT)

```
seq 612481 order.fired   2026-05-20T08:14:09.887087-07:00 mol-dog-compactor
seq 612614 order.failed  2026-05-20T08:17:07.739155-07:00 mol-dog-compactor "exit status 1"
```

| Metric | Prediction | Observed | Verdict |
|---|---|---|---|
| Fire window | 08:12–08:16 PT (±2min) | 08:14:09 PT | ✓ in band |
| Exit status | exit-1 | exit status 1 | ✓ |
| Duration | 23s–3min | 2m58s | ✓ upper edge |

**G2 SATISFIED.**

**Drift anomaly worth flagging:**

| Day | Fire ts | Δ vs prior |
|---|---|---:|
| 5/17 | 08:07:20 | — |
| 5/18 | 08:09:17 | +1m57s |
| 5/19 | 08:10:51 | +1m34s |
| **5/20** | **08:14:09** | **+3m18s** |

5/20 jump is ~2× the prior daily drifts and outside Day-28's "+1–2min/day" model. Three interpretations (most likely first):

1. **Noise widening.** 3-point drift model widens with a 4th sample; not necessarily a real shift.
2. **Scheduling-layer drift change.** Controller / cron / order-firing config could have shifted between 5/19 and 5/20.
3. **Contemporaneous-load coupling.** Today's pre-08:00 hq write load might have queued the fire behind something else.

**Action: flag-but-don't-investigate.** 4 samples is too thin to chase. If 5/21 shows another outlier OR a reversion to ~+1-2min/day, that data point will clarify which interpretation is right. Adding to Day-30 morning-read attention.

**Lesson candidate:** drift models built from 3 points are fragile. The "+1-2min/day" framing in Day-28's process lesson #3 ("drift model needs ±2min tolerance, not point estimate") was about tolerance for predictions, not stability of the underlying drift rate itself. They're different concerns — tolerance is per-prediction; rate stability is meta-model.

### Step 5: EOD recheck + tracker update (executed 08:40 PT)

**Final state read:**

| PR | state | reviewDecision | updatedAt | delta vs mid-morning |
|---|---|---|---|---|
| #2088 | OPEN | "" | 2026-05-16T00:01:45Z | unchanged (§24a, day 5 post-approval) |
| #2136 | OPEN | "" | 2026-05-18T11:03:58Z | unchanged (day 3 post-nudge) |
| #2316 | **MERGED** | "" | 2026-05-20T14:54:39Z | **MERGED 14:54:23Z (07:54 PT)** |

Beads release: v1.0.4. G3 satisfied.

**#2316 merge timeline (14:41–14:54Z = 07:41–07:54 PT):**

- 14:41:16Z — julianknutsen second force-push: rebased to resolve latest-base conflict; per Adoption Review, "without changing the reviewed patch."
- 14:46:07Z — Maintainer Adoption Review comment posted (templated, `/adopt-pr` workflow).
- 14:46:51Z — `status/merge-ready`.
- 14:47:16Z — `status/merge-queued`; `status/reviewing` removed.
- 14:54:23Z — merged via commit `1462317e`; closed.
- 14:54:39Z — `status/merge-queued` removed.

**Maintainer Adoption Review (essentials):**

- Decision: approve.
- 3 findings categorized + resolved (Concurrency/Ordering/State Safety; Test Evidence Quality; Debuggability/Operability).
- 2 non-gating follow-up invitations:
  - Clarify retry comment: "3 total attempts; only retries HEAD movement, not transient probe failures."
  - Add narrow test for top-of-loop HEAD refresh failure on retry attempt 2.
- 2 review passes performed by maintainer.
- Footer: "_Adopted via `/adopt-pr` workflow. Original contributor commits preserved._"

**`/adopt-pr` observation:** the workflow is automated and templated. Reframes §6.3b's "maintainer-direct-commit" as an instance of a documented adoption pathway, not an ad-hoc choice. Per pre-set constraint, treated as observed interaction shape; insufficient samples (n=1) to canonize as §24c. Defer.

**Tracker updates (batched into this close-out commit):**

- Move #2316 from Active items → Closed / merged items
- Counters: PRs merged 1 → 2; PRs awaiting maintainer 3 → 2
- Update Last updated header
- Brief anecdote on `/adopt-pr` observation under Closed / merged items section (observation, not policy)

### Step 6: Day-30 punt

**EOD state (08:40 PT):** #2316 merged; #2088 + #2136 + beads release all unchanged.

**Day-30 shape (modal: city-upgrade-day, ~75%):**

- Pull merged `gascity` ref, install locally, start 24h soak on mol-dog-compactor.
- Budget: 60–90 min execution + 24h passive soak.
- Branch B (~15%): install reveals issues → bounded-scope debug-day.
- Branch C (~5%): #2136 or #2088 moves overnight → fold into morning shape.
- Branch D (~5%): unforeseen.

**Anti-plans for Day-30:**

1. Don't file the two non-gating follow-ups as PRs immediately — they're invitations, not asks. File as beads first; convert to PRs only after soak completes.
2. Don't canonize §24c yet. n=1 is one data point.
3. Don't investigate the drift anomaly. 5/21 fire timestamp will inform.
4. Don't second-nudge #2088 or #2136. §24 holds.
5. Watch #3880 / beads v1.0.5 per usual cadence.

---

### G1-G3 verdicts (EOD)

- **G1 (#2316 OPEN + reviewDecision="" at 18:00 PT; generator: label = state classification, not execution timing):** **FALSIFIED.** PR merged at 07:54 PT. Field-layer text was literally true for most of the day; generator-layer assumption ("PR sits because reviewer hasn't found execution time") was wrong from 12:53Z onward. Maintainer used `/adopt-pr` workflow rather than the review-body path the prediction modeled.
- **G2 (6th-fire ~08:12–08:16 PT, exit-1, 23s–3min):** **SATISFIED.** Fire 08:14:09 PT, fail 08:17:07 PT, 2m58s, exit status 1. Drift anomaly +3m18s vs prior day logged but not interpreted.
- **G3 (beads stays at v1.0.4):** **SATISFIED.**

### Surprises

1. **`/adopt-pr` is a workflow, not freelancing.** §6.3b interpreted the fixup as an ad-hoc choice; the Adoption Review reveals it's a templated automated process. Changes the future-pattern question from "do maintainers sometimes commit directly?" to "how often does `/adopt-pr` trigger?"
2. **Adoption Review categorized findings against "claude" and "synthesis" reviewer entities.** Suggests AI reviewers in the workflow's review pass. Useful context for future PR submissions; not material to comment on publicly.
3. **Drift anomaly +3m18s** (Step 4) sits outside the +1–2min/day model. n=4 is too thin to interpret.
4. **Two non-gating follow-up invitations** in the Adoption Review are a different actionability tier than blocking review feedback — explicit "future PR welcome" signals.

### What the day actually produced

- §24 playbook canonicalized (`upstream-engagement-playbook.md`, `af5cf3d`)
- Tracker pointer + 2 loose §24 refs disclaimed (`20bd790`)
- Thank-you comment on #2316 (06:20 PT, ID `4498806241`)
- 6th compactor fire datum captured (G2 satisfied, drift anomaly flagged)
- #2316 merged with no contributor-side action between thank-you and merge
- Anti-actions held: no force-push to squash fixup, no review-grade comment on the test rewrite, no PR-body factual-error escalation

### Process lessons captured

1. **G falsification can be field-true while generator-wrong.** G1 field assertion held literally until 14:54Z, but the model of "why the PR sits" was wrong from 12:53Z onward. Day-28 lesson #1 (two layers) is necessary but not sufficient — also need a rule for which layer dominates the verdict. Memory candidate: `feedback_g_verdict_layer_priority.md`.
2. **`/adopt-pr` exists and is templated.** Future PR sizing: small surgical PRs against well-owned code paths may take the adoption path, bypassing iterative review. Doesn't change PR-authoring approach; informs expectations about response shape.
3. **Maintainer rebases differ from contributor rebases.** Per Adoption Review, second force-push at 14:41Z resolved latest-base conflict "without changing the reviewed patch." Templated review told us directly; otherwise we'd reverse-engineer from diff scan.
4. **Two-stage observation paid off.** Mid-morning recheck (05:59 PT) caught the first force-push 6 min after it landed; EOD recheck (08:40 PT) caught the merge 46 min after it landed. Single-point AM observation would have missed both.
