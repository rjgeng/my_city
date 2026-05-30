# UPSTREAM ISSUE — FILED 2026-05-30: https://github.com/gastownhall/gascity/issues/2814
# Target repo: gastownhall/gascity. Links dolt root-cause issue dolthub/dolt#11131.
# Companion: study/notes/upstream-issue-draft-dolt-2.0.8-wisp-corruption.md.

---

**Title:** gc HEAD-8d6d6bb ships bundled dolt **2.0.8**, whose wisp nonlocal-table migration
writes unreadable adaptive-TEXT — corrupts `hq.wisps`, controller can't boot. Pin dolt **2.0.4**
until dolthub/dolt fixes it.

## Summary
Upgrading to `gc HEAD-8d6d6bb` pulled the bundled **dolt 2.0.4 → 2.0.8**. On the next wisp
schema migration, dolt 2.0.8 wrote `hq.wisps` adaptive `longtext` values that **no engine can
read back** (`invalid hash length: 19`). Result: the controller/supervisor can't boot (its
snapshot load runs a wisp search → panic), and beads **writes** are blocked (DB-open runs the
now-failing wisp migration). It is **not recoverable** by downgrading dolt or by dolt-level
surgery — the bytes are already malformed, and the wisp tables are *nonlocal/federated* objects
that dolt `DROP`/`reset`/`checkout` can't rebuild. This is a data-loss-class regression that
bricks a city on upgrade.

Root cause sits in the dolt engine (filed separately at dolthub/dolt — link TBD), but it
**reaches users through gc's bundled-dolt version**, so the consumer-side ask is: pin/revert the
bundled dolt until the engine fix lands.

## What happened (timeline, one city)
- `gc upgrade` HEAD-fad5d3f → HEAD-8d6d6bb. Bundled dolt **2.0.4 → 2.0.8**
  (go-mysql-server `20260519` → `20260528`).
- ~8h later, the first wisp schema migration ran under 2.0.8 (`create nonlocal table wisps` /
  `wisp_*`, then `0006_add_wisp_is_blocked`). From that point every decode of `hq.wisps`
  longtext panics `invalid hash length: 19`.
- Supervisor "not running" thereafter (snapshot load → wisp search → panic). `bd` writes fail
  on `0007_recompute_wisp_is_blocked: table not found` once the corrupt table is touched.

## Why recovery failed (so others don't burn the same hours)
- Downgrade dolt → 2.0.4: necessary (stops further bad writes) but **insufficient** — 2.0.4
  also can't read the already-malformed bytes.
- dolt-level repair: the wisp tables are **nonlocal/federated**, materialized at runtime — not
  committed dolt tables (`SHOW TABLES … AS OF HEAD` = 0 wisp tables; DROP makes no commit;
  `DOLT_CHECKOUT` can't restore them). So `DROP`+`bd migrate schema` just breaks forward
  migrations; only beads' own federation/migration tooling (or the engine fix) can rebuild.
- No migration backup existed (`gc dolt rollback` → "No backups found").

## Repro / narrowing (honest)
Plain dolt 2.0.8 does **not** reproduce it: large-TEXT insert/commit/read (to 1 MB),
`INSERT…SELECT`, `ALTER ADD COLUMN`, and cross-version reads all work. The corruption appears
only via the wisp **nonlocal-table migration** path. So the consumer-side trigger is that
migration interacting with dolt 2.0.8's adaptive-TEXT write — see the dolt issue for the
engine-level detail and the offer to share a corrupted data dir.

## Version-pin discrepancy (actionable now)
The gascity source pins **Dolt 2.0.7** (`chore: pin Dolt to 2.0.7 (#2683)`), but the installed
`HEAD-8d6d6bb` ran against brew **dolt 2.0.8**. Worth verifying the intended pin vs. the
delivered binary — the bundled/runtime dolt drifted past the pinned version into the bad build.

## Recommendation
1. **Pin/revert the bundled (and brew-dependency) dolt to 2.0.4** — or gate off 2.0.8 — until
   the dolthub/dolt engine fix lands.
2. Ensure the shipped/runtime dolt matches the source pin (2.0.7 intended ≠ 2.0.8 delivered).
3. Consider a **migration backup before the wisp nonlocal-table migration** (there was none),
   and a preflight that fails the migration if a post-write decode of a sampled row panics —
   so a bad engine can't silently brick the city.
4. Link/track dolthub/dolt issue: https://github.com/dolthub/dolt/issues/11131.

## Impact / severity
Data-loss-class; bricks a city's controller on upgrade; unrecoverable without the engine fix
or beads-internal federation repair. Suggest priority on par with #2615 (managed-dolt) class.
