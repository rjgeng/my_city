# Day 14 — digest-generate 100%-fail: decide which premise is wrong

- **Plan authored:** 2026-05-12 (after Day-13 wrap)
- **Planned execution:** 2026-05-13 (or later same day)
- **Status:** Plan only; investigation not yet started

This is the pre-decomposition for Day-14: act on the digest-generate anomaly surfaced incidentally during Day-13's order catalog. Unlike Day-5 (mc-vj3hjk → needed a script fix in Day-7) or Day-13 (escort-mode tour, no fix), Day-14 is a **§22-style premise correction**: the error message tells us exactly what's wrong, so the investigation is short and the work is choosing the right fix.

---

## 1. The signal — what we see

From Day-13's events.jsonl mining: **digest-generate fired 17 times, failed 17 times** across 2026-05-07 to 2026-05-12. Every failure carries the same error message:

```
formula "mol-digest-generate" declares contract graph.v2 but formula_v2 is
disabled; enable [daemon] formula_v2 or remove [the declaration]
```

The order configuration on disk:

```toml
# .gc/system/packs/gastown/orders/digest-generate.toml
[order]
description = "Generate daily code digest across all rigs"
formula = "mol-digest-generate"
trigger = "cooldown"
interval = "24h"
pool = "gastown.dog"
```

Cadence: 24h cooldown × (1 city-scope + 5 rig-scope fan-out) = up to 6 fires/day. Observed pattern across the 5-day window:

| Day | Fires | Result |
|---|---:|---|
| 2026-05-07 | 2 | both failed |
| 2026-05-08 | 1 | failed |
| 2026-05-09 | 4 | all failed |
| 2026-05-10 | 5 | all failed |
| 2026-05-12 | 5 | all failed |

(2026-05-11 had zero fires — city was down that day.) Each daily wave fires the city-scope copy first, then the rig-scope copies follow within minutes. No backoff — the cooldown clock advances regardless of failure (per §25's lifecycle finding).

Two competing premises produced this state, and Day-14 has to decide which one is wrong:

- **Premise A — the city config is wrong:** the daemon has `formula_v2 = false` (or unset), but the formulas in this pack set were authored against `graph.v2` and need it. Fix: enable `[daemon] formula_v2 = true` in `.gc/site.toml`.
- **Premise B — the formula declaration is wrong:** `graph.v2` is over-declared in `mol-digest-generate.toml`. The formula may actually work fine under the older contract; the declaration is vestigial or aspirational. Fix: remove the contract declaration line from the formula TOML.

Neither premise is obviously right without reading the formula and the daemon flag's behavior.

---

## 2. Pre-flight: where this lives

- **Order:** `.gc/system/packs/gastown/orders/digest-generate.toml` — already read in Day-13.
- **Formula:** `.gc/system/packs/gastown/formulas/mol-digest-generate.toml` — exists on disk (Day-13 `find` confirmed); NOT YET READ.
- **Daemon flag (`formula_v2`):** lives in `.gc/site.toml` (or possibly `city.toml`). Probably under a `[daemon]` section, but unverified.
- **Contract definition (`graph.v2`):** lives in `study/gascity-src/` somewhere. Search needed for what `graph.v2` actually provides.
- **City state:** city does NOT need to be running. All files are static on disk; events.jsonl already gives the failure surface. Only at Step 4 (apply fix and verify) will the city need to be running.

---

## 3. What "done" looks like (success criteria)

**Decision milestones:**

- Read `mol-digest-generate.toml` end-to-end. Identify *why* it claims `graph.v2` (which field? what does the field do?).
- Find the `graph.v2` contract definition in gascity-src. Understand what it gates.
- Find the `formula_v2` daemon flag's handling in gascity-src. Understand what enabling it changes city-wide.
- Decide between Premise A and Premise B with explicit reasoning.

**Action milestone:**

- Apply the chosen fix (one-line change either in `.gc/site.toml` or in `mol-digest-generate.toml`).
- Restart the controller (`gc restart` or `gc reload` per §13/§14, depending on which is needed).
- Wait for the next digest-generate fire (or use `gc order run digest-generate` to bypass cooldown).
- Observe `order.completed` instead of `order.failed`.

**Manual artifact:**

- §25 gets a small appendix note about this resolution (or §22 gets a new sub-pattern entry, depending on framing). Probably **§25 makes sense** since the worked example is an order, and this closes a finding from Day-13. Target ~30-50 lines, NOT a full new section.

**Optional outcome:** if the fix turns out to be sub-optimal city-wide (e.g., enabling formula_v2 would break another formula, OR removing the contract declaration would lose functionality), file a bead and stop short of applying. Don't apply a fix whose blast radius isn't understood.

---

## 4. Execution plan — investigation-then-fix, narrated step-by-step

Day-14 is half-tour / half-action. Steps 1-3 are read-only investigation; Step 4 is a live config change.

### Step 1: Read mol-digest-generate.toml end-to-end (~10 min)

```bash
cat /Users/rfvitis/my-city/.gc/system/packs/gastown/formulas/mol-digest-generate.toml
```

For each field present, note what it declares. Key fields to surface:

- `contract` or `contracts` — which contract version is named, and what other fields are gated by that choice?
- `graph` — if there's a `[graph]` block or similar, what shape is it?
- `inputs`, `outputs`, `steps` — what is the formula's actual workload?
- Any other fields that would only make sense under `graph.v2`.

Output: a short paragraph explaining what mol-digest-generate is supposed to do, plus a one-line judgment on whether the `graph.v2` claim looks substantive or vestigial.

### Step 2: Find the `graph.v2` contract definition in gascity-src (~15 min)

```bash
cd /Users/rfvitis/my-city/study/gascity-src
grep -rn 'graph\.v2' --include='*.go' | head -20
grep -rn '"graph.v2"' --include='*.go' | head -20
grep -rn 'graph_v2\|GraphV2' --include='*.go' | head -20
```

What we want to find:

- Where the contract name `graph.v2` is registered/parsed.
- What the v2 contract enables vs. v1 (or the unversioned default).
- Whether v2 is additive (back-compat) or a breaking change.

Output: a short paragraph on what graph.v2 gives a formula. Hypothesis to validate: it's the newer, richer contract for declaring step graphs; v1 is the legacy flat-list shape.

### Step 3: Find the `formula_v2` daemon flag's handling (~15 min)

```bash
cd /Users/rfvitis/my-city/study/gascity-src
grep -rn 'formula_v2\|FormulaV2' --include='*.go' | head -20
grep -rn '\[daemon\]' --include='*.go' --include='*.toml' | head -10
```

What we want to find:

- Where the flag is read (probably in the daemon config struct + a check at formula-load time).
- What enabling it does in code paths beyond rejecting `graph.v2` declarations.
- Default value (off in this city, but is it off everywhere by default?).

Then check the live config:

```bash
grep -n 'formula_v2\|\[daemon\]' /Users/rfvitis/my-city/.gc/site.toml
cat /Users/rfvitis/my-city/city.toml | head -40
```

Output: a one-line confirmation of the flag's current value + a short paragraph on what enabling it changes besides "lets mol-digest-generate load."

### Step 4: Decide and apply the fix (~10 min decision + ~5 min apply)

Decision logic:

- **If Step 2 shows `graph.v2` is the new default contract** and Step 3 shows `formula_v2 = true` is the migration target (with no surprises in the other code paths it touches), **Premise A wins**: enable the flag.
- **If Step 1 shows `mol-digest-generate` doesn't actually use any v2-only features** and the formula would work fine under v1, **Premise B wins**: remove the contract declaration.
- **If both fixes look viable**, prefer Premise A (enable the flag) — it future-proofs the city for other v2-declared formulas. But document the choice.
- **If neither fix looks safe** (e.g., enabling formula_v2 might break another formula we haven't audited), STOP. File a bead, leave city as-is.

Apply (assuming Premise A):

```bash
# Edit .gc/site.toml — add [daemon] formula_v2 = true
# Then either:
gc reload    # Level 1 — preferred if it works (per §13)
# OR
gc restart   # Level 2 — if reload doesn't pick up daemon-level flags
```

Apply (assuming Premise B):

```bash
# Edit .gc/system/packs/gastown/formulas/mol-digest-generate.toml
# Remove the `contract = "graph.v2"` line (or similar; exact key TBD in Step 1)
gc reload    # config-only change, reload should suffice
```

### Step 5: Verify the fix (~5 min wait + ~2 min confirmation)

```bash
# Bypass cooldown to trigger a fresh fire
gc order run digest-generate
# Wait ~30s for the run to complete
sleep 30
# Confirm via events.jsonl
F=/Users/rfvitis/my-city/.gc/events.jsonl
tail -50 "$F" | grep digest-generate
```

Expected: an `order.completed` event for digest-generate with **no** `order.failed` event between fire and completion.

If completion is observed: success. Move to Step 6.

If failure persists with a different error message: the fix addressed the contract issue but exposed a downstream problem. Diagnose the new error in a follow-up bead.

If failure persists with the same error message: the config change didn't take effect. Try `gc restart` instead of `gc reload`; if still failing, the flag may live somewhere other than `.gc/site.toml` (back to investigation).

### Step 6: Document the resolution in v2 manual §25 (~15 min)

Add a short appendix subsection (~30-50 lines) titled something like *"Worked example: digest-generate's `formula_v2`/`graph.v2` skew (Day-14)"*. Cover:

- The error signature (exact message).
- The two premises and how we decided.
- The fix applied.
- The verification step.
- Generalize: this is a §22-pattern (verify premises before fixing) playing out at the order/formula layer.

Don't expand §25 by more than ~50 lines. This is an appendix, not a new section.

---

## 5. Things to look for (anticipated learnings to validate or falsify)

Pre-thought hypotheses, ranked by my prior guesses:

**H1: `formula_v2` is off by default in this city's `.gc/site.toml`.** Either the flag is absent (default off) or explicitly false. The city was probably set up before graph.v2 was the default formula contract. Verify in Step 3.

**H2: `mol-digest-generate` is the only formula in this pack set declaring `graph.v2`.** If true, the blast radius of enabling `formula_v2` is tiny — only this one formula starts loading correctly. If other formulas also declare it, enabling the flag fixes more than digest-generate. Easy check: `grep -r 'graph.v2' .gc/system/packs/`.

**H3: The intended fix is Premise A** (enable `[daemon] formula_v2 = true`). Reasoning: `graph.v2` is named after a contract version, suggesting it's a forward migration target. Pack-shipped formulas declaring it implies the pack authors expect formula_v2 to be on. Verify in Steps 2-3.

**H4: The 24h cooldown advances regardless of failure** — confirmed in §25's lifecycle. The 17/17 pattern is "fires daily, fails immediately, retries 24h later." This is not a hypothesis to verify, just a structural fact already established.

**H5: This is config skew from an early city-init era, not a recent regression.** The first failure (2026-05-07T22:40) was the very first fire of digest-generate in this events.jsonl. Day-13's window doesn't include a successful baseline. If there's an older events.jsonl in `.gc/jsonl-archive.git`, it might show whether digest-generate ever worked.

If H1-H3 all check out, the fix path is clean: enable the flag, reload, verify. If H2 falsifies (other formulas also declare graph.v2), the §25 appendix gets a stronger framing ("this fix unblocks N formulas, not just one").

---

## 6. Risk / blast radius

**Steps 1-3 (read-only):** zero risk. File reads + greps.

**Step 4 (apply fix):** small but non-zero. Risks by premise:

- **Premise A (enable formula_v2):** the flag's other side effects (per Step 3) might affect formulas that are currently *implicitly* working under v1 contract assumptions. Mitigation: Step 3 explicitly checks for those side effects. If found, document and decide.
- **Premise B (remove the contract declaration):** removes a possibly-load-bearing field from mol-digest-generate. If graph.v2 was actually being used by the formula's step graph, the formula will load but fail differently at run-time. Mitigation: Step 1 confirms whether the formula's other fields require v2 shape.

**Step 5 (gc order run):** the only non-read-only operation. Forces a manual digest-generate fire bypassing cooldown. Worst case: the formula loads correctly but its actual work (generate code digest) fails for an unrelated reason. That's a useful failure to surface; not a city-stability issue.

**Step 6 (manual edit):** zero risk. Notes file in study/, gitignored is not actually true — but committed locally, not pushed upstream.

City stability: a controller reload is safer than a restart. If reload alone picks up the change, prefer that.

---

## 7. Connection to prior days

- **Day-5 (mc-vj3hjk):** same pattern of an order failing repeatedly. But mol-dog-jsonl needed a script-level fix (Day-7's pack-script secondary-fallback). This one is config, not code. Worth a §25 appendix note contrasting the two failure modes.
- **Day-7 (pack-script fallback):** §22 pattern — verify premises before acting. Day-14 is the same pattern applied to a different layer (order/formula config vs. script).
- **Day-13 (orders tour):** Day-14 directly continues the orders mental model. The §25 catalog and failure-model sections now get a concrete worked example for *formula-flavored* order failures (mol-dog-jsonl was the exec-flavored worked example).
- **§22 (debugging pack scripts):** Day-14's resolution is exactly this pattern — the error message is precise; the work is choosing which premise to invert.

---

## 8. Adjacent work to fold in

Lightweight today-actions:

- **Daily check on PR #2037 + comment on #1487 status.** Once per day per Day-11 §4 Step 3. Passive observation only.
- **H2 verification:** quick `grep -r 'graph.v2' .gc/system/packs/` to see how many other formulas would benefit from formula_v2 = true. Done early in Step 3.

Soon (Day-15+):

- If Day-14's fix unblocks digest-generate, the **first successful digest output** itself becomes worth inspecting. Where does the digest go? Mayor's inbox? A new git repo? Day-15 candidate: "tour digest-generate's work product, now that it's producing one."
- **Convoys tour** (the long-deferred escort-mode tour). Now even better-informed: convoys + orders + gates form a triad.

---

## 9. Optional: mayor handoff

Skip. This is a small surgical investigation + fix. Mayor orchestration would add overhead for ~45 min of focused work.

If the Day-14 investigation reveals that the fix has broad implications (e.g., formula_v2 changes the semantics of multiple formulas), then escalating to mayor for a city-wide rollout decision becomes reasonable — but only after Step 3 surfaces that risk.

---

## 10. Execution log

(filled in as work happens)

### Adjacent: PR #2037 daily-check closed

PR #2037 (`fix(packs): fallback to dolt-provider-state.json`) **merged 2026-05-13T01:46:12Z** by maintainer sjarmak as commit `e1cee04`. No review iterations requested; clean first-pass merge. This closes the Day-11 §4 Step 3 daily-check obligation — no more polling needed. v2 manual §24 updated inline (opening paragraph + Anatomy subsection) with the merge outcome. The full retrospective on what carried the PR through (honesty-first body, clean `make check`, complementary-evidence framing in §24's issue-filing variant) stays in §24 itself rather than getting duplicated here.

### Pre-flight outcomes

- Formula TOML contents (Step 1):
- `graph.v2` contract behavior (Step 2):
- `formula_v2` flag behavior + current value (Step 3):
- Other formulas declaring `graph.v2` (H2 check):

### Decision

- Premise selected (A: enable flag / B: remove declaration / C: stop, file bead):
- Reasoning:

### Fix application

- File edited:
- Line changed:
- Reload or restart:
- Verification fire outcome (Step 5):

### H1-H5 verdicts

- H1 (formula_v2 off in site.toml):
- H2 (mol-digest-generate is the only graph.v2 declarer):
- H3 (Premise A is right answer):
- H4 (cooldown advances on failure — already confirmed §25):
- H5 (config skew from early city-init):

### v2 manual §25 appendix added

- [ ] Error signature
- [ ] Two-premise framing
- [ ] Resolution
- [ ] Contrast with mc-vj3hjk (exec-order failure mode)

### Surprises

(things this plan got wrong, or new things surfaced)

### Anything to promote (beyond §25 appendix)

(filled in after the fix is verified)
