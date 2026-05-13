# Day-14 PM retrospective: the arc from Day-3 to Day-14

- **Authored:** 2026-05-13 (Day-14 evening, after mc-kh9qdv investigation closure and Day-15 plan)
- **Method:** survey of all 13 raw chat logs in `~/temp/gastown_logs/chatting_logs/gc/` (Day-3 plan onward, plus the pre-Day-3 Gas City onboarding log), delegated to a general-purpose agent that read every file in full and reported back. This is the agent's report (reproduced verbatim below) plus a short preamble of headline insights for fast re-reading.
- **Purpose:** a reference point at the next inflection — re-read on Day-30 to see whether the trajectory held.

The chat logs contain process content (rejected approaches, dead ends, course corrections, real anxiety, in-flight friction) that doesn't survive into the polished study/notes/ day files. This retrospective tries to preserve that signal while it's still legible.

---

## Headline insights (TL;DR)

### The shape of the arc — four tonal shifts in 12 days

| Phase | Days | Frame |
|---|---|---|
| Resident tourist | 3-4 | "What does this thing do?" Mayor decomposition demo. |
| Operator | 5-6 | JSONL push storm triage. Real bugs, real fixes. |
| Cycle-on-cycle falsifier | 7-10 | Four straight days where the writeup or bead premise itself was wrong. The Step-1.5-grep-upstream-first ritual emerged here. |
| Contributor | 11-14 | PR #2037 opened, merged; commented on #1487; mc-kh9qdv filed; v2 manual §24/§25 land. |

### Three things the chat logs surfaced that aren't in the polished notes

1. **Step 1.5 is the most load-bearing step in the entire project.** Since Day-7, the "grep upstream to falsify the central claim" step has invalidated the bead's premise or the plan's title on Days 7, 8, 10, 12, and 14. It's been a corrective ritual; it could become a *generative* one (writeup template field "claim most likely to be wrong: ___") or even tooling (`gc-falsify <bead>`).
2. **The PR-opening day (Day-11) was actually existential** — "what if they reject me." Polished §24 reads breezier than the day was. Worth knowing if you ever lend §24 to a new contributor.
3. **`events.jsonl` keeps getting re-discovered.** Used offline Day-6, for traffic profiling Day-13, incidental find of digest-generate Day-13 — three rediscoveries that suggest it deserves its own v2 manual section rather than a paragraph buried in §23/§25.

### Five open threads beyond Day-15

| Thread | Age | Status |
|---|---|---|
| Convoys tour | Mentioned 5×, deferred 3× since Day-4 | Most-deferred item on the board |
| mc-f7u8fz (reconciler 27s no-op tick) | Open since Day-6, four candidate fixes | Biggest remaining technical finding; no upstream engagement |
| Submodule pointer drift (`M study/gascity-src`) | Dirty since Day-7 | <30 min cleanup; PR #2037 merged means pointer can advance |
| mc-uhvbb9 (refinery patrol hang) | Comment on #1487 filed Day-12 | Awaiting upstream; mol-refinery-patrol is one of the 7 v2 formulas — Day-15 may reframe it |
| Silent failure sweep of events.jsonl | digest-generate found *incidentally* Day-13 | Implies more silent failures haven't been grepped for |

### Natural Day-16-and-beyond ladder

- **Day-16: full-mayor demo with formula_v2 = true.** Same scope as Day-9/10 paired-control, one new variable (mayor vs light-mayor + flag on/off). Mayor's prompt template renders differently under formula_v2, which is the experimental hook.
- **Day-17: the actual convoys tour.** Three deferrals overdue. The Day-4 cross-rig-convoy workaround is load-bearing in §20 and hasn't been re-verified.
- **Day-18 (maintenance): submodule reconcile + an events.jsonl `grep order.failed` sweep.** Both sub-30-min. The sweep likely produces several new beads in the digest-generate mold.
- **Day-19+: mc-f7u8fz upstream.** PR #2037's playbook is the muscle to use it. This is the next worthy second-PR candidate.

### One outside observation

The user is "unusually fast on code-reading + diagnosis, unusually slow on 'just run it.'" Day-6 diagnosed S4 without restarting the city. The paired-control framing on Day-10 was the first experiment-shaped day and landed cleanly. Pattern: when uncertain about a writeup, *experiment* should be the default move, not *re-grep*.

---

## Full survey report (agent verbatim)

### 1. Shape of the arc

The arc is **four tonal shifts in twelve days**, each driven by what the previous one made possible:

