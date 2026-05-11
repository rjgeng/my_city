# Day 5 — Diagnose `mol-dog-jsonl` push failure on cs/hq/ship

- **Plan authored:** 2026-05-10 (end of day 4)
- **Planned execution:** 2026-05-11
- **Status:** Resolved 2026-05-11. Two root causes fixed (missing `origin` on jsonl-archive + stale `type` column reference in scrub filter). Molecule restored to healthy steady-state: 3 consecutive clean cycles ending at records=19448, push: ok. State file: `consecutive_push_failures=0`, `pending_archive_push` cleared.

This is the pre-decomposition for Day-5: the JSONL push-failure storm mayor surfaced and deferred at the start of Day 4 (bead `mc-vj3hjk` in HQ). Same exercise pattern as Day 4 — write the investigation strategy before doing it, then compare actual findings against this document. Differences are the learning value.

---

## 1. The bead — pointer, not summary

Authoritative source: **`mc-vj3hjk`** in HQ (`gc bd show mc-vj3hjk`). Labels: `ops,jsonl,patrol,deferred-triage`. Mayor's body captures: symptom timeline (storm started 2026-05-09 15:40, counter 4→161+ at 2026-05-10 session start, ticking ~9 min apart), evidence (`DOG_DONE: jsonl — exported 0/3, records: 0, push: skipped, failed: cs hq ship`), affected-vs-unaffected table, four ranked hypotheses (rig-local config most likely), and explicit out-of-scope ("silencing the wisp would lose the signal").

**Read `mc-vj3hjk` first thing tomorrow.** Don't re-derive what mayor already wrote.

---

## 2. What "fixed" looks like (success criteria)

- The wisp escalation counter on the active `JSONL push failed` bead stops climbing.
- Three consecutive `mol-dog-jsonl` cycles for cs/hq/ship report `push: ok` (or whatever the success log line is) instead of `push: skipped, failed: cs hq ship`.
- Mail surface quiet — no new escalation messages for ≥ 30 minutes after the fix lands.
- No regression on hw or co_auth (which were already healthy).
- The wisp watcher itself stays alive — it's the only signal we have; don't burn it just to silence the noise.

---

## 3. Affected-vs-unaffected — the key diagnostic

| Rig | Path | mol-dog-jsonl status | Notes |
|---|---|---|---|
| `cs` (co_store) | `~/co_store` | ❌ push: skipped | Day-0/1 rig; has codex polecat patch in city.toml |
| `hq` | `~/my-city` (city HQ) | ❌ push: skipped | The city's own bead database |
| `ship` (co_shipping) | `~/co_shipping` | ❌ push: skipped | Day-0/1 rig; prefix=ship |
| `hw` (hello-world) | `~/my-city/hello-world` | ✅ working | Inside my-city/, not a sibling |
| `co_auth` | `~/co_auth` | ✅ working | Day-4 rig; brand new |

