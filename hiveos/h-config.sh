#!/usr/bin/env bash
# epic-miner — render epic-miner.toml from the HiveOS flight sheet. Sourced by h-run.sh.
#
# Flight-sheet inputs:
#   CUSTOM_URL          stratum host:port, e.g. 10.0.200.151:3416 (an Epic node's stratum) or a pool.
#                       A stratum+ssl:// prefix (or tls=true below) turns TLS on.
#   CUSTOM_TEMPLATE     stratum login, e.g. %WAL%#%WORKER_NAME% for an Epic node,
#                       or ALIAS.%WORKER_NAME% for a pool.
#   CUSTOM_PASS         stratum password (default "x"; pools use e.g. m=pool / m=solo)
#   CUSTOM_USER_CONFIG  optional key=value lines (or space separated):
#                         threads=N        RandomX threads (default: all CPU threads minus 2)
#                         large_pages=true|false   (default true)
#                         tls=true|false   (default from the URL prefix)

[[ -z $CUSTOM_CONFIG_FILENAME ]] && . /hive/miners/custom/epic-miner/h-manifest.conf 2>/dev/null

conf="$CUSTOM_CONFIG_FILENAME"
mkdir -p "$(dirname "$conf")" "$(dirname "$CUSTOM_LOG_BASENAME")"

url="$CUSTOM_URL"
tls=false
case "$url" in
  stratum+ssl://*|ssl://*|stratum+tls://*|tls://*) tls=true ;;
esac
url="${url#*://}"
url="${url%%/*}"

login="$CUSTOM_TEMPLATE"
pass="${CUSTOM_PASS:-x}"

threads=$(( $(nproc) - 2 ))
(( threads < 1 )) && threads=1
large_pages=true

for kv in $CUSTOM_USER_CONFIG; do
  key="${kv%%=*}"; val="${kv#*=}"
  case "$key" in
    threads)     [[ "$val" =~ ^[0-9]+$ ]] && threads="$val" ;;
    large_pages) [[ "$val" == true || "$val" == false ]] && large_pages="$val" ;;
    tls)         [[ "$val" == true || "$val" == false ]] && tls="$val" ;;
  esac
done

# TOML basic-string escaping for user-provided values
esc() { local s="${1//\\/\\\\}"; printf '%s' "${s//\"/\\\"}"; }

cat > "$conf" <<EOF
[logging]
log_to_stdout = true
stdout_log_level = "Info"
log_to_file = true
file_log_level = "Info"
log_file_path = "${CUSTOM_LOG_BASENAME}.log"
log_file_append = false

[mining]
algorithm = "RandomX"
run_tui = false
stratum_server_addr = "$(esc "$url")"
stratum_server_login = "$(esc "$login")"
stratum_server_password = "$(esc "$pass")"
stratum_server_tls_enabled = $tls

[mining.randomx_config]
threads = $threads
jit = true
large_pages = $large_pages
hard_aes = true

[[mining.gpu_config]]
device = 0
driver = 2

[[mining.miner_plugin_config]]
plugin_name = "cuckatoo_lean_cpu_compat_19"
[mining.miner_plugin_config.parameters]
nthreads = 1
EOF

echo "[h-config] url=$url tls=$tls threads=$threads large_pages=$large_pages login=${login:0:6}..."
