# Phase-1 retrospective: Days 14-22

- **Authored:** 2026-05-13 (evening, end of Day-22; same calendar day as the entire phase)
- **Period covered:** Day-14 PM through Day-22 — 9 days of work compressed into one long evening of execution.
- **Method:** written directly from this session's working memory. External chat logs only go through Day-15; Days 16-22 happened entirely within one conversation thread. Unlike the Day-14 PM retrospective (which delegated to a subagent reading 13 separate chat files), this is a first-person write-up by the operator-of-record.
- **Companion document:** [Day-14 PM retrospective](2026-05-13-day14-pm-retrospective.md). Phase 0 = Days 3-13 (covered there). Phase 1 = this.

---

## Headline framings

### The shape of Phase 1

A 9-day arc compressed into one evening that produced:

- **2 fixes applied** locally (formula_v2 enabled, gc binary upgraded HEAD-caa44a4)
- **4 §sections added** to the v2 manual (§26, §27, §28, §29)
- **2 §sections substantially updated** (§22 sub-pattern, §24 Step 1.5 + iteration playbook)
- **4 upstream engagements** (PR #2037 confirmed merged, #1487 awaiting reaction, #3880 commented, **PR #2088 opened**) — 1 per 2.25 days, an acceleration over Phase 0's 1-per-3.7-days pace
- **0 active regressions** at phase end; failure baseline went from 36/36hr (pre-Day-18) → 2/66min (post-upgrade, pre-bd-symlink) → **0/12hr (post-symlink)**

### The phase had a single dominant mental model

**Migration as recurring bug surface** (now §28). Three of three city-discovered bugs in the phase were migration-shaped:

- PR #2037 (dolt-state.json fallback) — controller-pack-interface migration gap
- PR #1848 (SCRUB_FILTER column rename) — schema migration follow-up; received via Day-18 upgrade
- mc-mxl4vc (bd 1.0.4 auto-import misfire) — pre-0.56 data dir migration helper

The framing didn't exist on Day-14. By Day-20 it had a name; by Day-22 it had a §section.

### The other dominant emergent pattern: embed-as-source-of-truth

§27 ("Pack content in the gc binary: embed vs filesystem reconciliation") was the surprise of Day-17. The mental model — *"the live runtime pack content lives inside the gc binary, not on disk"* — wasn't in anyone's hypothesis space before Day-17's `cp -rf` experiment proved the auto-revert. Day-18's binary upgrade then validated it experimentally. The pattern extended to bd at Day-20 ("§27 applies to bd too").

---

## What didn't survive into the polished day notes

### Operational frustrations across the phase

- **`gc status` and `gc doctor` hung intermittently on five different days** (Days 15, 17, 18, 19, 20). Always after fresh supervisor restart or during reconciler-busy windows. Day-15 attributed it to orphan-from-shell-crash; Day-18 found launchd was respawning the supervisor against our kills; Day-22 found bd's CLI hangs under supervisor reconciler activity. Different root causes, same surface symptom. Worth a §22 sub-pattern: "intermittent gc-client hangs are usually not gc — they're the underlying dolt or controller in a busy or stuck phase."

- **`gc stop` hung four times in five days** (Days 15, 17, 18). The "supervisor shutdown escalation ladder" — gc stop → SIGTERM → launchctl unload + SIGKILL — was rediscovered three times before being written down. Worth §13 footnote: this escalation IS the supported recovery for a stuck supervisor.

- **`bd close` hung repeatedly** during dolt-contention windows (Day-18, Day-19). The mc-2ntb2p bead close was deferred TWICE before bd 1.0.3 symlink + supervisor quiet window allowed it. The user observed the supervisor was hammering bd reconciler queries; bd writes queued behind those. Worth a §22 footnote: "bd write operations can take 30+ sec during supervisor reconciler activity windows; expect retry."

- **`make check` taking 45 min** (Day-22 PR #2088). Per §24 it's documented as 5-15 min. The +130-commit codebase scaled the lint pass by 3-4×. Worth a §24 footnote: "full-pass make-check times scale with codebase size; budget 30-60 min for HEAD builds."

### Rejected approaches and pivots

- **Day-16 Option B → pivot to passive observation.** The plan called for briefing mayor with a synthetic `/health` endpoint task. Pre-flight (`gc session peek mc-d7k`) revealed mayor was already mid-flight on a real autonomous fix. Pivoted in <2 min; the synthetic brief was never sent. The retroactive observation produced §26's null-result framing — much sharper than the synthetic task would have. **Pattern surfaced: peek-before-brief is a one-line safety check that's now §24 worthy.**

- **Day-19 mc-f7u8fz measurement → pivoted to bd 1.0.4 regression.** The Day-19 plan was supposed to be falsification-first ("is mc-f7u8fz still reproducible under HEAD?"). Reality: the city was broken at the bd-write layer because Day-18's brew install silently bumped bd to 1.0.4. The mc-f7u8fz question became unmeasurable; the bd regression became the day's work. mc-f7u8fz is still open at phase end.

- **Day-20 Branch B (PR) → Branch A (comment).** Predicted a one-line PR to bd. Reality: the fix was already merged (#3691), waiting for release (#3870). Commented on the matching issue (#3880) instead. **Two of the city's four upstream engagements have been comment-not-PR; the duplicate-search-budget pattern was promoted to §24 Step 1.5 at Day-22.**

- **Day-21 G2 + G5 BOTH falsified.** The convoys tour expected to find that convoys and workflows are the same primitive with two names. Reality: distinct primitives at every layer (different bead types, different commands, different internal packages). §29 had to be bigger and more disambiguation-focused than the plan anticipated.

### The retrospective's own predictions, scored

The Day-14 PM retrospective's "Day-N ladder" predictions vs reality:

| Predicted | Reality |
|---|---|
| Day-15: apply formula_v2 = true | ✓ Done Day-15, 5/5 success |
| Day-16: full-mayor demo | ✓ Done Day-16, null result via real-incident pivot |
| Day-17: convoys tour | ✗ Done Day-21 instead. Day-17 became "investigate mayor's claim" → §27 discovery |
| Day-18: submodule reconcile + sweep | ✓ Submodule reconciled Day-17; sweep done Day-22 |
| Day-19+: mc-f7u8fz upstream | ✗ Blocked Day-19 by bd regression; still unmeasured |

3 of 5 hit; 2 missed by significant pivots. The pattern: **the retrospective's specific predictions weren't accurate but its TOPICS were exactly right.** Everything it predicted got done; the order and shape diverged based on what reality presented.

---

## Recurring themes — operator working style

- **"Pre-flight first" became a hard discipline.** Every day-plan since Day-14 starts with a §1 pre-flight section before any execution. Days that skipped this (Day-19 didn't actually pre-flight against `gc supervisor logs` before measuring) discovered the gap mid-execution. By Day-22 the pre-flight habit had inverted the failure pattern: instead of "discover regression mid-investigation," surprises arrived in §1 and re-shaped the day's scope cleanly.

- **"Follow the rules"** — Day-20 the user reinforced the discipline of not committing unrelated files (the 7 renames + `.beads/config.yaml` that have been in the working tree since Day-17). I committed several Day-N artifacts without touching those; user's housekeeping stayed user's. Phase-end state: those files are still untouched.

- **The user delegates exploration days, holds judgment on irreversible actions.** Branch decisions (Day-17 Case B+, Day-19 pivot, Day-20 Branch A) were all decided by the user via AskUserQuestion. Tour-day directions (Day-21 convoys, Day-22 sweep) were AI-proposed and user-accepted. The split is consistent: **decisions get checked; explorations get delegated.** Worth a §22 framing note.

- **Tour day → sweep day → fix day rhythm validated.** Day-21 was the first deliberate tour day after a 7-day fix stretch. Day-22 was the sweep. Days 23+ are now expected to follow this rhythm. The retrospective's "user is unusually fast on code-reading + diagnosis, unusually slow on 'just run it'" observation gets a new resolution: **diagnose on fix days, run experiments on tour days.**

- **The §22 falsification ritual extended twice in Phase 1.** "Step 1.5b — falsify the FIX's premises" emerged from Day-14/15 (verify the fix's blast radius). Day-20 extended it to "falsify whether the fix is already in upstream main." Day-22 surfaced a third extension that wasn't promoted yet: **"grep the changed string across the WHOLE repo, not just the source file"** — would have caught the Copilot docs-regen issue pre-submission. Worth adding to §24 Step 1.5.

---

## Threads open at phase end

| Thread | Status | Out-of-our-hands? |
|---|---|---|
| PR #2088 (convoy --help text) | OPEN, awaiting csells review, Copilot iteration cycle done | Yes |
| mc-mxl4vc (bd 1.0.4 regression) | OPEN, fix merged upstream (#3691), waiting for v1.0.5 release | Yes |
| mc-uhvbb9 (refinery patrol hang) | OPEN since Day-8, comment on #1487 Day-12 | Yes |
| mc-f7u8fz (reconciler 27s no-op tick) | Status UNKNOWN since Day-19 (couldn't measure) | No — Day-23 candidate |
| Renames + .beads/config.yaml | In user's working tree since Day-17 | Yes (user's housekeeping) |

**Only one open thread is in our hands:** mc-f7u8fz measurement retry. Everything else is genuine waiting.

---

## Natural Day-23+ moves

Given the open threads and the working-style patterns:

- **Day-23: mc-f7u8fz observability retry.** The city is functional and quiet (bd 1.0.3 symlink, 0 failures/12hr). Trace subsystem still requires explicit arming but may now produce data over a longer window. Fresh measurement attempt. If still blocked, fall back to supervisor.log timestamp-mining.
- **Day-24: mayor handoff experiment redux.** Day-16 was a null result for formula_v2's effect on mayor. With §29's convoy-vs-workflow disambiguation in hand, a fresh experiment where mayor explicitly creates a convoy (not just relies on implicit decomposition) might produce different results.
- **Day-25+: other subsystem tours.** Mail, sling, workflows-as-distinct-from-convoys. Each ~90 min, produces a §section, exercises the tour-day pattern.

The retrospective from Day-14 said "mc-f7u8fz upstream engagement" was the next-worthy-PR candidate. Phase 1 didn't get there. Phase 2 might — or might not, depending on whether the measurement reveals the bug is gone (upgrade-as-fix) or still present.

---

## Things an outside reader sees

- **The "follow the rules" discipline is a real artifact**, but it's strict in a particular direction: don't touch what the user is curating themselves. The renames have been in the working tree for 6+ days and I never touched them. That's not friction — it's clarity about scope.
- **The §section count went from 25 → 29 in 9 days.** That's ~one new §section per 2 days during heavy weeks (Days 14-22). The retrospective's "tour days produce manual sections; fix days produce beads/PRs" framing predicts the §29-era pace continuing only on tour-density days; fix-day pace produces zero new §sections.
- **The Day-12 "best-case negative outcome" framing fired three times in Phase 1.** Day-17 (Case B not C, fix already exists), Day-19 (no PR for mc-f7u8fz, regression discovered instead), Day-20 (Branch A not B, fix already merged). Each time the framing converted what looked like a setback into a clean outcome. Worth a §24 elevation: "finding the fix already exists is the second-best contribution shape, not a failure."
- **Phase 1 had a tighter feedback loop than Phase 0.** Phase 0 (Days 3-13) had ~6 days between findings; Phase 1 had findings every day. This isn't sustainable but it produced a lot of clean documentation. **Phase 2 might benefit from deliberately slower-cadence days** — pick one open thread, work it across 2-3 days, vs cramming.
- **The retrospective from Day-14 has held up surprisingly well.** Re-reading it at Day-22, its concrete predictions were ~60% accurate; its meta-observations ("Step 1.5 is the most load-bearing step," "events.jsonl is underused observability," "the user is fast on diagnosis, slow on just-run-it") have all held. Phase 2's retrospective should be writable from the same template.

---

## Anything to promote in Phase 2

- **§22 sub-pattern: "intermittent gc-client hangs are usually about underlying state, not the CLI."** Names a pattern that recurred 5+ times in Phase 1.
- **§24 footnote: "grep the changed string across the whole repo before submitting a docs PR."** Day-22 Copilot iteration would have been avoided with this discipline.
- **§22 footnote: "tour-day vs sweep-day vs fix-day rhythm."** Already partially in §22 from Day-22; could be promoted to its own bullet structure.
- **§24 elevation: "finding the fix already exists is the second-best outcome."** Day-12 / Day-17 / Day-19 / Day-20 all validated this. Should be explicit in §24's branching outcomes.
- **§13 footnote: "the supervisor-shutdown escalation ladder."** gc stop → SIGTERM → launchctl unload + SIGKILL. Used 3 times in Phase 1; worth codifying.

None are urgent; all are §footnote candidates for the next slow tour day.
