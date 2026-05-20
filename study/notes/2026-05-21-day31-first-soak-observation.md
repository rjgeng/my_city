# Day 31 — first post-upgrade soak observation

- **Plan authored:** 2026-05-20 PM (forward-prep at end of Day-30; resumes plan-commit cadence)
- **Planned execution:** 2026-05-21
- **Status:** Plan stamped. AM read goes into §6 Step 1 on execution.

Day-31 is the **first post-upgrade soak observation day.** PR #2316 merged Day-29 (07:54 PT); city upgraded Day-30 (~09:53 PT); first natural compactor fire arrives Day-31 ~08:14–08:18 PT. That fire is the load-bearing observation point.

---

## 0. Process note: Day-30 plan-file gap

Day-30 executed substantive work (city-upgrade, §24c canonization, 2 follow-up beads, #2088 §24b transition capture) **without a standalone plan file.** Day-29's close-out "Day-30 punt" section served as the de facto plan. Day-31 resumes the explicit plan-commit cadence.

Not a failure mode — a pattern observation: days that begin from an inherited close-out plan *can* skip the plan-commit step when the modal shape is clear and pre-staged. But it's a process gap because:

- No standalone falsifiable G1/G2/G3 stamped at Day-30 AM
- No explicit anti-plan refresh at Day-30 AM
- The Day-30 narrative lives only in commits + bead notes + tracker updates

Day-31 corrects forward.

---

## 1. Pre-flight context

**State going into Day-31 (Day-30 EOD, 2026-05-20):**

- **PR #2316** (mc-1zccc2/mc-4m2da1 fix): **MERGED Day-29** via `/adopt-pr`. Soak window active. mc-4m2da1 stays OPEN pending observation.
- **PR #2088** (convoy docs): OPEN, MERGEABLE. **§24b 0–24h wait window** entered 2026-05-20T16:13:41Z when write-access maintainer `quad341` applied `status/reviewing`. By Day-31 AM, ~14–16h into the §24b window.
- **PR #2136** (mol-dog-jsonl push race): OPEN, MERGEABLE. Day-31 = day 5 post-Day-27-nudge. Wait-only per §24a-ish.
- **Issue #3880 (beads)**: v1.0.4 latest (~12d old by Day-31). mc-mxl4vc still blocked.
- **mc-1zccc2, mc-4m2da1, mc-w9iua4, mc-mxl4vc, mc-z92fpi, mc-iho25h:** all OPEN. mc-z92fpi + mc-iho25h labeled `hold-until-soak`.
- **`gc` binary:** HEAD-fad5d3f (Day-30 upgrade from HEAD-caa44a4). Supervisor PID 75812 (or its successor if reboot intervened).

**Carry-forward Day-30 lessons:**

1. **n-counting matters before canonization.** Day-29's "n=1 defer §24c" was wrong because n=6 was visible in `git log --grep="adopt-pr"`. Future canonization decisions: do the pre-flight count first.
2. **Tracker freshness is what makes the morning read work.** A real state change to a tracked PR mid-day deserves an inline tracker update on the same day, not deferred to EOD.
3. **The post-engagement state machine has 3 active variants** (§24a/b/c). When watching a stalled PR, ask: which variant is it in, and what would a transition look like?

---

## 2. Morning read (same Day-29 template + #2088 timeline backstop)

```bash
date; gc version
for pr in 2088 2136; do
  gh pr view $pr --repo gastownhall/gascity \
    --json state,reviewDecision,updatedAt,latestReviews,labels \
    | jq '{state, reviewDecision, updatedAt, labels: [.labels[].name]}'
done
gh release list --repo gastownhall/beads --limit 3   # v1.0.5 watch
bd list | grep -E 'mc-(1zccc2|4m2da1|w9iua4|mxl4vc|z92fpi|iho25h)'

# Compactor fire watch (post-upgrade — should now succeed)
grep '"type":"order.fired"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-21T07:00:00")) | .ts'
grep '"type":"order.failed"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-21T07:00:00")) | .ts'
grep '"type":"order.completed"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-21T07:00:00")) | .ts'

# #2088 timeline backstop (Day-28 lesson #2)
gh api repos/gastownhall/gascity/issues/2088/timeline --paginate \
  | jq -r '.[] | select(.created_at >= "2026-05-20T16:13:00Z") | "\(.created_at) \(.event // "comment")"' \
  | tail -20
```

The snapshot picks the branch.

---

## 3. Decision matrix

| State read | Day-31 shape | Budget |
|---|---|---:|
| **Compactor succeeds, #2088 in §24b stall (modal, ~50%)** | Pure observation; log result + drift; close mc-4m2da1 only after Day-32+ soak completes cleanly | 30 min |
| Compactor succeeds, #2088 review body lands | Fix-day on #2088 — address inline if change-requests | 30–90 min |
| Compactor succeeds, #2088 via `/adopt-pr` (§24c) | Single thank-you comment per §24c template, no further action | 15 min |
| **Compactor FAILS** | **Diagnose-day.** Fix is merged; failure means something we missed. NOT a hot-fix PR. Trace, understand, file a new bead. | 60–180 min |
| Compactor doesn't fire (scheduling regression) | Investigate supervisor / order subsystem — possibly Day-30 upgrade fallout | 60–120 min |
| Beads v1.0.5 ships | mc-mxl4vc city-upgrade (smaller than gc upgrade; symlink swap) | 30–60 min |
| All idle | Light snapshot day; possible §-TBD playbook work (e.g., honesty-first PR body section) | 30–45 min |

**Modal reasoning:** the merged #2316 had solid maintainer review + new test coverage (1 abort test, 1 retry test, 1 verify-probe test). Probability the fix-as-merged actually works is high (~85%). #2088 sitting in §24b at <24h is the modal state for that PR.

---

## 4. Falsifiable predictions (G1–G4, two-layer per Day-28 lesson #1)

- **G1 (#2088 §24b state):**
  - *Field:* PR #2088 stays OPEN with `status/reviewing` label through 18:00 PT 5/21.
  - *Generator:* §24b 24–72h wait window applies. quad341's typical review cadence is unknown but his prior merges suggest he's not a constant-attention reviewer.
- **G2 (5/21 compactor fire):**
  - *Field:* `mol-dog-compactor` fires at **08:14–08:18 PT** (drift +1–2min/day continuing, or wider if Day-29 +3m18s anomaly persists), **exit-0**, NO `order.failed` event.
  - *Generator:* #2316 fix bounds preflight retry on HEAD movement; post-flatten quarantine + #2225 value-hash check catch residual races. New `gc` binary (HEAD-fad5d3f) is the binary spawning the compactor subprocess.
- **G3 (beads release):** stays at v1.0.4. Generator: 12d silence on v1.0.5; historical cadence 10–15d but no public movement signal.
- **G4 (drift anomaly resolution):**
  - *Field:* 5/21 fire timestamp falls within 08:15–08:18 PT.
  - *Generator:* 5/20's +3m18s was either noise (drift returns to +1–2min) or a persistent shift (drift continues wider). 5/21 is the resolving data point. If drift is now +5m+, the model needs revision.

---

## 5. Anti-plans

1. **Don't re-arm `gastown.deacon`** (Day-26 confirmed subprocess stderr not captured).
2. **Don't open new PRs** unless review forces one.
3. **Don't preemptively rebase #2136** — let it ride.
4. **Don't nudge #2088** even if §24b passes 24h. quad341 just labeled it; protocol holds.
5. **Don't nudge #2136** — Day-27 nudge spent.
6. **Local-time prefix when greping events.jsonl** (Day-27 lesson).
7. **Watch-day must produce an artifact** (Day-29 anti-plan #7).
8. **(New) If compactor fails on 5/21 → DO NOT immediately open a hot-fix PR.** Fix is freshly merged; failure means something we didn't anticipate. Trace + understand before patching. Possibly file a new bead and let the soak window extend.
9. **(New) Don't unlatch `hold-until-soak` labels on mc-z92fpi / mc-iho25h on Day-31.** 24h soak window doesn't complete until Day-32 AM at earliest. Even a successful 5/21 fire is one data point, not validation.
10. **(New) If §24c applies to #2088 → follow the playbook template literally.** Single thank-you comment, no requests, no apologies. The Day-29 #2316 sequence is the reference; deviating from it is the failure mode.

---

## 6. Execution log

### Step 1: morning read (pending — execute Day-31 AM ~05:00 PT)

### Step 2: 5/21 compactor fire observation (pending — window 08:14–08:18 PT)

### Step 3: #2088 timeline + state recheck (pending — mid-morning)

### Step 4: branch selection per §3 matrix (pending)

### Step 5: EOD recheck + tracker update (pending)

### Step 6: Day-32 punt (pending)

---

### G1–G4 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