Three failing, two succeeding. **The diagnostic split is what to lean on.** What's different about cs/hq/ship that hw/co_auth doesn't have? Possibilities to probe:
- Age (cs/ship/hq are older — predate some convention change)
- Path topology (hw is *inside* my-city; the others are siblings — but co_auth is also a sibling and succeeds, so this isn't the discriminator)
- `.beads/config.yaml` content (compare directly)
- Whether the target path/branch the molecule pushes to exists in each rig's `.git`
- Git remote configuration (do cs/hq/ship have remotes the molecule expects?)
- The patches in city.toml (cs has a codex polecat patch — does mol-dog-jsonl care?)

---

## 4. Investigation plan — falsify cheapest checks first

### Step 1: Confirm the storm is still live (~5 min)

```bash
gc bd show mc-vj3hjk                                       # mayor's brief, current counter
gc mail list 2>&1 | grep -c "JSONL push failed"            # how many active escalations
gc supervisor logs 2>&1 | grep -E "DOG_DONE.*jsonl" | tail -10
```

If the counter is still climbing and the supervisor log is still emitting `push: skipped`, the bug is live. (If it mysteriously self-resolved overnight, that's its own interesting data point.)

### Step 2: Diff `.beads/config.yaml` across the five rigs (~15 min)

```bash
for rig in ~/co_store ~/my-city ~/co_shipping ~/my-city/hello-world ~/co_auth; do
  echo "=== $rig ==="
  cat "$rig/.beads/config.yaml" 2>/dev/null
done
```

Look for `jsonl_output_path`, `export_target`, `remote`, `push_branch`, or anything per-rig that mol-dog-jsonl could be reading. Failing rigs should diverge from working rigs on one specific field.

### Step 3: Find and read the molecule itself (~15 min)

`mol-dog-jsonl` lives in the gastown pack. Find its formula source and read the push logic:

```bash
find /Users/rfvitis/my-city/.gc/system/packs/gastown -name "*jsonl*" -o -name "*dog*" | head -20
# Then read the relevant formula file(s)
```

Understand what `push: skipped` means at the code level. Is it conditional on:
- File existence (target output path missing)?
- Git remote presence?
- Branch existence?
- File permissions?
- A config flag?

This step is the highest-information move if the config diff in Step 2 didn't yield. The wording `skipped` (vs. `failed`) suggests a precondition check failing, not a network/auth error.

### Step 4: Try the molecule against one failing rig manually (~10 min)

If there's a way to invoke `mol-dog-jsonl` directly for a single rig (probably via `gc bd mol`):

```bash
gc --rig co_store bd mol fire mol-dog-jsonl --verbose  # or similar — check `gc bd mol --help`
```

A live invocation with verbose flags should surface the exact reason for `push: skipped`. If `gc bd mol` doesn't have a `fire` / `run` verb, fall back to reading the wisp's last run output from `.gc/events.jsonl` or wherever events live.

### Step 5: Compare git state per rig (~10 min)

```bash
for rig in ~/co_store ~/my-city ~/co_shipping ~/my-city/hello-world ~/co_auth; do
  echo "=== $rig ==="
  (cd "$rig" && git remote -v 2>&1)
  (cd "$rig" && git branch -a 2>&1 | head -10)
done
```

Does mol-dog-jsonl expect a specific remote or branch that cs/hq/ship are missing? co_auth was set up with `gc rig add --include` today and the molecule works there — so whatever co_auth has, cs/hq/ship are missing.

### Step 6 (only if 1-5 don't narrow it): Read recent events for failing rigs

```bash
tail -200 /Users/rfvitis/my-city/.gc/events.jsonl | grep -E "co_store|co_shipping|hq" | grep -i jsonl
```

The event stream may have a more detailed failure reason than `push: skipped` — that's an abbreviated log line, the underlying event probably has the real cause.

---

## 5. Fix patterns (pre-thought, choose based on what investigation surfaces)

**If config field is missing/different in cs/hq/ship:**
- `bd config set <field> <value>` in each failing rig.
- Verify by re-running the molecule manually.
- Commit the config change at the city level if it's tracked.

**If the molecule expects a path/file/branch that doesn't exist:**
- Create it in each failing rig (mkdir, git branch, touch).
- Or change the molecule's config to point at an existing target.
- Prefer the latter — adding rig-local artifacts to match a misconfigured molecule is a smell.

**If the molecule has a bug** (e.g., its precondition check is too strict, or it never ran the migration to the new convention):
- Fix the formula in `.gc/system/packs/gastown/`.
- Test against one failing rig.
- Then it'll auto-apply to the others on next patrol cycle.

**Anti-pattern to avoid:** burning the wisp watcher (`gc bd mol burn ...`) to silence the noise. That deletes the only signal that tells us if the fix worked. The watcher should keep firing until the underlying push actually succeeds.

---

## 6. Risk / blast radius

- **Per-rig config changes** are low-risk — affect only the rig touched. Easy to revert.
- **Molecule source edits** affect all rigs that use this molecule on next patrol cycle. Test against one rig first; don't push pack changes blind.
- **The wisp/mail noise itself is not destructive** — just loud. Don't rush to silence it; rushing leads to losing the signal before the real fix is in.

---

## 7. Connection to S4 (storage degradation)

Day-4 noted `slow_storage_degraded: ... durable` warnings throughout the day and 2-9 second API responses, plus a very laggy gc shell inside mayor. **Both S3 (JSONL push failure) and S4 (storage degradation) touch the durable storage layer.** Plausible connections:

- The JSONL push failure may be a *symptom* of storage problems (e.g., the molecule can't write because a path is on a degraded/full filesystem).
- Or the JSONL failures may be a *cause* of storage growth (failed pushes accumulating retry buffers somewhere).
- Or they may be independent issues that just both surfaced during this session.

**Tactic:** investigate JSONL first with the storage-degradation hypothesis in mind. If the JSONL fix also clears the slow-storage warnings, they're related. If JSONL fixes but storage is still slow, treat S4 separately as Day-6.

---

## 8. Adjacent work to fold in while you're already on Day-5

These are small, low-effort items worth picking up alongside the JSONL work:

- **Update memory `project_rig_topology.md`** — it still says "codex-default with one polecat→claude patch on co_shipping" but the workspace was inverted to claude-default on 2026-05-09 (commit `be4f3ff`). The codex patch now lives on `co_store` per `city.toml`. Trivial edit.
- **Promote Day-4 insights into v2 manual** (`study/notes/gas_city_build_manual_practical_guide_v2.md`). Six bullets from Day-4's Final outcome:
  - Polecat/refinery handoff truth (polecat never closes its own beads)
  - Nudge-vs-patrol pattern for refinery
  - Mayor's `PAUSE for Gn` spec anti-pattern (strands the merge)
  - Cross-rig convoy gap workaround (label-based soft-link)
  - Local-repo-vs-origin desync after long automated cascades
  - Bootstrap-after-clone reality (Prisma generate, migrate deploy)

These don't depend on JSONL findings — can be done in parallel or as a break from the bug hunt.

---

## 9. Optional: mayor handoff

You could repeat the Day-4 mayor exercise pattern for this investigation, but for a single-bug triage of this size I'd skip it. Reasons:

- Mayor decomposes well but gate-bypasses (saved as `feedback_mayor_gate_closure.md`); for investigation work, gates are less critical anyway.
- The diagnostic plan above is already at bead-sized granularity; mayor would just re-decompose what's already pre-decomposed.
- The information density is high — a single human session reading the molecule source + comparing configs will probably outpace a polecat-mediated investigation.

**Recommended:** do it directly. Document findings on `mc-vj3hjk` (add NOTES, update labels — drop `deferred-triage`, add `triage-in-progress`, then `triage-resolved`). If you find a workflow gap *inside* gastown itself worth fixing, file a separate bead for that work.

---

## 10. Execution log

(filled in as work happens)

### Steps run

| Step | Time (PDT) | Finding |
|---|---|---|
| 1. Confirm storm live | ~04:45 | City stopped since 2026-05-10 13:29:31, so storm frozen but bug condition unchanged. Mayor inbox: 240 `JSONL push failed` escalations, highest counter 248. Plan typo: `gc mail list` is not a real subcommand — actual surface is `gc mail inbox <session>` / `gc mail count <session>` (positional arg, not `--alias`). |
| 2. Config diff across 5 rigs | ~04:55 | Configs nearly identical. No rig-level field discriminates failing from working. `gc.endpoint_origin` differs only on hq (`managed_city`); `types.custom` only missing on auth — neither splits failing/working cleanly. Filesystem split (`embeddeddolt/` on cs+ship vs `dolt/` elsewhere) also doesn't sort by failing/working. **Reframe**: hw and auth weren't "succeeding" — at the time the bead was filed they simply weren't in the molecule's discovery set. |
| 3. Read molecule source | ~05:05 | Pack is `maintenance` (not `gastown` as plan assumed). Order is an `exec` script `assets/scripts/jsonl-export.sh`, not an LLM molecule (line 8: "no LLM judgment needed"). Found two layered bugs: **(a)** archive at `/Users/rfvitis/my-city/.gc/runtime/packs/maintenance/jsonl-archive/` has no `origin` remote → every push fails silently (stderr swallowed by `2>/dev/null` at line 361); **(b)** scrub filter at line 485 references column `type` but bd schema has `issue_type`. |
| 4. Configure bare-repo origin | ~05:15 | `git init --bare /Users/rfvitis/my-city/.gc/jsonl-archive.git`; `git remote add origin` on archive; manual `git push origin main` flushed the 5 commits backlogged since 2026-05-09. |
| 5. Manual verify (run 1) | ~05:20 | `push: ok` confirmed counter reset 248 → 0, `pending_archive_push` cleared. But `exported 0/5` — surfaced the schema bug. Direct query revealed `Error 1105 (HY000): column "type" could not be found in any table in scope`. Confirmed column is `issue_type`. |
| 5b. Schema fix + verify (run 2) | ~05:25 | One-line edit at `jsonl-export.sh:485`: `type` → `issue_type`. Re-ran: HALT on cs (59% spike vs 2026-05-09 baseline). All 5 DBs queryable; molecule's spike safety functional. |
| 6. Walk baselines forward | ~05:35–05:40 | 3 more HALT cycles (hq 60%, hw 69%, ship 61%), then 3 consecutive clean cycles: records 19446 → 19447 → 19448, push: ok every time. Bare repo mirrors archive at SHA `78b96b8`. |

### Hypothesis confirmed

- **None of mayor's four ranked hypotheses matched the actual cause.** All four assumed per-rig config drift. The real causes are city-level: missing `origin` on the jsonl-archive (storm driver) and stale column name in the scrub filter (latent, exposed once the storm cleared).
- **Why the bead's framing was wrong**: it conflated rigs with dolt databases. The molecule iterates `SHOW DATABASES` on the shared dolt server (city-level), not rigs. cs/hq/ship/hw/auth happen to be the database names too, which made the rig framing seem plausible.
- **Smoking-gun evidence for missing remote**: reproduced manually — `git push origin main` in the archive exits 128 with `fatal: 'origin' does not appear to be a git repository`. State-file counter (`consecutive_push_failures: 248`) matched the highest escalation counter in mayor's inbox (248) exactly.
- **Smoking-gun evidence for schema drift**: after pushing the manual fix, `exported 0/5, push: ok` revealed the schema bug. Direct dolt query surfaced `Error 1105: column "type" could not be found`. `SELECT DISTINCT issue_type` confirmed the column exists under the new name.

### Fix applied

- **Files / configs changed:**
  - Created bare repo at `/Users/rfvitis/my-city/.gc/jsonl-archive.git` (placed under `.gc/` which is already gitignored — won't appear in source control).
  - Added remote on archive: `git -C /Users/rfvitis/my-city/.gc/runtime/packs/maintenance/jsonl-archive remote add origin /Users/rfvitis/my-city/.gc/jsonl-archive.git`.
  - Edited `/Users/rfvitis/my-city/.gc/system/packs/maintenance/assets/scripts/jsonl-export.sh:485`: `WHERE type NOT IN (...)` → `WHERE issue_type NOT IN (...)`. The path is inside `.gc/` (gitignored); fix will need re-applying if the pack is re-synced from upstream. **Worth upstreaming.**
  - State file (`jsonl-export-state.json`) was intentionally NOT hand-edited — script self-heals via the `archive_has_local_only_commits_from_tracking == false` branch (lines 354-358) when push succeeds.
- **Verification:** ran `jsonl-export.sh` manually 6 times with `GC_CITY=/Users/rfvitis/my-city GC_DOLT_PORT=50095`. Sequence:
  - Run 1: HALT on cs (59%)
  - Run 2: HALT on hq (60%)
  - Run 3: HALT on hw (69%)
  - Run 4: HALT on ship (61%)
  - Run 5: clean — `exported 5/5, records: 19446, push: ok`
  - Run 6: clean — `records: 19447, push: ok`
  - Run 7 (counted separately above): clean — `records: 19448, push: ok`
- **First clean cycle observed at:** 2026-05-11 13:39:02 UTC (archive commit `3cf498b`).

### Mail surface quiet

- Last `JSONL push failed` escalation: counter 248, 2026-05-10 ~13:29 PDT (immediately before city stop). No new `push failed` escalations have fired since the fix was applied.
- Spike alerts fired during recovery: 4 total (cs, hq, hw, ship) — one per stale baseline, legitimate signal not bug-noise. Mayor's inbox went from 256/243 → 260/247 (+4 messages), all four are `JSONL spike detected [HIGH]`, not push failures.
- 240 stale `JSONL push failed` escalations remain in mayor's inbox awaiting bulk-archive cleanup (separate task — they're inert now).

### Surprises

1. **Plan's CLI command was wrong**: `gc mail list` is not a real subcommand. Actual surface: `gc mail inbox <session>` and `gc mail count <session>`, both positional. No `--alias` flag.
2. **The "failing vs working" framing in the bead was a red herring**: hw and auth weren't "succeeding" — at the time the bead was filed they simply weren't in the molecule's discovery set yet. The framing led the bead's hypothesis ranking astray (all four hypotheses assumed rig-local config).
3. **Two-bug stacking with a silent inner bug**: the push storm was masking a schema-drift bug. With push fixed in isolation, the script started reporting `exported 0/5, push: ok` — push working, but zero records actually exported. The error was silenced by `2>/dev/null` at line 526. Without manually reproducing the dolt query, this would have been very hard to spot.
4. **Configuration drift across packs (latent bug, not fixed)**: `maintenance/dolt-target.sh:146` and `dolt/runtime.sh:29` reference `dolt-state.json`; `bd/gc-beads-bd.sh:2482` uses the canonical name `dolt-provider-state.json`. The bd pack is the writer in this city. `gc dolt-state runtime-layout` returns `dolt-provider-state.json`. The maintenance script's fallback to port 3307 didn't bite us today (we set `GC_DOLT_PORT` manually), but it's a latent bug that will reappear if the dolt port changes after a city restart. Worth a separate bead.
5. **Storm driver was 100% silent — no log line, no commit, just an incrementing counter**: the `git push origin main -q 2>/dev/null` swallowed everything. From outside, all you could see was the wisp escalation. The actual `fatal:` from git was never recorded anywhere. This is an observability gap.

### S4 follow-on

- **Untested in this session** — city was kept stopped during the JSONL fix, so no live storage measurement. The whole triage ran against the standalone `bd dolt start` server, not the full controller/supervisor load.
- **Plausible relationship**: the JSONL storm fired every ~9 min with mayor inbox bombardment and silent push retries. Could plausibly have contributed to storage stress, but probably not the primary driver — `git push` to a non-existent remote returns fast (~ms), and the per-cycle write load on dolt was just one push attempt + state file write. The bigger contributors to S4 are more likely the controller/supervisor's normal write traffic (events.jsonl, interactions.jsonl growth — events.jsonl is now 2 MB).
- **Recommended for Day-6**: start city, observe `slow_storage_degraded` warning frequency and gc-shell latency for ~30 min. If still degraded with JSONL no longer thrashing, S4 is independent and needs its own investigation.

### Anything to promote to v2 manual

Three insights worth durable documentation:

1. **Silent failure via `2>/dev/null` is a debugging hazard.** Pack scripts swallow stderr to keep logs clean, but legitimate errors vanish. **Diagnostic technique**: when a script reports a vague status (`push: failed`, `exported 0/N`), reproduce the underlying operation manually outside the script (re-run the same `git push` or `dolt sql` directly) to see the real error. This single move cracked both root causes today within minutes. Worth a "diagnosing silent-failure scripts" section in the manual.

2. **Pack-script scope ≠ rig scope.** The bead's framing assumed `mol-dog-jsonl` was rig-scoped because its failure log named rig-prefix-like tokens (cs/hq/ship). Actually the molecule operates at city level — one archive, one dolt server, all databases enumerated via `SHOW DATABASES`. **Heuristic**: when a molecule's output lists rig-name-shaped tokens, check whether it's iterating rigs (from `gc.config.rigs`) or dolt databases (from `SHOW DATABASES`). They often share names but have different lifecycles.

3. **Config-name conventions can drift between packs (cross-pack contract gap).** The `maintenance` and `dolt` packs hardcode `dolt-state.json`; the `bd` pack writes `dolt-provider-state.json`. `gc dolt-state runtime-layout` is the canonical resolver. **Pack consistency principle**: when a script reads runtime state owned by another pack, it should query the path via `gc dolt-state runtime-layout` (or equivalent) rather than hardcoding the filename. Worth a section on cross-pack contracts in the manual.
