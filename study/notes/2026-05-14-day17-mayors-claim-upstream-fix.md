# Day 17 — investigate mayor's "upstream already carries the fix" claim

- **Plan authored:** 2026-05-13 (evening, after Day-16 closure)
- **Planned execution:** 2026-05-14 (Day-17)
- **Actual execution:** 2026-05-13 (evening — pushed straight through after the Day-16 wrap)
- **Status:** EXECUTED. Case B+ (pack staleness PLUS embed-vs-fs auto-revert) — bigger than expected. Bead `mc-2ntb2p` filed, submodule pointer advanced to upstream main HEAD, v2 manual §27 written as a standalone short section.
- **Provenance:** Day-16 mayor session reply (mc-wisp-vepr): *"Upstream (study/gascity-src) already carries the fix — submodule pointer bumped to 4819165 in the working tree, so nothing to do there."* But the local pack copy at `.gc/system/packs/maintenance/assets/scripts/jsonl-export.sh:485` STILL had the SCRUB_FILTER bug when mayor fixed it. Both facts can't be true. Day-17 falsifies.

This is a §22-pattern day: take mayor's claim, grep upstream, see which premise is wrong. Three terminal outcomes — one of them is "open a second upstream PR."

---

## 1. Pre-flight: the central contradiction

**The two competing facts:**

| Fact | Source | Implication if both true |
|---|---|---|
| Live pack copy at `.gc/system/packs/maintenance/assets/scripts/jsonl-export.sh:485` had `WHERE type NOT IN ...` (bug) | Mayor's session log + the failing mol-dog-jsonl 5/5 dispatch | Bug exists in the city's installed pack |
| Submodule at `study/gascity-src` @ `4819165` "carries the fix" | Mayor's mail reply to deacon (mc-wisp-vepr) | Same file at upstream has `WHERE issue_type NOT IN ...` |

If both are true, then **the local pack got out of sync with upstream**. That's a pack-refresh-path bug — high-value to fix.

If only the first is true (mayor was wrong about upstream), then **the column-name fix isn't actually upstream yet**. That's a one-line PR candidate — second upstream contribution.

**Three "upstreams" in play, often conflated:**

1. **HQ's recorded submodule pointer** (`b3dae6e`, per `git ls-tree HEAD study/gascity-src`). Older. The version HQ would clone if reset.
2. **Local submodule's working tree HEAD** (`4819165`, per `git -C study/gascity-src rev-parse HEAD`). The version Day-17 actually reads.
3. **Real upstream main** (`gastownhall/gascity` main branch on GitHub). The version the rest of the world sees.

Mayor was looking at #2. For the PR question we care about #3. The gap between #1 and #2 is the submodule pointer drift that's been "modified: study/gascity-src" in `git status` since Day-7.

**Known-relevant file paths:**

- City pack copy: `.gc/system/packs/maintenance/assets/scripts/jsonl-export.sh`
- Submodule copy: `study/gascity-src/examples/gastown/packs/maintenance/assets/scripts/jsonl-export.sh`
- Both are confirmed to exist (pre-research run).

---

## 2. What "done" looks like

**Falsification milestones:**

