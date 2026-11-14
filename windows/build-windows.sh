#!/usr/bin/env bash
# Cross-build a Windows x86-64 epic-miner.exe (+ cuckatoo CPU plugins) on Linux with mingw-w64.
#
# Same source as the HiveOS build (hiveos/build-linux.sh); only the target differs. The upstream
# Windows release (2.3.1-1) was a MinGW build too.
#
# Needs: mingw-w64 (posix threads: update-alternatives --set x86_64-w64-mingw32-g{cc,++} ...-posix),
#        rustup target add x86_64-pc-windows-gnu, cmake, clang/libclang (bindgen), perl/make (vendored OpenSSL).
#
# Usage (from the repo root):  windows/build-windows.sh
# Output: target/x86_64-pc-windows-gnu/release/epic-miner.exe and windows/dist/ (exe, DLLs, plugins)
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

T=x86_64-pc-windows-gnu
export CC_x86_64_pc_windows_gnu=x86_64-w64-mingw32-gcc
export CXX_x86_64_pc_windows_gnu=x86_64-w64-mingw32-g++
export AR_x86_64_pc_windows_gnu=x86_64-w64-mingw32-ar
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc
# openssl-sys 0.9.54 also lists Windows system libs (crypt32, ws2_32, …) when it decides between
# static and dynamic, finds them missing in the vendored libdir and panics; the vendored build is static.
export OPENSSL_STATIC=1
# ...and for any Windows target it names the libs "libssl"/"libcrypto" (MSVC style); MinGW's are libssl.a/libcrypto.a.
export OPENSSL_LIBS=ssl:crypto
# --cap-lints warn: 2019-era crates deny lints that newer rustc trips over (see build-linux.sh).
# Static libgcc/libstdc++ so fewer MinGW runtime DLLs have to ship next to the exe.
export RUSTFLAGS="${RUSTFLAGS:-} --cap-lints warn -C link-args=-static-libgcc -C link-args=-static-libstdc++"

cargo build --release --target "$T" --bin epic-miner

OUT=target/$T/release
DIST=windows/dist
rm -rf "$DIST"
mkdir -p "$DIST/plugins"
cp -f "$OUT/epic-miner.exe" "$DIST/"
x86_64-w64-mingw32-strip "$DIST/epic-miner.exe" || true

# Cuckatoo CPU plugins built by cuckoo-miner's CMake step (newest copy).
find "$OUT" -name '*.cuckooplugin' -printf '%T@ %p\n' | sort -n | awk '{print $2}' | while read -r p; do
  cp -f "$p" "$DIST/plugins/"
done

# RandomX is built as a shared library by randomx-rust (newest copy).
RX="$(find "$OUT/build" -name 'librandomx.dll' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
[ -n "$RX" ] || { echo "librandomx.dll not found in $OUT/build"; exit 1; }
cp -f "$RX" "$DIST/"

# Ship whatever MinGW runtime DLLs the exe, RandomX or the plugins still import.
SYSROOT_DIRS="$(dirname "$(x86_64-w64-mingw32-gcc -print-libgcc-file-name)") /usr/x86_64-w64-mingw32/lib"
deps() { x86_64-w64-mingw32-objdump -p "$@" 2>/dev/null | sed -n 's/^\s*DLL Name: //p' | sort -u; }
for dll in $(deps "$DIST/epic-miner.exe" "$DIST/librandomx.dll" "$DIST"/plugins/*.cuckooplugin); do
  for d in $SYSROOT_DIRS; do
    [ -f "$d/$dll" ] && cp -f "$d/$dll" "$DIST/" && break
  done
done
x86_64-w64-mingw32-strip --strip-unneeded "$DIST"/*.dll "$DIST"/plugins/*.cuckooplugin || true

echo "== dist"
ls -la "$DIST" "$DIST/plugins"
echo "== DLL imports (system DLLs are expected; anything else must be in dist/)"
deps "$DIST/epic-miner.exe" "$DIST"/*.dll "$DIST"/plugins/*.cuckooplugin 2>/dev/null || true
