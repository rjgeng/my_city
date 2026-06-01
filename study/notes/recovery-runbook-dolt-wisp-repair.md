# Recovery runbook — dolt hq.wisps adaptive-TEXT repair

**Status:** WAITING on G-b (vetted binary). Do not execute until all gates clear.
**Last verified:** 2026-06-01 (Day-42). Command syntax from `zachmu/schema-repair-tool` tip `709aad07`.
**Reference:** ADR-0003, `2026-05-31-day41-schemadrift-scout-findings.md`

---

## Gates (all must clear before execution)

| Gate | Status | Condition |
|------|--------|-----------|
| G-a | ✅ CLEARED | `hq.wisps` has `PRIMARY KEY (id)` — `migrate-adaptive` viable |
| G-b | ⏳ WAITING | Vetted binary: dolthub folds `schemadrift` admin commands into a public release |
| G-c | Ready to confirm | Explicit user auth + verify 5.7G backup is still intact before any write step |
| G-d | Superseded by G-b | Was "accept unvetted tool"; replaced by waiting for the vetted release |

**G-b signal:** a dolt release (≥2.1.x) includes `dolt admin schema-encoding-drift` in its public binary. Verify with `/tmp/dolt-<ver>/dolt admin --help | grep schema-encoding-drift` after download.

---

## Corrupted state summary

- **DB:** `~/my-city/.beads/dolt`, database `hq`, table `wisps`
- **Corruption:** 5 `longtext` columns have `StringAdaptiveEnc` schema tag but legacy raw-hash (20-byte) row data — written by dolt 2.0.8 migration 0049 (`TEXT→LONGTEXT` widening). Every decode panics `invalid hash length: 19`.
- **Corrupted columns:** `description`, `design`, `acceptance_criteria`, `notes`, `close_reason`
- **Backup:** `.beads/dolt.backup-20260530T1129-pre-reset` (5.7G, verified). This is the only undo.
- **Engine pinned to:** 2.0.4 via `/usr/local/bin/dolt → /usr/local/Cellar/dolt/2.0.4/bin/dolt`. Do NOT disturb this symlink.

---

## Step 0 — Obtain vetted binary in isolation (G-b)

When a dolt release ships the schemadrift commands:

```bash
# Download release binary to a temp path — NEVER brew link or replace /usr/local/bin/dolt
VER=2.X.X   # the first release shipping schemadrift
curl -L "https://github.com/dolthub/dolt/releases/download/v${VER}/dolt_darwin_arm64.tar.gz" \
  -o /tmp/dolt-${VER}.tar.gz
mkdir -p /tmp/dolt-${VER}
tar xzf /tmp/dolt-${VER}.tar.gz -C /tmp/dolt-${VER} --strip-components=1
DOLT=/tmp/dolt-${VER}/bin/dolt

# Verify the command exists
$DOLT admin --help | grep schema-encoding-drift
# expected: schema-encoding-drift   Detect and repair persisted-schema / on-disk-row encoding drift...

# Verify 2.0.4 guard is untouched
/usr/local/bin/dolt version   # must still show 2.0.4
```

---

## Step 1 — Pre-flight: stop server, verify backup

```bash
# Stop the dolt server (gc manages it; confirm it's down)
gc dolt stop   # or kill the dolt server PID directly if gc is unavailable

# Confirm server is down
lsof -i :3306 | grep dolt   # should return nothing

# Verify backup integrity
ls -lh ~/my-city/.beads/dolt.backup-20260530T1129-pre-reset
# expected: directory exists, ~5.7G
du -sh ~/my-city/.beads/dolt.backup-20260530T1129-pre-reset
# expected: ~5.7G
```

---

## Step 2 — check (read-only diagnosis)

Run from the dolt data directory. Safe on a corrupted DB — never invokes adaptive dispatch.

```bash
cd ~/my-city/.beads/dolt
$DOLT admin schema-encoding-drift check --database hq
```

**Expected output:** 5 rows flagged, all `severity=drift`, all in `wisps` table:
- `description`
- `design`
- `acceptance_criteria`
- `notes`
- `close_reason`

