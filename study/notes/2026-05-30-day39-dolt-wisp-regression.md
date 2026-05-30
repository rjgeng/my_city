# Day-39 (2026-05-30) — Dolt wisp-table regression blocks the mc-jhsp8y re-soak

**Status:** soak STALLED by a data-plane regression. Could NOT file as a bead — the
beads *write* path is itself blocked by this bug (see §"bd create blocked"). This file
is the bead-to-be; file it once the data plane is restored.

Proposed bead title:
> regression: dolt wisp-search panics 'invalid hash length: 19'
> (AdaptiveValue.convertToTextStorage) under gc HEAD-8d6d6bb — blocks supervisor boot,
> beads writes, and the mc-jhsp8y soak.  Type: bug. Priority: P1/P2 (town-wide).

## Symptom A — wisp-search read panic
Every `search wisps (merge)` panics under the engine bundled by HEAD-8d6d6bb
(go-mysql-server/dolt `v0.20.1-...-20260528221811-29886bb10b26`):
```
search wisps (merge): Error 1105 (HY000): panic recovered: invalid hash length: 19
  store/hash.New
  val.AdaptiveValue.convertToTextStorage   (adaptive_value.go:201)
  val.(*TupleDesc).GetStringAdaptiveValue
  prolly/tree.GetField                      (prolly_fields.go:161)
```
A variable-length text column in the wisps table (Dolt adaptive value) is decoded as a
20-byte out-of-line content hash from a 19-byte buffer.

## Symptom B — bd create blocked (write path)
`bd create` (10:30 PT 5/30) fails before writing:
```
[mysql] 10:30:21–10:30:50 packets.go:58 unexpected EOF   (flood)
Error: failed to open database: failed to initialize schema:
  schema migration: ignored migrations:
  migration 0006_add_wisp_is_blocked.up.sql: invalid connection
schema: release migration lock: ... driver: bad connection
```
The new binary carries a pending wisp-table migration `0006_add_wisp_is_blocked` that
cannot apply against the corrupt/panicking wisp table. Reads skip the migration; writes
force the schema-up check and die.

## Scope
- Narrow to the wisp table. Real-bead **point reads work**: `gc bd show mc-jhsp8y` clean
  at 10:20 AND 10:30.
- 652 occurrences of Symptom A in `~/.gc/supervisor.log`, all on `mc-wisp-*` fetches.

## Onset & persistence
- First panic: **2026/05/29 13:16:43 PT**, immediately after a mysql `unexpected EOF`
  (connection reset). ~8h AFTER the 05:21 upgrade, not at it.
- NOT transient: my-city dolt sql-server PID 24831 has been up since 16:12 PT 5/29
  (>18h) and still panics — survived a restart. Engine+data combination, persistent.

## Impact
- Supervisor cannot boot: snapshot load runs a wisp search → panic. No successful
  "Supervisor started" since onset; `gc status` / `gc supervisor status` report
  "not running" — an artifact of data-plane degradation, not a real wedge
  (cf. liveness-signals-unreliable-during-dolt-degradation).
- Beads writes blocked (Symptom B).
- mc-jhsp8y Day-39 re-soak: controller cannot dispatch the ~10:48 compactor fire.
  **Day-39 data point lost.** Soak clock effectively paused until this is fixed.

## Root cause (localized 2026-05-30, read-only probes via dolt @127.0.0.1:58545)
Engine regression in HEAD-8d6d6bb decoding the **hq.wisps** table's longtext (adaptive)
values. Isolated and reproduced:
- `SELECT COUNT(*) FROM hq.wisps` → 7485 (no decode → OK). Rows are present.
- `SELECT LENGTH(description) FROM hq.wisps LIMIT 5` → SAME panic (`hash.New` 19-byte) →
  the decode fails on the **checked-out branch**, not just `search wisps (merge)`.
- Control: `SELECT LENGTH(description) FROM hq.issues` → OK; `gc bd show mc-jhsp8y`
  renders its large description fine. So the engine's longtext decode works generally —
  **only the wisps table's stored values are unreadable** by the new engine.
- `SHOW COLUMNS FROM hq.wisps LIKE 'is_blocked'` → EMPTY: migration **0006 never applied**.
- `hq.ignored_schema_migrations`: wisp-migrations **1–5 stamped 2026-05-29 13:16:42–43** —
  exactly the panic onset. The 0006 attempt at 13:16 is the trigger that left wisps in an
  encoding the 20260528 engine misreads (out-of-line adaptive value → `hash.New` on a
  19-byte buffer).

Conclusion: an **upstream engine regression** (go-mysql-server/dolt `20260528`) on the
wisp-table adaptive longtext encoding, tripped by the wisp-migration 0006 run. The data is
NOT corrupt at rest (the old engine wrote and could read it) — it's an engine-version
read incompatibility.

## Remediation re-assessment (post-localization)
1. **Downgrade to HEAD-fad5d3f** — high confidence it restores reads (old engine reads its
   own wisp encoding). COST: reverts #2564/#2598 → abandons this soak round; re-soak after
   an upstream engine fix. Cleanest path back to a healthy town.
2. Clear/purge the 7485 wisps via raw `DELETE` (bypasses the blocked migration path; DELETE
   doesn't decode longtext). Risky, loses mail history, and may re-trigger on future large
   wisps if the engine bug is real. Not recommended.
3. `gc dolt recover` / rollback — WON'T help: data isn't corrupt at rest; rollback doesn't
   change engine compatibility.

Upstream-worthy: file against gascity/dolt bump — "20260528 engine panics decoding
out-of-line adaptive longtext written by prior engine (hq.wisps): invalid hash length 19".

## Evidence pointers
- `~/.gc/supervisor.log` line 452897-452899 (onset + preceding EOF).
- `study/scripts/soak-watch.sh` §0 has shown `Supervisor is not running` since ~16:40 5/29.
- Soak-watch §1 (events.jsonl, flat-file — unaffected) is still the valid fire detector.

## Remediation options (NOT yet attempted — all cross anti-plan #23 / mutate data)
1. Engine downgrade to HEAD-fad5d3f (pre-upgrade) — reverts the soak gate too.
2. Wisp-table repair / purge of corrupt mail-wisps, then let migration 0006 apply.
3. `gc dolt recover` / rollback on the beads DB.
Each needs explicit user authorization and a chosen approach.
