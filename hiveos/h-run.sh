#!/usr/bin/env bash
# epic-miner — HiveOS launcher. Runs the miner in the foreground so Hive's screen session
# shows its output; the miner writes its own log file (see h-config.sh).
cd "$(dirname "$0")" || exit 1

. h-manifest.conf
. h-config.sh

# Large pages for RandomX (HiveOS runs miners as root). Harmless if already set.
if [[ -w /proc/sys/vm/nr_hugepages ]] && (( $(cat /proc/sys/vm/nr_hugepages) < 1280 )); then
  echo 1280 > /proc/sys/vm/nr_hugepages
fi

export LD_LIBRARY_PATH="$PWD${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec ./epic-miner -c "$CUSTOM_CONFIG_FILENAME"
