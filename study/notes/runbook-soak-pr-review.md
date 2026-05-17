# Runbook: Soak Result + PR Review Read

A step-by-step procedure for reading a 24h post-fix soak result alongside the upstream PR review status, then deciding the bead's next state. Used at the end of any fix-day cycle (e.g., Day-25 reads Day-24's outputs).

**Scope:** generic. The Day-25 specifics (soak start `2026-05-14T22:16:17Z UTC`, PR `#2136`, bead `mc-w9iua4`) are listed as placeholders below — substitute for future cycles.

**Pairs with:**

- `study/notes/upstream-engagement-tracker.md` (the persistent state file)
- `study/notes/2026-05-19-day25-soak-result-pr-review.md` (the day-specific plan that invokes this runbook)

**Last updated:** 2026-05-15 AM (extracted from Day-25 walkthrough)

---

## Placeholders (substitute per cycle)

| Symbol | Day-25 example | Description |
|---|---|---|
| `<SOAK_START_TS>` | `2026-05-14T22:16:17Z` | UTC timestamp of fix-day commit (Step 7 of fix-day plan) |
| `<BASELINE_COUNT>` | `84` | `order.failed` count at soak start |
| `<PR_NUMBER>` | `2136` | Upstream PR opened by the fix-day |
| `<BEAD_ID>` | `mc-w9iua4` | HQ bead tracking the upstream contribution |
| `<SUBJECT_PREFIX>` | `mol-dog-jsonl` | Order subject the fix targets |

---

## A. Read the soak result

### A1. Count + categorize failures in the soak window

```bash
cd /Users/rfvitis/my-city

gc events --type order.failed --since 25h 2>/dev/null \
  | jq -r 'select(.ts >= "<SOAK_START_TS>") | "\(.ts)\t\(.subject)\t\(.message | gsub("\n";" ") | .[:60])"' \
  | sort
```

**Interpretation:**

