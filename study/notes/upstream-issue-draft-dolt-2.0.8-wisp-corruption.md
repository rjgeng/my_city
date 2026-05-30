# UPSTREAM ISSUE — FILED 2026-05-30: https://github.com/dolthub/dolt/issues/11131
# Target repo: dolthub/dolt (engine bundled in the 2.0.x release; may need cross-filing to
# dolthub/go-mysql-server). Consumer-side companion: gastownhall/gascity#2814.

---

**Title (live on #11131):** Dolt 2.0.8: adaptive out-of-line TEXT written via migration is unreadable — "invalid hash length: 19" on read (regression vs 2.0.4)

## Summary
Under dolt **2.0.8**, a consumer's schema migration produced on-disk adaptive `longtext`
values that **no engine can read back**: every decode panics `invalid hash length: 19` from
`store/hash.New`. The stored adaptive value is tagged as an out-of-line 20-byte content hash
but the buffer is only **19 bytes**. The writer (2.0.8) cannot read its own output, and an
older engine (2.0.4) cannot read it either — so the on-disk value is malformed, i.e. a
write-side defect, not a read-path bug.

This bricked a production-style workload: a table populated by a migration under 2.0.8 became
permanently unreadable; downgrading the reader did not help (the bytes are already bad).

**Honesty up front:** I could **not** reproduce this with plain dolt operations (see Repro).
Large-TEXT insert/commit/read, `INSERT…SELECT`, `ALTER ADD COLUMN`, and cross-version reads
all work fine under 2.0.8. The malformed value only appears via the consumer's *nonlocal /
federated* table-migration write path. So the open question is whether a specific dolt write
API (exercised by that path) can emit a malformed adaptive value, or whether the consumer is
mis-driving the API. I have a reproducible corrupt data dir and can share it privately.

## Duplicate search (performed 2026-05-30)
No existing issue for this symptom in `dolthub/dolt` or `dolthub/go-mysql-server` (searched
`invalid hash length`, `AdaptiveValue`, `convertToTextStorage`, `adaptive value`, `hash length`,
open + closed). **Not a duplicate.** Related, same subsystem: **dolt #11095** — "REGEXP_REPLACE
panics on TextStorage values" (`sql/panic/correctness`, closed **2026-05-22**), i.e. active
`val.TextStorage` work just before the `20260528` engine build this regressed in.

## Versions
- **Broken:** dolt `2.0.8` — go-mysql-server `v0.20.1-0.20260528221811-29886bb10b26`
- **Last good:** dolt `2.0.4` — go-mysql-server `v0.20.1-0.20260519163920-8a6f65450db7`
- Regression window: engine builds **20260519 → 20260528**.
- Platform: macOS (darwin/amd64), Homebrew install.

## Panic (recovered) — on any decode of the affected column
```
Error 1105 (HY000): panic recovered: invalid hash length: 19
  store/hash.New                                   hash/hash.go:104
  val.AdaptiveValue.convertToTextStorage           val/adaptive_value.go:201
  val.(*TupleDesc).GetStringAdaptiveValue          val/tuple_descriptor.go:612
  prolly/tree.GetField                             prolly/tree/prolly_fields.go:161
  index.prollyIndexIter.rowFromTuples / .Next      sqle/index/prolly_index_iter.go
```
The adaptive value is being interpreted as an out-of-line 20-byte content hash, but the stored
buffer is **19 bytes** → `hash.New` rejects it.

## Observations (what isolates it)
1. **Writer can't read its own output.** The rows were written by 2.0.8 (via a schema
   migration that populated a `longtext`-bearing table). Reading them back under 2.0.8 panics.
2. **Downgrading the reader doesn't help.** dolt 2.0.4 (engine 20260519) also panics on the
   same rows — confirming the corruption is in the *bytes written by 2.0.8*, not the reader.
3. **`COUNT(*)` succeeds** (7485 rows) — no decode, no panic. The table/rowset is structurally
   intact; only the adaptive value decode fails.
4. **Scoped to the affected table.** A different table in the same database with `longtext`
   columns decodes fine under both engines, including large values. So it is not "all adaptive
   values" — it correlates with how/when these specific values were written by 2.0.8.
5. Single-branch `SELECT LENGTH(<col>) ... LIMIT n` panics — it is not specific to merge/
   cross-branch reads; a plain working-set read trips it.

## Likely area
`val.AdaptiveValue.convertToTextStorage` / the out-of-line threshold + encoding for adaptive
TEXT values. The symptom (a 19-byte stored buffer where a 20-byte out-of-line hash is expected)
looks like an off-by-one or a write/read asymmetry in the inline-vs-out-of-line adaptive
encoding introduced between 20260519 and 20260528.

## Impact
- Silent, permanent data corruption of large TEXT values written under 2.0.8.
- Unrecoverable by engine downgrade (bad bytes persist).
- In our case it bricked a runtime table created by a migration, cascading to service boot
  failure and blocking all writes (DB-open ran a migration that read the corrupt table).

## Repro — attempted, NEGATIVE in pure dolt (this is a narrowing result)
Tested directly with the 2.0.8 binary in a throwaway dir (`dolt init`; values sized 10 B,
1 KB, 64 KB, 1 MB to span the adaptive inline→out-of-line threshold):

| Step (dolt 2.0.8) | Result |
|---|---|
| `CREATE TABLE t(id varchar(64) PK, body longtext)` + insert 10B/1KB/64KB/1MB | OK |
| read `SELECT id, LENGTH(body)` — working set | OK (no panic) |
| `CALL DOLT_COMMIT` then re-read | OK |
| `INSERT…SELECT` copy into `t2`, read | OK |
| `ALTER TABLE t ADD COLUMN is_blocked tinyint`, read `body` | OK |
| **control:** read 2.0.8's writes with **2.0.4** | OK (normal cross-version compat) |

So plain large-TEXT writes, table-copy, schema-alter, and cross-version reads are all fine in
2.0.8. **The corruption does NOT reproduce via ordinary dolt SQL.** It only appears in the
real database, on a table created/populated by the consumer's *nonlocal / federated* table
migration. The malformed value is unambiguously present there: any decode panics
`invalid hash length: 19`, while `COUNT(*)` (no decode) returns 7485 rows, under both 2.0.8
and 2.0.4.

Narrowing: the trigger is a specific write path the federation/migration uses — not generic
adaptive-TEXT encoding. **Offer:** I can share the corrupted data dir privately and/or help
bisect the `20260519 → 20260528` engine range; guidance on which write API the consumer uses
that could emit a malformed adaptive value would also localize it fast.

## Ask
- Confirm/deny a known regression in adaptive out-of-line TEXT encoding in this window.
- Guidance on detecting already-corrupted values (so operators can find blast radius), since
  `COUNT(*)` hides it and only a decode trips it.
