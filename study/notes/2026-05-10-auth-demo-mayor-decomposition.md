# Day 4 — Mayor's actual decomposition of the auth demo

**Filed:** 2026-05-10 (mayor session 08:22 PDT)
**Companion to:** [`2026-05-10-mayor-led-auth-demo.md`](./2026-05-10-mayor-led-auth-demo.md) (the pre-decomposition reference plan)
**Status:** Awaiting G1 closure to start; polecats idle and reconciler-ready.

This is what mayor produced when handed the day-4 epic in plain English. The reference plan in `2026-05-10-mayor-led-auth-demo.md` was written ahead of time precisely so we could compare; differences (or convergences) are the learning value.

---

## 1. JSONL tracking bead — filed in HQ first

Before starting the auth work, mayor filed a tracking bead for the operational issue dominating the inbox:

**`mc-vj3hjk`** — *"mol-dog-jsonl skipping push for cs/hq/ship"*

- Type: `task`, Priority: P2, Labels: `ops,jsonl,patrol,deferred-triage`
- No routing — this is mayor's-time work, not polecat-time work.
- Body captures: symptom timeline (live `JSONL push failed` storm since 2026-05-09 15:40, counter 4 → 161+ at session start; stale `JSONL spike detected` 3-message window from the same afternoon), evidence (`DOG_DONE: jsonl — exported 0/3, records: 0, push: skipped, failed: cs hq ship` from `.gc/events.jsonl`), affected-vs-unaffected table (cs/hq/ship failing, hw succeeding, auth queued), four ranked hypotheses (rig-local config likely), explicit out-of-scope ("silencing the wisp would lose the signal").

Triage deferred until after the auth demo lands.

---

## 2. Auth demo — decomposition and tree

### Convoy

**`mc-wjos2g`** — *"Next.js 16 auth demo"*, owned (manual lifecycle, no auto-close).

### Implementation beads (in `co_auth`, prefix `auth`)

| ID | Type | Priority | Title |
|---|---|---|---|
| `auth-748` | gate | P2 | Approve plan + dep choices before scaffolding (G1) |
| `auth-s4d` | task | P2 | Scaffold Next.js 16 (App Router + TS) + install Prisma + bcryptjs |
| `auth-wg0` | task | P2 | Define Prisma schema (User + Session) + initial SQLite migration |
| `auth-m1g` | gate | **P1** | Approve Prisma schema + auth security model (G2) |
| `auth-whf` | task | P2 | Implement auth core: password hashing, session lifecycle, cookie helpers |
| `auth-1hg` | task | P2 | Build /signup, /login, /logout pages with server actions |
| `auth-3qy` | task | P2 | Build protected /dashboard + session middleware |
| `auth-864` | task | P2 | Smoke test (signup → login → /dashboard → logout) + README |
| `auth-883` | gate | P2 | Final review — UI, README, smoke; close convoy (G3) |

