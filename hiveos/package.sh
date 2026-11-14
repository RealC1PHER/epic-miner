#!/usr/bin/env bash
# Assemble the HiveOS custom-miner package  epic-miner-<version>.tar.gz
# Layout Hive expects: one top dir  epic-miner/  with the binary, librandomx.so, manifest and h-*.sh.
#
# Usage (from the repo root, after hiveos/build-linux.sh):  hiveos/package.sh [outdir]
# The compiled binary is NOT committed to git; publish the tarball as a release asset.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
OUT="${1:-$ROOT}"
VER="$(sed -n 's/^CUSTOM_VERSION=//p' "$HERE/h-manifest.conf")"
BIN="$ROOT/target/release/epic-miner"
LIB="$ROOT/target/release/librandomx.so"

file "$BIN" | grep -q 'ELF 64-bit' || { echo "not a linux x86-64 ELF: $BIN"; exit 1; }
[ -f "$LIB" ] || { echo "missing $LIB (run hiveos/build-linux.sh)"; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
D="$STAGE/epic-miner"
mkdir -p "$D"
install -m 0755 "$BIN"                  "$D/epic-miner"
install -m 0644 "$LIB"                  "$D/librandomx.so"
install -m 0644 "$HERE/h-manifest.conf" "$D/h-manifest.conf"
install -m 0755 "$HERE/h-config.sh"     "$D/h-config.sh"
install -m 0755 "$HERE/h-run.sh"        "$D/h-run.sh"
install -m 0755 "$HERE/h-stats.sh"      "$D/h-stats.sh"
strip "$D/epic-miner" "$D/librandomx.so" 2>/dev/null || true

TARBALL="$OUT/epic-miner-${VER}.tar.gz"
tar -C "$STAGE" -czf "$TARBALL" epic-miner
sha256sum "$TARBALL"
tar -tzvf "$TARBALL"
