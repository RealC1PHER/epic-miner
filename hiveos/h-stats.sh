#!/usr/bin/env bash
# epic-miner — HiveOS stats. Sourced by Hive's stats loop; must set  khs  and  stats.
# epic-miner has no API, so this reads its log file:
#   "Mining: RandomX at 18357 hps (hashes per second)"   -> hashrate
#   "Share Accepted!!"                                   -> accepted
#   "Failed to submit a solution"                        -> rejected (includes stale)

[[ -z $CUSTOM_LOG_BASENAME ]] && . /hive/miners/custom/epic-miner/h-manifest.conf 2>/dev/null
log="${CUSTOM_LOG_BASENAME}.log"

khs=0
stats=""

if [[ -f "$log" ]]; then
  hps=$(tail -n 400 "$log" | grep -o 'at [0-9]* hps' | tail -n 1 | grep -o '[0-9]*')
  hps=${hps:-0}
  acc=$(grep -c 'Share Accepted!!' "$log")
  rej=$(grep -c 'Failed to submit a solution' "$log")
  pid=$(pgrep -o -x epic-miner)
  uptime=0
  [[ -n "$pid" ]] && uptime=$(( $(date +%s) - $(stat -c %Y "/proc/$pid") ))
  khs=$(awk -v h="$hps" 'BEGIN { printf "%.3f", h / 1000 }')
  cpu_t=$(cpu-temp 2>/dev/null)
  temp=$([[ "$cpu_t" =~ ^[0-9]+$ ]] && echo "[$cpu_t]" || echo "[]")

  stats=$(jq -nc \
    --argjson hs "[$hps]" --argjson temp "$temp" --argjson uptime "$uptime" \
    --argjson acc "$acc" --argjson rej "$rej" --arg ver "$CUSTOM_VERSION" '
    { hs: $hs, hs_units: "hs", temp: $temp, fan: [], uptime: $uptime,
      ver: $ver, algo: "randomx", ar: [ $acc, $rej ], bus_numbers: [null] }')
fi

[[ -z "$stats" ]] && { khs=0; stats='{"hs":[0],"hs_units":"hs","temp":[],"fan":[],"ar":[0,0],"algo":"randomx"}'; }
