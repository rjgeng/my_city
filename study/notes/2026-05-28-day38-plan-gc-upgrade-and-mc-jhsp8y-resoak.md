# Day 38 — gc upgrade + mc-jhsp8y re-soak kickoff (+ ambient PR #2638 watch)

- **Plan authored:** 2026-05-28 PM (end of Day-37, after Plan B execution)
- **Planned execution:** 2026-05-29
- **Status:** Plan stamped. Carry-forward day from Day-37 EOD.

Day-38 has one load-bearing action: **authorize `gc upgrade`** to a binary containing PR #2564 + #2598. Everything else is ambient or deferred.

---

## 1. Pre-flight context (terse — carry-forward from Day-37 EOD)

**State entering Day-38:**

- **Submodule** `study/gascity-src` at `0f50effe7` (latest `origin/main`). Contains PR #2564 + #2598.
- **Running gc binary** still `HEAD-fad5d3f` (predates PR #2564 + #2598). The race is still live until upgrade.
- **mc-cqm9nl:** CLOSED Day-37 (superseded by PR #2564 + #2598).
- **mc-aep8yk:** CLOSED Day-36, supersession note appended Day-37.
- **mc-jhsp8y:** OPEN. Acceptance #3 (≥3 clean fires under race conditions) now gated on `gc upgrade` + re-soak.
- **mc-1zccc2 / mc-4m2da1 / mc-iho25h / mc-z92fpi:** OPEN, gated on mc-jhsp8y.
- **mc-itt3xc:** OPEN, tracking PR #2638.
- **mc-mxl4vc:** OPEN, blocked on beads v1.0.5.
- **PR #2638:** OPEN, `CHANGES_REQUESTED` from sjarmak 5/27 11:54Z; my "all three addressed" reply 5/27 14:11Z. ~48h+ since my response by Day-38 morning; still inside the §24a wait window.
- **Supervisor PID 786** alive since 5/27. Anti-plan #15 lifted; no constraint.
- **4-city setup:** my-city, my-llm-wiki, gastownhall-logs, 4g-city.

**Carry-forward (load-bearing):**

- From Day-37 lesson #1 + [[feedback_upstream_pr_scan_during_soaks]]: scan upstream PRs in the same problem space before re-soak design — confirms PR #2564 + #2598 are still the only fix landed (no further refinements that change the validation oracle).
- From [[feedback_gc_global_supervisor_ops]]: `gc upgrade` is a machine-global op. It restarts the supervisor across all four cities. Capture pre-upgrade state in /tmp before authorizing.

---

## 2. Execution sequence

### Step 1 — morning sync

```bash
date; gc version; ps -o pid,etime,command -p 786 2>/dev/null
gh pr view 2638 --repo gastownhall/gascity --json state,reviewDecision,updatedAt,comments \
  --jq '{state, reviewDecision, updatedAt, last_comment: (.comments|sort_by(.createdAt)|last|{author:.author.login, createdAt})}'
gh release list --repo gastownhall/beads --limit 3
# Confirm PR #2564 + #2598 are still the only relevant upstream PRs in this space:
git -C study/gascity-src log --oneline --since="2026-05-25" -- examples/dolt/commands/compact/ \
  | head -15
```

### Step 2 — pre-upgrade snapshot (/tmp note)

Before authorizing `gc upgrade`, capture:
- Current `gc version` output.
- `ps -o pid,etime,command` for all gc supervisor + agent processes.
- Active city list: `gc cities`.
- Marker counts: `find .gc -path '*quarantine*' -name '*.json' | wc -l`, same for `pending_gc_dir`.
- Last 5 compactor fires from `events.jsonl`.

Goal: post-upgrade we want to know what changed and have evidence of the pre-upgrade race-marker state. Saved to `/tmp/day38-pre-upgrade-snapshot.txt`. No committed note unless something surprising surfaces.

### Step 3 — authorize gc upgrade (user-gated)

Surface to user with: target version (whatever upstream HEAD builds to), scope (machine-global, all 4 cities), expected restart (supervisor PID cycle + all rig agents). **Do NOT execute without explicit "go".** Per CLAUDE.md "Explain plan before major edits" + the machine-global risk class.

If user authorizes: `gc upgrade`. Capture before/after output. Verify new gc version contains the target commits.

If user defers: Day-38 becomes a watch-only / rig-expansion-chat day. The plan still ships (no harm) but Step 4-5 don't fire.

### Step 4 (conditional on Step 3) — mc-jhsp8y re-soak start

Once binary is upgraded:
- Confirm doctor cadence is active on hq (witness should be picking up beads).
- Start a 3-day soak window: 2026-05-29 → 2026-06-01.
- Add `pending_gc_dir` to the soak-evidence template (alongside `quarantine_dir`).
- File a /tmp tracking note with the soak start time and expected first compactor fire window.

**Critical**: under PR #2564, the success signal is **non-zero pending-GC markers AND zero quarantine markers**. A silent soak with neither could mean the doctor isn't firing — that's not a pass, that's a missing-evidence soak. The validation requires *seeing* the gate fire and defer correctly.

### Step 5 — EOD recheck + any /tmp note promotions

If anything surprising happened during upgrade, promote /tmp note to `study/notes/`. Otherwise EOD note is light: "upgrade landed, soak started, all green so far."

### Step 6 — Day-39 punt

Day-39 = mid-soak observation day. Day-40 = soak EOD if windows align. Re-soak EOD plan written when we have ≥1 day of data.

---

## 3. Decision matrix (light)

| Day-38 outcome | Branch | Day-39+ work |
|---|---|---|
| User authorizes upgrade → upgrade clean → soak starts | **(a)** modal | Soak observation Day-39, Day-40 |
| User authorizes upgrade → upgrade fails / unexpected behavior | (b) | Diagnose-day on upgrade; possibly revert |
| User defers upgrade → rig-expansion chat happens | (c) | Day-39 rig-expansion + push upgrade authorization |
| User defers upgrade → no chat, watch-only day | (d) | Day-39 same posture; nudge upgrade timing |
| PR #2638 gets maintainer activity mid-day | (e ambient) | Respond per §24a rules; doesn't change Day-38 shape |

**Modal expectation:** (a) at ~60%, (c) at ~20%, (d) at ~15%, (b) at ~3%, (e) ambient/independent.

---

## 4. Falsifiable predictions (light — ambient)

- **G2 (PR #2638 maintainer-response watch — ambient):**
  - *Field:* PR #2638 stays at `CHANGES_REQUESTED` with my 5/27 14:11Z reply unaddressed. Modal expectation: still in maintainer queue by Day-38 EOD (~50h+ post-response).
  - *Falsifier:* any maintainer activity — re-review, label change, merge, request for changes.

- **G3 (beads release watch — ambient):**
  - *Field:* v1.0.4 stays latest. mc-mxl4vc remains blocked.
  - *Falsifier:* v1.0.5 ships.

- **G4 (supervisor uptime — ambient, expected to cycle):**
  - *Field:* IF upgrade fires, supervisor PID cycles from 786. NOT a constraint violation.
  - *Falsifier:* PID 786 still alive at EOD = upgrade didn't fire (Step 3 deferred).

- **G5 (re-soak first-fire — load-bearing IF upgrade fires):**
  - *Field:* First post-upgrade compactor fire (probably ~6-8h after upgrade based on cadence) produces a `pending_gc_dir` marker and zero `quarantine_dir` markers, AND doctor commits land during the flatten window.
  - *Falsifier (any of):* quarantine marker reappears (PR #2564 didn't cover our case — re-open mc-cqm9nl); zero markers of either kind (doctor isn't firing — soak invalid); upgrade didn't include PR #2564 (version mismatch — investigate).

---

## 5. Anti-plans

**Inherited from Day-37 (carry-forward):**

1. Don't nudge PR #2638. ~48h since my response by Day-38 morning; still well inside §24a wait window. Maintainer engagement was good (substantive review); they'll come back.
2. Don't unlatch `hold-until-soak` labels on mc-iho25h / mc-z92fpi.
3. Don't promote co_store ↔ 4g-store or co_shipping ↔ 4g-shipping today (#20 from Day-37).
4. Don't fully implement any beads today. Day-38 is upgrade + soak start, not impl work.

**New for Day-38:**

23. **Don't run `gc upgrade` without explicit user authorization.** Machine-global, affects all 4 cities, supervisor PID cycle, rig agents restart. CLAUDE.md "explain plan before major edits" + the [[feedback_gc_global_supervisor_ops]] memory both apply.
24. **Don't re-file mc-cqm9nl as a "validation bead."** mc-jhsp8y already IS the validation bead — its acceptance #3 covers it. Fan-out for fan-out's sake is the anti-pattern.
25. **Don't close mc-jhsp8y on Day-1 of the soak even if it looks clean.** Acceptance is ≥3 consecutive clean fires under race conditions. Day-1 = n=1 at best. Patience.
26. **Don't post on PR #2638 about our supersession.** This is internal context. PR #2638 is about gc init supervisor cycling, not the compactor race. Cross-streams.

---

## 6. Execution log

### Step 1: morning sync (pending — execute 5/29 AM)

### Step 2: pre-upgrade snapshot (pending)

### Step 3: gc upgrade authorization + execution (pending)

### Step 4 (conditional): mc-jhsp8y re-soak start (pending)

### Step 5: EOD recheck (pending)

### Step 6: Day-39 punt (pending)

---

### G2–G5 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
