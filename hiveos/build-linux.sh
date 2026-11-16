#!/usr/bin/env bash
# Build a Linux x86-64 epic-miner that runs on HiveOS (Ubuntu 20.04 / 22.04 based).
#
# Build on an OLD glibc (Debian 11 / Ubuntu 20.04, glibc 2.31): a binary only runs on
# systems with the same or a newer glibc than the one it was built against.
#
# - OpenSSL is vendored (static) via the openssl crate's "vendored" feature in Cargo.toml.
# - No TUI: the "tui" feature is off, so cursive/ncurses is not linked (HiveOS is headless).
# - RandomX is built as librandomx.so by randomx-rust; the binary gets an rpath of $ORIGIN
#   so it loads librandomx.so from its own folder. package.sh ships the .so next to it.
#
# Usage (from the repo root):  hiveos/build-linux.sh
# Output: target/release/epic-miner  and  target/release/librandomx.so
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --cap-lints warn: the 2019-era crates use #![deny(...)] lints that newer rustc versions
# trip over (e.g. unused_mut); report them as warnings instead of failing the build.
export RUSTFLAGS="${RUSTFLAGS:-} --cap-lints warn -C link-args=-Wl,-rpath,\$ORIGIN"
cargo build --release --bin epic-miner

# newest copy: older cargo puts it in build/randomx-<hash>/, newer in build/randomx/<hash>/
LIB="$(find target/release/build -path '*/out/build/librandomx.so' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
[ -n "$LIB" ] || { echo "librandomx.so not found in target/release/build"; exit 1; }
cp -f "$LIB" target/release/librandomx.so

echo "== built"
ls -la target/release/epic-miner target/release/librandomx.so
echo "== dynamic deps"
ldd target/release/epic-miner
echo "== newest glibc symbol needed"
objdump -T target/release/epic-miner target/release/librandomx.so | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1
