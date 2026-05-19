#!/bin/bash
# Day-N morning/midday/EOD status check for the 3 upstream PRs.
# Usage:
#   ./status-check.sh             # default: timeline events since 12h ago UTC
#   ./status-check.sh "2026-05-19T13:00:00Z"   # explicit threshold

set -u

threshold="${1:-$(date -u -v-12H '+%Y-%m-%dT%H:%M:%SZ')}"

echo "=== $(date) — timeline threshold ${threshold} ==="
echo

echo "=== PR #2316 (mc-1zccc2 fix) ==="
gh pr view 2316 --repo gastownhall/gascity \
  --json state,reviewDecision,updatedAt,comments,latestReviews \
  | jq '{state, reviewDecision, updatedAt,
         comment_count: (.comments|length),
         latest_review_when: ((.latestReviews[-1].submittedAt // "")[:16])}'
echo

echo "=== #2316 timeline since ${threshold} ==="
gh api repos/gastownhall/gascity/issues/2316/timeline --paginate \
  | jq -r --arg t "${threshold}" '.[] | select((.created_at // .submitted_at) >= $t)
            | "\(.created_at // .submitted_at) \(.event // .__typename) \(.actor.login // .user.login) \(.label.name // .state // "")"'
echo

echo "=== other PRs (updatedAt only) ==="
for pr in 2088 2136; do
  gh pr view $pr --repo gastownhall/gascity --json updatedAt -q ".updatedAt" \
    | xargs -I{} echo "#$pr updatedAt={}"
done
