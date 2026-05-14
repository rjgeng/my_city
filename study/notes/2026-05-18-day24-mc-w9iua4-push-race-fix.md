# Day 24 — mc-w9iua4 push-race fix + upstream PR

- **Plan authored:** 2026-05-14 (Day-23 evening, immediately after Day-23 close)
- **Planned execution:** 2026-05-18
- **Status:** Plan only.

Day-23 surfaced `mc-w9iua4` — `mol-dog-jsonl` exits 1 intermittently (~1 in 30-50 dispatches) because step 3 (`git push origin main` to `.gc/jsonl-archive.git`) races against concurrent sibling pushes from other rigs. Evidence was strong but circumstantial: sibling commits landed at the exact same second as failures (`12:35:26 PT 5/13`), and two sibling commits landed 1s apart right after another failure (`06:59:01/02 PT 5/14`). No DOG_DONE nudge from any failed run → all three died before step 4. Failure durations (19-26s) sit in the upper end of successful runs' 9-43s range, consistent with reaching the push step.

The smoking-gun stderr from a failed push (`cannot lock ref` or `non-fast-forward`) was **not** captured on Day-23. Day-24 starts by capturing it via `gc trace`, then ships the fix.

This is a **fix-day shape** — narrow scope, confirm root cause first, then a small formula edit + PR.

---

## 1. Pre-flight: what Day-23 left ready

**State going in:**

- `mc-w9iua4` filed P3, OPEN, with 4-option fix ranking. Recommendation: option (1), retry-with-backoff in formula step 3.
- gc HEAD-caa44a4 + bd 1.0.3 symlink, supervisor stable since Day-18 (PID 13654, ~24h uptime accumulated past Day-23).
- Trace pipeline confirmed working **without arming** (Day-23 surprise — segments auto-write under HEAD-caa44a4).
- Failure rate baseline: 3 mol-dog-jsonl exit-1 in 19h = ~1 per 6.3h across 5 rigs. Day-24 4h trace window should capture 0-2 failures.

**Day-23 leftover discipline item:** I skipped reading `study/gascity-src/engdocs/contributors/reconciler-debugging.md` on Day-23 — it's the documented protocol for reconciler/controller incidents per `AGENTS.md`. Day-24 opens with that read (~15 min). Even if mc-w9iua4 isn't strictly a reconciler bug, the engdocs read is a discipline-reinforcement note from Day-23's meta-reflection.

---

## 2. What "done" looks like

**Primary outcomes (one of three branches):**

| Branch | Done state | Next |
|---|---|---|
| **A — confirmed + fixed** | trace captures an exit-1 with `cannot lock ref` / `non-fast-forward` stderr → retry-with-backoff applied → make check passes → PR opens upstream | 24h soak starts; Day-25 reads soak result |
| **B — different root cause** | trace captures an exit-1 with *different* stderr (e.g. dolt timeout, git config error, JSONL spike halt) → revise mc-w9iua4 root cause analysis; fix shape changes | Plan a follow-on day; may not ship PR Day-24 |
| **C — no failure captured in window** | trace window closes with zero exit-1 events captured | Ship the speculative fix anyway (low risk); 24h soak validates. Update mc-w9iua4 with the "couldn't capture" note. |

**Secondary outcomes regardless of branch:**

- §22 footnote candidate from mc-w9iua4 body — *"a primary regression's fix unmasks a latent secondary bug — measure 24h post-fix steady state before declaring done"* — added to v2 manual.
- engdocs/contributors/reconciler-debugging.md read; key takeaways noted; §23 footnote added if anything materially different from what we already documented.

---

## 3. Execution plan

Total budget: **~3 hours** active work + a 4h trace-window wait that's not blocking (work other things during it).

### Step 1: Pre-flight + engdocs read (~20 min)

```bash
# State check
gc version    # should still be HEAD-caa44a4
gc trace status    # should still return arms:null with segments flowing
bd show mc-w9iua4 | head -5
grep -c '"type":"order.failed"' .gc/events.jsonl   # baseline count

# Discipline read
less study/gascity-src/engdocs/contributors/reconciler-debugging.md
```

Document: was the engdocs read materially different from §23? If yes, queue a §23 update.

### Step 2: Arm trace on the mol-dog-jsonl templates (~5 min) → wait 4h

The mol-dog-jsonl order runs as a dog (short-lived molecule) under the dog template. Arm trace at detail level on the right templates so we capture each rig's push attempt:

