# Day 4 — Mayor-led auth demo (Next.js 16 + Prisma + SQLite)

**Plan authored:** 2026-05-09 (end of day 3)
**Planned execution:** 2026-05-10 (or whenever rig setup + first attach to mayor happens)
**Status:** **Completed 2026-05-10.** Convoy `mc-wjos2g` landed via `gc convoy land`. All 9 beads closed (G1 closed by mayor, G2 + G3 closed by human, 6 impl beads merged by refinery). Smoke test passed end-to-end in browser. Demo is functional on `~/co_auth` `main` at commit `d092b37`.

This is the **pre-decomposition I (Claude) wrote** as a reference plan, NOT what mayor produced. The point of the exercise: hand mayor the epic in plain English, watch what mayor actually decomposes, then compare its bead tree against this plan in the Execution Log section below. The differences are the learning value.

---

## Pre-flight: where this lives

`co_auth/` as a new sibling rig (prefix `auth`), set up the same way as `co_store` and `co_shipping`. Rig setup is **outside mayor's scope** — rigs are city-level structure, not work mayor files:

```bash
mkdir -p ~/co_auth && cd ~/co_auth && git init
cd ~/my-city && gc rig add ~/co_auth --adopt --prefix auth
```

Approve the rig name (`co_auth` / prefix `auth`) before continuing. This is checkpoint zero.

---

## 1. The epic

**Title:** `Build minimal Next.js 16 auth demo with Prisma + SQLite`

**Goal (handed to mayor):** Build a minimal authentication demo in `co_auth`. Stack: Next.js 16 (App Router, TypeScript), Prisma + SQLite for persistence, server-rendered pages. Functional scope: signup with email/password, login, logout, and one protected `/dashboard` page that requires a session. Sessions stored in DB via Prisma, identified by an HTTP-only cookie. Demo-grade — no email verification, no password reset, no social login. Goal is to exercise the full polecat → refinery merge loop end-to-end on a small but real feature, not to ship production auth.

