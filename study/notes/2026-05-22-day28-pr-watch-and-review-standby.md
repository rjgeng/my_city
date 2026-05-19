# Day 28 — PR-watch + #2316 review standby

- **Plan authored:** 2026-05-19 morning (Day-27 close-out punted to morning read)
- **Planned execution:** 2026-05-19
- **Status:** Plan + morning read stamped. Close-out pending EOD.

Day-28 is a **watch-day shape**. Three PRs still open with maintainer; mc-mxl4vc still blocked on beads v1.0.5. The morning read picks the actual branch.

---

## 1. Pre-flight context

**State going in (from Day-27 close-out, 2026-05-18 EOD):**

- **PR #2316** (mc-1zccc2 fix): OPEN, MERGEABLE, ~37h old. `reviewDecision` empty. Only Copilot-error bot review. `priority/p1` auto-tag from `randy-release-manager[bot]` ~37 min post-open. Filed against `flatten_database()` — same function julianknutsen refactored in #2225 (merged 5/16).
- **PR #2088** (convoy docs): OPEN, APPROVED by csells (CONTRIBUTOR, not write-access). ~3 days post-approval idle.
- **PR #2136** (mol-dog-jsonl push race): OPEN, MERGEABLE. Nudged 2026-05-18T11:03:58Z (single nudge per protocol). Let it ride.
- **Issue #3880** (beads auto-import regression): OPEN, beads still v1.0.4. mc-mxl4vc blocked on v1.0.5.
- **mc-1zccc2, mc-4m2da1, mc-w9iua4, mc-mxl4vc:** all OPEN.

**Key Day-27 lessons rolling in:**

1. events.jsonl uses local-time ISO strings, not UTC `Z` — compare against `"2026-05-19T07:00:00"` prefix.
2. Passive tracker entries decay silently — read-day cadence should `gh api .../issues/N` for any item last-read >1 week ago.
3. Compactor drift model needs ±2min tolerance, not point estimate.

---

## 2. Morning read (only pre-committed step, ~5 min)

```bash
date; gc version
for pr in 2088 2136 2316; do
  gh pr view $pr --repo gastownhall/gascity \
    --json state,reviewDecision,updatedAt,latestReviews \
    | jq '{state, reviewDecision, updatedAt}'
done
gh release list --repo gastownhall/beads --limit 3   # v1.0.5 watch
bd list | grep -E 'mc-(1zccc2|4m2da1|w9iua4|mxl4vc|o5fhwm)'
grep '"type":"order.failed"' .gc/events.jsonl \
  | jq -r 'select((.subject == "mol-dog-compactor") and (.ts >= "2026-05-19T07:00:00")) | .ts'
```

The snapshot picks the branch.

---

## 3. Decision matrix

| State read | Day-28 shape | Budget |
|---|---|---:|
| #2316 reviewed (any state) | Fix-day — address review inline; rebase only if explicitly asked | 60–120 min |
| #2316 merged (extreme luck) | City-upgrade pathway — update local gascity ref, install, soak 24h, close mc-4m2da1 | 90 min + soak |
| #2136 reviewed | Fix-day on #2136 (most likely ask: `awk srand() → $RANDOM`) | 30–60 min |
| #2088 merged | Tracker move to closed; no further action | 10 min |
| Beads v1.0.5 released | mc-mxl4vc city-upgrade execution — symlink swap to bd 1.0.5, validate empty-DB guard | 60–90 min |
| **All idle + nothing released (modal, ~65%)** | Tour-day on mc-mxl4vc; observe 5th compactor fire | 30–45 min |

**Modal reasoning:** Sunday→Monday→Tuesday tail; #2088 has sat 3+d post-APPROVAL with no merger movement, suggesting maintainer team isn't actively scanning; beads v1.0.5 historically months between releases.

---

## 4. Falsifiable predictions (G1-G3)

- **G1:** PR #2316 still OPEN, `reviewDecision=""` at Day-28 AM. Reasoning: weekend pattern, no human activity on the `priority/p1` tag yet.
- **G2:** 5th-consecutive `mol-dog-compactor` fire fails ~08:10-08:12 PT (±2min per Day-27 drift lesson), exit-1. Duration 23s-3min.
- **G3:** Beads release stays at v1.0.4.