**If exit 0 (no drift detected):** stop. Either the corruption is already resolved or the tool isn't reading the right DB. Do not proceed to migrate-adaptive.

**If unexpected tables/columns appear** beyond the 5 above: stop. Investigate before writing anything.

---

## Step 3 — dry-run each column

Safe: classifies rows by field shape only, no content dereferenced, no writes.

```bash
cd ~/my-city/.beads/dolt
for col in description design acceptance_criteria notes close_reason; do
  echo "--- dry-run: $col ---"
  $DOLT admin schema-encoding-drift migrate-adaptive \
    --table wisps --column "$col" --dry-run
done
```

**Expected per column:** a per-row-class summary showing N legacy rows to migrate, 0 already-adaptive rows (since all rows were written under 2.0.8), 0 unknown-shape rows. Exit 0.

**Abort condition:** any `--dry-run` run exits 1 or reports unknown-shape rows → stop. Do not proceed. Restore backup if anything was already written (nothing should be at this stage).

---

## Step 4 — migrate-adaptive, one column at a time

Each invocation produces one dolt commit. If any column fails, the previous columns' commits are already in place — that's acceptable; partial repair is better than no repair.

```bash
cd ~/my-city/.beads/dolt
for col in description design acceptance_criteria notes close_reason; do
  echo "--- migrating: $col ---"
  $DOLT admin schema-encoding-drift migrate-adaptive \
    --table wisps --column "$col"
  if [ $? -ne 0 ]; then
    echo "ABORT: migrate-adaptive failed on column $col — do NOT continue"
    echo "Restore from: ~/my-city/.beads/dolt.backup-20260530T1129-pre-reset"
    break
  fi
  echo "OK: $col migrated"
done
```

**Expected:** 5 × exit 0, 5 dolt commits visible in `$DOLT log`.

**Abort condition:** any exit 1 → stop immediately. Restore backup before attempting any restart.

---

## Step 5 — verify repair

```bash
cd ~/my-city/.beads/dolt

# Re-run check — should exit 0 (no drift)
$DOLT admin schema-encoding-drift check --database hq
# expected: exit 0, no output or "no drift detected"

# Spot-check: read a wisp row directly
$DOLT sql -q "SELECT id, LEFT(description, 80) FROM hq.wisps LIMIT 3"
# expected: rows returned without panic; description text visible
```

**If check still exits 1:** the migration did not fully resolve the drift. Do NOT restart the city. Investigate before proceeding.

---

## Step 6 — restart and confirm controller

```bash
# Start dolt server on 2.0.4 (the guarded symlink)
gc dolt start   # or however the city starts its dolt server

# Confirm controller comes up
gc status
# expected: supervisor up, controller initializing or running

# Confirm bd writes unblocked
bd show mc-jhsp8y   # should return the bead without error
bd create --title "test smoke" --dry-run   # or any read that would have panicked before
```

**If controller fails to init:** check `gc dolt logs` for residual panic. Do NOT force-restart in a loop — diagnose first.

---

## Step 7 — post-recovery cleanup and soak resume

Once controller is confirmed up:

1. Close deferred beads: `mc-itt3xc` (PR #2638) and `mc-w9iua4` (PR #2136 post-upgrade soak)
2. File the deferred tracking bead for dolt#11131 + gascity#2814 (title in ADR-0003)
3. Resume mc-jhsp8y soak — first compactor fire after recovery confirms the in-flatten race is still the current failure mode (expected: quarantine marker from the run before city was bricked is still there; clear it manually first per ADR-0003 guidance)
4. Migrate `my-llm-wiki` and other cities' `pack.toml → city.toml` if not already done

---

## Restore procedure (if any step fails)

```bash
# Stop everything
gc stop
pkill -f dolt   # belt and suspenders

# Restore backup
rm -rf ~/my-city/.beads/dolt
cp -r ~/my-city/.beads/dolt.backup-20260530T1129-pre-reset ~/my-city/.beads/dolt

# Verify 2.0.4 guard intact
/usr/local/bin/dolt version   # must show 2.0.4

# Restart on 2.0.4 (returns to pre-repair state: controller down, wisps broken, bd writes blocked)
gc dolt start
```
