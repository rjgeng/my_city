# Day 11 — First upstream PR: lifecycle, learning, and the contributor path forward

- **Plan authored:** 2026-05-12 (after opening PR #2037)
- **Planned execution:** 2026-05-13 onward (rolling — depends on maintainer response)
- **Status:** Plan only; PR submitted, awaiting first review

This is the pre-decomposition for Day-11: a different shape than Days 5-10. Those were technical investigations or controlled experiments. Day-11 is **process + learning capture** — managing the lifecycle of an open PR, codifying the contributor workflow so future PRs are easier, and marking the career-transition milestone explicitly.

The technical work that led here (Days 5-10) is done. The skill that activates now is **responsive open-source collaboration** — a fundamentally different muscle from the diagnostic + manual-correction rhythm.

---

## 1. The signal — what we're working with

- **PR #2037** at <https://github.com/gastownhall/gascity/pull/2037>
- Branch `rjgeng/fix/dolt-pack-script-state-fallback` on fork `rjgeng/gascity`
- Local submodule sits at commit `48191657` (rebased), submodule pointer in `my-city` intentionally dirty
- Status as of plan-write: 5 required CI checks pending maintainer approval; branch flagged "out-of-date with base" but cleanly mergeable; merge blocked (maintainer-only privilege)
- **Career signal**: this is the user's first upstream OSS contribution, transitioning from hardware tech into software engineering. The contribution itself is small (21 lines, shell-only), but the *act of doing it cleanly* — fork, rebase, lint, test, conform-to-template, public-PR — is the actual deliverable.

---

## 2. Pre-flight: where this lives

- The PR is *public* now. Anything we push to `fork/rjgeng/fix/dolt-pack-script-state-fallback` automatically updates the PR. Caution: don't push unrelated work to this branch.
- `gh pr view 2037 --repo gastownhall/gascity` checks status from CLI; `gh pr checks 2037 --repo gastownhall/gascity` shows CI state.
- GitHub will email on activity (comments, status changes, labels). Email notifications are the primary signal channel; don't poll.
- The two-state-files architecture that motivated this PR is now fully documented in v2 manual §22, with the Day-7+8+9+10 premise-falsification trail intact. If a maintainer asks "what made you write this," the answer lives in `study/notes/2026-05-12-mc-ma23a9-dolt-state-filename-fix.md`.

---

## 3. What "done" looks like (success criteria)

Three layered goals:

**Process learning (the durable deliverable):**

- A documented contributor workflow lives in v2 manual as new §24 "Upstreaming a Gas City fix: the contributor playbook." Captures the seven concrete steps (rebase, test, fork, push, PR-template-conform, monitor, iterate).
- The "premise-falsification" habit (§22) extends naturally into "verify your PR's testing claim isn't survivorship-biased either" — Day-10's surprise carried over.

**PR outcome (any of these three is fine):**

- **Merged cleanly** within Day-11's bounded watch window (24-72h). Best case.
- **Maintainer feedback received** and one iteration cycle completed. Demonstrates the iteration workflow concretely.
- **Pending with no response** at end of window. Document the wait; check `gh pr checks` periodically; don't poke.

**Personal milestone (worth marking explicitly):**

- Memory updated: user identity now includes "transitioning hardware → software; first OSS PR landed at gastownhall/gascity#2037 on 2026-05-12." Useful context for future sessions where the user references this work.

---

## 4. Execution plan — rolling, not linear

Day-11 is the only plan so far that doesn't have a strict end-of-day boundary. The PR lifecycle could last hours or weeks; the *learning capture* is done by end of day, but the *PR resolution* is whenever it happens.

### Step 1: Observation rhythm (~5 min today, then passive)

- Bookmark <https://github.com/gastownhall/gascity/pull/2037> in browser
- Verify email notifications are enabled for the upstream repo (the fork itself doesn't matter for PR comments — they fire from `gastownhall/gascity`)
- Establish a check cadence: **once per day** is plenty. Resist the urge to refresh.

```bash
# Quick CLI status — won't email maintainers, runs against gh's cached API
gh pr view 2037 --repo gastownhall/gascity
gh pr checks 2037 --repo gastownhall/gascity
gh pr comments 2037 --repo gastownhall/gascity   # if comments thread exists
```

### Step 2: Decide on the "out-of-date" warning (~10 min if rebasing, 0 if waiting)

The screenshot at PR-open time flagged "branch out-of-date with base, cleanly merged-able." Two paths:

- **Wait**: maintainers often update the branch themselves at merge time. No risk.
- **Be proactive**: rebase locally onto current `origin/main`, force-push. Cleaner. The force-push is normal on PR branches and doesn't surprise maintainers, BUT it invalidates any in-progress review they might be doing.

**Recommendation:** wait until either (a) the PR sits for 24h with no activity, then update proactively, or (b) a maintainer says "please rebase." Don't force-push while review is plausibly in flight.

### Step 3: Bounded watch window (24-72h) for feedback (~5 min/day passive)

Sample patterns:

- **No response in 24h**: still normal. Open-source review cadence is slow.
- **No response in 72h** but PR not closed: consider the proactive rebase from Step 2 to signal you're still engaged. Don't comment on the thread itself.
- **No response in 7+ days**: a polite "anything I can do to help unblock this?" comment is acceptable. Not before.

### Step 4: Handle feedback if it comes (~30 min-2h depending on scope)

The most likely feedback types, pre-thought (failure modes in §5):

- **Tiny wording changes**: edit, commit, push. The PR updates automatically.
- **Add a regression test**: covered in §5/F2 below.
- **Refactor / change approach**: bigger. May warrant pulling the PR into draft state via `gh pr ready 2037 --undo`, iterating, then marking ready again.
- **Maintainer asks "why not approach X instead?"**: respond in the PR thread, defend the approach with evidence (this is exactly what the Day-7 notes captured — both options 1 and 2 were considered and rejected).

For any iteration: commit cleanly, push, mention briefly in the PR thread what changed. Don't rebase or amend during active review without warning the reviewer.

### Step 5: Capture the contributor workflow as v2 manual §24 (~45 min today)

While the experience is fresh, add a new section to v2 manual. Proposed title: **"§24. Upstreaming a Gas City fix: the contributor playbook."** Subsections:

- **Pre-flight (read CONTRIBUTING.md + PR template).** What to expect from the project's specific contribution conventions.
- **Rebase to current main before pushing.** Even if you started from main; upstream advances. Use `git log <your-base>..origin/main -- <changed-files>` to spot conflict risk.
- **Run the project's test gate locally first.** For Gas City: `make check`. Requires Go installed. Document the gap-fill (install Go via brew if needed; ~5 min).
- **Fork with `gh repo fork`, push to fork, PR with `gh pr create`.** Specific commands.
- **PR-body honesty pattern.** If a checkbox in the template doesn't apply or you didn't run something, say so explicitly rather than fake-checking it. Maintainers appreciate the honesty.
- **Post-submit: wait, watch, iterate.** Don't poke. Don't force-push during active review.

Reference Day-11's execution log as the primary evidence trail.

### Step 6: Plan the next contribution (~15 min — optional)

If Day-11 leaves time, pick a second small upstream contribution from the backlog. Candidates the prior 10 days surfaced:

- **mc-uhvbb9** (refinery watch under load) — too speculative without more diagnostic depth; not PR-ready yet.
- **mc-f7u8fz** (reconciler cycle latency) — large upstream fix; multi-day. Not Day-11 scope.
- **A `slow_storage_degraded` rename PR**: the misnomer caught in Day-6 §19. Trivial-but-real one-liner (rename outcome code + update test). Good "second PR" candidate — even smaller than today's and validates that the workflow generalizes.

Don't open a second PR same-day — let the first one breathe. But identifying the next one helps prove "I can do this routinely."

---

## 5. Failure modes pre-thought

**F1: PR sits with no response for days.** Most likely outcome. Active open-source projects have backlog; small fixes from new contributors aren't always top priority. **Action:** patience. Verify the PR isn't stuck in some "needs label" limbo (it isn't currently — workflows are just awaiting approval). Update branch proactively if 48-72h pass with no activity.

**F2: Maintainer requests a regression test.** Concrete and addressable. The test would belong in `examples/gastown/maintenance_scripts_test.go` (which already tests these scripts; we'd add a case where the state file is *absent*). Effort: ~1 hour to write + verify locally with `make check`. Push, note in PR thread.

**F3: Maintainer asks to split the change or change approach.** Less likely given the diff is 21 lines and parallel-symmetric across two files. If asked, our Day-7 notes have the rationale for the secondary-fallback approach vs alternatives — we can quote that directly in the PR thread.

**F4: CI fails after maintainer approves workflows.** Unlikely — `make check` passed locally. Possible failure: an integration test we didn't run (`make test-integration` was the unchecked box). **Action:** read the failure, fix locally, force-push if scope is small. Mention in thread that we'll iterate.

**F5: PR closes without merge.** Worst case but rare. Reasons could be: maintainer doesn't want the change, prefers a different fix shape, or the project is moving in an incompatible direction. **Action:** thank the maintainer, capture the lesson, move on. The technical learning persists regardless of merge.

**F6: PR merges cleanly with no edits.** Best case. The behavior is now upstream — anyone in the Gas City community benefits. Update the v2 manual §22 secondary-fallback subsection to reference the merge commit SHA when known.

---

## 6. Risk / blast radius

- **Public PR**: anything pushed to `fork/rjgeng/fix/dolt-pack-script-state-fallback` updates the PR and is visible to anyone watching the upstream repo. **Don't push unrelated work to this branch.** Use a different branch for any future PR.
- **Force-push during review**: legitimate but disruptive. Avoid unless asked or until the PR has clearly stalled (72+ hours no review activity).
- **Comments on the PR thread**: every word is public, archived, indexed by search engines. Write as you would in any professional code review.
- **Maintainer dynamics**: if you disagree with feedback, the right move is to engage technically (with evidence) — never personally. The Day-7/8/9/10 notes give you a strong factual base if you need to defend the approach.

---

## 7. Connection to prior days

All 10 prior days led here, even though only the last few were obviously about this PR:

- **Days 3-4**: built the muscle for working *with* the system (orchestration, A/B testing).
- **Day-5**: surfaced the JSONL push storm that was the original symptom this PR ultimately fixes.
- **Day-6**: built the trace-reading + offline-diagnostic toolkit that informed how to characterize the bug.
- **Day-7**: filed the bead, did the falsification (Step 1.5), staged the fix locally and upstream.
- **Day-8**: validated the falsification pattern again on a different bug (S5).
- **Day-9 + Day-10**: ran the controlled validation that proved the fix worked end-to-end.
- **Day-11**: engaged upstream with the accumulated evidence.

This is also the first day that *makes the chain visible publicly*. Anyone reading PR #2037 sees the "Discovery context" section, which credits the local triage process. That story — observe → diagnose → fix → validate → upstream — is the unique signature of this work, and it's now linked to your GitHub identity.

---

## 8. Adjacent work to fold in

**Today (Day-11):**

- Update memory `user_role.md` with the career-transition note. The next session should have access to this context: "transitioning from hardware to software; first OSS PR at gastownhall/gascity#2037 on 2026-05-12."
- Add v2 manual §24 (the contributor playbook — Step 5 above).
- Update submodule pointer state note in Day-10 wrap: the upstream branch is no longer "local only" — it now lives on the fork at `rjgeng/gascity`.

**Soon (Day-12+):**

- Pick the next small upstream PR candidate (`slow_storage_degraded` rename suggestion from Step 6). Open it after PR #2037 has settled (merged, closed, or after a few days of inactivity).
- Consider opening an upstream issue for `mc-uhvbb9` if Day-10's diagnosis there is mature enough — even without a fix, filing the issue gives the maintainers evidence and shows ongoing engagement.

---

## 9. Optional: mayor handoff

Skip. This is personal development and process learning. No agent orchestration applies.

---

## 10. Execution log

(filled in as work happens)

### PR lifecycle observations

| Time | Event | Notes |
|---|---|---|
| 2026-05-12 10:31 | PR #2037 opened | First upstream contribution. Awaiting maintainer approval for workflows. |
| | First CI check approved | |
| | First CI run completed | Pass/fail breakdown |
| | First maintainer comment | Tone, content, requested changes if any |
| | Iteration pushed (if any) | What changed, push timestamp |
| | Final disposition | Merged / closed / sustained-pending |

### v2 manual §24 added

- [ ] Pre-flight subsection
- [ ] Rebase-before-push subsection
- [ ] Local test-gate subsection
- [ ] Fork-push-PR subsection
- [ ] PR-body-honesty subsection
- [ ] Post-submit-watch-iterate subsection

### Memory updates

- [ ] `user_role.md` updated with career-transition + first-PR context

### Iteration cycles (one row per push to the PR)

| # | Time | What changed | Reason | Result |
|---|---|---|---|---|

### What surprised me about the OSS contributor experience

(filled in over the lifecycle — initial nervousness vs actual experience, response speed reality vs expectation, etc.)

### Anything to promote to v2 manual (beyond §24)

(later — once the PR is resolved)