```bash
# Arm 4h, detail level, on each rig's dog dispatcher
gc trace start --template gastown.dog --for 4h --level detail
gc trace start --template hello-world/gastown.dog --for 4h --level detail
gc trace start --template co_store/gastown.dog --for 4h --level detail
gc trace start --template co_shipping/gastown.dog --for 4h --level detail
gc trace start --template co_auth/gastown.dog --for 4h --level detail

gc trace status    # confirm 5 arms active

# Capture pre-arm event count (so we can diff)
echo "Pre-arm order.failed count: $(grep -c '"type":"order.failed"' .gc/events.jsonl)"
date
```

**Predicted yield:** with failure rate ~1 per 6.3h across 5 rigs, expect 0-2 exit-1 events in a 4h window. If zero, fall through to Branch C.

While trace window runs, work other items below — the wait is not blocking.

### Step 3: Identify the captured failure (during/after wait, ~15 min)

```bash
# Check for new order.failed events
gc events --type order.failed --since 4h 2>/dev/null \
  | jq -r 'select(.subject | startswith("mol-dog-jsonl")) | "\(.ts)\t\(.subject)\t\(.message)"'

# If any captured, get the tick_id and full cycle
TICK=<tick-id-from-cycle_result-near-the-failure-timestamp>
gc trace cycle --tick $TICK --json | jq '.[] | select(.record_type | test("error|stderr|exec_output"))'

# Or just dump the segment file from today and grep for git push errors
LATEST=.gc/runtime/session-reconciler-trace/segments/2026/05/$(date +%d)/segment-000001.jsonl
grep -E "cannot lock ref|non-fast-forward|stderr|git push" "$LATEST" | head -10
```

**Branch A decision criterion:** captured stderr contains `cannot lock ref` or `non-fast-forward` or `Updates were rejected`. Proceed to Step 4.

**Branch B decision criterion:** captured stderr names a different failure (dolt timeout, scrub-filter, JSONL spike halt, etc.). Stop and reshape mc-w9iua4's root cause. Day-24 ends with the bead update; fix slips to Day-25+.

**Branch C decision criterion:** no exit-1 in the 4h window. Skip to Step 4 anyway, but note the fix is speculative.

### Step 4: Apply retry-with-backoff to mol-dog-jsonl.toml (~30 min)

Target file: `study/gascity-src/examples/gastown/packs/maintenance/formulas/mol-dog-jsonl.toml`, step `[[steps]]` with `id = "push"`. Current step 3 has a single-shot `git push origin main`. Replace with:

```bash
# Pseudocode — actual shape depends on formula's bash dialect
for attempt in 1 2 3; do
  if git -C <git_repo> push origin main 2>&1; then
    break
  fi
  if [ $attempt -eq 3 ]; then
    echo "push failed after 3 attempts" >&2
    exit 1
  fi
  # Jittered sleep 1-5s
  sleep $(awk 'BEGIN{srand(); print 1 + rand() * 4}')
done
```

Match the formula's existing bash style (read 152-165 carefully first). Don't introduce new conditionals beyond the retry loop. The "max_push_failures" config var (currently 3) already exists — preserve its escalation semantic, just give it 3 sub-attempts before it counts as a real push failure.

### Step 5: Local validation (~30-45 min)

Per the gascity-src CLAUDE.md quality gates:

```bash
cd study/gascity-src
make check    # or make test-fast-parallel — confirms formula TOML parses + tests pass
go vet ./...
```

Pack/formula changes don't have unit tests per se; the validation is "formula TOML parses + no regressions in pack-loading tests." If `make check` flags anything, fix before proceeding.

### Step 6: Open upstream PR (~30 min)

