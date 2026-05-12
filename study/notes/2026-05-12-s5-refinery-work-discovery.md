# Day 8 — Diagnose S5: how does refinery discover work, and why was `auth-wg0` skipped?

- **Plan authored:** 2026-05-12 (after day 7 wrap)
- **Planned execution:** 2026-05-13 (or later same day)
- **Status:** Plan only; investigation not yet started

This is the pre-decomposition for Day-8: continue with the last unaddressed Day-4 S-item. Day-4 surfaced six S-observations; S1, S2, S6, S7, S8 were narrative-only or already promoted to memory/manual; S3 was fixed Day-5; S4 was diagnosed Day-6; the work scripts S5 references were touched Day-7 incidentally. **S5 itself — the refinery work-discovery question — is still uninvestigated.** Same exercise pattern as Days 4-7: write the plan first, then compare actuals.

---

## 1. The signal — what S5 is

From `study/notes/2026-05-10-mayor-led-auth-demo.md:223-224` (Day-4):

> **S5. Refinery doesn't auto-discover work that lacks `merged_commit` metadata.**
> After the polecat finished `auth-wg0` (schema) it drained without closing the bead (it respected mayor's spec saying "Then STOP. auth-G2 reviews schema choices…" too literally). The bead sat OPEN with assignee=refinery, but refinery's patrol declared "queue empty" because its discovery logic keys off `merged_commit` metadata on closed beads. The human had to manually close `auth-wg0` with full merge metadata (branch, merged_commit=0672de7, target=main, work_dir), THEN nudge refinery — at which point refinery did the actual merge cleanly.

This narrative is internally inconsistent on close reading:

- The bead was **OPEN** when refinery declared "queue empty," but the writeup says refinery's discovery "keys off `merged_commit` metadata on **closed beads**." If refinery only looks at closed beads, why does an OPEN bead with assignee=refinery need to be in its set in the first place?
- v2 manual §19 line 808 says refinery **records** `merged_commit` on the bead after merging. So `merged_commit` is a *write output*, not a *discovery input*. The Day-4 writeup may have inverted cause and effect.
- v2 manual §19 line 825 says the right thing: "If mayor writes a bead spec that says **'Then STOP…'**, polecat … skips its own closure step. The branch lands, but the bead never enters refinery's **discovery set**." But what *is* refinery's discovery set?

**So S5 has two separable questions:**

1. **What does refinery's discovery logic actually look for?** (open beads with assignee=refinery? branches ahead of main? something else?)
2. **Why did `auth-wg0` not appear in that set on Day-4 even though it was OPEN with assignee=refinery?**

Both are answerable from code + historical event data. No reproduction strictly required, though one would confirm the diagnosis.

**Why this is the right Day-8 target:**

- Last unaddressed Day-4 S-item — closing the S-list is a clean narrative milestone.
- Pure diagnostic exercise (no fix in scope unless something obvious surfaces). Days 5 & 6 were diagnostics; Day-7 was a fix. Returning to diagnosis after a fix day matches the "diversify the exercise type" rhythm.
- The diagnostic toolkit is now well-rehearsed: `gc trace`, `bd query`, code reading + falsification. Should be efficient.
- Touches **a third surface** beyond what Days 4-7 covered: refinery / merge-discovery logic (Days 5-7 were dolt + reconciler + pack scripts).

---

## 2. Pre-flight: where this lives

- Refinery is a per-rig agent configured via `[[rigs]]` in `city.toml`. The discovery logic lives in upstream Go code (likely under `cmd/gc/` or `internal/`).
- Historical event data from Day-4 lives in `.gc/events.jsonl` and per-rig `.beads/` data. The `auth-wg0` bead and its sibling impl beads (`auth-1` … `auth-6`, `auth-s4d`, etc.) are in the `co_auth` rig's dolt database.
- The mayor demo's full event timeline (2026-05-10) is the substrate — refinery's "queue empty" decisions for that day should be in the event log.
- City is currently stopped. Dolt is running (port 50213 from Day-7). The bd query path against `auth` / `cs` / `hq` / etc. works via the patched dolt-target.sh.

---

## 3. What "diagnosed" looks like (success criteria)

- Locate the function(s) in `study/gascity-src/` that drive refinery's work discovery. Identify the exact predicate: bead state, assignee, metadata fields, branch state on disk, or some combination.
- Locate (or confirm absent) any refinery-specific trace records analogous to the reconciler's `cycle_result` — if refinery emits its own decisions to a trace stream, we can reconstruct what it saw on Day-4 directly.
- Reconstruct from historical data (event log + bead history) why `auth-wg0` was OPEN-with-assignee=refinery but not picked up. Likely answers:
  - Predicate requires bead in **CLOSED** state (matches manual §19's description), so OPEN beads are invisible no matter who they're assigned to.
  - Predicate requires a specific metadata field set by polecat at the end of its work (e.g., `branch`, `work_dir`, or a "ready for merge" flag) that polecat skipped along with the close.
  - Predicate scans rig branches ahead of `main` directly and never reads the bead at all; closure is what marks the merge as "done."
- Verdict on whether the Day-4 writeup's framing ("keys off `merged_commit` metadata on closed beads") is accurate, misleading, or backwards.
- File a follow-up bead if a real bug surfaces (e.g., a discovery predicate that's stricter than the polecat→refinery contract suggests). Diagnose-only is a valid end state if the system is working as designed.

---

## 4. Investigation plan — falsify cheapest checks first

### Step 1: Locate refinery discovery in code (~20 min, free)

Read these first:

- Grep `study/gascity-src/` for terms that name refinery's job: `refinery`, `merge`, `discover`, `claim`, `work_query`, `assignee`, `merged_commit`. Cast a wide net; refinery is a *role* not a *code object*, so it's likely referenced by a template/formula configuration, not a struct.
- Look at any "patrol" or "wake_decision" code path — refinery is described as patrolling for work; that's a reconciler-style loop with its own discovery predicate.
- v2 manual §19 line 808: "Fast-forwards (or merge-commits for non-FF), records `merged_commit` on the bead." That's the *write* side; the *read* side that decides what to merge is the discovery question.

Output: a one-paragraph mental model of refinery's discovery predicate, citing the specific Go function(s).

### Step 1.5: Grep for the "merged_commit" claim (~5 min, free)

**Day-7 lesson — front-load the grep that could invalidate the bead's premise.** S5's writeup claims refinery "keys off `merged_commit` metadata." Confirm or refute by:

```bash
grep -rn "merged_commit\|MergedCommit\|merged-commit" study/gascity-src/{cmd,internal,packs}/ 2>/dev/null
```

If zero hits → the writeup's term is wrong; refinery doesn't read `merged_commit` for discovery, it only writes it as an output. The real discovery key is something else. (Day-7-style premise inversion.)

If hits → trace those call sites to confirm they're read-paths (discovery) vs write-paths (output).

This single grep should reorient the investigation before any deeper hypotheses form.

### Step 2: Check whether refinery has its own trace stream (~5 min)

The reconciler has `gc trace` against `.gc/runtime/session-reconciler-trace/`. Refinery may have something analogous. Try:

```bash
ls .gc/runtime/ | grep -i refine
find .gc/runtime -maxdepth 3 -type d 2>/dev/null
gc help 2>&1 | grep -i refine
```

If a per-rig refinery trace exists, query it like we did for the reconciler. If not, fall back to `.gc/events.jsonl` for the Day-4 window.

### Step 3: Pull historical evidence for `auth-wg0` (~15 min)

```bash
bd show auth-wg0                          # current state, labels, metadata
bd comments auth-wg0                      # any human notes
# Event log scan for the bead's lifetime on Day-4 (2026-05-10):
grep -E "auth-wg0|gastown.refinery|refinery.*claim" .gc/events.jsonl | head -100
# Audit refinery's wake / decision events for the same window:
grep -E "refinery|merge" .gc/events.jsonl | grep "2026-05-10" | head -50
```

Reconstruct the timeline: when polecat drained, what refinery did (or didn't) decide, when human intervened, what changed.

### Step 4: Compare `auth-wg0` (skipped) vs `auth-1` … `auth-6` (auto-merged) (~10 min)

Six impl beads merged cleanly on Day-4 via refinery; one (`auth-wg0`) didn't. The metadata diff between them on disk (pre-human-fix snapshot if available, or via git history of `.beads/issues.jsonl`) tells us exactly which field's presence/absence governed refinery's skip.

```bash
# Inspect each of the auto-merged beads' final state:
for b in auth-1 auth-2 auth-3 auth-4 auth-5 auth-6 auth-s4d; do
  echo "=== $b ==="
  bd show "$b" 2>/dev/null | head -25
done
# Compare against auth-wg0's current state:
bd show auth-wg0
```

If we find a metadata field consistently set on the auto-merged beads but absent from `auth-wg0`'s pre-fix state, that's the discovery key.

### Step 5: Validate the hypothesis against the code from Step 1 (~10 min)

Cross-check the discovery predicate identified in Step 1 against the metadata diff from Step 4. If the predicate explains why `auth-wg0` was skipped, the diagnosis is complete. If not, return to Step 1 — the actual discovery logic is somewhere else.

### Step 6 (only if Steps 1-5 don't close the loop): live reproduce

Recreate the scenario by hand:

- Create a test bead in any rig, assignee=refinery, status=open, with the metadata polecat would have set if it had closed normally — but without closing the bead.
- Watch the refinery agent's behavior for one patrol cycle.
- See whether it picks up the bead, then progressively strip metadata fields to identify which one is the discovery key.

Same risk profile as Day-6 §6 (`gc start`); reversible via `gc stop`.

---

## 5. Hypotheses pre-thought (so we can rank them after Step 1)

Three plausible discovery predicates, ranked by my prior guess of likelihood:

**H1: Refinery scans `main`-ahead branches directly, doesn't read beads at discovery time.** Predicate: `git log main..<branch>` for each per-rig branch; if a branch has commits and matches a polecat work-bead's `gc.work_dir` / branch metadata, merge it. In this model, the bead is incidental to discovery — `auth-wg0` was skipped because polecat never wrote the metadata that links the branch back to the bead. Closure is just the natural after-merge bookkeeping.

**H2: Refinery queries the rig's bead store for OPEN beads with assignee=refinery AND a specific metadata field set (e.g., `gc.branch`, `gc.ready_for_merge`, or similar).** Predicate is bead-driven; the missing metadata is the discovery key.

**H3: Refinery queries for beads in a transitional state (e.g., status=in_progress with assignee=refinery) and the polecat's drain step is supposed to transition the bead into that state before stopping.** Predicate keys on a state transition that polecat skipped.

Step 1's code-read picks the winner. Pre-thinking them sharpens what we're looking for.

The Day-4 writeup's "keys off `merged_commit` on closed beads" wording fits none of the three cleanly, which is the smell. **H1 is closest to the v2 manual §19 description** ("the bead never enters refinery's discovery set" reads as "the branch isn't linked to a bead in a way refinery can use to find the merge target").

---

## 6. Risk / blast radius

- **Reading code + querying historical event log + running `bd show`**: zero risk.
- **Step 6 (live reproduce)** requires `gc start` and creating a synthetic test bead. Reversible; same profile as Day-6's optional Step 2-live. Mitigations: file the test bead in HQ where it's contained, use a unique title so it's easy to find/close after.
- **No upstream patches planned for Day-8.** Diagnosis-only. If a real bug is found, file a bead and stop — fix work belongs to a separate day.
- **Avoid editing `gascity-src/`** unless we find a bug and want to demonstrate a fix locally. Same upstream-discipline rules as Day-7.

---

## 7. Connection to prior days

- **Day-4** surfaced S5 as one of eight S-items. The other seven have all been addressed (resolved, diagnosed, promoted, or one-off). S5 is the last open item from that demo.
- **Day-5 & Day-6** built the diagnostic toolkit (silent-failure technique, `gc trace` offline use, bead-history reconstruction, cycle waterfall via `cycle_offset_ms`). All directly applicable to refinery patrol decisions.
- **Day-7** taught the "Step 1.5 grep saves you from a wrong premise" lesson. S5's Day-4 writeup has a wording smell (keys-off vs records-after); Step 1.5 is the falsification gate.
- **The S5 narrative already lives partly in v2 manual §19** (Polecat → Refinery Merge Workflow, especially the "Mayor's PAUSE spec anti-pattern" subsection). Day-8 should refine or correct §19 if the diagnosis warrants — that's the manual-promotion path.

---

## 8. Adjacent work to fold in while on Day-8

Lightweight items, none depend on the diagnosis:

- **File the "`slow_storage_degraded` message is misleading" upstream cosmetic bead** (Day-6 §11 candidate #3). One-line description, half the work was already done in Day-6's analysis. Ship if a free moment appears.
- **Promote Day-7's two insights to v2 manual**: (a) the "Step 1.5 falsification" pattern as a §22 complement, (b) the two-state-files architecture (controller-canonical vs bd-bridge) as a §22 cross-pack convention. Both are well-articulated already in the Day-7 execution log section "Anything to promote to v2 manual."
- **Ack `mc-n333b`** ("ack daily-verbs page") if it actually represents a still-pending learning checkbox; otherwise close with a note.
- **Push the Day-7 upstream branch** `rjgeng/fix/dolt-pack-script-state-fallback` if explicit sign-off has been given by Day-8 start. Otherwise leave it.

If Day-8 diagnosis is fast, the v2 manual promotions are the highest-yield adjacent work — they make the Day-7 lesson durable for future sessions.

---

## 9. Optional: mayor handoff

Skip, same shape as Day-6 and Day-7:

- Investigation work, high information density per human read of Go source.
- Refinery code is upstream `gascity-src`; agent-mediated edits there have higher blast radius than a single-human read.
- The diagnosis depends on reading historical event-log data and bead metadata, which is faster done directly than orchestrated.

---

## 10. Execution log

### Steps run

| Step | Time | Finding |
|---|---|---|
| 1.5 — grep upstream for `merged_commit` (front-loaded per Day-7 lesson) | 2026-05-12 | **Zero hits** for `merged_commit\|MergedCommit\|merged-commit` across all of `cmd/`, `internal/`, `packs/`, `examples/` in `gascity-src`. The Day-4 writeup's premise that refinery "keys off `merged_commit` metadata on closed beads" is **wrong**. `merged_commit` is a write-output only. Same shape as Day-7's mc-ma23a9 premise inversion. |
| 1 — locate refinery code paths | 2026-05-12 | Per submodule AGENTS.md ("ZERO hardcoded roles. If a line of Go references a specific role name, it's a bug"), refinery isn't a Go thing. Its behavior lives in `agent.toml`, `prompt.template.md`, and the formula `mol-refinery-patrol.toml`. Found at `study/gascity-src/examples/gastown/packs/gastown/`. |
| 2 — read the formula's discovery step | 2026-05-12 | `mol-refinery-patrol.toml`, step `find-work`: discovery predicate is `gc bd list --assignee=$GC_AGENT --status=open --exclude-type=epic --limit=1`, followed by a requirement that `metadata.branch` exist on the matched bead. **No closed beads. No `merged_commit`.** Refinery enters a `gc events --watch --type=bead.updated` loop with exponential-backoff timeout when no work is found. |
| 3 — pull `auth-wg0` from co_auth's bead store via direct dolt | 2026-05-12 | Current (post-fix) state: status=closed, assignee=co_auth/gastown.refinery, metadata includes `branch`, `target`, `merged_at`, `merged_commit`, `refinery_pushed_at`, `refinery_pushed_by`, `work_dir`. So the data fields all exist now — the question is when. |
| 3.5 — reconstruct auth-wg0 timeline from events.jsonl | 2026-05-12 | **The Day-4 narrative is wrong in two specific places.** Real timeline (PDT): 09:21:19 mayor creates → 10:03:54 polecat (`furiosa`) claims, status=in_progress, sets branch+work_dir → 10:04:30 human reverts to status=open, clears assignee → 10:10:14 polecat adds `target` metadata → **10:10:19 polecat sets assignee=co_auth/gastown.refinery**, status remains open, full metadata present → **(1h 19m gap)** → 11:29:58 human closes with `merged_at`+`merged_commit` → 11:35:51 refinery adds `refinery_pushed_at`+`refinery_pushed_by`. **Polecat DID NOT skip the handoff** — it explicitly assigned to refinery with all required metadata. The bead was in a valid discoverable state at 10:10:19. |
| 4 — verify refinery session was running during the gap | 2026-05-12 | `session.woke` for `co_auth/gastown.refinery` at 09:59:19; `session.stopped` at 13:29:30. Running through the entire gap. |
| 5 — verify there were events in the gap that should have triggered refinery's watch | 2026-05-12 | **2534 `bead.updated` events** in the gap window (2401 by `human`, 52 by `cache-reconcile`, 43 by `gastown.deacon`, 34 by `co_shipping/gastown.refinery`, 3 by `co_auth/gastown.furiosa`, 1 by `co_auth/gastown.refinery` itself). Refinery's `gc events --watch --type=bead.updated` should have triggered thousands of re-checks. None visibly happened — refinery had zero actor-side bead activity from 10:02:21 (Wisp #2 created) until 11:35:51 (auth-wg0 push). |
| 6 — inspect the stuck patrol wisp | 2026-05-12 | Attempted direct dolt query against `auth.issues` for `auth-wisp-cnxi` — silent empty result on multiple `SELECT` attempts despite `SHOW TABLES` working. Dolt instability (consistent with Day-6 reconciler perf finding). Skipped; not essential to the primary diagnosis. |

### Hypothesis confirmed

- **Discovery predicate (exact reference):** `gc bd list --assignee=$GC_AGENT --status=open --exclude-type=epic --limit=1` plus `metadata.branch` required, at `study/gascity-src/examples/gastown/packs/gastown/formulas/mol-refinery-patrol.toml` step `find-work`. Closes the question with H2 (bead-metadata-driven), not H1 (branch-driven) as guessed.
- **Why `auth-wg0` was skipped on Day-4:** It WASN'T skipped at the discovery-predicate level. Polecat correctly assigned it to refinery at 10:10:19 with valid `branch`/`target`/`work_dir`/`gc.routed_to` metadata. The bead was in a state that satisfies the discovery predicate exactly. The actual failure was **refinery's running patrol wisp didn't react to 2534 bead.updated events over 1h 19m**, including the polecat's own assignment event. That's a second-order bug, not a discovery-predicate issue.
- **Evidence:** events.jsonl timeline reconstruction; the formula's `find-work` step text; the empty `merged_commit` grep across all of upstream.

### Was the Day-4 writeup accurate?

- **"keys off `merged_commit` metadata on closed beads":** False. Discovery looks at OPEN beads. `merged_commit` is a write-output only and has zero read-side code in upstream.
- **"polecat finished `auth-wg0` and drained without closing the bead":** Partially true. Polecat didn't close the bead — but that's the correct contract (refinery closes, not polecat). What polecat DID do correctly: pushed the branch, set metadata (branch, target, work_dir, gc.routed_to), and assigned the bead to refinery. The Day-4 framing makes it sound like polecat dropped the handoff entirely. It didn't.
- **"The human had to manually close `auth-wg0` with full merge metadata":** True, but the cause attributed (refinery's discovery looking at closed beads with merged_commit) is wrong. The real reason the human had to intervene is that refinery's patrol wisp got stuck for 1h 19m despite the bead being correctly assigned with the right metadata.
- **Verdict:** v2 manual §19 needs a correction. The "Mayor's `PAUSE for Gn` spec anti-pattern" framing should change: the anti-pattern isn't "polecat skips closure," it's "polecat assigns but no nudge happens, and refinery's patrol-only path can be unreliable on its own." The fix isn't "tell polecat to close normally" — it's "tell polecat to nudge refinery after assignment, or rely on the controller nudging refinery on bead.updated events with assignee transitions."

### Fix applied (if any)

- **Diagnosis-only end state.** No code changes.
- **Documentation fix in scope:** v2 manual §19 to be corrected (separate edit, batched with the §22 promotion).
- **Follow-up bead:** to file — refinery patrol wisp doesn't reliably react to bead.updated events under live conditions (Wisp #2 was stuck through 2534 events). Either `gc events --watch --type=bead.updated` is unreliable, the formula's exponential-backoff has a coverage gap, or refinery's session was somehow event-isolated during that window. Worth tracking but not diagnosing further today.

### Surprises

1. **Day-4 line 224's writeup got the central claim wrong.** Day-7 taught "Step 1.5 falsification catches bad bead premises"; Day-8 confirms that the same pattern catches bad writeup premises. The five-line narrative on line 224 misattributes the failure to discovery logic when the real failure is in event-driven wake-up.
2. **The contract from refinery's prompt is crisp**: "polecats push a branch, set metadata on the work bead (`branch`, `target`), and assign it to you. You merge … then close the bead." This was already in upstream all along; the Day-4 writeup just didn't read it.
3. **Refinery is configured-driven, not hardcoded.** The submodule's AGENTS.md says "ZERO hardcoded roles," and refinery is a clean example: zero refinery-specific Go code, all behavior comes from the agent's config + prompt + formula. This is a stronger version of "templates over code" than I expected.
4. **The real bug uncovered (refinery's watch not reacting) is harder to diagnose than the original S5 question.** It might involve the city API streaming layer (Day-6 noted "2-9 sec API responses" — slow API could starve `gc events --watch`). The S5 investigation incidentally exposed a downstream consequence of Day-6's reconciler-cycle-latency issue.
5. **`gc events --watch` requires the streaming city API** (`cmd_events.go:769` requires `requireStreamingCityAPI`). If the controller is slow or the API endpoint is degraded, refinery's wisp could be sitting in a broken watch waiting on an SSE stream that never delivers. This is consistent with the symptom but not yet proven.

### Anything to promote to v2 manual

1. **Correct §19 "Mayor's `PAUSE for Gn` spec anti-pattern" subsection.** The current text says polecat reads "STOP" too literally and skips its closure step, stranding the merge. The corrected framing should be: polecat DOES the handoff (branch, metadata, assignee=refinery), but if refinery's patrol wisp doesn't react to the bead.updated event in a timely way (separate bug, see follow-up bead), the bead can sit indefinitely. The mitigating practice is to **explicitly `gc session nudge co_auth/gastown.refinery "<bead-id> ready"`** after polecat drains — already documented in §19's "nudge refinery pattern" subsection but not connected to the PAUSE pattern explanation.
2. **Correct §19 "What refinery actually does" subsection.** The current line 808 says "records `merged_commit` on the bead" — true. But the line earlier in the writeup ("its discovery logic keys off `merged_commit` metadata on closed beads") is the part that was wrong. Make sure §19 says: *Discovery looks at OPEN beads with `assignee=self` + `metadata.branch` present. `merged_commit` is a write-output recorded after merging, not a discovery key.*
3. **Add a §23 or §22 subsection: "Don't trust your own notes' diagnosis."** Day-7 + Day-8 both invalidated a Day-N writeup via Step 1.5 grep. Worth promoting the pattern: when revisiting a deferred observation, grep for the central claim's exact terms in upstream code BEFORE accepting the framing. Same shape as the "silent failure via `2>/dev/null`" principle in §22.
