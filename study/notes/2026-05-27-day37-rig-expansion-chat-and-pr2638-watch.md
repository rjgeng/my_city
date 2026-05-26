# Day 37 — rig expansion chat + PR #2638 watch + mc-cqm9nl kickoff (post-soak)

- **Plan authored:** 2026-05-26 PM (end of Day-36, post-soak)
- **Planned execution:** 2026-05-27
- **Status:** Plan stamped. First post-soak day; rhythm continues for sequencing purposes, not for fire-window observation.

Day-37 is the **first post-soak day.** The mc-jhsp8y characterization closed cleanly at Day-36 with n=4 evidence + Candidate A selected + mc-cqm9nl impl bead filed. Anti-plan #15 is fully LIFTED. No supervisor freeze, no fire window watch, no G2 experiment ongoing.

**The day shape is conversational + decisional**, not observational. Two paths fork early depending on the morning chat outcome:

1. **co_thinking + co_ops rig adds path** — user is ready to start; we sequence + execute.
2. **defer further path** — user wants to think; we don't start rig work today, fall back to mc-cqm9nl implementation kickoff or PR-watch-only.

---

## 0. Process note

The soak rhythm (decision matrix → fire window → branch outcome → EOD writeup) doesn't fit a post-soak day cleanly. This plan keeps the day-N file convention (per `feedback_day_numbering`: tracks plan EXECUTION date) but trims the soak-shaped sections that don't apply. Future post-soak day plans should follow this lighter template until a new observational rhythm (next soak, next experiment) re-introduces fire-window-style structure.

---

## 1. Pre-flight context (brief)

**State entering Day-37 (Day-36 EOD + post-EOD work, 2026-05-26):**

- **mc-jhsp8y:** OPEN, characterized n=4. Closes when mc-cqm9nl ships and validates ≥3 consecutive clean fires under previously-race-triggering conditions.
- **mc-aep8yk:** CLOSED Day-36+ (Candidate A picked, rationale recorded in closing note).
- **mc-cqm9nl:** OPEN, P3 feature. Implementation bead for Candidate A (persistence-policy branching). Awaits separate diagnose-day for actual code work.
- **mc-itt3xc:** OPEN, P2 bug. The gc-init silent-supervisor-cycle bead. Tracks PR #2638.
- **mc-1zccc2, mc-4m2da1, mc-iho25h, mc-z92fpi:** OPEN, awaiting mc-jhsp8y resolution (downstream).
- **mc-mxl4vc:** OPEN, blocked on beads v1.0.5.
- **PR #2638:** OPEN at gastownhall/gascity, status/needs-triage, opened 18:46Z 5/26 (day 0). Title: `fix(gc): warn before supervisor recycle during city init`. AI-assist disclosed in commit body.
- **gc binary:** HEAD-fad5d3f. Supervisor PID 30349 alive since 5/24 04:33 PT (~76h+ at Day-37 morning). **Anti-plan #15 LIFTED** — no preservation required.
- **Active 4-city setup:** my-city, my-llm-wiki, gastownhall-logs, 4g-city (the last added via the 04:33 PT incident; previously empty post-init, may need further setup).

**Carry-forward (load-bearing):**

- From Day-34 lesson #2: "demote, don't keep load-bearing — patch plans before tests."
- From Day-36 lesson #3: "rebaselined experiments can recover with disciplined holds."
- From [[feedback_gc_global_supervisor_ops]]: `gc init` / `gc cities` / `gc supervisor *` / `gc upgrade` / `gc dashboard restart` are machine-global operations. If today's rig adds use `gc init <new-city>` path, our own PR #2638's guard will now fire — eat the dogfood.

---

## 2. Execution sequence

### Step 1 — Morning sync + PR #2638 status check

```bash
date; gc version; ps -o pid,etime -p 30349
gh pr view 2638 --repo gastownhall/gascity --json state,labels,reviewDecision,updatedAt | jq '{state, labels: [.labels[].name], reviewDecision, updatedAt}'
gh release list --repo gastownhall/beads --limit 3
bd list 2>/dev/null | grep -E 'mc-(jhsp8y|aep8yk|cqm9nl|itt3xc|1zccc2|4m2da1|mxl4vc|z92fpi|iho25h)'
```

### Step 2 — co_thinking + co_ops chat with user

The chat covers ([[project_post_day34_rig_expansion_plan]] is the reference):

