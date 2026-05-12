# Day 12 — File `mc-uhvbb9` as an upstream issue (second-surface contributor engagement)

- **Plan authored:** 2026-05-12 (after Day-11 wrap)
- **Planned execution:** 2026-05-13 (or later same day)
- **Status:** Plan only; issue not yet filed

This is the pre-decomposition for Day-12: a different shape from Day-11 (which was a PR) and from Days 5-10 (which were investigations or experiments). Day-12 is a **second upstream surface** — translating Day-8 and Day-10's diagnosis of `mc-uhvbb9` into a `gh issue create` against `gastownhall/gascity`.

The technical work is already done. The new skill activating today is **issue-filing as a separate contributor mode from PR-filing**: filing observations that lack a clean fix-shape, demonstrating ongoing engagement with the project, and translating internal-diagnostic-notes into something a maintainer can act on.

---

## 1. The signal — what we're filing

**Local bead `mc-uhvbb9`** (P3, open in our HQ store): "refinery patrol wisp doesn't react to bead.updated events despite live session + matching metadata." Originally filed Day-8 after S5 investigation. Day-10 paired-control validation narrowed the scope: refinery's `gc events --watch` IS reliable under nominal conditions, but **fails under heavy concurrent reconciler I/O load** — likely streaming-API starvation traced to `mc-f7u8fz`.

**Why issue-shaped, not PR-shaped:**

- The fix lives upstream in Go, probably in the reconciler tick body at `cmd/gc/city_runtime.go:610-749` (the same code mc-f7u8fz is about). Beyond a 21-line shell-script PR's scope.
- The reproduction is conditions-dependent (needs the city under reconciler I/O load). Hard to package as a deterministic test.
- The right next step is **maintainer awareness** so they can decide whether to fix at the watch layer, the API layer, or the reconciler layer. We don't have enough Go-internal context to choose for them.

**Career arc (Day-12 framing):**

After Day-11 landed PR #2037 (first upstream PR), Day-12 exercises the **second contributor surface**: filing an issue. Different muscle from PR work — less code commitment, more observation-quality, faster to ship, and useful when the right fix isn't yet clear. Normalizes "I file issues for things I notice" as a routine engagement pattern.

---

## 2. Pre-flight: where this lives

- Day-8 notes: `study/notes/2026-05-12-s5-refinery-work-discovery.md` — full diagnosis trail, 2534-events evidence
- Day-10 notes: `study/notes/2026-05-12-day10-consolidation-and-paired-control.md` — the R-equiv finding that narrowed scope
- Local bead `mc-uhvbb9` itself — has the original signal + the Day-10 `bd note` scope refinement
- PR #2037 should still be in flight (Day-11 plan §4 Step 3 set 24-72h watch). Day-12 issue filing is parallel work, not a substitute. Don't comment on PR #2037 while filing the issue; they're separate threads.
- `gh issue` CLI: `gh issue create --repo gastownhall/gascity ...`
- Need to check pre-flight: (a) does the project have an `.github/ISSUE_TEMPLATE/`? (b) is there already an issue covering this? (c) what's the project's issue-style convention (looking at recent issues)?

---

## 3. What "done" looks like (success criteria)

**Process learning (durable deliverable):**

- v2 manual extended with the **issue-filing variant** of the §24 contributor playbook. Either §24's own subsection ("Filing an issue instead of a PR") or a new §25. Captures the differences: how to search for duplicates first, what level of evidence is appropriate for an issue vs PR, how to format reproduction steps when the bug is condition-dependent.

**Issue outcome (any of these is fine):**

- **Issue filed cleanly** with a clear repro, evidence, and a "what to investigate" suggestion. Best case.
- **Closed as duplicate** of an existing issue. Acceptable — means we found a related thread to follow.
- **Closed as "by design"** with maintainer explanation. Educational — we learn what the intentional design is.

**Bead update:**

- `mc-uhvbb9` local bead gets a `bd note` linking to the upstream issue number (e.g., `gastownhall/gascity#<N>`). Future references to mc-uhvbb9 land at the upstream tracking record.

**Personal milestone:**

- Two upstream surfaces engaged: PR #2037 (Day-11) and Issue #N (Day-12). The "I contribute upstream as a routine matter" identity is now visible in your GitHub activity, not just in a single PR.

---

## 4. Execution plan — translate, then file, then capture

### Step 1: Search for duplicates (~5 min)

```bash
gh issue list --repo gastownhall/gascity --search "refinery watch" --state all --limit 10
gh issue list --repo gastownhall/gascity --search "patrol bead.updated" --state all --limit 10
gh issue list --repo gastownhall/gascity --search "events watch SSE" --state all --limit 10
gh issue list --repo gastownhall/gascity --search "streaming API starvation" --state all --limit 10
```

If a related issue exists, the right move may be to **comment on the existing thread** with our evidence rather than open a duplicate. Day-12 still produces value: we engage upstream and add data to a known-tracked concern.

### Step 1.5: Falsification grep (Day-7 lesson — front-loaded again)

Before filing, confirm our central claims still hold in current upstream:

