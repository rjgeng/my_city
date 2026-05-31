# Day 41 — schemadrift recovery-feasibility scout (read-only) + upstream watch

- **Day:** 41 (executed 2026-05-31). Plan: `study/notes/2026-05-31-day41-plan-dolt-incident-followup.md` (the watch/respond day after the Day-39–40 dolt 2.0.8 incident).
- **Posture:** strictly read-only. No clone/build/run against `.dolt`; no `dolt`/`gc`/`brew` upgrade or link; no backup-consuming action. Anti-plans #27–#30 binding. Scout read the `zachmu/schema-repair-tool` branch via the GitHub contents API only.

## Pre-flight (read state, mutate nothing)

### Guard — HELD ✅
- `dolt version` = **2.0.4**; symlink `/usr/local/bin/dolt → /usr/local/Cellar/dolt/2.0.4/bin/dolt` intact.
- brew still advertises "newest 2.0.6" — a stray `brew upgrade` would pull **2.0.6 (also in the recall, see below)**, NOT the fix. Anti-plan #28 remains binding.

### dolt#11131 — RESOLVED upstream 🎉
- reltuk + zachmu confirmed repro and root cause: **schema corruption, not data corruption** — `TEXT→LONGTEXT` ALTER skipped a required row rewrite because the storage *encoding* changed (`StringAddrEnc → StringAdaptiveEnc`) even though SQL-type widening looked rewrite-free; adaptive decode then consumes the first byte of the 20-byte hash as a varint length → `invalid hash length: 19`.
- **Fixed in dolt `v2.1.0` (released).** zachmu: **all 2.x releases prior to 2.1.0 are being recalled.**
- Repair tooling: `schemadrift` admin commands on branch `zachmu/schema-repair-tool` — *agent-produced, not yet fully vetted by dolthub, not in any public release; back up `.dolt` first* (their words).
- **timsehn flagged our exact case:** the corruption is in **wisps**, which are dolt-ignored, so the `dolt reset`/branch-cherry-pick self-service route does NOT apply — **the tool will be required.**

### gascity#2814 — owner engaged; PR stays HELD
- julianknutsen (collaborator) posted an escalation status (matches dolt's root cause exactly) and linked the dolt repro. He did **NOT** address rjgeng's PR offer → per anti-plan #27 + §24, **Branch C wait-only**, no nudge. **No comment posted today** (per instruction; he owns the floor and already knows about 2.1.0/recall).
- Premise shift: the prepared "block known-bad 2.0.8, keep 2.0.7 floor" PR is now partly OBE — the recall covers 2.0.7 too, so the correct guard is `ManagedMin → 2.1.0`. Owner sets the floor; we hold.

## The tool — `dolt admin schema-encoding-drift` (hidden admin suite, 4 subcommands)

1. **`check`** — read-only diagnose. Walks all sibling DBs/tables, classifies each drifted column into a bucket. **Never invokes adaptive dispatch → safe to run on a corrupted DB.** Exit 1 if drift found; `--json` pipes to repair. Buckets:
   - `drift` — pure legacy raw-hash under an adaptive tag → repair will flip.
   - `safe-empty` — all-NULL / all-0x00 payload → repair only with `--include-empty`.
   - `heterogeneous` — a **mix** of legacy raw-hash AND genuine adaptive rows. Code note: *"real-world TEXT columns all heterogeneous."* repair refuses these.
2. **`repair`** — atomic per-column schema-tag flip (adaptive→legacy), one dolt commit each. **REFUSES:** genuine-adaptive columns, heterogeneous columns, **and `dolt_ignore`'d tables** (would dangling-fault on never-committed content chunks) → redirects to `migrate-adaptive`.
3. **`recover-rows`** — row-by-row migration of heterogeneous payload → canonical legacy form, single commit. **Also REFUSES `dolt_ignore`'d tables** → redirects to `migrate-adaptive`.
4. **`migrate-adaptive`** — FORWARD migration → canonical adaptive (v2) form. Has the dedicated **`dolt_ignore`'d-table force-inline path** (`migrateIgnoredTableInline`): force-inlines every out-of-band text/blob column to adaptive-inline and **persists the working set WITHOUT a dolt commit** (because bd never `dolt add`s wisp content chunks, so an out-of-band ref couldn't be commit-rooted).

## Verdict for the my-city wisp corruption

1. **2.1.0 alone does NOT recover my-city.** The schema-side fix (commits `4969194e2` / `09278d859` shipped in 2.1.0) only *prevents new ALTERs from extending* corruption. Columns already ALTERed under 2.0.8 keep the wrong persisted tag → reads still panic. **The repair tool is required to heal the existing damage.**
2. **wisps are `dolt_ignore`'d** → `repair` and `recover-rows` both refuse them and point at **`migrate-adaptive`**. **`migrate-adaptive` is the required command** — the only one with a dolt-ignore path.
3. Content is preserved byte-for-byte (≤20B inlined, larger keeps its out-of-band chunk + length prefix); the command aborts loud with the offending row's PK on any unknown-shape row → no partial/silent loss.

## Gates before ANY execution (all must clear — none cleared today)

- **G-a (gating UNKNOWN): is `hq.wisps` keyless?** `migrate-adaptive` (and the ignored-table path) **refuses keyless tables**. If wisps is keyless, NONE of the three write paths work → need direct dolthub guidance. Must be determined via the tool's own `check` (which never panics) or dolthub — NOT a raw `SELECT` (corrupted-row reads panic).
- **G-b: a `2.1.0`+branch dolt binary** must be built/obtained in isolation, WITHOUT disturbing the 2.0.4 guard symlink (anti-plan #28) — never `brew link` / replace `/usr/local/bin/dolt`.
- **G-c: explicit user auth + the verified 5.7G backup** (`.beads/dolt.backup-20260530T1129-pre-reset`) in hand — `migrate-adaptive` WRITES (persists the working set). Anti-plan #29.
- **G-d: acceptance of an agent-produced, dolthub-unvetted tool** on postgres-tier wisp data. **Recommendation: prefer waiting for dolthub to fold the repair into a vetted release, or get their direct sign-off, before running the branch tool** — given the data sensitivity and that the tool is explicitly un-vetted.
- Note: `inlineSizeCapBytes = 16KB` defensive ceiling; dolthub's census says ignored-table content ≤~200B. A larger wisp body still inlines (one big row beats a dangling ref) and surfaces `MaxContentLen` as a warning. Low risk.

## Bottom line / carry-forward
- **PR stays HELD** (Branch C, §24, anti-plan #27); owner sets the `ManagedMin → 2.1.0` floor.
- **my-city recovery now has a concrete path** — `migrate-adaptive` — but it is GATED on G-a–G-d; nothing executed today.
- **Lowest-regret next step:** resolve **G-a (is wisps keyless?)** read-only, then decide *wait-for-vetted-release* vs. *run-the-branch-tool under G-b/G-c*. No destructive action without explicit auth + verified backup.
- **mc-jhsp8y** stays PAUSED (anti-plan #30); bd writes still blocked → no bead mutations possible.