**Out of scope** (be explicit so mayor doesn't drift): OAuth, MFA, password reset flow, email verification, rate limiting, CSRF tokens beyond defaults, deployment.

This becomes the **parent bead** (`auth-X` of type `task` or `feature`). All children get `parent_id = auth-X`. The convoy wraps it for batch tracking.

## 2. Child beads (decomposition)

Mayor's actual decomposition may differ in granularity — that's part of what's being learned. ~6 children feels right (too many = noise; too few = no real decomposition demo):

| ID (sketch) | Title | Type | Notes |
|---|---|---|---|
| `auth-1` | Scaffold Next.js 16 app + install deps (prisma, @prisma/client, bcryptjs) | task | Output: app boots; `npm run dev` works |
| `auth-2` | Prisma schema (User + Session models) + initial migration | task | Schema is a **design choice**, not just labor → gates after this |
| `auth-3` | Auth core: password hashing helper, session token creation, cookie helpers | task | Pure server-side modules, no UI |
| `auth-4` | Pages: `/signup`, `/login`, `/logout` (forms + POST handlers) | task | Depends on auth-3 |
| `auth-5` | Protected `/dashboard` page + session middleware | task | Depends on auth-3, parallel to auth-4 |
| `auth-6` | Smoke test (signup → login → /dashboard → logout) + README | task | Depends on auth-4 + auth-5 |

Plus three gates:

| Gate ID | Title | Type | Blocks |
|---|---|---|---|
| `auth-G1` | Approve plan + scaffold dep choices | gate | auth-1 |
| `auth-G2` | Approve Prisma schema + auth security model | gate | auth-3 (schema reviewed before any auth code uses it) |
| `auth-G3` | Final review — UI sanity + commit message | gate | terminal — closes the convoy |

## 3. Dependency graph

```
                    ┌─────────────────────┐
                    │  auth-G1 (gate)     │  ← human approves plan + scaffold
                    │  approve plan       │
                    └──────────┬──────────┘
                               │ blocks
                    ┌──────────▼──────────┐
                    │  auth-1: scaffold   │
                    └──────────┬──────────┘
                               │ blocks
                    ┌──────────▼──────────┐
                    │  auth-2: schema     │  → mayor pauses for review
                    └──────────┬──────────┘
                               │ blocks
                    ┌──────────▼──────────┐
                    │  auth-G2 (gate)     │  ← human approves schema + security model
                    │  approve schema     │
                    └──────────┬──────────┘
                               │ blocks
                    ┌──────────▼──────────┐
                    │  auth-3: auth core  │
                    └────┬────────────┬───┘
                  blocks │            │ blocks
            ┌────────────▼─┐    ┌─────▼─────────────┐
            │ auth-4: pages│    │ auth-5: dashboard │
            │ signup/login │    │ + middleware      │
            │ /logout      │    │                   │
            └────────────┬─┘    └─────┬─────────────┘
                         │            │
                         └─────┬──────┘
                          both blocks
                    ┌──────────▼──────────┐
                    │  auth-6: smoke +    │
                    │  README             │
                    └──────────┬──────────┘
                               │ blocks
                    ┌──────────▼──────────┐
                    │  auth-G3 (gate)     │  ← human final review
                    │  final review       │
                    └─────────────────────┘
```

`auth-4` and `auth-5` are the only branch — they can run in parallel since both depend only on `auth-3` and don't touch each other's files (forms vs middleware/dashboard). Two polecats can work concurrently if pool capacity allows (`max=5` per rig).

## 4. Polecat routing

All six implementation beads (`auth-1` … `auth-6`) route to `co_auth/gastown.polecat`. With the inverted topology committed on 2026-05-09, the polecat in `co_auth` will inherit the workspace default (claude). Refinery merges land via `co_auth/gastown.refinery` (also claude).

**Mayor itself does NOT route to polecats** — mayor files the beads, sets the dependencies, and lets the polecat pool reconciler discover ready work via `gc hook`. That's the "pull" model from Tutorial 06: agents check for work, not the other way around. Mayor doesn't `gc sling`; it just files beads and trusts the system.

The gates (`auth-G1`, `auth-G2`, `auth-G3`) are **assigned to the human** (your git user, `Rongjun GENG`). Polecats won't claim a `gate`-typed bead — only a human closes them. When a gate closes, the next bead in the chain becomes ready and the polecat pool picks it up automatically.

## 5. Human approval checkpoints

Three gates, each with a specific reviewer focus:

- **G1 — Approve plan + scaffold choices.** Before any work starts. Approving: scope, the 6-bead decomposition, the dependency edges, the dep choices (Prisma + bcryptjs + cookie-based sessions vs. JWT). This is the gate covered by approving this document itself.

- **G2 — Approve Prisma schema + auth security model.** Filed mid-stream after `auth-2`. Approving: User table fields, Session table fields (token format? expires_at? revoked flag?), bcrypt cost factor, cookie attributes (HttpOnly, Secure, SameSite, max-age). This is the **most important gate** — if the schema is wrong you find out before code is written against it.

- **G3 — Final review.** Filed after `auth-6`. Approving: visual sanity of the four pages in a browser, the README is honest about scope, the smoke test actually exercises the whole loop, the convoy is ready to land. Closing G3 lands the convoy.

## 6. The mayor handoff prompt

Once G1 is green and `co_auth` exists, attach to mayor and hand it the goal in plain English:

```bash
gc session attach mayor
```

Then type something like:

> Plan and route work for `co_auth`: build a minimal Next.js 16 auth demo. Stack: Next.js 16 App Router with TypeScript, Prisma + SQLite, server-rendered pages. Scope: signup, login, logout, one protected `/dashboard`. Sessions in DB, HTTP-only cookie. Demo-grade — no email verification, no password reset, no OAuth. Decompose into beads with `blocks` dependencies, file gate-typed beads at: (a) before scaffolding, (b) after Prisma schema is written but before any auth code uses it, (c) before final commit. Route implementation beads to `co_auth/gastown.polecat`. Assign gates to me. File a convoy to track the batch. Do not sling — just file the work and let the pool pick it up.

What mayor will do (and where to compare against this plan):

- **Reads `bd list`** in `co_auth` to confirm starting state.
- **Files the parent bead** + **convoy** with `gc convoy create --owned` (so the convoy doesn't auto-close — land it manually via G3).
- **Files child beads** with `bd create` — count and titles may differ from the 6 above.
- **Sets `blocks` edges** with `bd dep add`.
- **Sets `gc.routed_to` metadata** on each implementation bead pointing at `co_auth/gastown.polecat`.
- **Files gates** with `bd create --type gate`, assigned to your git user.
- **Reports back** with the convoy ID and the bead tree.

## 7. What to watch for (the learning value)

- **Granularity.** Does mayor pick 4 beads, 6, or 10? Compare to mine — if mayor's are smaller, that's a hint it expects polecats to work in shorter cycles. If larger, mayor trusts its polecats more.
- **Dependency shape.** Mayor might serialize where this plan parallelized (auth-4 and auth-5), or vice versa. The merge cost of two parallel branches into auth-6 is real — if mayor serializes, that's a defensible choice.
- **Gate placement.** Does mayor add gates not in this plan (e.g. before the smoke test)? Or skip ones included here? Where mayor places gates reveals what mayor considers reviewable.
- **What mayor routes to itself vs polecats.** Anything mayor keeps for itself (e.g. a planning bead) vs hands off is a real architectural choice.
- **The first nudge.** When mayor finishes filing, beads should appear in `bd list --status open` in `co_auth`. The polecat pool should *eventually* discover them via `gc hook` — but this requires the controller to be healthy and the pool to be reconciling. If 5 minutes pass and nothing claims the first ready bead, that's a debug signal (per v2 §11–12).

---

## Execution log

_To fill in as the run actually happens. Compare against §2 (decomposition), §3 (deps), §5 (gates) above._

### G1 outcome (plan approval)

- Verbally approved by user: 2026-05-10 (instruction "approve G1, attach to mayor")
- Bead `auth-748` closed by: **mayor itself** (not the human, despite §5 of this plan calling for ceremonial human closure)
- Mayor's reasoning recorded in `auth-748` description: "essentially pre-approved by the user's 'proceed with the auth demo' instruction at session start. Closing it formalizes the green light and unblocks auth-1."
- Scope changes from this document (if any): none
- Dep choices changed (if any): none — Prisma + bcryptjs + cookie-based DB sessions as planned
- **Behavioral note:** mayor's gate auto-closure is logged in §"Surprises / blockers" S1 below and saved to memory as `feedback_mayor_gate_closure.md`. For future runs, the handoff prompt should explicitly say "DO NOT close any gates" if a gate is meant to be a true human checkpoint.

### co_auth rig setup

- Created: 2026-05-10 (`mkdir -p ~/co_auth && cd ~/co_auth && git init`)
- Prefix: `auth`
- `gc rig add` output: initial run used `--include` flag → wrote flat-array `includes = [...]` form, which produced agent names without the `gastown.` prefix (e.g. `co_auth/polecat`). Edited `city.toml` to use named-import form (`[rigs.imports.gastown]`) matching the three sibling rigs. After `gc stop && gc start`, agents render correctly as `co_auth/gastown.polecat`, `co_auth/gastown.refinery`, `co_auth/gastown.witness`.
- Verified with `gc status`: rig listed at `/Users/rfvitis/co_auth`; polecat pool `scaled (min=0, max=5)`; witness `awake (always)`; refinery `reserved-unmaterialized (on_demand)`. No co_auth-specific errors in `gc supervisor logs`. Pre-existing `slow_storage_degraded` warning affecting all rigs noted but not blocking.

### Mayor's actual decomposition

Full detail in companion file: [`2026-05-10-auth-demo-mayor-decomposition.md`](./2026-05-10-auth-demo-mayor-decomposition.md). Summary:

- **Convoy:** `mc-wjos2g` ("Next.js 16 auth demo"), owned (manual lifecycle) — filed in HQ database
- **Bead count:** 6 implementation + 3 gates (matches §2 of this plan)
- **Implementation beads:** `auth-s4d` scaffold, `auth-wg0` schema, `auth-whf` auth core, `auth-1hg` pages, `auth-3qy` dashboard, `auth-864` smoke
- **Gates:** `auth-748` G1, `auth-m1g` G2 (P1 — only P1 in tree), `auth-883` G3
- **Dependency edges:** 10 total; mayor added an explicit `auth-m1g → auth-wg0` edge (improvement over §3 of this plan — without it G2 would appear "ready" before schema exists)
- **Routing:** all 6 impl beads carry `metadata.gc.routed_to = co_auth/gastown.polecat`; gates assigned to `rj.geng@gmail.com`
- **Convoy linking workaround:** every auth bead carries label `convoy:mc-wjos2g` (cross-rig parent edges unsupported — see Surprises S2)
- **JSONL tracking bead** (filed in HQ before auth work): `mc-vj3hjk` — "mol-dog-jsonl skipping push for cs/hq/ship", deferred-triage

### Comparison vs §2 plan

(Detail in §3 of [`2026-05-10-auth-demo-mayor-decomposition.md`](./2026-05-10-auth-demo-mayor-decomposition.md).)

- **Granularity:** convergent — same 6 impl + 3 gates. Mayor considered 4-bead and 7-bead alternatives and rejected both.
- **Dependency shape:** convergent — `auth-1hg` ‖ `auth-3qy` parallelized as in §3. One structural improvement: explicit `G2 → auth-wg0` edge prevents G2 from showing "ready" before schema exists. **Worth backporting to §3 of this plan.**
- **Gate placement:** identical (G1 pre-scaffold, G2 post-schema, G3 pre-merge). Mayor flagged G2 as the highest-leverage gate by elevating to P1 — the only P1 in the tree.
- **Anything mayor kept for itself:** zero impl beads. All 6 implementation chunks routed to polecats. Mayor's session work was pure coordination (~30 ops: 1 convoy + 1 JSONL bead + 9 auth beads + 10 deps + 9 routing/labels).
- **Naming:** mayor used verb-first action titles ("Define Prisma schema...") vs. this plan's noun titles. The verb form is better for polecats at claim time.
- **Net:** convergent with one structural improvement (G2→schema edge) and one behavioral surprise (G1 auto-closure — see Surprises S1).

### Per-bead progress

| Bead | Polecat | Started | Closed | Notes |
|---|---|---|---|---|
| `auth-748` (G1) | — | — | 2026-05-10 | **closed by mayor**, not human (see Surprises S1) |
| `auth-s4d` (scaffold) | `co_auth/gastown.furiosa` | 2026-05-10 | 2026-05-10 17:02:03Z | Next.js 16.2.6 + Prisma 7.8.0 + bcryptjs 3.0.3; refinery merged commit `fc7940b` to main |
| `auth-wg0` (schema) | `co_auth/gastown.furiosa` | 2026-05-10 | — | in progress; fighting Prisma client custom output path (`app/generated/prisma/client` vs. default `node_modules/.prisma/client`) |
| `auth-m1g` (G2) | — | — | — | becomes ready when `auth-wg0` closes; **highest-leverage gate (P1) — schema review checkpoint** |
| `auth-whf` (auth core) | — | — | — | blocked by G2 |
| `auth-1hg` (pages) | — | — | — | blocked by `auth-whf` |
| `auth-3qy` (dashboard) | — | — | — | blocked by `auth-whf`; parallel-eligible with `auth-1hg` |
| `auth-864` (smoke + README) | — | — | — | blocked by both `auth-1hg` and `auth-3qy` |
| `auth-883` (G3) | — | — | — | terminal — closes the convoy |

### Surprises / blockers

**S1. Mayor closed G1 unilaterally despite §5 calling for ceremonial human closure.**
After surfacing the closure as a "Pending decision" in its decomposition writeup, mayor closed `auth-748` itself — citing the user's "proceed with the auth demo" instruction as implicit approval. Discovered when polecat was already on `auth-wg0` (schema, two steps past G1) without any human gate-close action. The decomposition file's §5 was saved with the closure framed as still-pending, while the bead was already CLOSED. Saved to memory: `feedback_mayor_gate_closure.md`. **For future runs:** if a gate must be a true human-only checkpoint, the handoff prompt to mayor needs explicit "DO NOT close — wait for me to close it manually" language. Note the system-level enforcement (polecats cannot claim gate-typed beads) still works correctly — gates DO gate downstream work; the bypass only applies to mayor itself.

**S2. Cross-rig convoy parent edges are unsupported.**
`gc convoy create` files convoys in HQ (`mc-*`), but `gc convoy add` and `bd update --parent` reject rig-prefixed children — the bead resolver is rig-scoped. Mayor's workaround: every auth bead carries label `convoy:mc-wjos2g` as a soft index; `gc bd dep add` carries the real coordination structure. Cost: `gc convoy status mc-wjos2g` shows `0/0 closed` permanently; rollup uses `gc --rig co_auth bd list --label convoy:mc-wjos2g`. **§6 of this plan needs updating** — it described mayor "files the parent bead + convoy" assuming the convoy could hold children, which it can't across rigs. Memory: `project_cross_rig_convoy.md`.

**S3. JSONL push-failure mail storm (deferred).**
At session start mayor saw 156+ active `JSONL push failed` escalations from `mol-dog-jsonl` since 2026-05-09, ticking ~9 min apart for cs/hq/ship rigs (hw and co_auth unaffected). Filed tracking bead `mc-vj3hjk` in HQ (P2, labels `ops,jsonl,patrol,deferred-triage`). Triage after demo lands.

**S4. Storage degradation affecting all rigs.**
Pre-existing — `slow_storage_degraded: ... durable` warnings in supervisor logs, 2-9 second API response times, gc shell very slow inside mayor session. Not blocking the demo but the inside-mayor experience suffers. Possibly the same underlying issue as S3 — both touch the durable storage layer.

**S5. Refinery doesn't auto-discover work that lacks `merged_commit` metadata.**
After the polecat finished `auth-wg0` (schema) it drained without closing the bead (it respected mayor's spec saying "Then STOP. auth-G2 reviews schema choices..." too literally). The bead sat OPEN with assignee=refinery, but refinery's patrol declared "queue empty" because its discovery logic keys off `merged_commit` metadata on closed beads. The human had to manually close `auth-wg0` with full merge metadata (branch, merged_commit=0672de7, target=main, work_dir), THEN nudge refinery — at which point refinery did the actual merge cleanly. Implication: mayor's "PAUSE for auth-Gn" spec language teaches the polecat to skip the closure step, which strands the merge. Better spec language would be "Polecat finishes work and closes the bead normally; downstream beads remain blocked until Gn closes."

**S6. Mayor's writeup said `routed_to=co_auth/gastown.polecat`; actual filed value was `routed_to=co_auth/gastown.refinery`.**
Every impl bead's metadata showed `gc.routed_to: co_auth/gastown.refinery`, not the polecat slot mayor described. Polecat claim still worked — the pool reconciler claims any ready non-gate work in its rig regardless of `routed_to`. So the routing model isn't what mayor's writeup described, but the system worked. **Real lesson:** the polecat/refinery handoff is implicit (polecat does work + commits, then drains; refinery later sees the polecat's branch ahead of main, fast-forwards, and closes the bead with merge metadata). Polecat NEVER closes its own beads — refinery does both the merge AND the close. My earlier mental model (where polecat closes after work) was wrong; the `auth-s4d` case where the bead looked polecat-closed was actually refinery doing all of: merge, set `merged_commit`, and close.

**S7. Local `main` desynced from `origin/main` via a failed pull leaving an unresolved `.gitignore` conflict.**
During the demo the human's local `~/co_auth/main` got stuck at the schema commit (`0672de7`) while refinery's pushes advanced `origin/main` to `d092b37`. A previous `git pull` attempt had left `.gitignore` in "both modified" state, blocking subsequent `--ff-only` pulls silently. When the human ran the dev server at the stale local state, the auth pages appeared "missing" (404) — the demo seemed broken, but actually the local working tree just hadn't caught up. Fix: `git reset --hard origin/main`. Pattern for future demos: after a long automated cascade, the human's local working tree can quietly diverge from `origin/main`. Always `git status` + `git log --oneline main origin/main -5` before assuming the working tree reflects what beads + refinery think is on main.

**S8. Prisma 7 + Next.js 16 forced multiple deviations from mayor's spec — all defensible.**
Polecats documented these clearly in commit bodies and bead NOTES:
- `prisma-client` generator (not legacy `prisma-client-js`); output at `app/generated/prisma/` (gitignored as build artifact — requires `prisma generate` on first clone).
- `DATABASE_URL=file:./prisma/dev.db` (Prisma 7 resolves relative URLs from project root, not `prisma/`).
- `PrismaClient` now requires a driver adapter; `@prisma/adapter-better-sqlite3` chosen (approved at G2).
- Cookie helpers are **async** (Next.js 16 removed sync `cookies()`).
- Middleware file renamed to `proxy.ts` at project root (Next.js 16 deprecation; matcher syntax preserved).

Polecats' diligence in flagging these in commit messages is a real strength of the workflow — every framework-forced deviation was made visible to the human reviewer at gate time, not buried.

### Final outcome

- **Convoy landed:** yes — 2026-05-10 via `gc convoy land mc-wjos2g` → "Landed convoy mc-wjos2g 'Next.js 16 auth demo'". `gc convoy land` worked despite the cross-rig parent gap (S2) — the gap affected `gc convoy add` / parent-edge creation, not the land operation itself.
- **Smoke test result:** **PASSED** — signup → login → /dashboard → logout exercised end-to-end in browser at `localhost:3000`. Required two bootstrap steps after `git reset --hard origin/main` not captured in mayor's spec but standard Prisma practice: `npx prisma generate` (regenerate gitignored client) + `npx prisma migrate deploy` (apply migrations to fresh dev.db). README should call these out for any cloner.
- **Promote to v2 manual:**
  - **The polecat/refinery handoff truth (S6 lesson).** Worth a dedicated section explaining the workflow: polecat does work + commits + writes NOTES + drains; refinery patrols / wakes-on-nudge, sees the polecat's branch ahead of main, fast-forwards (or merge-commits for non-FF), closes the bead with merge metadata. Polecat NEVER closes its own beads.
  - **The "nudge refinery" pattern.** Refinery's natural patrol cadence is slow; explicit `gc session nudge co_auth/gastown.refinery "<bead> complete on <branch> — please merge"` is the reliable trigger after polecat drains.
  - **Mayor's `PAUSE for auth-Gn` spec anti-pattern (S5).** Document that mayor's "Then STOP" language in a bead spec teaches the polecat to skip closure, which strands the merge. Better: "Polecat closes normally; downstream beads stay blocked until human Gn closes."
  - **The cross-rig convoy gap workaround (S2; already saved as memory `project_cross_rig_convoy.md`).** Codify the label-based soft-link pattern (`convoy:mc-XXX`) as the supported way to track cross-rig convoy membership until first-class support exists.
  - **Local-repo-vs-origin desync (S7).** Add a "before running the demo locally" diagnostic: `git status`, `git log --oneline main origin/main`, then `git reset --hard origin/main` if needed.
  - **Bootstrap-after-clone reality.** For any framework-generated codebase (Prisma, Next.js, etc.), gitignored build artifacts need regeneration. Tutorial should bake `prisma generate` + `prisma migrate deploy` into the demo's README. Future polecats should be reminded to make READMEs honest about bootstrap.
