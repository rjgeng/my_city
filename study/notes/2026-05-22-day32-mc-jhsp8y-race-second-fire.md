# Day 32 — mc-jhsp8y second fire (in-flatten race repeat-or-not)

- **Plan authored:** 2026-05-21 PM (end of Day-31; inherited from Day-31 §6 Step 6 punt)
- **Planned execution:** 2026-05-22
- **Status:** Plan stamped. AM read goes into §6 Step 1 on execution.

Day-32 is the **second post-upgrade compactor observation day**, designed to characterize the in-flatten race that mc-jhsp8y captured from Day-31's quarantine marker. One data point is not a pattern; today's 5/22 fire is the discriminator.

---

## 0. Process note

Day-31 closed cleanly (commit `3f83944`), with a full §6 Step 6 punt that this plan is the expansion of. No plan-file gap this cycle.

---

## 1. Pre-flight context

**State going into Day-32 (Day-31 EOD, 2026-05-21):**

- **mc-jhsp8y** (in-flatten race on hq): **OPEN.** First quarantine marker captured 5/21 08:31:51 PT. Reason: `post-flatten value hash changed with row-count increase`. Acceptance: 3+ more daily fires to confirm reproducibility, OR non-repeat → downgrade.
- **mc-1zccc2** (original diagnosis bead): **OPEN**, redirected — preflight race confirmed FIXED by #2316. Closes when mc-jhsp8y resolves.
- **mc-4m2da1** (preflight-fix design bead): **OPEN**, partial-scope merged in #2316; flatten-cycle retry portion was speculative when written, now justified by mc-jhsp8y data.
- **PR #2316:** MERGED Day-29. Day-31 confirmed preflight retry works; safety net activates cleanly. No regression.
- **PR #2088** (convoy docs): **MERGED Day-30 evening** (2026-05-20T18:45:45Z by quad341, §24b direct-merge variant). Closed-loop verification due Day-32 AM.
- **PR #2136** (mol-dog-jsonl push race): OPEN, MERGEABLE, last update 2026-05-18T11:03:58Z. Day 6 post-Day-27-nudge. Wait-only.
- **Issue #3880 (beads):** v1.0.4 still latest (~13d old by Day-32). mc-mxl4vc blocked.
- **mc-z92fpi, mc-iho25h:** still OPEN with `hold-until-soak` labels. 24h post-upgrade soak window now satisfied (Day-30 09:53 PT + 24h = Day-31 09:53 PT), so labels are eligible to unlatch — but anti-plan #9 from Day-31 said don't unlatch on a single data point; today's fire is the second.
- **`gc` binary:** HEAD-fad5d3f (Day-30 upgrade, holds).
- **Quarantine marker preserved:** `.gc/runtime/packs/dolt/compact-quarantine/hq` — DO NOT delete, primary evidence for mc-jhsp8y.

**Carry-forward Day-31 lessons:**

1. **Help-text verbs need layer-disambiguation** ("replaces / supersedes" — ask interface vs. implementation before drawing structural conclusions).
2. **First-time safety-net activations are high-leverage observation events.** If a NEW artifact appears today (different quarantine reason, new file, new event type), treat it as primary diagnostic input over logs.
3. **End-of-day plan stamps go stale by morning for active PRs.** Morning read confirms #2088 didn't flip back, #2136 didn't move, beads release didn't ship.
4. **Drift prediction needs upgrade-shift hypothesis** — today's fire timing is the discriminator.

---

## 2. Morning read

```bash
date; gc version

# 5/22 compactor fire watch — same template as Day-31, but with full event capture
grep -E '"type":"order\.(fired|completed|failed)"' .gc/events.jsonl \
  | jq -r '"\(.ts)  \(.type)  \(.subject // .message)"' \
  | grep 'mol-dog-compactor' \
  | tail -5

# Quarantine state — did a NEW marker appear? what reason?
ls -la .gc/runtime/packs/dolt/compact-quarantine/
for f in .gc/runtime/packs/dolt/compact-quarantine/*; do
  echo "=== $f ==="; cat "$f"
done

# pending-gc state — did the failed run leave anything queued?
ls -la .gc/runtime/packs/dolt/compact-pending-gc/

# Order-due / next-fire snapshot
gc order check 2>&1 | grep mol-dog-compactor
gc order history mol-dog-compactor 2>&1 | head -3

# PR + release state
for pr in 2088 2136; do
  gh pr view $pr --repo gastownhall/gascity \
    --json state,mergedAt,reviewDecision,updatedAt,labels \
    | jq '{state, mergedAt, reviewDecision, updatedAt, labels: [.labels[].name]}'
done
gh release list --repo gastownhall/beads --limit 3

# Watched beads
bd list | grep -E 'mc-(jhsp8y|1zccc2|4m2da1|w9iua4|mxl4vc|z92fpi|iho25h)'
```

---

## 3. Decision matrix (three branches on compactor fire outcome)

