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

### Step 2: timeline backstop on #2316

(pending — run as part of mid-morning recheck before playbook write)

### Step 3: §24 playbook note

(pending)

### Step 4: 6th-fire observation (~08:14 PT)

(pending)

### Step 5: EOD recheck + tracker update

(pending)

### Step 6: Day-30 punt

(pending — EOD)

---

### G1-G3 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