- **0 lines** → zero failures in soak window (best case; baseline rate lower than thought)
- **1-3 lines, all `<SUBJECT_PREFIX>` exit-1** → matches the pre-fix estimated rate
- **≥4 lines `<SUBJECT_PREFIX>`** → rate higher than expected; reconsider escalation options
- **Any new subject (e.g., a sibling formula's exit-1)** → file a separate bead; do NOT expand `<BEAD_ID>` scope (anti-plan)
- **Any non-exit-1 message** → investigate context; may be supervisor-blip noise

### A2. Total event count delta

```bash
grep -c '"type":"order.failed"' .gc/events.jsonl
```

**Baseline:** `<BASELINE_COUNT>` at soak start. Difference = total failures in window.

### A3. Sanity check — did the relevant order actually fire during the window?

**Why this check exists:** Day-24 surfaced the lesson that 0 captures in a trace window is meaningless if the order didn't fire in that window. Confirm the soak covered actual fires before trusting the failure count.

**⚠ Important:** `gc events --since` **truncates non-failure event types** to a recent window (Day-25 finding — see Lessons table). For historical fire counts that go back ≥ a few hours, **grep events.jsonl directly** instead. Also note the parenthesization in the jq `select` — the first version below has a subtle bug that silently misclassifies records.

```bash
# Correct: parens around the first conjunct so jq evaluates startswith against
# .subject, then ANDs the resulting boolean with the .ts comparison.
grep '"type":"order.fired"' .gc/events.jsonl 2>/dev/null \
  | jq -r 'select((.subject | startswith("<SUBJECT_PREFIX>")) and (.ts >= "<SOAK_START_TS>")) | .ts' \
  | wc -l
```

**Bug to avoid** (left here as a reference — see Lessons): writing this as
`select(.subject | startswith("...") and (.ts >= "..."))` makes jq pipe `.subject`
into `startswith("...") and (.ts >= "...")`, which tries to index a string with
`.ts` and errors silently in many records. Always parenthesize the first conjunct.

**Interpretation:**

- **≥10 fires** → window covered multiple bursts; sample is meaningful
- **<5 fires** → window happened to land in a low-activity period; treat result with caution
- **0 fires** → soak window is invalid; extend or re-time

---

## B. Read PR review status

```bash
gh pr view <PR_NUMBER> --repo gastownhall/gascity \
  --json state,reviewDecision,statusCheckRollup,comments,reviews,mergeable \
  | jq '{
      state,
      reviewDecision,
      mergeable,
      ci_pass: (.statusCheckRollup // [] | map(select(.conclusion == "SUCCESS")) | length),
      ci_total: (.statusCheckRollup // [] | length),
      comments: [.comments[] | {author: .author.login, when: .createdAt[:10], body: .body[:100]}],
      reviews: [.reviews[] | {author: .author.login, state, when: .submittedAt[:10], body: (.body // "" | .[:100])}]
    }'
```

**Interpretation of `state` × `reviewDecision`:**

| state | reviewDecision | Meaning | Action |
|---|---|---|---|
| `MERGED` | (any) | ✅ Shipped | Move to "Closed/merged" in tracker; close `<BEAD_ID>` once city upgrades to the merged version |
| `OPEN` | `APPROVED` | Approved, awaiting merge | Wait — maintainer merge usually follows approval within hours |
| `OPEN` | `CHANGES_REQUESTED` | Need to address | Read review comments; edit; push to the same branch (§24 pattern) |
| `OPEN` | `REVIEW_REQUIRED` | Awaiting first review | Per tracker protocol: nudge if past 1.5× repo cadence (~48h for gascity) |
| `OPEN` | `null` | No formal review yet | Same as `REVIEW_REQUIRED` |
| `CLOSED` (not merged) | (any) | Rejected | Read closing comment; decide whether to reshape the fix or drop |

**Bonus check — CI status:**

If `ci_pass < ci_total`, click through the failing check URLs from `statusCheckRollup` to see what failed. CI failure on an otherwise-clean PR is usually an environment flake; re-running often clears it.

---

## C. Combine into the decision matrix

The fix-day plan (`study/notes/<fix-day-doc>.md` §2 "What done looks like") usually carries its own decision matrix. The generic shape:

| Soak result | PR status | Action |
|---|---|---|
| 0 failures | MERGED | Close `<BEAD_ID>` as fixed; bump tracker counters |
| 0 failures | OPEN | Note baseline rate lower than thought; bead stays OPEN until upstream merge + city upgrade + post-install soak |
| 1-3 failures | MERGED | Close `<BEAD_ID>` only after city upgrades + fresh 24h soak shows 0 |
| 1-3 failures | OPEN | Same as above — wait for upstream + reinstall |
| ≥N failures (N = escalation threshold) | any | Rate higher than expected. Reconsider fix shape; may need flock/stagger fixes. Update bead + PR if needed. |
| New related-but-different failure mode | any | File separate bead. Do NOT expand current bead's scope (anti-plan). |

---

## D. Update artifacts

After the decision is made, update these in order:

### D1. The HQ bead

```bash
# Draft the note in /tmp/<bead-id>-day-N-result.md, then append:
bd update <BEAD_ID> --append-notes "$(cat /tmp/<BEAD_ID>-day-N-result.md)"
```

Include in the note: soak window dates, failure count vs baseline, fire count (the sanity check), PR status snapshot, decision made, PR URL.

### D2. The day plan's execution log

Edit the §6 (or last) execution-log section of `study/notes/<day-N-plan>.md`. Fill in the placeholders that were left blank in the plan template.

### D3. The upstream tracker

Edit `study/notes/upstream-engagement-tracker.md` per its **Maintenance protocol** section:

- Update the item's **State**, **Activity**, and **Last action by us** fields
- Bump counters at top (e.g., if a PR merged: increment "merged", decrement "awaiting maintainer")
- Move closed/merged items to the "Closed / merged items" section
- Update the **Last updated:** timestamp

### D4. Commit

Match the day-plan commit cadence:

```bash
git add study/notes/<day-N-plan>.md study/notes/upstream-engagement-tracker.md
git commit -m "$(cat <<'EOF'
docs: Day-N — <BEAD_ID> soak result + PR #<PR_NUMBER> <status>

<2-3 line summary of decision + numbers>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Preliminary-read option

You can run sections A and B before the full 24h window closes for an interim signal. Useful when:

- You want early warning of any failure (so you can investigate before the canonical read)
- The PR has changes-requested feedback you want to address sooner
- You're checking whether the city is still healthy

**Note that preliminary reads use a partial window** — interpret accordingly. A 12h preliminary read showing 0 failures means baseline rate ≤ 0.08/h with 50% confidence; not a definitive close.

---

## Lessons captured (update as discovered)

| Date | Lesson | Source |
|---|---|---|
| 2026-05-14 | Soak window must cover actual order-fire activity, not just elapsed time. Add the A3 sanity check before trusting failure count. | Day-24 G1 falsification |
| 2026-05-14 | The city runs the unpatched code while the fix is in the PR branch only. Soak measures baseline, NOT fix effectiveness. Real validation requires upstream merge + city upgrade + fresh soak. | Day-24 Step 7 caveat |
| 2026-05-14 | Wait 1.5× repo cadence before nudging. Single-line nudges only; never twice. | Upstream tracker protocol |
| 2026-05-15 | `gc events --since <window>` truncates non-failure event types (order.fired, bead.updated, etc.). The CLI surface optimizes for live streams, not history. For historical queries (especially count-of-fires sanity checks), grep events.jsonl directly. Day-25 read returned "16 fires" via `gc events` and "298 fires" via grep — same window, ~19× difference. | Day-25 A3 retrieval |
| 2026-05-15 | jq `select(.subject \| startswith("...") and (.ts >= "..."))` has a subtle bug — jq pipes `.subject` into the full `startswith() and (.ts >= "...")` expression, which tries to index a string with `.ts`. **Always parenthesize the first conjunct:** `select((.subject \| startswith("...")) and (.ts >= "..."))`. | Day-25 A3 jq error |
| 2026-05-15 | "Burst pattern" frame can be an artifact of API truncation. If you only see N fires in a non-uniform pattern, verify against raw event log before claiming firing cadence. | Day-25 retraction of Day-24's burst-pattern claim |
| 2026-05-17 | `gastown.deacon` trace template scope = controller cycle events, NOT subprocess stderr from dogs running inside. Arming the deacon to capture a failing order subprocess's stderr will produce trace records but no stderr content — the order-dispatcher does not plumb subprocess stderr into events.jsonl. Fall back to manual repro for stderr; track the gap separately (§27). | Day-26 mc-1zccc2 G3 falsification |
| 2026-05-17 | Diagnostic-day anti-plan ("don't open a PR on Day-N") is a default, not a rule. If diagnosis surfaces a low-effort fix matching a proven prior retry-with-backoff pattern, same-day PR is acceptable. Decide explicitly; don't drift. | Day-26 mc-1zccc2 → PR #2316 |
| 2026-05-17 | Before writing a fix against a stale-bead's line reference, `git fetch origin main` and verify the target structure is unchanged. PR #2225 had refactored `flatten_database()` the day before mc-4m2da1 was filed; the bead's `compact/run.sh:962-968` reference was already stale. Symptom of the underlying bug shifted (abort → quarantine) but the bug persisted. | Day-26 upstream-freshness check |