1. **Sequencing**: parallel (both same day) vs serial (co_thinking first, then co_ops). Cost/benefit: parallel is faster but mixes failure modes; serial keeps the diagnose-loop tight per rig.
2. **Path**: city.toml-only `[[rigs]]` entry (no supervisor restart) vs `gc init <new-city>` (uses our PR #2638 guard, lets us dogfood it). Memory recommendation: prefer city.toml-only unless explicit reason for new-city scope.
3. **Remote setup**: 4g-thinking and 4g-ops as GitHub remotes (mirror co_auth's pattern: `git init` local, `git remote add` to upstream).
4. **Step 3 deferral**: confirm co_store/co_shipping promotion stays deferred (per memory: "explicitly deferred and may not happen at all").

### Step 3 (conditional) — Execute rig adds

If chat resolves to GO: execute per sequencing decision from Step 2. Otherwise, skip to Step 5.

### Step 4 (conditional) — mc-cqm9nl implementation kickoff

If chat defers rig work AND user has appetite: start mc-cqm9nl Candidate A implementation in `study/gascity-src` (parallel branch to PR #2638 — `rjgeng/fix/compact-persistence-policy-variant` or similar). Per anti-plan #19 from the soak era, picking a candidate is one thing; implementing is a separate scoped task. Day-37 can do the *kickoff* (branch + scaffold + first test) but not the full implementation.

### Step 5 — EOD recheck + bead/note updates

### Step 6 — Day-38 punt (if any)

---

## 3. Decision matrix (light — rig-add path conditional)

| Chat outcome | Branch | Day-37 work | Day-38+ work |
|---|---|---|---|
| GO — both rigs, parallel, city.toml path | **(a)** | Add `[[rigs]]` entries for co_thinking + co_ops, `git init` two local sibling repos, `git remote add` to 4g-thinking + 4g-ops, verify gc picks them up | Operational watch (witness activity, dispatcher, mail routing) for a few days |
| GO — both rigs, serial, city.toml path | (b) | Add co_thinking first; observe one day; then co_ops Day-38 | Same operational watch but staggered |
| GO — `gc init` path (dogfood PR #2638) | (c) | Run `gc init` for one of the rigs as a separate city to exercise the PR #2638 warn+confirm flow. Capture the dogfooded UX as evidence on the PR. | Decision: continue with separate-city path or revert to city.toml `[[rigs]]` |
| DEFER — chat resolves to "not today" | (d) | Skip Step 3. Either start mc-cqm9nl implementation kickoff (Step 4) OR park as a PR-watch-only day | Re-attempt rig chat Day-38 or later |
| DEFER — chat opens new questions we can't answer today | (e) | Skip to Step 4 or Step 5; capture questions in a bead | Schedule a focused diagnose-day for the unresolved questions |

**Modal expectation**: branch (a) or (b) at ~50% combined, (c) at ~15% (cool but probably premature), (d) at ~25%, (e) at ~10%.

---

## 4. Falsifiable predictions (light — mostly ambient)

**No load-bearing G1 today** (no experimental test in progress).

- **G2 (PR #2638 maintainer-response watch — ambient):**
  - *Field:* PR #2638 stays at `status/needs-triage`, no review yet. Day 0 of post-open silence; modal expectation is no response.
  - *Falsifier (good):* any maintainer activity — label change, comment, review, reviewer assignment, CI fail/pass surface.

- **G3 (beads release watch — ambient):**
  - *Field:* v1.0.4 stays latest. mc-mxl4vc remains blocked.
  - *Falsifier:* v1.0.5 ships → trigger mc-mxl4vc city-upgrade workflow.

- **G4 (supervisor uptime — ambient, no constraint):**
  - *Field:* PID 30349 still alive at end of day. Anti-plan #15 lifted, so a restart is NOT a failure — just a data point.

---

## 5. Anti-plans

**Inherited (slimmed — only those still applicable post-soak):**

1. Don't nudge PR #2638 (§24a wait-only, day 0 — too early).
2. Don't open new PRs today (let PR #2638 land first; mc-cqm9nl PR is later work).
3. Don't unlatch `hold-until-soak` labels on mc-iho25h / mc-z92fpi (those soaks are conceptually different — bound to mc-jhsp8y fix landing, not the closed Day-34/35/36 supervisor-age experiment).
4. Preserve archived markers in `/tmp` (Day-31, Day-34, Day-35).

**Lifted (the soak-era constraints are GONE):**

- ~~anti-plan #15~~ — supervisor freeze: LIFTED.
- ~~anti-plan #18~~ — no deferred work until Day-36 EOD: LIFTED.
- ~~anti-plan #19~~ — no fix-shape pick during Day-36 EOD: LIFTED (Candidate A picked).

**New for Day-37:**

20. **Don't promote co_store ↔ 4g-store or co_shipping ↔ 4g-shipping today.** That's Step 3 of [[project_post_day34_rig_expansion_plan]], explicitly deferred. Only co_thinking and co_ops are in scope this round.
21. **If chat resolves to `gc init` dogfood path (branch (c)), record the warn+confirm UX in a /tmp note** — that's evidence material for PR #2638's reviewers. But don't add it as a PR comment unless the maintainer asks (one-and-done framing keeps the PR clean).
22. **Don't fully implement mc-cqm9nl today.** Kickoff scaffold + first test is fine if user has appetite; full implementation is a multi-hour task and the post-soak-day-1 budget shouldn't be spent on it.

---

## 6. Execution log

### Step 1: morning sync + PR #2638 status (pending — execute 5/27 AM)

### Step 2: co_thinking + co_ops chat (pending)

### Step 3 (conditional): execute rig adds (pending)

### Step 4 (conditional): mc-cqm9nl impl kickoff (pending)

### Step 5: EOD recheck + bead/note updates (pending)

### Step 6: Day-38 punt (pending)

---

### G2–G4 verdicts (EOD)

(pending)

### Surprises

(pending)

### What the day actually produced

(pending)

### Process lessons captured

(pending)
