#!/bin/bash
# soak-watch.sh — mc-jhsp8y re-soak per-fire evidence capture (Day-39+, post-#2564/#2598)
#
# Captures one compactor fire's evidence and classifies the G5 verdict from the
# Day-38 plan: under PR #2564 the success signal is non-zero pending-GC markers
# AND zero quarantine markers, WITH a doctor commit landing inside the flatten
# window. A silent fire (no markers) is NOT a pass — it is a missing-evidence
# soak (race window missed or doctor not firing). See:
#   study/notes/2026-05-28-day38-plan-gc-upgrade-and-mc-jhsp8y-resoak.md (G5)
#
# Usage:
#   ./soak-watch.sh                 # today (local/PT)
#   ./soak-watch.sh 2026-05-30      # a specific soak day
#
# Read-only. Mutates nothing. Run from anywhere; paths resolve to my-city.

set -u

CITY="$HOME/my-city"
EVENTS="$CITY/.gc/events.jsonl"
PACK_STATE="$CITY/.gc/runtime/packs/dolt"
QUAR_DIR="$PACK_STATE/compact-quarantine"
PGC_DIR="$PACK_STATE/compact-pending-gc"
DEP_RUNSH="$CITY/.gc/system/packs/dolt/commands/compact/run.sh"
SRC_RUNSH="$CITY/study/gascity-src/examples/dolt/commands/compact/run.sh"

DAY="${1:-$(date +%Y-%m-%d)}"

md5of() { md5 -q "$1" 2>/dev/null || md5sum "$1" 2>/dev/null | awk '{print $1}'; }
# Count real markers in a dir, excluding the .tmp.*/.probe.* temp files run.sh creates.
count_markers() {
  local d="$1"
  [ -d "$d" ] || { echo 0; return; }
  find "$d" -maxdepth 1 -type f ! -name '*.tmp.*' ! -name '*.probe.*' 2>/dev/null | wc -l | tr -d ' '
}
dump_markers() {
  local d="$1"
  [ -d "$d" ] || return
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.tmp.*|*.probe.*) continue ;; esac
    echo "    --- $(basename "$f") ---"
    sed 's/^/    /' "$f"
  done
}

echo "=================================================================="
echo " mc-jhsp8y soak-watch — day=$DAY   ($(date))"
echo "=================================================================="

# ---- 0. Environment + stale-pack guard (re-verify every run) ------------
echo
echo "## 0. Environment"
echo "gc version : $(gc version 2>&1 | head -1)"
echo "supervisor : $(gc supervisor status 2>&1 | head -1)"
DEP_MD5=$(md5of "$DEP_RUNSH"); SRC_MD5=$(md5of "$SRC_RUNSH")
if [ "$DEP_MD5" = "$SRC_MD5" ] && [ -n "$DEP_MD5" ]; then
  echo "pack guard : OK  deployed compact/run.sh == source-of-truth ($DEP_MD5)"
else
  echo "pack guard : *** MISMATCH *** deployed=$DEP_MD5 source=$SRC_MD5"
  echo "             Deployed pack is STALE/regressed — soak would test the wrong"
  echo "             script. Re-extract before trusting any fire (see"
  echo "             feedback_gc_upgrade_stale_system_packs). HALT soak read."
fi

# ---- 1. Compactor fire events for the day -------------------------------
echo
echo "## 1. Compactor fire events ($DAY)"
grep -a "mol-dog-compactor" "$EVENTS" 2>/dev/null \
  | jq -r --arg d "$DAY" 'select((.type|test("^order\\.")) and (.ts[:10]==$d))
      | "  \(.ts)  \(.type)  \(.message // "-")"'
FIRED_TS=$(grep -a "mol-dog-compactor" "$EVENTS" 2>/dev/null \
  | jq -r --arg d "$DAY" 'select((.type=="order.fired") and (.ts[:10]==$d)) | .ts' | tail -1)
END_LINE=$(grep -a "mol-dog-compactor" "$EVENTS" 2>/dev/null \
  | jq -r --arg d "$DAY" 'select((.type|test("^order\\.(completed|failed)$")) and (.ts[:10]==$d)) | "\(.ts)\t\(.type)\t\(.message // "-")"' | tail -1)
