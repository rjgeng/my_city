<!--
soak-evidence-template.md — per-fire record for the mc-jhsp8y re-soak (post-#2564/#2598).
Copy this block into the day's note (study/notes/YYYY-MM-DD-dayNN-...md), one block
per compactor fire. Fill from `study/scripts/soak-watch.sh <day>` output.
Soak window: 2026-05-29 -> 2026-06-01 (3-day min from upgrade). Acceptance #3: >=3
clean fires under race conditions. Day-1 close is forbidden even if clean (anti-plan #25).
-->

## Fire record — Day-NN (YYYY-MM-DD)

| field | value |
|---|---|
| fire `order.fired` ts |  |
| end ts / type | `order.completed` \| `order.failed` |
| exit / message |  |
| gc version | HEAD-________ |
| supervisor PID / uptime |  |
| **pack guard** (deployed run.sh md5 == source) | OK \| MISMATCH (`____`) |

**Marker mix**

| dir | count | db / reason (if present) |
|---|---|---|
| `compact-pending-gc` |  |  |
| `compact-quarantine` |  |  |

**Race-trigger check** — did a writer (doctor commit) land inside `[fired, end]`?

| field | value |
|---|---|
| doctor events in window | yes / no |
| writer-class events in window (count) |  |

**G5 verdict** (from soak-watch §4 — pick one)

- [ ] **PASS** — pending-GC ≥1, quarantine 0, doctor wrote in-window. Defer gate fired under a real race. *(counts toward the ≥3.)*
- [ ] **PASS (weak)** — pending-GC ≥1, quarantine 0, but no doctor write seen in-window. Defer fired; race not confirmed.
- [ ] **MISSING-EVIDENCE** — exit-0, no markers, no in-window writer. Race window missed. NOT a pass (Day-38 plan L75).
- [ ] **INCONCLUSIVE** — exit-0, doctor wrote in-window, but no marker. Gate may have no-op'd. Investigate.
- [ ] **FALSIFIER** — quarantine marker reappeared → PR #2564 didn't cover our case. **Re-open mc-cqm9nl.**
- [ ] **BLOCKED/OTHER** — exit-1 from a pre-existing gate or unrelated cause. Not a soak data point.

**Running tally:** clean-under-race fires so far = ____ / 3

**Notes / surprises:**

<!-- end fire record -->
