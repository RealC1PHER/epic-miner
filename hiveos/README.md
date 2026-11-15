# epic-miner for HiveOS

A HiveOS custom-miner package for epic-miner (Epic Cash, RandomX on CPU).
It runs on current HiveOS images (Ubuntu 20.04 / 22.04 based):

- built against glibc 2.31, with OpenSSL linked in statically and no ncurses (no TUI)
- `librandomx.so` ships next to the binary and is found through an `$ORIGIN` rpath

The mining code and the stratum protocol are the same as upstream epic-miner 2.3.1.

## Flight sheet

In the flight sheet, set **Miner** to **Custom**, then:

| Field | Value |
|---|---|
| Miner name | `epic-miner` (filled in from the URL) |
| Installation URL | the `epic-miner-<version>.tar.gz` release asset URL |
| Hash algorithm | `randomx` |
| Wallet and worker template | the stratum login. For an Epic node's own stratum: `%WAL%#%WORKER_NAME%`. For a pool: what the pool asks for, e.g. `ALIAS.%WORKER_NAME%` |
| Pool URL | `host:port` of the stratum, e.g. `192.168.1.10:3416` for an Epic node. Prefix with `stratum+ssl://` for TLS |
| Pass | stratum password, e.g. `m=pool` (default `x`) |
| Extra config arguments | optional, see below |

### Extra config arguments

`key=value` pairs, one per line or separated by spaces or commas:

| Key | Default | Meaning |
|---|---|---|
| `threads` | all CPU threads | RandomX mining threads (set lower to leave cores free) |
| `large_pages` | `true` | use huge pages for the RandomX dataset (h-run.sh reserves them) |
| `tls` | from the URL prefix | force TLS on or off |
| `msr` | `true` | apply the RandomX MSR tweak before the miner starts (see below) |

### MSR tweak

`h-run.sh` writes the RandomX MSR presets that XMRig and SRBMiner also use (cache prefetcher
settings, same values as XMRig): Zen 4, Zen 3, Zen 1/2 and Intel. On bare metal this gives
several percent more RandomX hashrate. The values stay until the next reboot, also after
`msr=false`.

It never blocks mining. In a VM, on an unknown CPU or when a write fails, it logs one
`MSR tweak skipped: …` line and the miner starts as normal. The result is in
`/var/log/miner/epic-miner/msr.log` and the miner screen, e.g.
`MSR tweak applied (zen4) on 32 CPUs: 0xc0011020=0x0004400000000000 …`.

## Behaviour

Epic Cash switches between RandomX, ProgPow and Cuckoo phases. During a ProgPow or Cuckoo
phase this miner is idle (0 H/s, log line `my algo: randomx, algo from job progpow`) and
resumes on its own when RandomX comes back. That is expected.

## Stats

epic-miner has no API. `h-stats.sh` reads its log
(`/var/log/miner/epic-miner/epic-miner.log`): hashrate from `Mining: RandomX at N hps`,
accepted shares from `Share Accepted!!`, rejected from `Failed to submit a solution`
(stale "too late" submits count as rejected).

## Building the package

On Debian 11 or Ubuntu 20.04 (old glibc on purpose), with build-essential, cmake, clang,
libclang-dev, pkg-config, perl and Rust (rustup):

```
git clone --recursive https://github.com/RealC1PHER/epic-miner.git
cd epic-miner && git checkout frenziez/hiveos-build && git submodule update --init --recursive
hiveos/build-linux.sh
hiveos/package.sh            # -> epic-miner-<version>.tar.gz
```