All 9 beads carry the label `convoy:mc-wjos2g` (see §4 for why).
All 6 impl beads carry `metadata.gc.routed_to = co_auth/gastown.polecat`.
All 3 gates are assigned to `rj.geng@gmail.com` (the bead-system identity for the human's git user).

### Dependency graph

```
auth-748  G1               <- entry: human closes to start
   |
   v  (blocks)
auth-s4d  scaffold
   |
   v
auth-wg0  schema
   |  \
   |   `--> auth-m1g  G2   <- gate dormant until auth-2 closes
   |
   v
auth-whf  auth core   <- needs auth-wg0 AND auth-m1g
   |
   +-- auth-1hg  pages       (parallelizable)
   |
   `-- auth-3qy  dashboard   (parallelizable)
       |
       v
auth-864  smoke + README   <- needs auth-1hg AND auth-3qy
   |
   v
auth-883  G3              <- terminal; close to land convoy
```

10 dep edges total. Verified via `gc bd dep tree auth-883`. The tree printer dedupes the redundant `auth-whf -> auth-wg0` edge (transitively covered by `auth-whf -> auth-m1g -> auth-wg0`); the edge is still recorded.

### How it actually starts

`gc bd ready` from `co_auth` correctly returns "no work" — gates can't be claimed by polecats. **G1 (`auth-748`) closing is the only thing the system is waiting for.** When the human closes it:

1. `auth-s4d` becomes `ready` (its only blocker resolved)
2. The polecat pool reconciler in `co_auth` sees a ready bead with `gc.routed_to=co_auth/gastown.polecat`
3. One of the 5 polecat slots in `co_auth` (currently `stopped-but-scaled`) wakes up and claims it
4. Polecat does the scaffold work in its worktree, opens an MR, refinery merges, bead closes
5. `auth-wg0` becomes ready -> next polecat -> ... and so on, up to `auth-2` closing
6. `auth-2` closing also makes `G2` ready for human review (because G2 needs auth-wg0)
7. Human closes G2 -> `auth-3` becomes ready -> ... cascading until G3
8. Human closes G3 -> convoy is land-able

Rig state at handoff: `gc rig status co_auth -> Suspended: no, witness running, refinery and polecats stopped-but-scaled`. Refinery and polecats wake on demand.

---

## 3. Decomposition compared to the reference plan

| Dimension | Reference plan (§2-3 of `2026-05-10-mayor-led-auth-demo.md`) | What mayor filed | Notes |
|---|---|---|---|
| **Granularity** | 6 impl + 3 gates | 6 impl + 3 gates | Genuine convergence. Mayor considered 4 chunks (collapse pages + dashboard) and 7 (split scaffold from `npm i`); rejected both. The signup/login/logout flows share a code surface and merge cost; dashboard + middleware share another; a 2-line scaffold-only bead would be churn. |
| **Dependency shape** | auth-4 \|\| auth-5 in parallel, both feeding auth-6 | Same parallelism preserved | Two polecat slots can run them simultaneously; merge into auth-6 is cheap (different file trees: `app/signup/`, `app/login/`, `app/logout/` vs. `app/dashboard/`, `middleware.ts`). |
| **Gate placement** | G1 pre-scaffold, G2 post-schema, G3 pre-merge | Identical | The reference's gate placement is correct on the merits. G2 is the highest-leverage of the three: errors caught here don't propagate into auth-3..6. Mayor flagged this by filing G2 at P1 (the only P1 in the tree). |
| **Explicit `G2 -> auth-2` edge** | Implied by ordering | Made explicit (`gc bd dep add auth-m1g auth-wg0`) | Without this edge, G2 appears "ready" before auth-2 even exists, which would invite premature human review. The redundant `auth-3 -> auth-2` direct edge is suppressed in the tree printer because it's transitive through G2; the edge is still in the database as defense-in-depth. |
| **What mayor kept for itself** | "Mayor doesn't sling — files and trusts the system" | Zero impl beads | All 6 implementation chunks routed to `co_auth/gastown.polecat`. No "design X" bead for mayor; design questions are resolved at the human gates (G1 chooses the stack, G2 reviews the schema, G3 reviews UX). Mayor's session work was approximately 30 ops: 1 convoy + 1 JSONL bead + 9 auth beads + 10 deps + 9 routing/labels. All coordination. |
| **Naming style** | Generic noun titles ("Schema work") | Verb-first action titles ("Define Prisma schema...") | Helps polecats disambiguate at claim time. |

Net: **convergent on the reference plan**, with one structural improvement (the explicit `G2 -> auth-2` edge).

---

## 4. The one surprise — cross-rig convoy gap

`gc convoy create` always files convoys in the city's HQ database (mc-* prefix), even when run from inside a rig directory or with `--rig <rig>`. Convoys are city-level coordination artifacts.

But: `gc convoy add <convoy> <child>` and `gc bd update <child> --parent <convoy>` both fail when parent and child live in different rig databases. The bead resolver looks up the parent in the same database (rig) as the child, and `mc-wjos2g` (HQ) is invisible to a lookup scoped to `co_auth`.

**Reproduction:**

```bash
gc convoy add mc-wjos2g auth-748
# -> gc convoy add: getting bead "auth-748": bead not found

gc --rig co_auth bd update auth-748 --parent mc-wjos2g
# -> Error getting parent mc-wjos2g: not found: issue mc-wjos2g
```

**Workaround applied:** every auth bead got the label `convoy:mc-wjos2g` as a soft index. The dependency tree (via `gc bd dep add`) is the real coordination structure; the convoy bead is a tracking marker.

**Cost:**
- `gc convoy status mc-wjos2g` shows `0/0 closed` permanently (it cannot see its children).
- Real rollup needs `gc --rig co_auth bd list --label convoy:mc-wjos2g` instead.
- `gc convoy land mc-wjos2g` may not behave as documented for cross-rig convoys; manual close of the convoy bead is the safe path.

**Implication for the day-4 note:** §6 of `2026-05-10-mayor-led-auth-demo.md` describes mayor "Files the parent bead + convoy with `gc convoy create --owned`" — that assumes the convoy can hold the children, which it can't across rigs. Either:

- The day-4 note's §6 should be updated to describe the label-based workaround, or
- `gc` should grow first-class support for cross-rig parent edges (probably the right long-term answer; convoys are explicitly billed in CLAUDE.md as the cross-rig coordination primitive).

This is a worthy follow-up bead in its own right after the auth demo lands — saved as project memory for the next mayor session.

---

## 5. Pending decision

Polecats are idle and waiting. **Closing `auth-748` (G1) is the only thing that needs to happen** for the engine to start moving. Two reasonable choices:

1. **Leave G1 open for the human to close ceremonially.** Preserves the "feel the gates" moment from the day-4 exercise design.
2. **Close G1 immediately as part of this session.** The user's "proceed with the auth demo" instruction is implicit approval already; the gate becomes paperwork.

Mayor surfaced this choice rather than deciding unilaterally — gates exist precisely because some calls belong to the human.

---

## 6. Execution log (to fill in as the run progresses)

This section parallels §7 of `2026-05-10-mayor-led-auth-demo.md` ("Execution log"). Mayor leaves it empty here; humans fill it in or polecats append from their session work.

### G1 outcome

- Closed at:
- By:
- Notes:

### Per-bead progress

| Bead | Polecat | Started | Closed | Notes |
|---|---|---|---|---|
| auth-s4d (auth-1) | | | | |
| auth-wg0 (auth-2) | | | | |
| auth-whf (auth-3) | | | | |
| auth-1hg (auth-4) | | | | |
| auth-3qy (auth-5) | | | | |
| auth-864 (auth-6) | | | | |

### Gate outcomes

- G1 (auth-748):
- G2 (auth-m1g):
- G3 (auth-883):

### Surprises / blockers

(things that broke flow, debugging needed, deviations from this plan or the reference plan)

### Final outcome

- Convoy landed:
- Smoke test result:
- Anything from this run worth promoting to v2 manual:
