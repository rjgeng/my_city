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

### Step 1: morning read — executed 2026-05-21 04:44 PT

- `gc version`: HEAD-fad5d3f (Day-30 upgrade holds).
- **PR #2088: MERGED 2026-05-20T18:45:45Z by quad341.** Labeled `status/reviewing` 16:13:41Z, merged 2.5h later — same maintainer, no review comments, no inline change requests. Merge commit `a652a26`. PR author: `rjgeng` (own PR), NOT a `/adopt-pr` adoption → §24b → direct-merge variant, NOT §24c. **Anti-plan #10 (§24c template) does not apply.** G1 falsified: PR did not stay OPEN through 18:00 PT 5/21 — exited §24b on Day-30 evening (75 min after plan was authored). Plan is post-hoc-stamping the merge that already happened.
- **PR #2136: OPEN, MERGEABLE, last update 2026-05-18T11:03:58Z.** Day 5 post-Day-27-nudge. No movement, wait-only per anti-plan #5.
- **beads v1.0.4 holds** (no v1.0.5; ~12d cadence). G3 on track.
- **All watched mc-* beads OPEN**: mc-mxl4vc, mc-1zccc2, mc-4m2da1, mc-iho25h, mc-w9iua4, mc-z92fpi. Status unchanged.
- **events.jsonl rotated at 2026-05-20T16:55:23Z (~09:55 PT)** = same window as Day-30 city upgrade. Pre-upgrade archive `events.jsonl.archive-20260520T165523Z-seq-1-617462.gz` contains full mol-dog-compactor history through 5/20 08:14:09 PT fire (exit-1 as expected). Post-upgrade events.jsonl has zero compactor entries — **expected**, since the daily fire happened ~95 min before rotation. First post-upgrade fire = today's window.
- **Drift series 5/13–5/20** (pre-upgrade, from archive): 08:02:07 → +45s → +29s → +1m35s → +2m24s → +1m57s → +1m34s → **+3m18s** (5/20). 5/21 prediction stands: 08:15–08:18 PT.
- **Inbox**: 3,844 mail items dominated by routine MEDIUM Dolt-health + reaper-anomaly wisp ESCALATIONs. `bd list --status open | grep -c wisp` = 8 live open wisps → reaper has caught up; mail backlog is historical noise, not Day-31 work.

**G1 verdict (early stamp):** FALSIFIED.

### Step 2: 5/21 compactor fire observation — executed 2026-05-21 ~08:21–08:35 PT