| Fire outcome | Branch | Budget | Action |
|---|---|---:|---|
| **(a) Same quarantine reason** — `value hash changed with row-count increase` | In-flatten race **confirmed reproducible** (2/2 fires under post-#2316 code). | 60–120 min | Update mc-jhsp8y: bump confidence, note 2nd marker. Start *designing* (not implementing) flatten-cycle retry. Draft design notes inline in bead. No PR today. |
| **(b) Different quarantine reason** (e.g., `value hash changed without row-count increase`, `value hash probe failed`, `value hash probe returned empty value`, `post-flatten INTEGRITY check failed`) | A **third** failure mode in the same safety-net family. Widen mc-jhsp8y scope. | 60–90 min | Update mc-jhsp8y: append new variant section. The fix design becomes broader (not just row-count-gain case). |
| **(c) No fire OR exit-0** | In-flatten race may be **write-spike-dependent** or one-off. Don't close mc-jhsp8y on one clean fire. | 30–45 min | Update mc-jhsp8y: note 5/22 clean, continue soaking. Anti-plan #9-equivalent: 3+ clean fires required before downgrade. |
| **No fire AT ALL by 09:30 PT** (drift/dispatch broken) | Distinct from (c) — a scheduling regression. | 60–120 min | Diagnose dispatcher: `gc order check` snapshot, dispatcher trace UTC window, supervisor PID continuity. Possibly separate bead. |
| **Beads v1.0.5 ships** (low probability) | Auxiliary work. | +30–60 min | mc-mxl4vc city-upgrade (symlink swap). |

**Modal reasoning:** Day-31's marker reason was specific (`row-count increase` branch). If the underlying race is structurally "hq receives writes during flatten" then (a) is modal (~60%), since that condition is daily-typical for hq. (b) ~20% if other code paths in the safety-net family also race. (c) ~15% if Day-31's spike was unusual. "No fire at all" ~5% — would surprise.

---

## 4. Falsifiable predictions (G1–G4)

- **G1 (compactor fire outcome):**
  - *Field:* On Day-32 (5/22), `mol-dog-compactor` fires once between 08:30–08:50 PT and writes a NEW quarantine marker file in `.gc/runtime/packs/dolt/compact-quarantine/` with reason matching Day-31's (`post-flatten value hash changed with row-count increase`). `order.failed exit status 1`.
  - *Generator:* hq's write rate during compact is structural (mail/beads/wisps/sessions all write during the same 1–2 minute window). The race is reproducible.
  - *Falsifier:* (b) different reason; (c) no quarantine + exit-0; or no fire by 09:30 PT.

- **G2 (drift discriminator):**
  - *Field:* Fire timestamp lands in 08:30–08:50 PT (post-upgrade dispatch-shift hypothesis).
  - *Generator:* Day-30 binary upgrade reordered the cooldown-due-order dispatch slot; the new effective fire-time is the new baseline, not a continuing drift trajectory.
  - *Falsifier:* lands ~09:00+ PT → geometric drift acceleration hypothesis (a) holds; needs deeper investigation. Lands ~08:14–08:18 → drift has reverted, also surprising.

- **G3 (beads release):**
  - *Field:* v1.0.4 stays latest. mc-mxl4vc remains blocked.
  - *Generator:* ~13d silence on v1.0.5; cadence is 10–15d but no public movement signal as of Day-31.
  - *Falsifier:* v1.0.5 ships → trigger mc-mxl4vc upgrade workflow.

- **G4 (#2088 closed-loop):**
  - *Field:* PR #2088 stays MERGED. No revert. No follow-up issues opened against it (`is:issue mentions 2088`). No new comments on the merged thread since Day-30.
  - *Generator:* §24b direct-merge variants are typically stable post-merge (maintainer didn't request changes; merge was clean).
  - *Falsifier:* Revert PR opened, or critical comment thread on #2088, or issue cross-referencing it as breaking something.

---

## 5. Anti-plans

**Inherited from Day-31 (still apply):**

1. **Don't re-arm `gastown.deacon`** — quarantine markers are the diagnosis vector now.
2. **Don't open new PRs** unless review on #2136 forces one.
3. **Don't preemptively rebase #2136** — let it ride.
4. **Don't nudge #2136** — Day-27 nudge spent, no new nudge today.
5. **Local-time prefix when greping events.jsonl** (Day-27 lesson).
6. **Watch-day must produce an artifact** (Day-29 anti-plan #7).
7. **`gc dolt --help` style verbs** ("replaces") need layer-disambiguation before structural conclusions (Day-31 lesson #1).

**New for Day-32:**

8. **Don't open a flatten-cycle-retry PR even if branch (a) fires.** Design notes inline in mc-jhsp8y body only. PR comes after 3+ data points + a design decision, not on day-2 of evidence. Anti-plan #8 from Day-31 stays in force.
9. **Don't unlatch `hold-until-soak` labels on mc-z92fpi / mc-iho25h yet.** 24h soak window is satisfied by clock, but the compactor soak is still active (mc-jhsp8y open). Re-evaluate after 3+ clean fires OR fix shipped.
10. **Don't delete or rotate the Day-31 quarantine marker.** It is the baseline-1 evidence; if Day-32 marker differs in reason, comparison requires both files intact. If a NEW marker appears today, preserve BOTH (Day-31 + Day-32) — they become evidence pair for mc-jhsp8y.

---

## 6. Execution log

### Step 1: morning read (pending — execute Day-32 AM)

### Step 2: 5/22 compactor fire observation (pending — window 08:30–08:50 PT per G2)

### Step 3: branch selection per §3 matrix (pending)

### Step 4: #2088 closed-loop verification (pending — quick check)

### Step 5: EOD recheck + tracker / bead updates (pending)

### Step 6: Day-33 punt (pending)

---

### G1–G4 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
