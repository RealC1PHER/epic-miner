#!/usr/bin/env bash
# epic-miner — HiveOS stats. Sourced by Hive's stats loop; must set  khs  and  stats.
# epic-miner has no API, so this reads its log file:
#   "Mining: RandomX at 18357 hps (hashes per second)"   -> hashrate
#   "Mining: RandomX per thread hps: 571 569 ..."        -> one hashrate box per thread (fz7+)
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
  # one box per mining thread; falls back to the total when there is no per-thread line yet
  threads_hs=$(tail -n 400 "$log" | grep -o 'per thread hps: [0-9 ]*' | tail -n 1 | cut -d: -f2 | xargs)
  [[ -n "$threads_hs" ]] || threads_hs="$hps"
  hs="[${threads_hs// /,}]"
  cpu_t=$(cpu-temp 2>/dev/null)
  [[ "$cpu_t" =~ ^[0-9]+$ ]] || cpu_t=null

  stats=$(jq -nc \
    --argjson hs "$hs" --argjson cpu_t "$cpu_t" --argjson uptime "$uptime" \
    --argjson acc "$acc" --argjson rej "$rej" --arg ver "$CUSTOM_VERSION" '
    { hs: $hs, hs_units: "hs",
      temp: (if $cpu_t == null then [] else [$hs[] | $cpu_t] end), fan: [], uptime: $uptime,
      ver: $ver, algo: "randomx", ar: [ $acc, $rej ], bus_numbers: [$hs[] | null] }')
fi

[[ -z "$stats" ]] && { khs=0; stats='{"hs":[0],"hs_units":"hs","temp":[],"fan":[],"ar":[0,0],"algo":"randomx"}'; }