END_TS=$(printf '%s' "$END_LINE" | cut -f1)
END_TYPE=$(printf '%s' "$END_LINE" | cut -f2)
END_MSG=$(printf '%s' "$END_LINE" | cut -f3)
if [ -z "$FIRED_TS" ]; then
  echo "  (no compactor fire recorded for $DAY — next fire ~24h after the last one)"
fi

# ---- 2. Writer-ledger inside the flatten window ------------------------
#  The race requires a doctor (or other) commit on hq DURING flatten.
#  Window = [fired_ts, end_ts]. Presence of a doctor write = race was testable.
echo
echo "## 2. Writer activity inside the flatten window"
if [ -n "$FIRED_TS" ] && [ -n "$END_TS" ]; then
  echo "  window: $FIRED_TS  ->  $END_TS"
  DOCTOR_HITS=$(jq -r --arg a "$FIRED_TS" --arg b "$END_TS" \
    'select((.ts>=$a) and (.ts<=$b) and ((.actor//"")|test("doctor"))) | "  \(.ts)  \(.actor)  \(.type)  \(.subject // "-")"' \
    "$EVENTS" 2>/dev/null)
  if [ -n "$DOCTOR_HITS" ]; then echo "$DOCTOR_HITS"; else echo "  (no doctor events inside window)"; fi
  WRITER_N=$(jq -r --arg a "$FIRED_TS" --arg b "$END_TS" \
    'select((.ts>=$a) and (.ts<=$b) and (.type|test("bead\\.updated|order\\.completed"))) | .ts' \
    "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')
  echo "  writer-class events in window (bead.updated|order.completed): $WRITER_N"
  DOCTOR_IN_WINDOW=$([ -n "$DOCTOR_HITS" ] && echo 1 || echo 0)
else
  echo "  (window unknown — no complete fire/end pair for $DAY)"
  DOCTOR_IN_WINDOW=0
fi

# ---- 3. Marker mix ------------------------------------------------------
echo
echo "## 3. Marker mix (current state)"
PGC_N=$(count_markers "$PGC_DIR")
QUAR_N=$(count_markers "$QUAR_DIR")
echo "  pending-gc markers : $PGC_N"
dump_markers "$PGC_DIR"
echo "  quarantine markers : $QUAR_N"
dump_markers "$QUAR_DIR"

# ---- 4. G5 verdict ------------------------------------------------------
echo
echo "## 4. G5 verdict"
if [ "$QUAR_N" -gt 0 ]; then
  echo "  FALSIFIER — quarantine marker present. PR #2564 did NOT cover our case."
  echo "  Action: re-open mc-cqm9nl; soak fails this fire."
elif [ "$PGC_N" -gt 0 ] && [ "$QUAR_N" -eq 0 ]; then
  if [ "$DOCTOR_IN_WINDOW" = "1" ]; then
    echo "  G5 PASS — pending-GC marker(s) present, zero quarantine, doctor wrote"
    echo "  inside the flatten window. Defer gate fired correctly under a real race."
  else
    echo "  G5 PASS (weak) — pending-GC present + zero quarantine, but NO doctor"
    echo "  write observed in the window. Defer fired; race-trigger not confirmed."
  fi
elif [ "$PGC_N" -eq 0 ] && [ "$QUAR_N" -eq 0 ]; then
  if [ "${END_TYPE:-}" = "order.completed" ] && [ "$DOCTOR_IN_WINDOW" = "1" ]; then
    echo "  INCONCLUSIVE — clean exit-0 with a doctor write in-window but no marker."
    echo "  Gate may have no-op'd (HEAD stable despite the write). Not a pass; investigate."
  elif [ "${END_TYPE:-}" = "order.completed" ]; then
    echo "  MISSING-EVIDENCE — exit-0, no markers, no doctor write in-window. Race"
    echo "  window missed. NOT a pass (per Day-38 plan line 75). Need more fires."
  else
    echo "  BLOCKED/OTHER — end=${END_TYPE:-none} msg='${END_MSG:-}', no markers."
    echo "  Could be a pre-existing gate or an unrelated exit-1. Investigate, not a soak point."
  fi
fi

echo
echo "  fire end: ${END_TYPE:-none}  ${END_MSG:+($END_MSG)}"
echo "=================================================================="
echo "Record this fire in study/notes via the soak-evidence-template.md form."
