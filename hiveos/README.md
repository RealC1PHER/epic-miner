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
| `threads` | all CPU threads minus 2 | RandomX mining threads |
| `large_pages` | `true` | use huge pages for the RandomX dataset (h-run.sh reserves them) |
| `tls` | from the URL prefix | force TLS on or off |

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
