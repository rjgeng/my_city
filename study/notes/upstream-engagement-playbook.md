# Upstream Engagement Playbook

Static rules and patterns for working with upstream maintainers on `gastownhall/*` repos. Counterpart to `upstream-engagement-tracker.md`, which holds dynamic per-item state.

**Convention:** sections are append-only, numbered for stable references (`§N`). New patterns get the next free number. Numbering may have gaps — gaps are expected (placeholders for rules that exist informally but haven't been canonicalized yet). When the tracker or a note cites `§N`, this file is the canonical anchor.

---

## §24 — Post-engagement stall protocol

**Stall definition:** a PR has received *some form of maintainer acknowledgement* but has not progressed toward merge or explicit decision for longer than the repo's typical cadence allows. Distinct from pre-engagement silence (no maintainer touch yet) — that's §-TBD on the nudge cadence, partially captured in tracker's "When considering a nudge" section.

**Core principle:** once a maintainer has engaged, **do not actively manage the engagement from our side**. Pressure at this stage is asymmetric — it costs us nothing to wait, and adds friction to a maintainer who has already signaled they're aware. Acknowledgement is the contract; the maintainer owns the next step. Our job is to be ready when they return, not to chase.

Two sub-cases observed in the wild:

---

### §24a — APPROVED but unmerged (non-write-access reviewer)

**Trigger:** a reviewer with `authorAssociation: CONTRIBUTOR` (or any non-write-access role) submits an `APPROVED` review. `reviewDecision` remains empty on `gh pr view` because GitHub only honors approvals from write-access reviewers for the decision field. Merge still requires a write-access maintainer to act.

**Reference case:** PR #2088 — csells APPROVED 2026-05-16T00:01Z; 4+ days post-approval idle as of Day-29; no write-access maintainer (e.g. sjarmak, quad341) has touched it.

**Wait / engage protocol:**

| State | Action |
|---|---|
| 0–48h post-APPROVAL | Wait. APPROVAL is meaningful peer signal; let it sit in the maintainer queue. |
| 48h–7d post-APPROVAL | **Still wait.** Do not nudge — the pre-approval nudge protocol has already been spent (1 nudge total per PR lifetime). |
| 7d+ post-APPROVAL | Re-evaluate at the **tracker level**, not the PR level. Open a meta question: is this repo's merge cadence genuinely this slow, or is this PR specifically stuck? If specifically stuck, the unblock path is *not* a second nudge on this PR — it's reading nearby merged PRs to understand the actual merge-decision route, then deciding whether the PR is worth keeping open. |
| Indefinite | The PR may simply sit. That is an acceptable outcome — the engagement was real, the work is preserved, and silently sitting is not a rejection. |

**What to engage with (if a maintainer eventually returns):** address inline, push to same branch, do not re-open the approval question — the APPROVAL is durable across force-pushes unless the reviewer says otherwise.

**When to stop tracking actively:** never *stop* tracking (the row stays in the tracker), but downgrade from per-day re-checks to weekly snapshots after 7d post-APPROVAL. Add a calendar-aligned "monthly stale-PR sweep" as a recurring obligation on the tracker if this ever accumulates to 3+ items.

**Anti-rules:**

1. **Do not second-nudge.** The contributor approval is itself a soft escalation; piling another nudge on top reads as pressure on the wrong audience (the maintainer who hasn't engaged yet, not the reviewer who already did).
2. **Do not @-mention a specific maintainer** to ask for merge. That breaks the queue model and selects against future engagement.
3. **Do not close-and-reopen** to "bump" the PR. It's transparent and aggravating.
4. **Do not rebase preemptively** unless the PR is genuinely stale against `origin/main` and CI is failing because of it. A clean rebase on a working PR adds noise without changing the merge decision.

---

### §24b — REVIEWING acknowledged, no body submitted

**Trigger:** a maintainer applies a `status/reviewing` label (or equivalent — e.g. self-assigns as reviewer, posts a "I'll take a look" comment without substance) but no review body, request-for-changes, or approval lands within the typical review-completion window.

**Reference case:** PR #2316 — julianknutsen swapped `status/needs-review-auto` → `status/reviewing` at 2026-05-19T06:54Z; no body submitted in the 22h+ since (as of Day-29 AM).

**Interpretation of the label:** the `status/reviewing` (or equivalent acknowledgement) reflects **reviewer intent / state classification, not guaranteed active review execution timing**. A reviewer may flip the label and then context-switch to another priority, get pulled into a meeting, draft a long review offline, or simply forget. None of these states are visible to us. The label is a queue-management artifact, not a commitment to a deadline.

**Wait / engage protocol:**

| State | Action |
|---|---|
| 0–24h since `status/reviewing` flip | Wait. Reviewer may be actively reading. Any comment from us during this window is direct interference. |
| 24h–72h since flip | **Still wait.** The label may simply persist across the reviewer's other work. No nudge. |
| 72h+ since flip with zero body / comments / further label movement | Re-evaluate. Read maintainer's recent activity (`gh api users/<login>/events`) to distinguish "context-switched away from open-source for the week" (wait longer) from "active on the repo but not on this PR" (single polite "happy to walk through the diff if useful?" comment is *defensible*, not *required*). |
| Reviewer ships review body | Branch out per Day-28 §3 pre-staged response model: prep responses to likely angles cold; do not preempt with self-corrections during the review window. |

**What to engage with:** once the body lands, address every actionable point in a single push to the same branch. Acknowledge non-actionable comments inline ("good point, kept current shape because X" or "agreed, will fix"). Do not bundle unrelated changes.

**When to stop tracking actively:** when either (a) the review body lands and is addressed, or (b) the label is removed without a body (silent reviewer-disengagement — rare, but a signal to wait further, not nudge). The PR row stays active in the tracker either way until merged or closed.

**Anti-rules:**

1. **Do not preempt with self-corrections during the review window.** Even when we know the PR body has a factual error or a likely-questioned design choice, posting "BTW I realized X" mid-review reads as anxious and forces the reviewer to re-thread. Stage the response cold; let them raise it; respond when they do.
2. **Do not refactor or push to the branch** while `status/reviewing` is active. A force-push mid-review can reset comment threads on outdated lines and frustrate the reviewer.
3. **Do not @-mention the reviewer** to ask for status. The label IS the status.
4. **Do not start a parallel PR** with "an improved version." Compete with yourself on a different branch if you must, but don't fragment the maintainer's attention.

---

### §24 — Common rules (apply to both sub-cases)

- **Cold prep-read is the only legitimate "active" work** during a post-engagement stall. Read related PRs, anticipated review angles, and adjacent code. Stage responses internally; do not publish them. (Day-28 §3 is the template — three findings, posture per finding, no comment posted.)
- **The bead behind the PR stays OPEN** until merge + post-install soak confirms the fix. PR state is not bead state.
- **A stall is not a rejection.** Filing a stall under "this didn't work" is wrong framing; it under-counts engagement and biases future contribution decisions toward shorter, lower-value PRs.
- **A stall is also not a "win to defend."** Resist the temptation to post a "still relevant" comment to keep the PR warm. The PR's relevance lives in its diff, not in its activity timestamp.

---

### §24 — Where this is cited

Synced 2026-05-20 (Day-29 EOD) after PR #2316 merge moved its tracker entry to Closed/merged:

- `upstream-engagement-tracker.md` line 7 — header pointer to this playbook.
- `upstream-engagement-tracker.md` line 49 — PR #2088 next-actions (active §24a citation).
- `upstream-engagement-tracker.md` line 144 — PR #2316 Closed entry notes `/adopt-pr` as a §24c candidate (deferred until n≥2 observations).
- `upstream-engagement-tracker.md` line 166 — PR #2037 retrospective disclaims §24 attribution ("honesty-first PR body + clean make check" is a future-section candidate).
- `upstream-engagement-tracker.md` line 181 — Issue #1487 retrospective disclaims §24 attribution (supportive-comment engagement is a future-section candidate).

Historical: an earlier §24b citation lived at tracker line 112 (PR #2316 next-actions, "If silent at 48h: leave a brief 'any thoughts?' comment per §24 playbook"). When PR #2316 merged on Day-29 via `/adopt-pr`, the entry moved to Closed/merged and dropped the next-actions block, removing that citation. §24b still governed the day's behavior; the literal text is no longer in the tracker.
