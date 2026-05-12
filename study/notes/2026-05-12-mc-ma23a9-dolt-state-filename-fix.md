# Day 7 — Fix `mc-ma23a9`: legacy `dolt-state.json` filename hardcoded in two pack scripts

- **Plan authored:** 2026-05-12 (after day 6 wrap)
- **Planned execution:** 2026-05-12 (continuation) or 2026-05-13
- **Status:** Plan only; fix not yet started

This is the pre-decomposition for Day-7: shift from three consecutive diagnostic days (Day-4 demo + S-list, Day-5 JSONL triage, Day-6 reconciler perf) into a single fix-and-verify exercise. Target is the lowest-friction open bead: `mc-ma23a9`, filed during Day-5 triage. Same exercise pattern as before — write the plan first, then compare actuals.

---

## 1. The signal — what `mc-ma23a9` is

Two pack scripts hardcode the legacy state filename `dolt-state.json` instead of the canonical `dolt-provider-state.json`:

- `.gc/system/packs/maintenance/assets/scripts/dolt-target.sh:146`
- `.gc/system/packs/dolt/assets/scripts/runtime.sh:29`

The canonical name is owned by the `bd` pack at `.gc/system/packs/bd/assets/scripts/gc-beads-bd.sh:2482`, and resolvable at runtime via `gc dolt-state runtime-layout` → `GC_DOLT_STATE_FILE`.