Per §24 playbook (Day-11 PR #2037 + Day-22 PR #2088 patterns):

1. New branch off `study/gascity-src` HEAD: `rjgeng/fix/mol-dog-jsonl-push-race`
2. Commit the formula change with a body referencing mc-w9iua4 evidence
3. `gh pr create` with honesty-first body (in-flight on first push, full citation after make check confirms)
4. PR title under 70 chars, body has Summary + Test plan

Hold off on requesting reviewers until make check confirms — Day-22 pattern.

### Step 7: Start soak + close out (~15 min)

```bash
# Record post-fix baseline
echo "Post-fix order.failed count at $(date): $(grep -c '"type":"order.failed"' .gc/events.jsonl)" >> day24-soak-log.txt

# Stop the 4h trace arms (or let them expire)
gc trace stop --template gastown.dog
# (repeat for the per-rig templates)
```

The 24h soak result lands on Day-25. Day-24 doc gets a "Soak begins HH:MM" marker; Day-25 reads it.

### Step 8: §22 footnote fold (~15 min, only if time)

Fold the mc-w9iua4 §22 footnote candidate into v2 manual:

> *"After fixing a primary regression, hold the baseline-zero claim for a full 24h soak before publishing — because the noise reduction that proves the fix also exposes the next-loudest bug. The fix is not over until you've measured the post-fix steady state for at least 24h."*

If §22 footnotes pile up, do them on a tour-day (Day-25 or 26 if Day-25 is fix-day).

---

## 4. Anti-plans

Things NOT to do on Day-24:

- **Don't apply the fix without confirming the failure mode first.** Even though Day-23's evidence is strong, Branch B exists for a reason. Spending 4h on a wrong fix is the failure mode.
- **Don't escalate to fix options (3) — flock — or (4) — stagger fires — before measuring option (1)'s effect.** YAGNI applies. If retry-with-backoff doesn't fix it, Day-25 picks up. Don't ship multiple competing fixes.
- **Don't add p95/max observability scope.** That's Day-23's deferred recommendation; it's a Day-26+ scope-out, not Day-24.
- **Don't read 5 engdocs files.** Read the one Day-23 skipped. The others can wait.
- **Don't expand mc-w9iua4's scope into mc-f7u8fz.** They share the "bd 1.0.3 unmasked latent issues" lineage but are unrelated bugs. Keep separate.

---

## 5. G1-G4 predictions (falsifiable)

**G1: A 4h trace window will capture at least 1 exit-1 event.** Reasoning: rate ~1 per 6.3h, 5 rigs, 4h window → expected count = 4/6.3 ≈ 0.63 failures. Plus the bursts tend to cluster, so when one fires, others nearby are more likely. **Predicted outcome:** captured ≥ 1.

**G2: The captured stderr will mention `cannot lock ref` OR `non-fast-forward` OR `Updates were rejected`.** Reasoning: the local-bare-repo push race produces one of these three messages from git ~99% of the time; the other 1% is a transient network/permission error which doesn't apply to local pushes. **Predicted outcome:** Branch A holds.

**G3: Retry-with-backoff (3 attempts, 1-5s jittered sleep) will drop post-fix failure rate to 0 within a 24h soak.** Reasoning: the race window is sub-second per push; 3 retries with 1-5s gaps covers ~10-20s of total backoff per call, well beyond the contention window. **Predicted outcome:** Day-25 soak shows 0 mol-dog-jsonl exit-1.

**G4: The upstream PR will land within 7 days, possibly within 24h** (matching PR #2037's 32h cadence with sjarmak). Reasoning: 1-file formula change, narrow scope, evidence-rich bead body, sjarmak's pattern of fast first-pass review for similar small fixes. **Predicted outcome:** merge by Day-25 or Day-26.

---

## 6. Risk assessment per step

| Step | Risk | Mitigation |
|---|---|---|
| 1 (engdocs read) | zero | pure read |
| 2 (arm trace) | zero | arms auto-expire after 4h |
| 3 (identify failure) | zero | pure read |
| 4 (edit formula) | low — bad bash → formula errors at runtime | make check catches TOML parse errors; runtime errors visible in next dispatch |
| 5 (make check) | low — slow but harmless | run in background; ~30-45 min wall clock |
| 6 (open PR) | low — visible to others | use honesty-first body; can edit |
| 7 (close out) | zero | pure docs |

No destructive operations. No data loss possible. PR is the only externally-visible action and follows the established playbook.

---

## 7. Time + scheduling

- **Active work:** ~3h (steps 1, 3, 4, 5, 6, 7)
- **Async waits:** 4h (trace window) + 30-45 min (make check) — overlap with active work
- **Realistic wall clock:** 4-5h start-to-finish, with breaks during waits

Schedule recommendation: start in morning so the 4h trace window fits within the workday and the PR opens before EOD for first-pass maintainer review during their working hours.

---

## 8. Execution log

(filled in as work happens)

### Step 1: pre-flight + engdocs read

- gc version:
- gc trace status:
- mc-w9iua4 state:
- Pre-arm order.failed count:
- engdocs read takeaways:

### Step 2: arms registered

- Arms active:
- Pre-arm timestamp:
- Pre-arm event count:

### Step 3: failure capture

- Captured (count + timestamps):
- Stderr contents:
- Branch determined (A / B / C):

### Step 4: formula edit

- Diff summary:
- Lines changed:

### Step 5: make check

- Result:
- Wall clock:
- Anything failed:

### Step 6: PR

- Branch name:
- PR URL:
- Title:
- First-pass review status:

### Step 7: soak begins

- Post-fix timestamp:
- Post-fix event count:
- Soak ends timestamp:

### Step 8: §22 footnote fold (optional)

- Footnote added:
- Lines:

### G1-G4 verdicts

- G1 (≥1 exit-1 captured):
- G2 (stderr is push race):
- G3 (retry drops to 0):  (requires Day-25)
- G4 (PR merges within 7 days):  (requires Day-25+)

### Surprises

(filled in as encountered)

### Anything to promote

(filled in at end)
