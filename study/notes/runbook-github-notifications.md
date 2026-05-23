# Runbook: GitHub notification channels (out-of-process watch)

On watch-days (PR-in-review state) you're waiting on upstream maintainer action — but the local Mac doesn't need to be awake or actively checked to know when something happens. GitHub has out-of-process notification channels that run independently of this CLI/agent setup.

**Scope:** generic. Captures the "you don't have to poll" insight from Day-28 (2026-05-19).

**Pairs with:**

- `study/scripts/status-check.sh` — the manual-poll fallback when you want a direct read
- `study/notes/upstream-engagement-tracker.md` — the persistent state file the polls feed

**Last updated:** 2026-05-19 (Day-28 PM, in the middle of #2316 active-review wait)

---

## The channels

| Channel | Where it runs | Best for |
|---|---|---|
| **Email** | Mail provider | Authoritative async log; searchable; tolerates long latency |
| **GitHub mobile app** | iOS/Android push | Minutes-latency surfacing on the go |
| **Web notifications (bell)** | github.com when logged in | When already at a desk |
| **Atom/RSS** | Any RSS reader | Per-repo or per-user activity stream |
| **Webhooks** | Wherever you wire it | Custom routing (Slack, scripts) — overkill for solo workflow |
| **`gh api notifications`** | Local CLI, on demand | Programmatic morning sweep that returns the same unread stream as the bell, as JSON |

The key property: **email and mobile push run on infrastructure you don't control or maintain.** Laptop closed, Wi-Fi off, agent not running — they still deliver.

## Configuration paths

- **Per-repo subscription** — Repo page → `Watch` dropdown → "Custom" → check Pull requests + Releases (recommended for `gastownhall/gascity` and `gastownhall/beads`). Don't pick "All Activity" — drowns the signal on a high-volume repo.
- **Account-level email** — `github.com/settings/notifications` → granular per-event toggles + email frequency
- **Mobile app** — iOS/Android; sign in once, per-repo and per-PR toggles
- **Programmatic** — `gh api notifications` returns unread-notifications JSON; useful for a `status-check.sh`-style morning sweep that bypasses the web UI

## What to subscribe to (specific to this project)

- ✅ Review activity on PRs you opened (#2088, #2136, #2316) — default for PR author
- ✅ @mentions on issues you commented on — would have surfaced #1487's closure via #2127 (julianknutsen, merged 5/16) when it happened, instead of being caught stale on Day-27
- ✅ Releases on `gastownhall/beads` — v1.0.5 surface (mc-mxl4vc unblocker)
- ❌ All-activity on `gastownhall/gascity` — too noisy

## When this replaces `status-check.sh`

The script is useful for **deliberate checks** (morning read, EOD close-out, "is anything moving?"). Notifications are useful for **passive surfacing** (something just happened, here's what). They're complementary:

- Notification arrives → know something happened
- `status-check.sh` confirms → see the full timeline + state + the other PRs in one frame

The anti-pattern is what we did on Day-28: 4 manual status-checks across the day while waiting passively. That's polling work the email/mobile channels could have done for free.

## Drill takeaway

Anything that runs purely on GitHub's servers (label changes, comments, reviews, merges, releases) can be surfaced *to you* without a single local process being awake. The local Mac's job is only to *react* — read the diff, draft the response, push the fix. Reaction is bounded; surveillance shouldn't be.
