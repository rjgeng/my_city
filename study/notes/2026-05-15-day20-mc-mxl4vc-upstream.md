# Day 20 — mc-mxl4vc upstream contribution: bd 1.0.4 auto-import regression

- **Plan authored:** 2026-05-13 (evening, after Day-19 closure)
- **Planned execution:** 2026-05-15
- **Status:** Plan only

Day-19 discovered the bd 1.0.4 auto-import-on-empty-database regression, identified root cause in `cmd/bd/auto_import_upgrade.go`, applied a 2-line workaround (symlink to bd 1.0.3), and filed bead `mc-mxl4vc` with full diagnostic. Day-20 takes that finding upstream.

Upstream is **`gastownhall/beads`** (resolved Day-19 — `steveyegge/beads` redirects to it). Same maintainer org as gascity, where sjarmak merged PR #2037 and PR #1848. Known process, known review cadence.

This is the third upstream engagement from this city — PR #2037 (Day-7 → Day-13 merge), #1487 comment (Day-12), and now mc-mxl4vc. The §24 playbook applies again, with the Day-12 duplicate-search rigor as Step 1.

---

## 1. Pre-flight: what mc-mxl4vc is

**Symptom (rediscoverable):**
- After upgrading bd from 1.0.3 to 1.0.4 (transitively bumped by `brew install --HEAD gascity`), every `bd create` and `bd close` hangs for 2+ minutes with:
  ```
  bd create: timed out after 2m0s: auto-importing 4619172 bytes from .../issues.jsonl into empty database...
  ```
- Reads (`bd show`) work; only writes are affected.
- Reverts cleanly: `ln -sf /usr/local/Cellar/beads/1.0.3/bin/bd /usr/local/bin/bd` restores working state.

**Root cause (already analyzed Day-19):**
- `cmd/bd/auto_import_upgrade.go::maybeAutoImportJSONL` fires on every write.
- Checks if database is "empty" AND if `.beads/issues.jsonl` has content; if both → migrates.
- Intended as one-time migration helper for users upgrading from pre-0.56 (`.beads/dolt/`) to 1.0+ (`.beads/embeddeddolt/`). See GH #2994 (per the file's comment block).
- Misfires for cities using `.beads/dolt/` (pre-0.56 path) because the new default `.beads/embeddeddolt/` is always empty. Migration never completes (times out), retriggers next call.

**Cities affected:**
- Any city created before bd 0.56, that upgraded bd to 1.0.4 while keeping its existing `.beads/dolt/` data dir. This includes the user's city AND likely many others (gc shipped before bd 0.56 was released).

**Local state going in:**
- bd is currently symlinked to 1.0.3 (the workaround). The city is operationally healthy.
- Bead `mc-mxl4vc` is OPEN with full root-cause notes.
- The fork remote at `study/gascity-src` exists (used for PR #2037). The user does NOT yet have a fork of `gastownhall/beads`.

---

## 2. What "done" looks like — three outcome paths

**Like Day-17, this is a branching investigation:**

| Branch | Outcome | Action | Time |
|---|---|---|---|
| **A** — duplicate issue already open | Comment with evidence (Day-12 pattern) | Cast wide net via `gh issue list --search`, find the existing thread, add complementary data point | ~45 min |
| **B** — no duplicate, fix shape clean | File issue + open PR (Day-11 pattern) | Use §24 playbook: fork, branch, fix, `make check`, PR | ~2.5 hours |
| **C** — no duplicate, fix shape unclear | File issue only, defer PR | Substantive bug report; let maintainer guide the fix shape | ~60 min |

**Day-12's "best-case negative" framing applies:** finding a duplicate isn't a setback — it's the upstream community already organizing around the right concern. Commenting consolidates the record.

**Success criteria for any branch:**
- The bug is visible to maintainers via the right thread.
- The diagnostic is preserved (root cause analysis, repro steps, workaround).
- The user's bead `mc-mxl4vc` tracks the upstream link.

**Stretch outcomes (Branch B only):**
- PR merges same day (PR #2037 cadence) → second worked example in §24.
- PR enters review → §24 gets a "review-iteration playbook" addition.
- PR is rejected → document the reasoning; the workaround stands.

---

## 3. Execution plan

### Step 1: Confirm regression still reproducible (~5 min)

The workaround is in place (bd → 1.0.3). Switch back to 1.0.4 momentarily, verify the regression, then revert.

```bash
ln -sf /usr/local/Cellar/beads/1.0.4/bin/bd /usr/local/bin/bd
bd --version    # should report 1.0.4
# Reproduce in a temp dir so we don't disturb the city:
TEMP=$(mktemp -d)
cd "$TEMP" && cp /Users/rfvitis/my-city/.beads/issues.jsonl .beads/issues.jsonl 2>/dev/null
# OR a simpler repro: create a fresh empty data dir + run bd create against it
mkdir -p .beads
echo '{"id":"test","title":"t","issue_type":"task"}' > .beads/issues.jsonl
(bd create test -t task --silent &
PID=$!
sleep 180
if kill -0 $PID 2>/dev/null; then echo "(hung, killing)"; kill -9 $PID; fi)

# Revert to working state
ln -sf /usr/local/Cellar/beads/1.0.3/bin/bd /usr/local/bin/bd
bd --version    # should report 1.0.3
cd - && rm -rf "$TEMP"
```

If the regression doesn't reproduce on bd 1.0.4 in a fresh dir, that's important data — might mean the bug is data-state-dependent (e.g., needs an existing-but-stale `.beads/dolt/`). Document and decide.

### Step 2: Duplicate search rigor (Day-12 pattern, ~15 min)

Cast a wide net before filing anything:

```bash
gh issue list --repo gastownhall/beads --search "auto-import empty" --state all --limit 10
gh issue list --repo gastownhall/beads --search "1.0.4 hangs" --state all --limit 10
gh issue list --repo gastownhall/beads --search "bd create timeout" --state all --limit 10
gh issue list --repo gastownhall/beads --search "auto_import_upgrade" --state all --limit 10
gh issue list --repo gastownhall/beads --search "embeddeddolt empty" --state all --limit 10
gh issue list --repo gastownhall/beads --search "GH#2994" --state all --limit 10
```

Per the Day-12 finding: filter `--state all` (closed issues with maintainer disposition are valuable signal too). If a query returns plausibly-related issues, **read them and their comments fully**.

Also check PRs:

```bash
gh pr list --repo gastownhall/beads --search "auto-import" --state all --limit 10
gh pr list --repo gastownhall/beads --search "1.0.4" --state all --limit 10
```

Also check the referenced issue from the bd source itself:

```bash
gh api repos/gastownhall/beads/issues/2994 --jq '{title, state, body: .body[0:500]}'
```

GH#2994 is the issue this code intends to solve. Reading that issue is essential context — the maintainers may have already discussed misfire cases.

### Step 3: Branch decision

Based on Step 2 outputs:

- **If a thread matches our exact symptom (`auto-importing X bytes... into empty database` repeated forever):** Branch A. Comment with our evidence (gc-managed dolt scenario, the symlink workaround, root-cause grep at file:line). Skip to Step 5.
- **If GH#2994 (or its PR) shows the auto-import was added recently and has known caveats but no fix:** Branch C. File a clean issue referencing #2994 with the gc-managed dolt as a new misfire case. Skip to Step 5.
- **If no matches and the fix shape is obvious:** Branch B. Continue to Step 4.

### Step 4: Branch B path — file PR (~90 min)

**4a. Fork + clone:**

```bash
gh repo fork gastownhall/beads --clone=true
cd beads
```

**4b. Reproduce in the fork's test env:**

```bash
make check 2>&1 | head -10    # baseline; this should pass
```

If `make check` fails out of the box, document and defer — we need a clean baseline.

**4c. Write the fix:**

The fix shape (per Day-19's root cause): in `cmd/bd/auto_import_upgrade.go::maybeAutoImportJSONL`, add a guard to skip auto-import when the user's data dir indicates a pre-0.56 install. Pseudocode:

```go
func maybeAutoImportJSONL(ctx, s, beadsDir) {
    // NEW: skip if the pre-0.56 data dir exists with content
    if isPreV056DataDirPopulated(beadsDir) {
        return // user is on the old path; don't migrate
    }
    // ... existing logic ...
}

func isPreV056DataDirPopulated(beadsDir string) bool {
    pre056Dir := filepath.Join(beadsDir, "dolt")  // the pre-0.56 path
    if info, err := os.Stat(pre056Dir); err == nil && info.IsDir() {
        // Check for actual dolt content (subdirs like __gc_probe, etc.)
        entries, _ := os.ReadDir(pre056Dir)
        return len(entries) > 0
    }
    return false
}
```

Plus a test that creates a `.beads/dolt/` populated dir, runs auto-import, and asserts no import happens.

**Alternative fix:** check whether the import has been *attempted* recently (sentinel file `.beads/.auto-import-failed`) and back off, regardless of data location. Less surgical but more defensive.

**4d. Run `make check`:**

```bash
make check 2>&1 | tail -20
```

If anything fails, fix before proceeding.

**4e. PR via §24 playbook:**

```bash
git checkout -b rjgeng/fix/auto-import-skip-pre-v056
# apply changes
git add ...
git commit -m "fix(import): skip auto-import when pre-0.56 .beads/dolt/ exists"
git push -u origin rjgeng/fix/auto-import-skip-pre-v056
gh pr create --repo gastownhall/beads --base main \
  --title "fix(import): skip auto-import when pre-0.56 data dir exists" \
  --body-file /tmp/pr-body.md
```

PR body must include:
- Symptom (`bd create timed out... auto-importing X bytes into empty database`)
- Repro (the empty-`.beads/embeddeddolt/` + populated-`.beads/dolt/` scenario)
- Root cause (which line of `auto_import_upgrade.go` misfires, citing GH#2994)
- Fix (the new guard function, explanation)
- Testing (`make check` clean; new test added)
- Discovery context (gc-managed city, surfaced via supervisor.log timeouts across 12 orders in 45 min)
- Workaround (the symlink approach, in case other users need to wait for the fix to land)

### Step 5: Update mc-mxl4vc + cross-link (~10 min)

Whichever branch:

```bash
bd update mc-mxl4vc --append-notes "Day-20: upstream engagement.

Branch: A / B / C (chosen).
Upstream link: <issue or PR URL>.

Next steps: <wait for review / wait for maintainer triage / workaround stands until release>."
```

If a PR ships, don't close mc-mxl4vc immediately — wait for the fix to merge AND be released. Closing prematurely loses the link.

### Step 6: v2 manual update (~20 min)

**§22 footnote on bd-version-compatibility** (one or two paragraphs):

> When `gc HEAD-caa44a4` (and likely subsequent HEAD builds) is installed via `brew install --HEAD gascity`, Homebrew transitively bumps bd to 1.0.4. bd 1.0.4 added auto-import-on-empty-database migration logic (`cmd/bd/auto_import_upgrade.go`, GH#2994) intended for pre-0.56 → 1.0+ upgrades. The logic misfires for cities using `.beads/dolt/` (pre-0.56 path) because the new default `.beads/embeddeddolt/` is always empty. Symptom: every `bd create`/`bd close` times out after 2 min with `auto-importing X bytes into empty database`. Workaround: pin bd to 1.0.3 via `ln -sf /usr/local/Cellar/beads/1.0.3/bin/bd /usr/local/bin/bd`. Upstream issue: <link from Step 5>. The bug surfaces yet another instance of the migration-as-recurring-bug-surface pattern (see also PR #2037, PR #1848). Day-20.

**§24 second worked example** (if Branch B and PR opens):

A short "Anatomy of mc-mxl4vc's PR" subsection, paralleling the existing "Anatomy of PR #2037" subsection. Cover the same axes: branch name, lines changed, time profile, discovery context.

**Meta-footnote: migration as recurring bug surface** (~10 lines):

Three of three city-discovered bugs are migration-related:
- PR #2037: dolt-state.json filename fallback (when controller didn't write the canonical file yet, scripts couldn't find it)
- PR #1848: jsonl-export SCRUB_FILTER column rename (`type` → `issue_type`, schema migration follow-up)
- mc-mxl4vc: bd 1.0.4 auto-import misfire on pre-0.56 data dir

Pattern: **operational stress + version-skew exposes migration-shaped bugs**. The diagnostics often have a similar shape (something's "empty" or "missing" because the code looks for the new thing while the data lives at the old thing). Worth promoting to a §22 sub-pattern for future days.

### Step 7: Commit + push (~10 min)

```bash
git add study/notes/2026-05-15-day20-mc-mxl4vc-upstream.md study/notes/gas_city_build_manual_practical_guide_v2.md
git commit -m "docs: Day-20 execution — mc-mxl4vc upstream <branch chosen>"
git push
```

If a PR landed (Branch B), reference its URL in the commit message.

### Step 8: Housekeeping (optional, ~10 min)

The renames + `.beads/config.yaml` modification noted Day-17/18 are still uncommitted in the working tree. They're the user's housekeeping; don't touch per the "don't change unrelated files" rule. But mention in Day-20 closure if they're still pending.

---

## 4. Hypotheses (G1-G5)

**G1: The regression IS still reproducible on bd 1.0.4 in a fresh test env.** Reasoning: the code path is unconditional. Predicted outcome: Step 1's bd-1.0.4 test hangs reliably.

**G2: A duplicate issue exists at `gastownhall/beads`.** This is a known pre-0.56 → 1.0+ migration helper, GH#2994 was the originating issue, and other operators must be hitting the same misfire. Predicted outcome: Step 2's `gh issue list --search "auto-import"` finds 1-3 plausible threads.

**G3: If G2 holds (duplicate found), the existing thread doesn't fully cover the gc-managed dolt scenario.** Most users encountering this are probably running bd standalone; the "gc has an existing dolt server on the same data dir" angle is distinctive. Predicted outcome: our evidence adds a data point, not redundant.

**G4: The fix is single-function-sized (~20-50 lines).** Adding the pre-0.56-data-dir check is a guard; doesn't require restructuring. Predicted outcome: Branch B's `make check`-clean PR ships in <2 hours.

**G5: sjarmak (or another maintainer) reviews quickly.** Reasoning: same maintainer org as gascity; PR #2037 was reviewed cleanly with no iterations. Predicted outcome: PR enters review state within 24h; possibly merges within 72h.

If G1-G5 all hold, **Day-20 ships PR #2 as the third upstream contribution.** §24 grows a second worked example. The "migration as recurring bug surface" sub-pattern enters §22.

If G2 holds but G3 falsifies (duplicate covers our case perfectly), comment + add the symlink-workaround data point. Still valuable; closes the city's bead.

---

## 5. Risk / blast radius

**Step 1 (reproducibility test):** zero risk — fresh tempdir, isolated. Reverting the symlink back to 1.0.3 is one command.

**Step 2 (duplicate search):** zero risk — read-only `gh` queries.

**Step 3 (branch decision):** zero risk — judgment call.

**Step 4 (PR, Branch B):** medium risk. Same profile as PR #2037 — small public-facing change. Specific risks:
- The fix might be incomplete (handle case X but not Y). Mitigation: write the test FIRST, prove the test reproduces the bug, then write the fix.
- The fix might conflict with concurrent work on the same file. Mitigation: Step 4b rebases against current main before pushing.
- Maintainer might prefer a different fix shape. Mitigation: the PR body should explicitly invite alternative approaches.

**Step 5 (bd update):** zero risk.

**Step 6 (manual update):** zero risk.

**Step 7 (commit + push):** zero risk standard.

**Rollback path:** if a PR introduces a problem, maintainer rolls it back; the user's city is unaffected (the symlink workaround stands until they choose to upgrade bd). Local-city impact is zero for all of this.

---

## 6. Connection to prior days

- **Day-11 / 12 (PR #2037 + #1487 comment):** Day-20 is the third upstream engagement. Day-11's playbook (§24) + Day-12's duplicate-search rigor combine here. The third application validates the pattern.
- **Day-13 (PR #2037 merged):** Day-20's hoped-for cadence — clean honest body, `make check` passes, maintainer responds quickly. PR #2037 took 32 hours of post-submit wait time; Day-20 might be similar.
- **Day-17 (mc-kh9qdv investigation):** the §22 falsification ritual fired again on Day-19; led directly to mc-mxl4vc. Day-17's three-branch decision template is reused as Day-20's structure.
- **Day-18 (gc binary upgrade, §27 validation):** the upgrade that exposed this regression. mc-mxl4vc is a direct downstream consequence of Day-18's actions. The §27 "embed-as-source-of-truth" finding extends to bd: bd is *also* a binary with its own embedded behavior; version-pinning matters as much as gc-version-pinning.
- **§22 (debugging pack scripts):** Day-20 extends the §22 pattern from "scripts" to "binaries you didn't even know existed in your stack." Worth a small framing note.
- **The retrospective's Day-N ladder:** predicted Day-19 = mc-f7u8fz PR; reality = bd 1.0.4 regression. The ladder's specific calls weren't perfect, but the meta-pattern (upstream contribution as a recurring shape) is real.

---

## 7. Adjacent work

Lightweight (any branch):

- **mc-f7u8fz status check:** while bd is on 1.0.3, the city's writes work again. The trace subsystem question (HEAD-caa44a4 doesn't auto-baseline trace; explicit arming required, but even armed didn't produce data Day-19) is still open. Worth a 5-min check: try `gc trace start` again with a longer arm window, see if new data accumulates.
- **The pending renames** in `study/notes/` (Day-17-noted): your housekeeping. Don't touch.

Soon (Day-21+):

- **Convoys tour** (6+ deferrals now). The retrospective's longest-overdue thread. Still on the board.
- **mc-uhvbb9** (refinery patrol hang from Day-8): still awaiting upstream #1487 reaction. No action.
- **The mc-f7u8fz mystery:** what was driving p50=129s under gc 1.1.0? Did HEAD fix it? Without trace observability, the answer is buried. A future day could dig into supervisor.log timestamp-mining as an alternative.

---

## 8. Optional: mayor handoff

Skip. Same reasoning as Days 14/15/17/18/19. Focused diagnostic + possible PR is the user's own muscle; mayor delegation doesn't add value for this shape of work.

The §24 playbook is now well-rehearsed enough that mayor could in principle execute a Branch B PR autonomously, but the user-as-operator wants to learn the rhythm, not delegate it.

---

## 9. Execution log

(filled in as work happens)

### Pre-flight (Step 1)

- bd 1.0.4 regression reproducible in fresh tempdir?
- Confirmation method:
- bd reverted to 1.0.3 after test?

### Duplicate search (Step 2)

- Issues matching keywords (count + IDs):
- PRs matching keywords (count + IDs):
- GH#2994 disposition (open/closed, summary):
- Most relevant existing thread:

### Branch decision

- Branch (A: comment / B: PR / C: issue only):
- Reasoning:

### If Branch A: comment

- Existing issue URL:
- Comment URL:
- Comment summary:

### If Branch B: PR

- Branch name:
- Lines changed:
- `make check` result:
- Test added:
- PR URL:
- Maintainer response (if any):

### If Branch C: issue only

- Issue URL:
- Issue summary:
- Open questions for maintainer:

### G1-G5 verdicts

- G1 (regression reproducible on 1.0.4):
- G2 (duplicate issue exists):
- G3 (our angle is distinctive):
- G4 (fix is ~20-50 lines):
- G5 (review within 24h):

### v2 manual update

- [ ] §22 footnote on bd-version-compatibility
- [ ] §24 second worked example (if Branch B PR opens)
- [ ] §22 meta-footnote: migration-as-recurring-bug-surface

### Surprises

(things this plan got wrong, or new things surfaced)

### Anything to promote

(filled in after the day)