**Failure mode** (per Day-5 surprises §10 #4): `dolt-target.sh` looks up the legacy name, doesn't find the file, falls back to default port `3307`. If the running dolt server is on an ephemeral port (default behavior with the `bd` pack), every dolt query from the `maintenance` pack fails silently because callers like `jsonl-export.sh:526` swallow stderr with `2>/dev/null`. Day-5's JSONL triage hit this; worked around with `GC_DOLT_PORT=50095` in test runs.

**Why this is the right Day-7 target:**

- Bead already drafted with two fix options — the decision work is already done, just need to apply.
- Two-line change per script. Smallest possible diff.
- Validates the **cross-pack config name conventions** principle promoted to v2 manual §22 — applying our own writeup.
- Touches pack-script territory (shell), not Go internals — different surface area from Days 4-6.
- Verification is concrete and visible: `mol-dog-jsonl` either falls back to 3307 (broken) or finds the right port (fixed).

---

## 2. Pre-flight: where this lives

- The two scripts live under `.gc/system/packs/` which is **gitignored locally** (Day-5 finding promoted to §21). So local edits won't survive a `gc doctor --fix` or pack reinstall — they are *validation-grade*, not persistent.
- The source-of-truth for those pack scripts lives in the `gascity-src` submodule. Likely paths:
  - `study/gascity-src/packs/maintenance/assets/scripts/dolt-target.sh`
  - `study/gascity-src/packs/dolt/assets/scripts/runtime.sh`
  - To be confirmed in Step 1.
- City is currently stopped (Day-6 left it that way). Dolt is also stopped now (we restarted it briefly during Day-6 bead operations, then it kept running; verify state at start of Day-7).
- The fix needs to be testable without a fully-running city. `mol-dog-jsonl` (the workflow that hit the failure on Day-5) runs as an order on a schedule; we may need to either invoke it directly or wait for a scheduled tick.

---

## 3. What "fixed" looks like (success criteria)

- Both scripts updated to use the canonical filename or, preferred, a resolver-based lookup.
- Reproduction case from Day-5 no longer triggers the fallback-to-3307 path: `mol-dog-jsonl` (or a manual equivalent) finds the dolt server on the actual ephemeral port without `GC_DOLT_PORT` override.
- Verification with **explicit stderr unmasked** (the §22 silent-failure technique): re-run the underlying operation by hand and watch for the success path.
- Decision recorded: local-only (validation), upstream patch staged, or upstream PR opened. Plus rationale.
- Bead `mc-ma23a9` updated with the outcome — closed if upstream PR opened, kept open with a clear next-step note otherwise.

**Pre-decision: option 2 (resolver-based) over option 1 (rename).**
Option 1 (rename hardcoded constant) is two characters per script and trivially correct, but it bakes the *new* name in just as brittlely as the old. Option 2 (`gc dolt-state runtime-layout`) embodies the cross-pack contract principle from §22 and is the durable choice. Cost difference: ~3 lines of shell vs ~1 line. Worth it.

Falsification check during Step 2: confirm `gc dolt-state runtime-layout` is callable from a shell-script context (no TTY assumed, no controller required). If it requires the controller to be running, fall back to option 1.

---

## 4. Execution plan — read, then patch, then verify

### Step 1: Read the two scripts and the resolver (~15 min, free)

- `cat .gc/system/packs/maintenance/assets/scripts/dolt-target.sh | sed -n '130,170p'` — see the hardcoded constant in context, identify what the surrounding logic does with the resolved path.
- `cat .gc/system/packs/dolt/assets/scripts/runtime.sh | sed -n '15,45p'` — same for the dolt pack.
- `gc dolt-state --help` and `gc dolt-state runtime-layout` — confirm the resolver's output format and whether it requires the controller.
- Locate the source-of-truth files in `study/gascity-src/packs/...` — needed for the upstream patch.

Output: a 1-paragraph summary of the surrounding logic in each script + confirmation that the resolver is shell-callable.

### Step 2: Falsify the resolver-availability assumption (~5 min)

```bash
# Does the resolver work when the controller is stopped?
gc status                                  # confirm controller state
gc dolt-state runtime-layout               # try without controller
gc dolt-state runtime-layout | grep STATE_FILE
```

If output is empty or errors → option 2 is not viable, fall back to option 1.

### Step 3: Patch locally first (~10 min)

Edit both `.gc/system/packs/...` scripts to use the resolver. Keep the change minimal — one line of resolution, one line of variable use. Example shape (to be refined against actual surrounding code):

```bash
# Before:
STATE_FILE="$CITY/.gc/runtime/packs/dolt/dolt-state.json"

# After:
STATE_FILE=$(gc dolt-state runtime-layout | awk '/GC_DOLT_STATE_FILE/ {print $2}')
```

Watch for context-specific details: the script may already export `STATE_FILE` from elsewhere, may have a default fallback, may run in a `set -u` context where `gc` not being on PATH would crash.

### Step 4: Verify the fix triggers the success path (~10 min)

- Re-run the underlying operation manually with stderr UNMASKED (§22 technique). The actual `mol-dog-jsonl` invocation is gated behind an order, but its core operation should be runnable directly. Find the entry point in the dolt or maintenance pack, run it with `2>&1` instead of `2>/dev/null`.
- Confirm: it reads the canonical state file path, finds the actual ephemeral port (not 3307), connects successfully.
- If the test surface needs the controller running: `gc start`, run the test, `gc stop`. Same risk profile as Day-6 §6.

### Step 5: Stage the upstream patch (~10 min)

- Apply the same two edits to `study/gascity-src/packs/.../dolt-target.sh` and `study/gascity-src/packs/.../runtime.sh`.
- Run any submodule-side tests if there's a quick way to validate (`go vet`, lint, the relevant `*_test.go` if scripts have test harnesses).
- Commit on a feature branch in the submodule — **do not push or open PR yet** unless explicitly authorized. Just stage the change locally.

### Step 6: Decide on PR (~5 min, decision-only)

Three end states for the bead:

- **Close + upstream PR opened**: highest-effort, only if we're ready to engage upstream review.
- **Close + upstream patch staged locally on a branch**: middle path — fix is durable in our submodule, future-us can push when ready.
- **Keep open with progress note**: validate-only run; local hot-patch in place, upstream not yet touched.

Default for Day-7: middle path. Don't open upstream PRs from a learning exercise without explicit sign-off; do leave a clean branch so the work isn't lost.

---

## 5. Fix patterns pre-thought (decisions ready before code)

**On the resolver vs rename choice:** picked resolver in §3. If Step 2 falsifies resolver availability, fall back to rename + a comment block above the constant pointing to `gc dolt-state runtime-layout` for future re-fix-ability.

**On error handling at the boundary:** the §22 cross-pack principle implies the script should fail loudly if the resolver doesn't return what's expected, not silently fall through to a default. Suggested pattern:

```bash
STATE_FILE=$(gc dolt-state runtime-layout 2>&1 | awk '/GC_DOLT_STATE_FILE/ {print $2}')
if [[ -z "$STATE_FILE" || ! -f "$STATE_FILE" ]]; then
  echo "fatal: dolt-state resolver returned empty or missing path: $STATE_FILE" >&2
  exit 1
fi
```

But: pack scripts run under a supervisor that aggregates stderr; loud errors there land in supervisor logs and can themselves cause noise. Calibrate based on what Step 1 reveals about the surrounding context.

**On test coverage:** if the upstream submodule has `*_test.sh` or shell-test harnesses for these scripts, run them. If not, the verification in Step 4 is the test.

---

## 6. Risk / blast radius

- **Local-only edit in `.gc/system/packs/`:** zero risk — gitignored, doesn't affect any other city, reversible by `gc doctor --fix` or pack reinstall. Validation-grade only.
- **Upstream edit in `study/gascity-src/packs/`:** moderate risk — it's the source-of-truth, but the submodule is unpinned/local and we're not pushing without explicit sign-off. Reversible via `git checkout`.
- **`gc start` for live verification:** same profile as Day-6 §6 — restarts the full agent ecosystem, reversible via `gc stop`. Optional, only if Step 4's offline test is insufficient.
- **The fix could break workflows that still expect the legacy filename.** Mitigation: grep `study/gascity-src/` for `dolt-state.json` (legacy) before patching — if anything else reads it, the fix is incomplete. **Make this Step 1.5.**

---

## 7. Connection to prior days

- **Day-3 (A/B):** unrelated.
- **Day-4 (mayor-led auth demo):** S3 surfaced the JSONL push storm, which Day-5 traced and which incidentally exposed this `dolt-state.json` filename inconsistency.
- **Day-5 (JSONL triage):** filed `mc-ma23a9`, deferred the fix because it requires upstreaming. Promoted §22 "cross-pack config name conventions" to v2 manual.
- **Day-6 (reconciler perf):** found a separate but related issue (cycle latency); also confirmed `.gc/system/packs/` is gitignored. Both Day-5 and Day-6 framed the local-vs-upstream question, which Day-7 actually answers by staging an upstream change.
- **The hop pattern:** observe (Day-4) → diagnose (Days 5 & 6) → fix (Day-7). First closure of the loop.

---

## 8. Adjacent work to fold in while on Day-7

Lightweight items, none dependent on the fix:

- **S5 investigation (deferred from Day-4):** "Refinery doesn't auto-discover work that lacks `merged_commit` metadata." If Day-7's fix work goes fast, S5 is a meaty diagnostic next item — same shape as Day-6 (read code, query trace data, characterize behavior).
- **Step 2-live from Day-6 plan:** start city briefly, confirm cycle duration profile is unchanged post-Day-5. Cheap, validates Day-6's diagnosis under live conditions.
- **File the "slow_storage_degraded message is misleading" bead** (Day-6 §11 candidate #3). One-line cosmetic upstream bead — could be batched with the mc-ma23a9 upstream patch into a single "small fixes" branch.
- **Ack `mc-n333b`** "ack daily-verbs page" — looks like a learning checkbox from Day-3 still open. Trivial.

If Day-7's primary fix lands in under an hour, do at least S5 — it's the last unaddressed Day-4 S-item that's a real behavioral question rather than a one-off.

---

## 9. Optional: mayor handoff

Skip. Reasons (same shape as Day-6):

- Single-engineer fix-and-verify exercise; mayor-led orchestration would add ceremony without value.
- The fix is a 2-line shell edit per script — too small for decomposition into multiple beads.
- Scripts are gitignored locally; mayor's polecat-via-formula path doesn't have a clean way to edit gitignored files anyway.

---

## 10. Execution log

### Steps run

| Step | Time | Finding |
|---|---|---|
| 1 — read scripts in context | 2026-05-12 | Both scripts already honor `GC_DOLT_STATE_FILE` env override — hardcoded `dolt-state.json` is only the fallback. Premise of bead (rename hardcoded constant) is incomplete: env-injection is the primary path. |
| 1.5 — grep upstream for legacy name | 2026-05-12 | **Premise inverted.** `dolt-state.json` is canonical in 20+ upstream Go files including `cmd/gc/beads_provider_lifecycle.go:864` ("The only managed-local authority is `.gc/runtime/packs/dolt/dolt-state.json`"). Written by `publishManagedDoltRuntimeState`. `dolt-provider-state.json` is what the bd pack writes (`gc-beads-bd.sh:2482`). Renaming the hardcoded constant would have **broken** the controller-managed Go path. |
| 2 — falsify resolver availability | 2026-05-12 | `gc dolt-state runtime-layout` returns **empty output** when controller is stopped. Option 2 (resolver-based) is **not viable** as planned. The real wire-up is `providerLifecycleDoltPathEnv` at `lifecycle.go:1381-1393` setting `GC_DOLT_STATE_FILE` env when the controller invokes pack scripts. |
| 2.5 — find the actual upstream design | 2026-05-12 | Smoking-gun commit `921cb292`: "fix: recover dolt-state.json from stale or missing provider state". Two files by design: bd pack writes `dolt-provider-state.json`, controller publishes `dolt-state.json` as canonical authority by reading provider-state + port-probe verification. JSON shape is compatible — both have `running, pid, port, data_dir, started_at`. |
| 3 — design real fix | 2026-05-12 | **Secondary-fallback pattern** instead of either Option 1 or Option 2 from the original plan. Order: `GC_DOLT_STATE_FILE` env → `dolt-state.json` (canonical) → `dolt-provider-state.json` (bd-pack) → legacy default. Preserves both lifecycle paths. |
| 4 — patch locally | 2026-05-12 | Applied to `.gc/system/packs/maintenance/.../dolt-target.sh:145-158` and `.gc/system/packs/dolt/.../runtime.sh:29-37`. Parallel if-elif-elif-else chains. |
| 5 — verify live | 2026-05-12 | Setup: `dolt-state.json` absent, wrote fresh `dolt-provider-state.json` matching the running dolt server (pid=32053, port=50213, running=true). Sourced `dolt-target.sh` in a clean shell with no env. Result: `DOLT_STATE_FILE=…/dolt-provider-state.json`, `GC_DOLT_PORT=50213`. `dolt_sql -q "SHOW DATABASES;"` returned the actual rig databases (auth, cs, hq, hw, ship). **Fix proven end-to-end.** |
| 6 — stage upstream | 2026-05-12 | Both upstream files in `study/gascity-src/examples/` were byte-identical to local. Applied parallel patch. Created branch `rjgeng/fix/dolt-pack-script-state-fallback` (submodule was in detached HEAD; needed branch first). Commit `291b37c2`. **Not pushed; awaiting explicit sign-off.** |
| 7 — close bead | 2026-05-12 | `mc-ma23a9` closed with a comprehensive close reason capturing the inverted premise and the actual fix. |

### Decision actually taken

- **Resolver vs rename:** Neither. The original two options were both wrong because the bead's premise was inverted. Picked **secondary-fallback** instead — preserves both the controller-managed path (uses `dolt-state.json` when present) and the standalone-bd path (uses `dolt-provider-state.json` when only that exists).
- **Local-only vs upstream-staged vs upstream-PR:** Middle path per plan §4 Step 6. Local applied, upstream staged on branch, not pushed.
- **Rationale:** End-to-end verified locally; the upstream branch is durable and ready when the user is ready to engage upstream review.

### Files changed

- **Local** (`.gc/system/packs/`):
  - `maintenance/assets/scripts/dolt-target.sh` lines 145-158
  - `dolt/assets/scripts/runtime.sh` lines 29-37
  - Both gitignored locally; will be reset on `gc doctor --fix` or pack reinstall.
- **Upstream** (`study/gascity-src/examples/`):
  - `gastown/packs/maintenance/assets/scripts/dolt-target.sh`
  - `dolt/assets/scripts/runtime.sh`
  - Committed on branch `rjgeng/fix/dolt-pack-script-state-fallback` (commit `291b37c2`).

### Verification

- **Day-5 reproduction case re-run:** `dolt-state.json` absent + fresh `dolt-provider-state.json` with running dolt on port 50213.
- **Outcome before fix:** `DOLT_STATE_FILE` resolves to non-existent `dolt-state.json` → `managed_runtime_port` returns empty → falls back to port 3307 → connection fails (Day-5 symptom).
- **Outcome after fix:** `DOLT_STATE_FILE` falls through to `dolt-provider-state.json` → reads port 50213 → `dolt_sql` connects → `SHOW DATABASES` returns real rig databases. **Passes.**

### Surprises

1. **The bead's premise was completely backwards.** It claimed `dolt-provider-state.json` was canonical; actually `dolt-state.json` is. This is the single biggest lesson of Day-7: **Step 1.5 (grep upstream for the legacy filename) saved us from a wrong fix.** Without the grep, Option 1 would have been applied and broken the controller-managed path.
2. **`gc dolt-state runtime-layout` requires the controller to be running.** Even with dolt itself running (via `bd dolt start`), the resolver returns nothing when the controller is stopped. Option 2 in the original plan was non-viable from the start; the falsification step caught it before any code changed.
3. **Two state files exist by design**, not by accident. The bd pack is a "backend bridge" that doesn't own runtime-layout policy (per its own comment); the GC controller does. The bd pack writes provider-state, the controller publishes canonical state by reading provider-state + port-probe verification. Commit `921cb292` is the smoking gun for this design.
4. **The hardcoded fallback is correct as the LAST resort.** `dolt-state.json` IS the canonical name; the fall-through is a "best guess if env injection didn't happen and no state file exists" path. The real bug was the lack of an intermediate fallback to `dolt-provider-state.json` (the file that bd pack actually writes locally).
5. **The plan's Step 1.5 was added as a risk-section note, not a primary step.** It became the most valuable step of Day-7. Lesson: pre-thought risk-section items deserve primary-step billing when they could falsify the premise.

### Anything to promote to v2 manual

1. **"Step 1.5 was the most important step" pattern.** When a bead prescribes a fix, the cheapest possible falsification (`grep` for the thing the bead claims is broken across the broader codebase) often invalidates or refines the prescription. Worth adding to §22 as a complement to "silent failure via `2>/dev/null`": this is "wrong-direction-fix via incomplete-evidence."
2. **The two-state-files architecture** is a real recurring nuance worth documenting once. bd pack writes `dolt-provider-state.json`; controller publishes `dolt-state.json` as canonical. Pack scripts reading state should try both, with canonical winning when both exist. This is a §22-style cross-pack convention.
