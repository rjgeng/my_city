# Day 27 — PR watch + 4th compactor fire observation

- **Plan authored:** 2026-05-17 (Day-26 EOD, immediately after PR #2316 shipped)
- **Planned execution:** 2026-05-18 (morning, ~07:30-09:30 PT window)
- **Status:** Plan only.

Day-27 is a **watch-day shape** — light scope, observational. Three PRs are open with maintainer; the 4th consecutive `mol-dog-compactor` fire happens ~08:06 PT and provides another reproducibility datum. No fix-shaping or new code edits unless a PR review forces it.

---

## 1. Pre-flight context

**State going in:**

- **PR #2316** (mc-1zccc2 fix, retry-with-backoff): OPEN, MERGEABLE, ~17h old at start of Day-27. `reviewDecision` empty. CI green. Filed against a function the maintainer (julianknutsen) just refactored in #2225 — meaningful review-pushback risk.
- **PR #2088** (convoy docs): OPEN, **APPROVED by csells** 2026-05-16T00:01Z (CONTRIBUTOR, not maintainer — needs write-access merge). ~2.5 days post-approval idle.
- **PR #2136** (mol-dog-jsonl push race): OPEN, MERGEABLE, content-idle since 2026-05-14T22:28Z. ~89h at Day-27 AM — well past 1.5× repo cadence threshold.
- **mc-1zccc2**: OPEN, P3 BUG. Acceptance criteria 1+2 met, 3 advanced via PR, 4 pending.
- **mc-4m2da1**: OPEN, P3 BUG, carries PR #2316 link.
- **mol-dog-compactor**: predicted to fire ~08:05-08:07 PT (+1 min/day drift from 5/15's 08:03), predicted to fail (4th consecutive). City still on bundled gascity-src (unpatched).

**Key Day-26 lessons rolling in:**

1. Day-N tracks plan-execution date, not calendar — see [[feedback_day_numbering]].
2. `gastown.deacon` trace doesn't capture subprocess stderr — DO NOT re-arm for this fire.
3. Diagnostic-day anti-plan ("don't open a PR") is a default, not a rule. Day-27 is back to discipline.
4. Verify upstream main hasn't moved before writing fixes against bead line references.

---

## 2. What "done" looks like

| Branch | Done state | Next action |
|---|---|---|
| **A — PR activity** | One or more PRs received review/merge/changes-requested overnight | Address inline per §24 playbook; update tracker; if merged: prepare city-upgrade pathway (separate work, not Day-27 scope) |
| **B — PRs idle, 4th fire confirms pattern** | All 3 PRs unchanged; compactor failed again ~08:06 PT exactly as predicted | Nudge #2136 (past cadence); observe-only on #2088 (post-approval) and #2316 (too fresh); append 4th-datum note to mc-1zccc2; tracker update |
| **C — Surprise** | E.g., #2316 closed or pushed back hard; compactor succeeded unexpectedly; new failure mode appears | Investigate the surprise; reshape PR or file new bead as appropriate |

**Modal expectation:** Branch B (~70% — Sunday→Monday weekend tail, no maintainer activity expected).

---

## 3. Execution plan

Total budget: **~75 min** active. No critical timing constraint (PRs are async; the compactor fire is observe-only).

### Step 1: Pre-flight (~5 min, any time after 07:30 PT)

```bash
cd /Users/rfvitis/my-city
date
gc version
git log --oneline origin/main..HEAD  # should be empty (Day-26 pushed)
bd list | grep -E 'mc-(1zccc2|4m2da1|w9iua4|mxl4vc)' 2>&1 | head -10
```

### Step 2: Read PR states (~15 min)

```bash
for pr in 2088 2136 2316; do
  echo "=== PR #$pr ==="
  gh pr view $pr --repo gastownhall/gascity \
    --json state,reviewDecision,mergeable,updatedAt,latestReviews \
    | jq '{state, reviewDecision, mergeable, updatedAt,
           reviews: [.latestReviews[] | {author: .author.login, state, when: .submittedAt[:16]}]}'
done
```

Note: use `latestReviews` (not `comments`) per Day-26 lesson — the comments view doesn't include APPROVE/REQUEST_CHANGES actions.

### Step 3: Observe 4th compactor fire (~10 min passive, around 08:00-08:10 PT)

Don't arm anything. The harness notifies on order.failed; otherwise just check after 08:10 PT:

```bash
gc events --type order.failed --since 30m 2>/dev/null \
  | jq -r 'select(.subject == "mol-dog-compactor") | "\(.ts)  \(.message | gsub("\n"; " ") | .[:80])"'

# Cross-check fires directly (gc events truncates non-failure events per Day-25 lesson)
grep '"type":"order.fired"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-18T14:00:00Z")) | .ts' \
  | tail -5
```

Capture: exact fire ts, exact fail ts, error message class (script-side `HEAD changed before flatten` on the bundled version vs the new post-#2225 `value hash changed` symptom).

### Step 4: Decide nudges per protocol (~10 min)

- **#2088 — APPROVED:** DO NOT nudge. Protocol: post-approval is wait-only.
- **#2136 — content-idle ~89h:** past 1.5× cadence (~36-48h for gascity). Single-line nudge per §24 playbook.
  ```bash
  gh pr comment 2136 --repo gastownhall/gascity --body "Friendly bump — any thoughts on this?"
  ```
- **#2316 — <24h old:** DO NOT nudge. Too fresh.

### Step 5: Bead updates (~10 min)

```bash
bd update mc-1zccc2 --append-notes "$(cat <<'EOF'
Day-27 (2026-05-18): 4th consecutive daily fire failed (compactor exit-1 at ~08:06 PT). Pattern confirmed deterministic. PR #2316 still OPEN awaiting maintainer review. Bead remains OPEN until upstream merge + city upgrade + post-install soak.
EOF
)"
```

If PR #2316 received review activity: append summary to mc-4m2da1 too.

### Step 6: Tracker + commit (~15 min)

Update `study/notes/upstream-engagement-tracker.md`:
- Bump header to Day-27 with summary line
- Update each PR section's **Activity** + **Last action by us** fields
- If nudge sent on #2136: record nudge timestamp
- If review activity on any PR: record review state + action taken

```bash
git add study/notes/upstream-engagement-tracker.md \
        study/notes/2026-05-21-day27-pr-watch-and-fire-observation.md
git commit -m "$(cat <<'EOF'
docs: Day-27 — PR-watch + 4th compactor fire observed (mc-1zccc2 unchanged)

<2-3 line summary of branch outcome + nudges + fire datum>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

### Step 7: Day-28 punt (~10 min)

Brief note on what Day-28 should be:

- **If all 3 PRs still idle** → mc-mxl4vc tour-day shape (light diagnostic on the remaining active local-only bead) OR another PR-watch
- **If #2316 reviewed** → fix-day to address comments
- **If #2316 merged** → city upgrade pathway + fresh post-install soak setup

---

## 4. Anti-plans

- **Don't re-arm `gastown.deacon`** for the compactor fire. Day-26 confirmed it doesn't capture subprocess stderr. The 4th fire's symptom is already known.
- **Don't nudge #2088 or #2316.** Post-APPROVAL is wait-only; <24h is wait-only.
- **Don't open new PRs Day-27.** Day-26 already burned the diagnostic-day anti-plan; back to discipline.
- **Don't expand scope to mc-mxl4vc** unless Day-28 picks it up. Today is watch-only.
- **Don't reshape #2316 preemptively.** Wait for actual review feedback before iterating; speculation about what julianknutsen might want is wasted effort.

---

## 5. G1-G3 predictions (falsifiable)

**G1: PR #2316 will still be OPEN with `reviewDecision` empty at EOD Day-27.** Reasoning: ~17h old at start; observed pattern on #2136 + #2088 is multi-day review latency, and 5/17→5/18 is Sunday→Monday tail. **Predicted outcome:** `state=OPEN, reviewDecision=""`.

**G2: mol-dog-compactor will fail at ~08:05-08:07 PT.** Reasoning: 3 prior consecutive failures (5/14 08:02, 5/15 08:03, 5/16 ~08:04 inferred, 5/17 ~08:05 observed). City unpatched. Drift +1 min/day. **Predicted outcome:** order.failed observed in 08:00-08:10 PT band for subject `mol-dog-compactor`.

**G3: #2136 will cross threshold and receive a single nudge from us.** Reasoning: ~89h content-idle, past 1.5× repo cadence. Protocol triggers exactly one polite nudge. **Predicted outcome:** one new comment authored by rjgeng on #2136.

If all 3 hold → Branch B (modal). G1 falsified → Branch A. G2 falsified (compactor succeeds!) → Branch C with big-surprise investigation.

---

## 6. Execution log

(filled in 2026-05-18 morning when Day-27 executes)

### Step 1: pre-flight (2026-05-18 ~04:00 PDT)

- Local main: up to date with origin (no unpushed commits)
- Open beads (relevant): mc-mxl4vc, mc-1zccc2, mc-4m2da1, mc-w9iua4 — all 4 OPEN, unchanged
- Pre-day branch state: clean

### Step 2: PR states snapshot (2026-05-18 ~04:00 PDT, ~11:00Z)

- **#2088:** OPEN, MERGEABLE, `reviewDecision=""`. APPROVED by csells 2026-05-16T00:01Z (still latest). `updatedAt` 2026-05-16T00:01:45Z — **unchanged since Day-26.** ~2.5 days post-approval idle.
- **#2136:** OPEN, MERGEABLE, `reviewDecision=""`. Only Copilot bot comment (2026-05-14T22:19Z). `updatedAt` 2026-05-14T22:28Z — **unchanged since open.** ~93h content-idle at decision time.
- **#2316:** OPEN, MERGEABLE, `reviewDecision=""`. Only Copilot bot comment (2026-05-17T21:36Z, benign). `updatedAt` 2026-05-17T22:09:12Z — **unchanged since open.** ~13h old at decision time.

### Step 3: compactor fire observation

- **Actual fire ts:** 2026-05-18T08:09:17.62-07:00 (predicted 08:05-08:08 PT; +2 min over yesterday rather than +1)
- **Actual fail ts:** 2026-05-18T08:12:04.59-07:00
- **Duration:** ~2m47s (vs ~23s on 5/17 — **7× longer**)
- **Error message class:** `"exit status 1"` (controller surface only — stderr not in events.jsonl per Day-26 lesson; not re-armed per anti-plan #1)
- **4th-consecutive confirmed (yes/no):** **YES** — G2 satisfied
- **Auto-tracking bead created:** `mc-o5fhwm` (P2, controller-owned, closed; labels `exec-failed`, `order-run:mol-dog-compactor`, `order-tracking`)

Reference: 5/17 fire fired 2026-05-17T08:07:20-07:00, failed 2026-05-17T08:07:43-07:00 (+1min drift continuing → predicted 5/18 ~08:08 PT; **actual was 08:09:17 = +2min, model needs ±2min tolerance**).

**Duration variance is the new observation worth thinking about.** Same exit-1 surface message, but compactor reached ~167s of work before failing today vs ~23s yesterday. Suggests HEAD-race window varies with hq's contemporaneous write load — race is timing-dependent, not deterministic-instant. Strengthens retry-with-backoff (PR #2316) over alternatives.

### Step 4: nudge decisions

- **#2088:** NO — post-APPROVAL is wait-only.
- **#2136:** YES — nudge sent 2026-05-18T11:03:58Z (https://github.com/gastownhall/gascity/pull/2136#issuecomment-4477023113). Past 1.5× cadence threshold. G3 satisfied.
- **#2316:** NO — <24h old at decision time. Too fresh.

### Step 5: bead updates

- **mc-1zccc2:** appended Day-27 datum (fire/fail ts, duration variance observation, PR #2316 status, plan-grep lesson). Bead stays OPEN pending upstream merge.
- **mc-4m2da1:** no update — PR #2316 received no human review activity today.
- **Other:** Issue #1487 detected closed by upstream PR #2127 (moved tracker entry to closed-items section + counter updated).

### Step 6: tracker commit hash

(commit pending — single commit covers tracker + plan + bead notes — hash filled after `git commit`)

### Step 7: Day-28 punt

**Modal Day-28 shape: PR-watch + mc-mxl4vc tour-day hybrid (~90 min budget).**

- All 3 upstream PRs still idle as of EOD Day-27: #2088 (post-APPROVAL ~3d, no second nudge yet — protocol says wait), #2136 (just nudged today; let sit), #2316 (~43h by Day-28 AM, approaching 48h "any thoughts?" threshold but still wait-only per <48h rule).
- Day-28 morning: 5-min PR-state snapshot + brief check of `gh release list --repo gastownhall/beads` for v1.0.5 (mc-mxl4vc unblocker).
- If beads v1.0.5 shipped → Day-28 becomes mc-mxl4vc city-upgrade execution day.
- If beads still v1.0.4 + no PR movement → tour-day shape on mc-mxl4vc body's next-steps (re-read the upstream auto-import-upgrade thread for any movement; light scope).
- **DO NOT** prep a Day-28 plan file yet — punt is for the morning read, not pre-commitment.

Also expect the 5th compactor fire ~08:10-08:12 PT on 5/19 (drift continues). Observation-only; same anti-plan against re-arming deacon.

### G1-G3 verdicts

- **G1 (PR #2316 still OPEN/unreviewed): SATISFIED** as of EOD-AM check — `state=OPEN`, `reviewDecision=""`, only Copilot-error bot review. Recheck at EOD.
- **G2 (compactor fails ~08:06 PT): SATISFIED** — fired 08:09:17 PT, failed 08:12:04 PT, exit-1. Predicted window slightly off (+2min vs +1min drift model) but failure-class matched.
- **G3 (#2136 nudge sent): SATISFIED** at 2026-05-18T11:03:58Z.

**All 3 predictions held → Branch B (modal, ~70% pre-day) is the realized branch.**

### Surprises

- **PR #2316 auto-tagged `priority/p1` by `randy-release-manager[bot]`** at 2026-05-17T22:09:12Z (~37 min after open) — higher than the local bead's P3 classification. Same burst replaced `status/needs-triage` with `kind/bug`. Maintainer team's triage pipeline saw it; no human has acted since. P1 is a queue-priority signal, not a review signal. Discovered via `gh api repos/gastownhall/gascity/issues/2316/timeline` during Day-27 PR-state read.
- **Issue #1487 was closed 2 days ago and the tracker missed it.** quad341 closed it at 2026-05-16T12:10:35Z via merge of PR #2127 (`fix: bound events multiplexer provider fan-out` by julianknutsen, +386 -21 in `internal/events/multiplexer.go` + new tests). A3Ackerman's multiplexer-fan-out diagnosis (which our supportive comment backed) was correct. **Stale-detection lesson:** the tracker entry's "**Next action:** No action. Monitor for thread movement" comment effectively meant nobody was actively checking; tour-day or read-day cadence should include `gh api .../issues/N` for any item whose status was last read >1 week ago, not just our own PRs. Moved #1487 to closed-items section; counters updated.

### What the day actually produced

- **#2136 nudged** at 2026-05-18T11:03:58Z (G3); polite one-liner per playbook.
- **4th-consecutive compactor failure observed** (G2): fire 08:09:17 PT, fail 08:12:04 PT, exit-1, 2m47s duration. mc-o5fhwm auto-tracking bead spawned & closed.
- **mc-1zccc2 bead** updated with Day-27 datum + duration-variance observation + plan-grep lesson.
- **Tracker entry for Issue #1487** moved to closed-items section (detected closed by upstream PR #2127 — julianknutsen's `fix: bound events multiplexer provider fan-out` merged by quad341 2026-05-16T12:10:33Z, +386 -21 in `internal/events/multiplexer.go`); counters updated.
- **PR #2316 timeline-event check** revealed `randy-release-manager[bot]` auto-classified it `priority/p1` ~37 min post-open; recorded in tracker.
- **No new PRs opened** (per anti-plan).
- **No deacon re-arm** (per anti-plan).

### Process lessons captured

1. **events.jsonl uses local-time ISO strings, not UTC `Z`.** Plan's Step-3 grep template (`select(.ts >= "2026-05-18T14:00:00Z")`) would have missed all today's local-time-formatted events. **Fix the template before reuse on Day-28+** — compare against local-time prefix (`"2026-05-18T07:00:00"`) instead, or normalize timestamps inside jq with `fromdateiso8601`.
2. **Passive tracker entries decay silently.** Issue #1487's "Monitor for thread movement" comment effectively meant nobody was actively checking. Tour-day cadence should include `gh api .../issues/N` for any item whose status was last read >1 week ago.
3. **Drift model needs tolerance.** Compactor fire's +1min/day drift held for 4 prior days but slipped to +2min on 5/18. Use ±2min window on next-day predictions, not point estimates.