- **Window 08:14–08:18 PT passed silently** in the fresh post-upgrade events.jsonl. At 08:22 PT no `order.fired mol-dog-compactor` event present.
- Initial false trail: `gc dolt --help` text "replaces ZFC-exempt mol-dog-compactor formula" misread as "order no longer exists." Corrected via `gc order list` → order wrapper persists (24h cooldown, exec-type, `Exec: gc dolt compact`); only the dispatch contract changed, the order definition is intact.
- `gc order check` snapshot (returned 08:27 PT) showed `mol-dog-compactor cooldown - yes elapsed 24h12m55s >= interval 24h0m0s` → order **was due** but had not been dispatched yet. Rules out cooldown-reset-at-restart hypothesis; the dispatcher is simply slow / queued for this slot.
- **Fire arrived 08:30:38 PT, +16 min past predicted window.** Tracking bead `mc-wisp-pt4lo` created same instant.
- **Failed 08:32:07 PT** (`order.failed message="exit status 1"`, 1m29s runtime). Zero retry telemetry / per-attempt events in events.jsonl during the window. dolt.log silent from 08:18:32 → 08:33:34 (compactor doesn't log to dolt.log; dolt is its *target*).
- **Smoking gun:** `.gc/runtime/packs/dolt/compact-quarantine/hq` created 08:31:51 PT:
  ```
  db=hq
  reason=post-flatten value hash changed with row-count increase
  created_at=2026-05-21T15:31:51Z
  ```
- First observed instance of the NEW post-#2316 safety net firing. Source: `study/gascity-src/examples/dolt/commands/compact/run.sh:1538-1540` on the `verify_counts_saw_gain=1` branch.
- Cross-check against 5/14–5/16 archive (mc-1zccc2, mc-3dgnc6, mc-d9a595, mc-7811ab): same surface signal (`exit status 1`, empty tracking-bead descriptions, no payload detail). Differs in *abort path*: those aborted at the OLD preflight `head_commit` re-check (old run.sh line 962-968); today aborted at the NEW post-flatten value-hash check. Different races, different lifecycle points.

### Step 3: #2088 timeline + state recheck — moot (already merged Day-30 evening)

- Step 1 morning read established #2088 was MERGED 2026-05-20T18:45:45Z by quad341 (the §24b labeler) without any review comments — direct §24b → merge transition, not §24c. Step 3 timeline recheck became unnecessary. G1 stamped FALSIFIED in Step 1.

### Step 4: branch selection per §3 matrix — resolved: diagnose-day, no hot-fix PR

- Branch taken: row "Compactor FAILS — Diagnose-day. Fix is merged; failure means something we missed. NOT a hot-fix PR. Trace, understand, file a new bead. 60–180 min."
- Anti-plan #8 honored: no hot-fix PR opened. Anti-plan #1 honored: deacon not re-armed (didn't need its subprocess stderr after all — quarantine marker gave us the diagnosis).
- **New diagnosis bead filed: mc-jhsp8y** — "mol-dog-compactor: in-flatten race window on hq exposed post-#2316 — first quarantine marker 2026-05-21." Citations wired: DISCOVERED-FROM mc-4m2da1, RELATED mc-1zccc2, references PR #2316 + this plan file + the quarantine marker artifact.
- Bead acceptance criteria: 3+ more daily data points (5/22, 5/23, 5/24) to confirm in-flatten race repeats with similar frequency, OR non-repeat in which case downgrade and close.

### Step 5: EOD recheck + tracker update — executed 2026-05-21 PM

- **Tracker (`study/notes/upstream-engagement-tracker.md`) updated:**
  - Headline counter: "Local-only beads" bumped 3 → 4 active; added mc-jhsp8y inline summary.
  - **New entry** for mc-jhsp8y in Active local-only section, ahead of mc-1zccc2: full causal-separation framing, evidence-artifact callout (`compact-quarantine/hq` — DO NOT DELETE), lineage chain mc-1zccc2 → mc-4m2da1 → mc-jhsp8y, acceptance criteria, candidate fix shapes (NOT decisions today), Day-32 three-branch outcome map.
  - **mc-1zccc2 entry updated** with Day-31 soak result paragraph: preflight race confirmed FIXED by #2316; remaining work is the in-flatten race captured in mc-jhsp8y. "Becomes upstream when" pointer redirected to mc-jhsp8y.
  - **PR #2316 closed-items entry updated** with Day-31 soak result paragraph: confirms #2316 was correctly scoped; new failure mode is the next layer, not a regression; explicit "No regression, no hot-fix PR" stamp.
- **No PR opened, no hot-fix drafted.** Anti-plan #8 honored end-of-day.
- **Quarantine marker preserved**: `.gc/runtime/packs/dolt/compact-quarantine/hq` — referenced from mc-jhsp8y body, the tracker mc-jhsp8y entry, and this plan §6 Step 2. Three pointers to the artifact ensures it stays findable across future sessions.

### Step 6: Day-32 punt — executed 2026-05-21 PM (authored as inherited plan)

**Day-32 target: investigate mc-jhsp8y (flatten-time race on `hq` exposed post-#2316).**

- **Day-32 modal shape: watch-day → conditional diagnose.** Read 5/22 compactor fire (expected window 08:30–08:50 PT given today's +16m drift baseline). Three outcomes mapped to mc-jhsp8y acceptance:
  - **(a) Same quarantine reason** `value hash changed with row-count increase` → in-flatten race confirmed reproducible → start *designing* (not implementing) the flatten-cycle retry, now justified by 2 data points.
  - **(b) Different quarantine reason** (e.g., `value hash changed without row-count increase` — the `verify_counts_saw_gain=0` branch) → a *third* failure mode; widen scope of mc-jhsp8y.
  - **(c) No fire at all OR exit-0** → in-flatten race may be `hq`-write-spike-dependent; downgrade mc-jhsp8y, continue soaking.
- **Drift sub-prediction (G4 carry-forward):** Day-32 fire time discriminates between (a) geometric drift acceleration (lands ~09:00+ PT) vs (b) post-upgrade dispatch-order shift (lands ~08:30–08:50 PT, same band as today). Record timestamp explicitly.
- **Carry-forward deferrals from Day-31:**
  - beads-v1.0.5 watch (G3 ongoing; mc-mxl4vc remains blocked; ~13d since v1.0.4 by Day-32).
  - #2136 wait-only — no nudge spent, day 6 post-Day-27-nudge by Day-32.
  - mc-z92fpi / mc-iho25h soak labels (`hold-until-soak`) stay latched until Day-32 AM at earliest — 24h post-upgrade window now satisfied by Day-32 AM, but unlatch requires explicit decision based on 5/22 fire result (anti-plan #9 from Day-31).
- **Day-32 anti-plans (initial set, will refresh at Day-32 AM):**
  - Don't open a hot-fix PR on (a) outcome — design only, no implementation; flatten-cycle retry will be its own bead/PR following the standard workflow.
  - Don't re-arm `gastown.deacon` — quarantine markers are now the diagnosis vector, deacon stderr capture isn't needed.
  - If outcome (c), don't close mc-jhsp8y same-day — one clean fire is one data point, not validation. Wait for 3+ clean fires before downgrade.

---

### G1–G4 verdicts (EOD)

- **G1 (#2088 §24b state) — FALSIFIED early (Step 1 stamp).** Predicted: stays OPEN with `status/reviewing` through 18:00 PT 5/21. Actual: MERGED 2026-05-20T18:45:45Z by quad341 — 75 min after plan was authored, before Day-31 even began. Generator (quad341 review cadence unknown) was wrong-direction: he didn't wait 24–72h, he merged same-evening. **Lesson:** §24b wait-window prediction needs to model the case where the labeling maintainer IS the merger (vs. a separate reviewer adding the label for someone else to merge). The plan implicitly assumed the latter; #2088 was the former.
- **G2 (5/21 compactor fire) — FALSIFIED on both axes, but failure was graceful.**
  - **Timing axis:** predicted 08:14–08:18 PT; actual 08:30:38 PT (+16m). Falsified.
  - **Outcome axis:** predicted exit-0 + no `order.failed`; actual `order.failed exit status 1`. Falsified.
  - **Critical reframe:** failure was the NEW post-#2316 quarantine safety net activating exactly as designed. NOT a regression of #2316. The fix's preflight retry succeeded (would have failed under old code); the fix exposed a deeper in-flatten race by removing the earlier abort point. Captured in mc-jhsp8y.
- **G3 (beads release) — VERIFIED.** v1.0.4 still latest at Step 1 read; ~12d cadence holds. No movement signal. Carry to Day-32; mc-mxl4vc remains blocked.
- **G4 (drift anomaly resolution) — FALSIFIED, drift widens dramatically.**
  - Predicted resolving data point in 08:15–08:18 window (model: drift either reverts to +1–2m or persists at +3m18s).
  - Actual: +16m, well outside both bands. Drift series now: 5/19 (+0m baseline) → 5/20 (+3m18s) → 5/21 (+16m20s).
  - Two competing generators for Day-32 to discriminate:
    - **(a) Geometric drift acceleration** — Day-32 fire lands ~09:00+ PT. Implies a feedback loop in the dispatcher's slot allocation.
    - **(b) Post-upgrade dispatch-order shift** — Day-30 binary changed the order in which cooldown-due orders fire; new effective slot is ~08:30 PT. Day-32 fire lands ~08:30–08:50 PT (same band as today).
  - Day-32 fire timestamp is the discriminator. Add to Day-32 plan as a falsifiable sub-prediction.

### Surprises

1. **`gc dolt --help` "replaces" language is layer-ambiguous.** I read it as "the order no longer exists" when it actually meant "the dispatch contract changed but the order wrapper persists." ~5 min of wrong-tree investigation before `gc order list` corrected it. Lesson: when help text uses verbs like "replaces / supersedes," verify whether they describe the *implementation* layer or the *interface* layer before drawing structural conclusions.
2. **Successful fixes can expose the next hidden failure layer.** PR #2316 was correctly scoped to the preflight race that Day-26 manual repro identified. By fixing it, the compactor now reaches code paths it never reached before — and a *different* race that was structurally always there became observable. This is not a regression and not a defect of #2316; it's the normal behavior of a layered fix. **Going forward: when soaking a fix, watch for "new failure layer becoming visible," not just "old bug recurring."**
3. **The quarantine artifact is the only reason today was diagnosable in <60 minutes.** `order.failed` event carries only `"exit status 1"`. Tracking bead description empty. dolt.log silent during the compact window. Without the quarantine marker file (a PR #2316 byproduct), today would have required a Day-26-style manual repro. The marker file is fortunate — the underlying observability gap (controller drops subprocess stderr) is unfixed.
4. **Day-31 plan correctly anticipated the failure-branch response shape even with predictions falsified.** §3 matrix row "Compactor FAILS" + anti-plan #8 (no hot-fix PR, trace + understand) prescribed today's exact shape. Pattern lesson: falsifiable predictions paired with explicit branch responses are robust to prediction errors — even when the model is wrong on the prediction, the response is still right.
5. **G1 falsified by Step 1 read.** #2088 already merged Day-30 evening (before Day-31 began). The plan was authored at end-of-Day-30 — the merge happened *between* plan authoring and Day-31 morning. Reminder: PRs at <24h §24b age can flip overnight; predictions written from an end-of-day snapshot are stale by morning.

### What the day actually produced

- **New diagnosis bead:** mc-jhsp8y (in-flatten race window on hq), P3 BUG, open. Cites mc-1zccc2 + mc-4m2da1 + PR #2316. Acceptance defined.
- **Quarantine marker preserved on disk:** `.gc/runtime/packs/dolt/compact-quarantine/hq` — first artifact of this kind; **do NOT delete** (primary evidence for mc-jhsp8y).
- **Confirmed PR #2316 working as intended:** preflight retry succeeded today (would have failed under old code); safety net caught downstream race correctly with no data corruption. Net: #2316 was a good ship.
- **Refined drift model:** G4 falsified at +16m; Day-32 fire is discriminator between accelerating-drift (a) and upgrade-shift (b) hypotheses.
- **Process artifact:** corrected framing of "fix-failed-on-day-31" → "fix-worked, exposed-next-layer." Documented in Surprise #2 as a generalizable lesson.
- **G1 closure on #2088:** PR merged into upstream Day-30 evening. mc-1zccc2 / mc-4m2da1 still open pending mc-jhsp8y soak resolution.

### Process lessons captured

1. **Help-text verbs need layer-disambiguation.** "Replaces" / "supersedes" / "deprecates" should always prompt: "which layer — interface or implementation?" before drawing structural conclusions.
2. **Diagnose-day matrix branch fires correctly even when predictions are falsified.** Keep the §3-style matrix pattern in future plan files; the branch response is independently load-bearing from the prediction.
3. **First-time safety-net activations are high-leverage observation events.** When a fix adds a new artifact (quarantine marker, snapshot file, defer-marker, etc.) and that artifact appears for the first time, it's the cleanest signal you'll ever get on the underlying race — better than logs. Treat first-marker artifacts as primary diagnostic input.
4. **Subprocess stderr being dropped by the controller is a recurring blind spot.** Day-26 needed manual repro to see the stderr; today the quarantine file rescued us. The observability gap (controller drops exec stderr to events.jsonl, only "exit status N" survives) is worth filing as its own future bead if a third diagnosis is blocked by it. Candidate title: "controller does not capture exec-order subprocess stderr — diagnosis requires artifact byproducts or manual repro."
5. **Drift prediction needs upgrade-shift hypothesis.** When a binary upgrades, cooldown-due-order dispatch ordering can change. Future drift predictions should explicitly model "did anything in the dispatcher's scheduling order change recently?" as a generator alongside drift-acceleration.
6. **End-of-day plan stamps go stale by morning for active PRs.** Day-31 plan was authored end-of-Day-30; #2088 merged 75 min later. For any prediction touching an active-review PR, the Step 1 morning read needs to assume the state could have flipped since plan authoring.