```bash
cd /Users/rfvitis/my-city/study/gascity-src
git fetch origin
# Verify refinery's discovery predicate is still what we documented in Day-8
grep -rn "find-work\|RecordSessionBaseline" examples/gastown/packs/gastown/formulas/
# Verify gc events --watch still requires the streaming city API
grep -n "requireStreamingCityAPI" cmd/gc/cmd_events.go
```

If the formula step or the API requirement has changed since Day-8 (it's been days; upstream is active), the issue's framing needs adjustment. The Day-9, 10, and PR-2037 experience showed upstream advances fast (Day-7's local fix already got reverted once via `gc start`).

### Step 2: Check issue template + recent issue style (~10 min)

```bash
ls .github/ISSUE_TEMPLATE/ 2>&1
cat .github/ISSUE_TEMPLATE/*.md 2>&1 | head -100
gh issue list --repo gastownhall/gascity --state open --limit 5
gh issue view <recent-issue-number> --repo gastownhall/gascity   # for tone
```

Match their convention. Recent merged commits used `fix(scope):` style for PRs; issues may use a labels-based system (`bug`, `enhancement`, etc.) or a templates-based one.

### Step 3: Draft issue body (~20 min)

Skeleton (adjust for whatever template they provide):

```markdown
## Summary

Under heavy concurrent reconciler I/O load, `refinery`'s patrol formula
`mol-refinery-patrol` step `find-work` does not react to `bead.updated`
events that satisfy its discovery predicate. The patrol wisp sits in
`gc events --watch --type=bead.updated` indefinitely while the watch's
underlying SSE stream is presumably starved.

## Repro context

Observed in a local Gas City instance on 2026-05-10:

- Polecat assigned bead `auth-wg0` to refinery at 10:10:19 PDT with valid
  metadata (`branch`, `target`, `work_dir`, `gc.routed_to`).
- Bead was `status=open`, `assignee=co_auth/gastown.refinery`, satisfying
  the find-work predicate exactly.
- Refinery's session was alive (`session.woke` at 09:59:19, no `session.stopped`
  until 13:29:30).
- 2534 `bead.updated` events fired in the 1h 19m window between assignment
  and human intervention (timestamp `2026-05-10T10:10:19-07:00` →
  `2026-05-10T11:29:58-07:00`).
- Refinery did not pick up the bead in that window. Human intervened at
  11:29:58 to manually close with merge metadata.

Concurrent context: the city was under the JSONL push-failure storm at the
time (now-fixed in [PR #2037](#2037) reference once landed), which kept the
reconciler in heavy I/O cycles (later measured at p50=27s, p99=166s,
max=244s).

## Day-10 paired-control validation

On 2026-05-12, ran a hello-world handoff with the same shape but under
nominal load (no concurrent JSONL storm, less I/O pressure). The bead was
filed without any explicit nudge instruction and refinery picked it up
within seconds via the watch. Total handoff: 9 min 29s.

So the watch IS reliable under nominal conditions. The failure mode is
specifically under heavy concurrent reconciler I/O.

## Hypothesis

The `gc events --watch` path requires the streaming city API
(`requireStreamingCityAPI` at `cmd/gc/cmd_events.go:769`). Under
reconciler I/O saturation, the streaming API endpoint may be starved
enough that the SSE stream hangs — and refinery's patrol wisp sits
forever in the watch.

## What I checked / ruled out

- Refinery's discovery predicate matched the bead exactly (verified by
  reading the bead metadata at the relevant timestamp).
- The 2534 intervening `bead.updated` events were not lost — they appear
  in `.gc/events.jsonl` at the expected timestamps.
- The refinery session was alive throughout (verified via session.woke /
  session.stopped events).

## What I didn't reproduce

- I haven't been able to deterministically reproduce the watch hang in
  a controlled setting. The Day-10 paired control passed under nominal
  load; the original Day-4 occurrence was under storm load. Reproducing
  the storm conditions on demand is non-trivial.

## Suggested investigation directions

- Add timing instrumentation around the SSE delivery path on the city
  API server side — does the stream go idle, or does it deliver events
  that the watch client silently drops?
- Consider a belt-and-suspenders periodic poll inside the patrol formula
  (e.g., every 60s explicit `bd list` poll alongside the watch) as a
  reliability fallback.
- Possibly related: any upstream tracking on reconciler I/O cycle
  latency? (Locally tracked but not yet filed upstream.)

## Reference

Filing context: Gas City SDK was self-hosted in a local "city" for
learning purposes; this issue emerged through 8 days of guided
diagnostic and validation work. Full notes available on request if
helpful.
```

The draft above is the proposal — refine before filing based on what Step 1 finds (duplicates) and Step 2 finds (template format).

### Step 4: File (~5 min)

```bash
gh issue create \
  --repo gastownhall/gascity \
  --title "<title>" \
  --body-file /tmp/issue-body.md \
  --label bug   # if applicable to project's labels
```

Record the returned issue URL/number.

### Step 5: Link the local bead (~3 min)

```bash
bd note mc-uhvbb9 --content "Upstream issue filed at gastownhall/gascity#<N>: <URL>. Day-12 (2026-05-13)."
```

(If `bd note --content` doesn't exist as we saw on Day-10, use `bd note <id> "text"` positional form.)

### Step 6: v2 manual issue-filing variant (~30 min)

Add a subsection to §24 (or open §25) covering the issue-filing path:

- **When to file an issue instead of a PR**: bug is observable but fix shape unclear; bug needs maintainer triage to assign priority; bug is in scope you can't credibly fix yourself.
- **Search for duplicates first** — comment on existing threads rather than opening new ones.
- **Evidence level**: issues can be lower-polish than PRs but still need repro context. Be precise about what you observed and what you couldn't prove.
- **Issue-body honesty pattern**: include "What I checked / ruled out" and "What I didn't reproduce" sections. The latter is the issue-equivalent of the PR-template-checkbox honesty pattern from §24.
- **Don't propose specific code changes** — issues are for "what's wrong"; let the maintainer decide on "how to fix." If you have a fix idea, briefly mention it as a *direction*, not a prescription.

---

## 5. Failure modes pre-thought

**F1: Closed as duplicate.** Best case "negative" outcome — there's already a tracked thread. Add our evidence as a comment on the existing issue, link our local bead to it. The Day-10 evidence likely adds value even to a tracked issue.

**F2: Closed as "by design" or "intended behavior."** Possible if the watch is documented as best-effort. **Action:** thank the maintainer, capture the design rationale in our v2 manual §19 (the "nudge refinery" pattern subsection already softened post-Day-10; this would just be one more data point).

**F3: Maintainer asks for more reproduction info.** Hard to provide more — we have what we have. **Action:** acknowledge the gap, offer to instrument our setup if they can suggest specific traces to capture next time the conditions arise.

**F4: Maintainer says "interesting, will investigate" then no further action.** Most likely outcome for a low-priority diagnostic issue. Acceptable; the upstream record is the deliverable.

**F5: Maintainer says "could you turn this into a PR?"** Triggers a future Day-N where we attempt the fix. Probably belongs at the reconciler-perf layer (mc-f7u8fz territory), which is a multi-day undertaking. **Action:** thank them, agree, but be explicit that the fix's scope is bigger than a one-day PR and we'll plan it carefully.

---

## 6. Risk / blast radius

- **Issue is public and indexed.** Same considerations as PR #2037 — write as professional as you would in any code-review context.
- **Don't speculate beyond evidence.** Mark hypotheses as hypotheses, ruled-out cases as ruled-out, unknowns as unknowns. The Day-7 and Day-10 lesson about premise inversion applies — *our own diagnosis* could be wrong in ways we haven't caught.
- **Don't @-mention maintainers.** Open the issue, let the project's normal triage do its work.
- **Avoid linking PR #2037 in a way that implies we expect bundled attention.** They're separate threads; respect that.

---

## 7. Connection to prior days

- **Day-8** filed `mc-uhvbb9` locally with the original 1h-79min narrative.
- **Day-10** validated the watch IS reliable under nominal load, narrowed the bug's scope to "watch under heavy concurrent reconciler I/O."
- **Day-11** opened PR #2037 — proved the upstream-contribution workflow works for a fix-shape issue.
- **Day-12** completes the second upstream surface — the issue-shape engagement.
- Cumulative: PR + issue, both visible in your GitHub activity feed, both with internal-notes evidence trails behind them.

---

## 8. Adjacent work to fold in

**Today (Day-12):**

- Check PR #2037 status (Day-11 §4 Step 3 set a once-per-day cadence): `gh pr view 2037 --repo gastownhall/gascity` and `gh pr checks 2037 --repo gastownhall/gascity`. **Don't interact** unless something changed; just observe.
- v2 manual §24 issue-filing variant (Step 6 above).

**Soon (Day-13+):**

- If the issue gets a "duplicate of #X" response, Day-13 can be reading #X's full thread to understand the upstream's prior thinking.
- If PR #2037 receives feedback, that takes priority over filing additional content.
- Consider the third surface eventually: **a docs PR** (smaller stakes than a code PR). Anything in `docs/` or `engdocs/` we noticed during Days 5-10 that could be clearer?

---

## 9. Optional: mayor handoff

Skip. Personal-engagement work, same as Day-11.

---

## 10. Execution log

(filled in as work happens)

### Pre-flight outcomes

- Duplicate search results:
- Issue template format:
- Recent issue style observations:
- Falsification grep (Step 1.5) results:

### Issue filed

- URL:
- Number: gastownhall/gascity#
- Title used:
- Labels applied (if any):

### Local bead linkage

- [ ] `mc-uhvbb9` updated with upstream link

### v2 manual extension

- [ ] §24 issue-filing variant (or §25 added)

### Iteration / response

| Time | Event | Notes |
|---|---|---|
| | Issue filed | |
| | First maintainer response | |
| | Disposition (closed/in-progress/etc.) | |

### Surprises

(things this plan got wrong, or new things surfaced)

### Anything to promote to v2 manual (beyond Step 6)

(filled in after the response cycle)