- Grep `study/gascity-src` @ `4819165` for the SCRUB_FILTER line. Either it has `type` (bug) or `issue_type` (fix).
- Grep `study/gascity-src` @ `b3dae6e` (HQ's recorded pointer) for the same. Tells us when the fix landed in the local submodule.
- Check `gastownhall/gascity` main on GitHub via `gh api`. Tells us what the real world sees.

**Decision milestones (one of three terminal cases):**

- **Case A — Mayor was wrong.** Upstream (#3 main) doesn't have the fix. → Open second upstream PR. Use §24 playbook. Fast — one-line fix, same shape as PR #2037.
- **Case B — Mayor was right; pack staleness.** Upstream (#3 main) has the fix, but the local pack copy in `.gc/system/packs/maintenance/` is stale. → The fix is "available" but didn't reach the pack-install path. Investigate the pack-refresh flow; file a bead, possibly PR.
- **Case C — Mayor was right; pack-refresh path bug.** Upstream has it AND the local pack-refresh code has a bug that prevents pulling the fix down. → Deeper investigation; potentially the biggest PR candidate of the three.

**Manual artifact:**

- v2 manual §22 footnote OR a new short §27 covering the three-upstreams framing and the pack-refresh-path findings. Defer the form until the diagnostic resolves.

**Adjacent housekeeping (sub-30-min, do alongside):**

- Reconcile the submodule pointer (`git submodule update`-style commit or accept the new pointer as HQ's view). The drift has been dirty since Day-7; if Day-17's investigation makes the right pointer obvious, also close this housekeeping debt in the same commit boundary.

---

## 3. Execution plan — step-by-step

Total budget: ~60-90 min for the diagnostic, +30 min if Case A unlocks a PR.

### Step 1: Grep the local submodule HEAD (~5 min)

```bash
cd /Users/rfvitis/my-city
SUB=study/gascity-src
FILE=examples/gastown/packs/maintenance/assets/scripts/jsonl-export.sh

# What does the working tree @ 4819165 say?
git -C "$SUB" show 4819165:"$FILE" | grep -nE 'SCRUB_FILTER|type NOT IN|issue_type NOT IN' | head -10

# Cross-check with the local file content (should match HEAD):
grep -nE 'SCRUB_FILTER|type NOT IN|issue_type NOT IN' "$SUB/$FILE" | head -10

# Show the git log for this file in the local submodule:
git -C "$SUB" log --oneline -- "$FILE" | head -20
```

**Interpretation:**
- If line 485ish has `issue_type` → fix IS in `4819165` → mayor was right about #2.
- If it still has `type` → fix is NOT in `4819165` → mayor was wrong; the pack copy and the submodule both have the bug.

### Step 2: Grep HQ's recorded pointer @ b3dae6e (~5 min)

```bash
git -C "$SUB" show b3dae6e:"$FILE" 2>&1 | grep -nE 'SCRUB_FILTER|type NOT IN|issue_type NOT IN' | head -10
```

**Interpretation:**
- If `b3dae6e` has the fix → the fix has been in HQ-tracked land for a while; the pack copy's bug means the local pack-install didn't pick it up.
- If `b3dae6e` has the bug → the fix landed between `b3dae6e` (HQ's pointer) and `4819165` (working tree). The local submodule was advanced forward at some point but HQ doesn't know.

### Step 3: Check real upstream main (~10 min)

```bash
# Find the file on the GitHub upstream main branch:
gh api 'repos/gastownhall/gascity/contents/examples/gastown/packs/maintenance/assets/scripts/jsonl-export.sh?ref=main' \
  --jq '.content' | base64 -d | grep -nE 'SCRUB_FILTER|type NOT IN|issue_type NOT IN' | head -10

# Or simpler — show the file directly via raw URL:
gh api 'repos/gastownhall/gascity/git/trees/main?recursive=1' \
  --jq '.tree[] | select(.path | endswith("jsonl-export.sh")) | .path'
# Then for each path:
gh api 'repos/gastownhall/gascity/contents/<path>?ref=main' --jq '.content' | base64 -d | grep -nE 'SCRUB_FILTER|issue_type'
```

**Interpretation:** This is the *real* upstream. The decision tree branches here:

- **If upstream main has `type` (bug):** Case A. Open second PR. The fix is one-line. Proceed to Step 5.
- **If upstream main has `issue_type` (fix):** Case B or C. The fix is upstream but didn't propagate to the local pack copy. Proceed to Step 4.

### Step 4: Trace the pack-refresh path (~20 min, only if Case B/C)

How does the city's `.gc/system/packs/maintenance/` get its content?

```bash
# Look at how pack imports work in the city
grep -rn 'imports\|pack.gastown\|maintenance' city.toml
ls .gc/system/packs/maintenance/.pack-meta* 2>/dev/null  # any metadata file?
gc pack --help 2>&1 | head -25
gc import --help 2>&1 | head -25
```

Read `study/gascity-src/internal/pack/` or wherever the pack-install logic lives. Look for:
- Where the city decides which version of a pack to install.
- Whether `gc pack refresh` is a real command and what it does.
- Whether there's a known issue tracker for pack-version-pinning.

**Decision branch:**

- If pack install is "copy from `study/gascity-src` at HEAD" and HEAD is `4819165` → why doesn't the copy match? Possibly the city's `.gc/system/packs/` was populated at an older commit and never refreshed. Manual fix: `rm -rf .gc/system/packs/maintenance && gc import gastown` (or equivalent). Case B.
- If pack install is by-pinned-version and the pin is older than the fix → fix isn't *available* to install. Case B, with a path forward (advance the pin).
- If pack install SHOULD have picked up the fix but didn't → pack-refresh bug. Case C, possibly a real upstream contribution.

### Step 5: Decide on PR (~10 min if Case A, longer if Case C)

**Case A (fix isn't upstream): open PR #2.** Skeleton:

```bash
cd study/gascity-src
git checkout -b rjgeng/fix/jsonl-export-column-name-issue_type
# Apply the same one-line edit at examples/gastown/packs/maintenance/assets/scripts/jsonl-export.sh
git add ...
git commit -m "fix(packs): jsonl-export SCRUB_FILTER uses issue_type column (was type)"

# Run the test gate
make check

# Push to fork + open PR via §24 playbook
gh pr create --repo gastownhall/gascity --base main \
  --title "fix(packs): jsonl-export SCRUB_FILTER column name (type → issue_type)" \
  --body-file /tmp/pr-body.md
```

PR body should follow §24's honesty pattern. Include:
- Symptom: mol-dog-jsonl fails 5/5 with the SQL error.
- Root cause: column was renamed `type` → `issue_type` at some point in the schema; the SCRUB_FILTER WHERE clause wasn't updated.
- Fix: one-line change.
- Testing: `make check` passes; live script run reports `exported 5/5`.
- Discovery: surfaced via mayor's autonomous escalation response on Day-16; documented in v2 manual §26.

**Case B (pack staleness):** file a bead with the diagnostic, possibly fix manually via pack refresh, then file an upstream issue (NOT a PR) about pack-install version pinning.

**Case C (pack-refresh bug):** file a bead with full reproduction steps. Don't try to PR-fix the pack-refresh path on Day-17 — that's a deeper diagnostic for a future day.

### Step 6: Submodule pointer reconcile (~5 min)

Whichever case lands, the local submodule pointer is currently ahead of HQ's record. Decide:

- If `4819165` is what HQ should track (e.g., it's now post-PR #2037's merge plus any other beneficial fixes), commit the bump:
  ```bash
  cd /Users/rfvitis/my-city
  git add study/gascity-src
  git commit -m "submodule: bump study/gascity-src to 4819165 (post-PR #2037 + adjacent)"
  ```
- If the working tree was rebased to a commit that isn't on real upstream (e.g., a local branch that shouldn't be HQ-tracked), reset the submodule:
  ```bash
  git -C study/gascity-src checkout main
  git -C study/gascity-src pull origin main
  ```

Step 1's `git log -- jsonl-export.sh` output will tell us which fork the `4819165` belongs to. If it's clean upstream main, accept it; if it's a local rebase branch with non-upstream commits, reset.

### Step 7: Document + commit + push (~15 min)

Update v2 manual with the findings:

- If Case A → §24 gets a second worked-example PR added (mentioning Day-16's discovery path).
- If Case B → §22 footnote: "pack-refresh path can stale-copy upstream fixes; verify with `git -C study/gascity-src show HEAD:<file>` before assuming the live pack is current."
- If Case C → new §27 candidate: "Pack-refresh path internals." Defer to a longer day if needed.

Single commit covers:
- Submodule pointer reconcile (Step 6).
- Manual update (above).
- Day-17 execution log fill.

If a PR landed (Case A), reference its URL in the commit message.

---

## 4. Hypotheses (G1-G5)

**G1: The fix IS at `4819165` (mayor was right about #2).** Reasoning: mayor checked git history before claiming this, and mayor's diagnostic accuracy on Day-16 was high. Predicted outcome: Step 1's grep returns `issue_type`.

**G2: The fix is NOT yet on upstream main (Case A).** Reasoning: this is a tiny, unannounced one-line fix; the user's PR #2037 was about a different bug. There's no reason for it to have been independently fixed upstream in the last 24 hours. Predicted outcome: Step 3's `gh api` shows `type`.

**G3: The local submodule's `4819165` is on the user's own fix-branch (`rjgeng/fix/dolt-pack-script-state-fallback` or similar) and was advanced beyond HQ's `b3dae6e` during PR #2037 work.** Reasoning: PR #2037's merge commit was `e1cee04`; the local working tree is at `4819165`, which doesn't match `e1cee04`. So either (a) the local branch contains MORE than upstream, OR (b) the local branch is missing the upstream merge. Predicted outcome: Step 1's `git log` shows local commits not on upstream.

**G4: If G1 + G2 hold (Case A), the second PR ships in <90 min.** Reasoning: same workflow as PR #2037; same maintainer (sjarmak) who merged #2037 with no review iterations; clean honesty pattern in body; passes `make check` because the change is shell-only. Predicted outcome: PR opens and either auto-merges or gets approved within the session.

**G5: The submodule drift is benign** — `4819165` is a clean working state that should just be promoted to HQ's pointer. Reasoning: the working tree has been stable since Day-7 (no further commits), and PR #2037's merge happened post-`4819165`, so `4819165` is from before merge. Predicted outcome: Step 6's reconcile is a straight bump.

If G1-G5 all hold, Day-17's terminal output is: **PR #2 opened, submodule reconciled, §24 gets a second worked example, v2 manual now references two real upstream contributions.**

If G1 falsifies (mayor was wrong, fix isn't in `4819165`), the day pivots to: investigate where mayor's "fix" actually came from. Either the local working tree has uncommitted edits (visible in `git -C study/gascity-src status`) or mayor's claim was confabulation. Both are interesting findings.

---

## 5. Risk / blast radius

**Steps 1-3 (greps + gh api):** zero risk. Read-only.

**Step 4 (pack-refresh investigation):** read-only. Reading pack-install code in `study/gascity-src/internal/pack/`.

**Step 5 (PR #2):** medium risk. Pushing to a public PR. Same risk profile as PR #2037 — but the user now has the muscle. The honest body should explicitly state the discovery context (Day-16 mayor escalation), in keeping with §24's transparency norm.

**Step 6 (submodule reconcile):** the only mutation. Two sub-risks:
- If we bump HQ's pointer to a local fix-branch commit that isn't on upstream main, future `git submodule update` operations will diverge. Mitigation: Step 1's `git log` reveals branch lineage before the bump.
- If we reset the submodule to upstream main, any uncommitted local edits in the submodule working tree get lost. Mitigation: `git -C study/gascity-src status` first; if dirty, decide before resetting.

**Step 7 (commit + push):** zero risk if standard.

**Rollback path:** if PR #2 goes badly, close the PR and document. If submodule reconcile makes the city unhealthy, `git -C study/gascity-src checkout 4819165` restores the prior state; HQ commit can be reverted.

---

## 6. Connection to prior days

- **Day-6 / 7 (PR #2037 origin):** Day-7 was the first §22 falsification day — the bead's premise (dolt-state.json is legacy) was inverted. Day-17 extends the same pattern but to mayor's claim instead of a bead's premise. Same instinct, different target.
- **Day-11 / 12 (PR #2037 ship + #1487 comment):** Day-11 was the first upstream-engagement day. Day-17's potential PR #2 is the natural follow-on; the playbook now exists in §24.
- **Day-16 (mayor's autonomous fix):** the immediate provenance. Day-17 investigates a claim mayor made yesterday.
- **§22 (debugging pack scripts):** Day-17 generalizes §22 to "debugging the pack itself" — same falsification rhythm, different layer.
- **§24 (upstreaming playbook):** if Case A → §24 gets its second worked example.
- **The retrospective's Day-30 promise:** "Step 1.5 deserves promotion to Step 1" — Day-17 is yet another fix-day where Step 1.5 (grep upstream) is load-bearing.

---

## 7. Adjacent work

Lightweight today-actions:

- **Daily check on PR #2037 + comment on #1487 status.** Per Day-11 §4 Step 3. (PR #2037 merged Day-13; the daily check is closed. Just observe.)
- **Submodule pointer reconcile** — Step 6 of this plan.

Soon (Day-18+):

- **mc-uhvbb9 (refinery patrol hang)** — still awaiting reaction on #1487. If a maintainer responds, that thread reopens.
- **mc-f7u8fz (reconciler 27s p50 no-op tick)** — still the biggest remaining technical finding. If Day-17's PR #2 lands cleanly, the user has fresh muscle for this bigger contribution.
- **Convoys tour** — 4th deferral now. Still on the board.
- **events.jsonl silent-failure sweep** — digest-generate was found incidentally Day-13; a deliberate sweep would surface more. ~30 min exercise.

---

## 8. Optional: mayor handoff

Skip. This is a focused diagnostic + possible PR. Mayor orchestration would add overhead for a 60-90 min surgical day. The §22-pattern falsification is the user's own muscle, not something to delegate.

(Day-17 is also a fix-it day, not an experiment day. The mayor escalation that surfaced the bug yesterday is already resolved. The diagnostic now is about the PR-shape, not about agent behavior.)

---

## 9. Execution log

(filled in as work happens)

### Pre-flight outcomes

- **Local submodule HEAD (`4819165`) — fix present?** YES (line 485 `WHERE issue_type NOT IN ...`). Git log shows `bd69a607 fix(maintenance): use issue_type column in jsonl-export SCRUB_FILTER (#1848)` in lineage.
- **HQ's recorded pointer (`b3dae6e`) — fix present?** NO (line 485 `WHERE type NOT IN ...`). `git merge-base --is-ancestor bd69a607 b3dae6e` returned NO.
- **Upstream `gastownhall/gascity` main — fix present?** YES (line 637 in the refactored file — `WHERE issue_type NOT IN ...`). PR #1848 merged by sjarmak as commit `bd69a607`.
- **Git log lineage of `4819165` vs upstream main:** `4819165` (the user's PR #2037 commit, `48191657`) is `ahead_by:1, behind_by:130, status:diverged` relative to upstream main (`caa44a40`). Real main HEAD has advanced 130 commits since the user's last branch tip.

### Case determination

- **Case selected: B+ (pack staleness, with a deeper finding underneath).** Upstream has the fix; local submodule has the fix; city's pack copy does not. Investigation went further than Case B's "just refresh the pack manually" — empirical test showed manual refreshes are **automatically reverted** by gc's pack-integrity reconciliation. The reconciliation source is the gc binary's `//go:embed packs/**`. So Case B's classical "pack staleness" doesn't apply — the .gc/system/packs/ directory is not stale relative to its source; it's correctly synced to the BINARY's embed, which itself predates PR #1848.
- **Reasoning:** Day-17 Step 1 confirmed mayor's claim about #2 (local submodule has fix). Step 2/3 confirmed upstream has fix. Step 4 (originally for pack-refresh investigation) escalated to a `cp -rf` experiment that surfaced the auto-revert pattern. Step 5's PR opportunity is gone (PR #1848 already exists). Final framing: this is **case "B+" = pack-refresh is by-design ephemeral, gc binary embed is the runtime source of truth**.

### If Case A: PR #2 outcome

N/A — sjarmak's PR #1848 beat us to the column-name fix.

### If Case B/C: bead filed

- **Bead ID:** `mc-2ntb2p` ("Pack staleness + mayor confabulation: city maintenance/ pack drifted from submodule, SCRUB_FILTER bug still active despite mayor's claimed fix").
- **Priority:** P2
- **Labels:** config, pack-refresh, mayor-confabulation
- **Status:** OPEN
- **Next-step plan:** wait for gc binary upgrade (Homebrew formula bump OR build from source); the SCRUB_FILTER bug will continue firing every 15 min until then. Bead also flags the embed-vs-fs pattern as upstream-issue-worthy if gc maintainers consider it a UX gap.

### Submodule reconcile

- **Approach:** fetch upstream main + advance submodule to upstream HEAD (`caa44a40`).
- **Reasoning:** the working tree at `4819165` was the user's old PR #2037 branch tip, diverged from main by 130 commits. Tracking real upstream main is more idiomatic + gives the submodule a clean reference baseline that includes PR #1848 et al. The submodule is reference-only (per §27 — not a runtime input), so advancing it doesn't break anything in the city.
- **Commit hash:** included in the Day-17 commit (this one).

### G1-G5 verdicts

- **G1 (`4819165` has the fix):** TRUE. mayor's claim was accurate about the local working tree.
- **G2 (upstream main does NOT have the fix):** FALSE. Upstream DOES have the fix (PR #1848 by sjarmak, commit bd69a607). No PR #2 opportunity for this bug.
- **G3 (`4819165` includes local-only commits):** TRUE — `48191657` is the user's PR-2037 branch tip, ahead_by:1 vs main (the pre-squash-merge commit).
- **G4 (Case A PR ships <90 min):** N/A — Case A is out.
- **G5 (submodule drift is benign — straight bump):** TRUE for the submodule reconcile, but the larger finding is that submodule advancement doesn't help the city's runtime. The drift was benign because the submodule is reference-only.

### v2 manual update

- [ ] §24 worked example #2 (N/A — Case A didn't apply)
- [ ] §22 footnote on pack-staleness (folded into §27 instead)
- [x] **§27 written: "Pack content in the gc binary: embed vs filesystem reconciliation"** (~50 lines). Establishes the embed-vs-fs mental model, the diagnostic procedure, and when the pattern fires vs not.
- [x] §26 revised: mayor's Day-16 "fix" reframed from "confabulation" to "true-at-the-moment fact that was about to become false." More precise.

### Surprises

- **The PR #2 opportunity was already taken by sjarmak (PR #1848).** Day-17's predicted G2 (upstream doesn't have the fix) was wrong. The actual finding was deeper and more interesting than another one-line PR would have been.
- **`gc import upgrade` doesn't work on path imports.** `gc import upgrade gastown` returned "import 'gastown' is a path import and cannot be upgraded." The path-import mechanism is unidirectional — the city installs once, then auto-reverts from binary embed. No constraint-based refresh exists.
- **Manual `cp -rf` lasts ~3 minutes.** The empirical test fully nailed down the auto-revert mechanism. After cp: FIX in place, file size 24553. After `gc order run`: BUG back, file size 24167. Same mtime preserved (which initially made it look like the file wasn't touched, but the size diff is conclusive).
- **gc binary 1.1.0 was installed `May 7 22:31`** (city init day). The binary's embed dates from before PR #1848 (which merged "months ago" per upstream history). All maintenance-pack fixes that merged in those 130 commits are inaccessible to this city until the gc binary is upgraded.
- **The submodule's `4819165` is the user's own PR #2037 branch tip.** Originally was at `b3dae6e` (HQ's recorded pointer) at city-init; got advanced to `4819165` during PR #2037 work. The submodule has been on a personal fix-branch the entire time. Real upstream main has moved 130 commits past it.

### Anything to promote

- **§22 sub-pattern "Step 1.5b — falsify the FIX's premises":** now has a third worked example. Day-14 surfaced the pattern; Day-15 paid off; Day-17 extended it from "verify the fix doesn't have side effects" to "verify the fix actually reaches the runtime." The retrospective's call to promote this to permanent §22 tooling becomes more urgent.
- **The retrospective's "events.jsonl is an underused observability surface"** got another data point — Day-17's diagnostic relied heavily on cross-referencing events.jsonl (DOG_DONE messages) with dolt-server.log (SQL errors). Both surfaces were needed; neither alone tells the story.
- **Pack-binary-version-drift as an upstream discussion candidate.** Whether gc should auto-detect or surface "your installed binary embeds an old pack version" is a real ergonomic question. Could be the next upstream contribution (discussion or feature request, not a fix PR).
- **The "mayor's fact was true at the moment" framing.** Worth promoting from §26 into a general note about agent reporting reliability: an agent's report is a *snapshot*, not a guarantee of persistence. For pack-managed code paths, the snapshot can become false within minutes. Future Days investigating agent autonomy should bake this in.