- **Days 3–4 (resident tourist).** Day 3 was deliberate scope-narrowing — A/B sling, codex-vs-claude on identical input, ~6 hours including the controller restart that revealed `[[rigs.patches]]` only scopes the patched agent. Day-4 expanded to the full mayor-led decomposition demo. The Day-4 log (2025 lines, the biggest) reads as half "this is amazing, mayor decomposed it cleanly" and half "wait, polecat didn't close the bead, refinery doesn't see it, why is the metadata wrong" — the JSONL push storm and `mc-vj3hjk` were filed by mayor *at the start of Day 4* but explicitly deferred so the demo could finish.
- **Days 5–6 (operator).** Day-5 was the JSONL triage; two layered root causes (missing `origin` remote + stale column reference) were found in a single sitting, with the chat log showing the user only restarting the city late after `bd dolt start` + cold investigation. Day-6 reframed `slow_storage_degraded` as a misnamed 25ms-fsync budget warning, *without restarting the city at all* — `gc trace` worked entirely offline against persisted segments, beating the plan's Step 2.
- **Days 7–10 (cycle-on-cycle falsification).** Day-7 was the user's first "fix-the-thing" day, and Step 1.5 (a grep that was originally only listed in the risk section) invalidated the bead's own premise. Same pattern fired on Day-8 (S5 — Day-4 writeup claim about refinery's `merged_commit` discovery key was wrong; predicate is `assignee+status+type+metadata.branch`). Day-9 validated, Day-10 paired-control disproved that the explicit nudge was load-bearing. Four straight days of "the writeup was wrong, the upstream code disagrees."
- **Days 11–14 (contributor).** PR #2037 opened Day-11, the first OSS PR of the user's career (memory entry `user_role.md` captures "transitioning hardware → software"). Day-12 redirected mid-flight from "file an issue" to "comment on existing #1487" — the falsification pattern fired against *the plan itself*. Days 13–14 returned to escort-mode (orders tour) but kept generating fix candidates: `digest-generate` 17/17 fail discovered incidentally during Day-13's traffic profiling, then opened as Day-14 with the explicit STOP-and-file-bead branch when Step 3 surfaced two non-obvious side effects of enabling `formula_v2`.

**What's maturing:** the falsification habit, the v2 manual as a credible reference, the upstream engagement loop. **What's still nascent:** mayor coordination (only Day-4 exercised real mayor handoff; Days 9/10/14 used light-mayor), convoys (touched on Day-4, never toured), full-mayor experiments.

### 2. Dead ends, rejected approaches, course corrections (chat-only)

- **Day-3:** the codex-rate-limit-stalls-the-whole-city moment that drove the workspace provider inversion (codex → claude default). Chat shows the user nearly inverted mid-flight; the assistant talked them out of it ("the controller frees itself once stuck sessions complete"). The runbook only records the final inversion.
- **Day-4 (2026-05-10_chat_for_day-4.md:1196):** the assistant proposed `gc agent suspend` to gate the workflow at G2; it failed silently and the assistant said "actually that was fine — natural pause at G2 is coming." Suspend approach abandoned as unnecessary.
- **Day-4:** repeated assistant errors on `gc city stop` (subcommand doesn't exist), `gc agent show` (no `show` subcommand), `gc bd close` flag-guessing. The published Day-4 plan elides these; the chat is full of them.
- **Day-4:** the **convoy-cross-rig gap** was first surfaced as "mayor produced cosmetic workaround `convoy:mc-XXX` label" — chat treats it as a real defect; polished notes treat it as "memory'd, move on."
- **Day-5 (chat:75–101):** the user asked "what's the strategy in plain English, with no jargon" — assistant gave a "diagnose a car: check gas gauge before the engine" framing. That metaphor never made it into the polished `study/notes/...triage.md`. The chat made the cold-investigation-before-live-restart decision explicit; the notes show only the outcome.
- **Day-6 (chat:42–46):** assistant nearly went down the "start city + grep stderr" path before noticing the submodule's own `engdocs/contributors/reconciler-debugging.md` documented an offline `gc trace` workflow. That re-routing isn't in the notes — just the cleaner finding.
- **Day-7 (chat:9–43):** the bead `mc-ma23a9`'s premise was *inverted* (the user thought `dolt-state.json` was legacy; it's canonical). Both planned fix options (rename, resolver-based) were rejected within minutes by the Step 1.5 grep. The polished plan note captures the conclusion but not the "Stop the press" reframe moment.
- **Day-8 (chat:36–55):** caught Day-5's manual §22 entry having the *same inversion* in transit. Three writeups in a row corrected. The notes record the fix; the chat records discovering that prior manual entries themselves had the bug.
- **Day-10 (chat:46–53):** assistant flagged its own Day-8 conclusion as having "survivorship bias" — extrapolated from a single stalled run. Paired control disproved it. This self-critique is in the chat as the compounding lesson; not in the polished §22.
- **Day-11 (chat:200–230):** Go wasn't installed; the user briefly weighed skipping `make check` and "letting CI verify." Chose `brew install go` instead. The chat shows the option-of-3 menu; the polished §24 plays it as a clean linear workflow.
- **Day-12 (chat:11–18):** the duplicate-search found issues #1991 (initially looked like a strong match for Day-9 finding #1, then disqualified — Day-9's "no routed_to at all" was documentation-shaped, not bug-shaped) and #1487 (kept). The notes only mention #1487. The "looked match, ruled out" #1991 work is invisible there.
- **Day-13 (chat:107–122):** assistant offered to switch the worked example from `mol-dog-jsonl` to `digest-generate` once the 17/17 anomaly surfaced; user stuck with `mol-dog-jsonl` for the Day-5 loop-closure value. Polished §25 leaves no trace of that branching choice — but Day-14 is a direct consequence of it.
- **Day-14 (chat:97–101):** the assistant flagged a meta-process note — "reading gascity-src injected its CLAUDE.md, which mandates `bd` for tracking; I'm keeping TaskCreate because we're in city scope" — and asked the user to correct if they'd rather switch. Notes don't capture this kind of in-flight harness/agent friction.

### 3. Recurring themes — the user's working style

- **"Premise before action."** Every day since Day-7 starts with Step 1.5 — grep upstream to confirm the central claim. This wasn't designed; it emerged after the Day-7 bead premise inversion. The user now treats *plans themselves* as falsifiable — Day-12 invalidated its own title mid-flight.
- **Plan-then-execute, even on small tasks.** Days 5, 6, 9, 10, 13, 14 all use the same 10-section plan template (Section 1 pointer → Section 10 empty execution log). The user explicitly told the assistant on Day-5 ("pre-writing the Day-N+1 plan is the methodology, so we should lock it in now while context is fresh"). It became a ritual.
- **Failure → bead, not patch in place.** mc-vj3hjk (Day-4 deferred), mc-f7u8fz (Day-6 reconciler perf), mc-ma23a9 (Day-6 latent), mc-uhvbb9 (Day-8 refinery patrol), mc-kh9qdv (Day-14 formula_v2 decision-deferred). The user almost never patches blind. Day-14 is the cleanest example — STOP-and-file-bead because Step 3 found two non-obvious side effects.
- **"Documentation alongside execution"** — the v2 manual is updated *the same day* the finding lands. Section grew §19/§20/§21/§22 (Day-5), §23 (Day-6), §24 (Day-11), §25 (Day-13). The user pushed back on the assistant when it tried to commit before docs were updated.
- **"Slow down when uncertain"** — Day-11's PR opening took ~2 hours and involved `make check` + Go install + rebase + fork + push + draft body. The chat shows real nervousness ("worth pushing through ... but the fix is good"). Day-13/14 returned to slower tour mode after two upstream-engagement days.
- **Escort mode requests.** Days 9, 11, 12 explicitly: "narrate each step before running it." User trades speed for legibility.

### 4. Threads started and not closed

Confirmed open from the logs:

- **Convoys tour.** Mentioned in 2026-05-08 (stop 3 sidebar), Day-4 (`mc-wjos2g` workaround), Day-13 (assistant offered convoys as an alternative for Day-13, deferred), Day-13 plan §8 (deferred again), Day-13 wrap (deferred to Day-15+). Three explicit deferrals over 6 days.
- **mc-uhvbb9** (refinery patrol streaming-API starvation). Comment on #1487 filed Day-12; awaiting reaction. Day-15 plan notes refinery-patrol is one of the 7 v2-declaring formulas — flipping the flag may re-frame this.
- **mc-f7u8fz** (reconciler p50=27s for no-op tick). Open since Day-6, four candidate fix directions, no upstream engagement — biggest remaining technical finding on the board.
- **mc-kh9qdv** (Day-14 formula_v2 decision-deferred). 7 v2-declaring formulas blocked; Day-15 will apply.
- **Day-7 `dolt-state.json` orphan-file edge case** (Day-14 chat:131): "Neither state file present" wasn't covered by PR #2037's fallback chain. User flagged it for a potential §22 footnote; nothing filed.
- **Stash entries in `~/co_auth/.git`** (Day-4 chat:1430): two stale stash entries from autostash, flagged as "drop when convenient." Probably still there.
- **`digest-generate` was a city-level event-bus signal you'd been ignoring** — the order had fired 17/17 fail before Day-13 *incidentally* surfaced it. There's an implicit thread: "what else is failing silently in events.jsonl that I never grepped?"
- **mol-dog-jsonl state-file sample** — Day-13 mentioned it as a Day-14+ candidate, never picked.
- **The Day-6 `slow_storage_degraded` rename PR** — flagged in Day-11 plan §6 as a possible second PR; declined because of coordination cost.
- **The `study/gascity-src` submodule pointer drift** — appears in `git status` every single day since Day-7 (it's `M study/gascity-src` in the initial state too). The submodule's local branch `rjgeng/fix/dolt-pack-script-state-fallback` was rebased to `48191657`, then PR #2037 merged at `e1cee046` upstream. The pointer should now be reconcilable with a single `git submodule update --remote` + commit. User hasn't done it.

### 5. Natural next moves beyond Day-15

Anchoring on what the user has actually shown interest in:

- **Day-15 = apply formula_v2 = true.** Already planned. The downstream surprise will likely come from the other 6 v2-declaring formulas the user has never observed. `mol-refinery-patrol` is one of them; if it changes behavior, mc-uhvbb9 may resolve or shift shape.
- **Day-16: validate via mayor.** The full-mayor demo has been deferred since Day-9 ("save full-mayor variant for a later day"). With formula_v2 on, mayor's prompt template renders differently (graph-worker swap). It's the natural follow-on experiment to Day-9/10 — same scope, change one variable (mayor vs light-mayor + flag on vs off).
- **Day-17: convoys tour (the actual one).** Three deferrals overdue. Day-4's `mc-wjos2g` workaround is a load-bearing claim the user has never re-examined, and §20 in the v2 manual states it without recent re-verification.
- **Reconcile the submodule pointer.** Sub-30-minute housekeeping that's been dirty since Day-7. PR #2037 merged means the pointer can now legitimately advance.
- **mc-f7u8fz upstream engagement.** Day-10 noted the pipeline has a "~9-minute throughput floor under current reconciler load" — fixing this is the most impactful upstream contribution still on the board. The user has the muscle now (PR #2037 worked example).
- **A second exec/formula investigation pass.** `digest-generate` was found incidentally. Grepping `events.jsonl` for `order.failed` would surface every other silent failure — likely a 30-minute exercise that produces several beads. Pattern matches Day-13's incidental discovery model.

### 6. Things the outside reader sees

- **Step 1.5 deserves promotion to Step 1.** The risk-section grep has been the most load-bearing step on every fix-day since Day-7. The user keeps re-deriving "always grep upstream first." Worth a permanent tool/script (`gc-falsify <bead>` that greps the submodule for the bead's central claim).
- **Plans and writeups are accreting *the same* failure mode.** Day-5 §22, Day-7 mc-ma23a9, Day-8 S5, Day-10's own Day-8 conclusion — each writeup confidently inverted the prior one's central claim. The user has built a corrective ritual but not yet a *generative* one. A writeup template field like "claim most likely to be wrong: ___" might short-circuit this earlier.
- **Mayor's "Then STOP." anti-pattern is more general than recorded.** Day-4 found polecat over-interpreting it. Day-13/14 the *user* runs the same pattern in their own plans — "STOP-and-file-bead is an explicit branch." This is the same shape, applied healthily; worth naming as a positive cousin of the anti-pattern.
- **The user is unusually fast on code-reading + diagnosis, unusually slow on "just run it."** Day-6 diagnosed S4 without restarting the city. Day-9 took 12 minutes before realizing the bead needed `gc.routed_to`. Pattern: cheap-cold-investigation is over-budgeted relative to cheap-hot-experimentation. The "paired control" framing on Day-10 was the first experiment-shaped day; it landed cleanly and probably should become the default for any "is the writeup right?" question.
- **The chat shows real existential moments around the PR** — "what if they reject me." Polished notes flatten this to a milestone. A future reader of just the notes would underestimate how much courage that day required, which matters because the contributor-playbook §24 reads breezier than the day itself was.
- **`events.jsonl` is an underused observability surface.** Day-6 used it offline, Day-13 used it for traffic profiling, Day-13 incidentally found `digest-generate`. The user keeps re-discovering it. It deserves a v2 manual section of its own, not a paragraph in §23/§25.
- **The bd-prefix-vs-rig-name asymmetry** (Day-9 found refinery's discovery predicate; agent alias = rig name, bd prefix = arbitrary) was a real finding that ended up in §19 corrections but never as a standalone section — it's the kind of thing that bites the next time someone adds a rig.

### Files of particular relevance

- `~/temp/gastown_logs/chatting_logs/gc/2026-05-10_chat_for_day-4.md` (full Day-4 trajectory including 1196 line abandoned suspend, 1430 stash flag, 1815 §S5–S8 surprise list)
- `~/temp/gastown_logs/chatting_logs/gc/2026-05-12_chat_for_day-7.md:9–43` (the "Stop the press" premise inversion moment)
- `~/temp/gastown_logs/chatting_logs/gc/2026-05-12_chat_for_day-10.md:46–53` (assistant self-critique of Day-8 survivorship bias)
- `~/temp/gastown_logs/chatting_logs/gc/2026-05-12_chat_for_day-11.md` (PR-opening real anxiety; brevity belies effort)
- `~/temp/gastown_logs/chatting_logs/gc/2026-05-14_chat_for_day-14.md:97–101` (the harness/agent friction note that doesn't appear elsewhere)