If all hold → modal branch realized; light tour-day.
If G1 falsified (#2316 reviewed) → fix-day.
If G3 falsified (v1.0.5 ships) → mc-mxl4vc upgrade day.

---

## 5. Anti-plans

1. **Don't re-arm `gastown.deacon`.** Day-26 confirmed subprocess stderr not captured.
2. **Don't open new PRs** unless review forces one.
3. **Don't preemptively rebase #2316** — wait for explicit ask.
4. **Don't second-nudge #2088.** Post-APPROVAL is wait-only at protocol level even at 4+ days; flag as §24 playbook question for a different day.
5. **When greping events/timestamps, compare against local-time prefix** (`"2026-05-19T07:00:00"`), NOT UTC `Z`. Day-27 lesson.

---

## 6. Execution log

### Step 1: morning read (2026-05-19 ~04:00 PDT)

```
Tue May 19 03:59:20 PDT 2026
gc version: HEAD-caa44a4
```

PR states:

| PR | state | reviewDecision | updatedAt | delta vs Day-27 EOD |
|---|---|---|---|---|
| #2088 | OPEN | "" | 2026-05-16T00:01:45Z | unchanged |
| #2136 | OPEN | "" | 2026-05-18T11:03:58Z | unchanged (our nudge is last activity) |
| #2316 | OPEN | "" | **2026-05-19T06:54:02Z** | **CHANGED ~3h ago** |

Beads release: still v1.0.4 (2026-05-09). G3 holds.

Compactor fires today: none yet (fire predicted ~08:10 PT, currently 03:59 PT).

Beads (relevant): mc-mxl4vc, mc-1zccc2, mc-4m2da1, mc-w9iua4 all OPEN, unchanged.

### Step 2: #2316 timeline dig (G1 partial-falsification)

`updatedAt` advanced — investigated via `gh api repos/.../issues/2316/timeline`:

- `2026-05-19T06:12:15Z` julianknutsen labeled `status/needs-review-auto`
- `2026-05-19T06:54:02Z` julianknutsen unlabeled `status/needs-review-auto`, labeled `status/reviewing`

**julianknutsen is actively reviewing #2316 as of ~3h ago.** No review body submitted yet (`comments[]` empty, `reviews[]` still only the errored Copilot bot). Same maintainer who authored #2225 — strongest possible signal of imminent action.

**G1 verdict: partially falsified.** State/reviewDecision unchanged, but the underlying assumption ("no human activity") is broken. Branch is in-flight, not landed.

### Step 3: cold prep-read on #2316 + #2225 (~04:30-05:30 PDT)

Per anti-plan #3 nothing pushed. Read both diffs cold to anticipate likely review angles. Three findings:

**Finding 1 (high-likelihood) — PR #2316 body has a factual error.**

The body claims:

> Prior to #2225 the symptom was `"HEAD changed before flatten — aborting before reset"` at the pre-flatten guard. #2225 removed that guard.

Verified against `2948574^` (the #1957 merge, pre-#2225 file): **no such guard or phrase ever existed.** The pre-#2225 `flatten_database()` captured `head`, did remote-fetch compare, went straight into `preflight_counts` → `dolt_query` flatten — no HEAD-stability re-check.

What #2225 actually added was the **detection** (the `value_hash` preflight/postflight comparison + quarantine marker). Before #2225, the race existed silently. So the accurate framing is "#2225 made this race visible; this PR adds the prevention." Current body inverts that. julianknutsen, as #2225's author, will likely notice.

**Posture decision:** wait for him to raise it (confirmed in conversation). Do not preempt with a self-correcting comment during his review.

**Finding 2 (medium-likelihood) — "why not use the pending_gc/pending_push markers?"**

#2225 invested heavily in cross-fire recovery infra. A reviewer who wrote that scaffolding may ask why the new retry doesn't lean on it.

Pre-staged answer: orthogonal concerns. Markers are for cross-fire recovery after flatten/GC/push succeed-then-fail; my retry is inside a single fire, gating preflight before the expensive flatten. If 3 attempts exhaust, control flows back into the existing pending_gc path — markers not bypassed.

**Finding 3 (medium-likelihood) — three smaller asks.**

- `awk srand()` again — same nit as #2136. Offer `$RANDOM` switch.
- No new test — be ready to add a "side-process-writes-during-preflight" test in `compact_real_dolt_test.go`.
- Residual sub-ms race between preflight HEAD-stable confirmation and actual flatten reset — won't propose more retry; the #2225 value-hash quarantine is the safety net. Offer a one-line comment if asked.

**Self-check on `compacted_from_head` reassignment:** verified safe. Variable semantics = "the local HEAD value the compaction's preflight succeeded against"; updating on retry is consistent with #2225's marker contract (line 871 ancestry check still works).

### Step 4: compactor fire observation (PENDING ~08:10 PT)

(filled at EOD)

### Step 5: nudge decisions

- **#2088:** NO — second nudge would break protocol; flag as §24 question for another day.
- **#2136:** NO — nudged yesterday; let it ride.
- **#2316:** NO — actively under review; don't disturb.

### Step 6: tracker + commit

This commit covers the plan note only. Tracker update batched into the close-out commit at EOD.

### Step 7: Day-29 punt

(EOD — depends on whether julianknutsen submits review today, and the 5th-fire datum)

### G1-G3 verdicts (pending EOD recheck)

- **G1:** partially falsified at AM read (active review in-flight, no submitted body yet). Final verdict EOD.
- **G2:** pending — fire window 08:08-08:12 PT.
- **G3:** SATISFIED at AM read — beads still v1.0.4.

### Surprises

(EOD)

### What the day actually produced

(EOD)

### Process lessons captured

(EOD)
