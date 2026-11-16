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

# RandomX MSR tweak: the cache-prefetcher register presets XMRig and SRBMiner apply (same
# values as XMRig), several percent more RandomX hashrate on bare metal. The values stay
# until reboot. Any problem skips the tweak with one log line; mining always starts.
msr_logfile="$(dirname "$CUSTOM_LOG_BASENAME")/msr.log"
msr_log() { echo "$*"; echo "$(date '+%F %T') $*" >> "$msr_logfile"; }

# msr_read CPU REG -> 16 hex digits
msr_read() {
  dd if="/dev/cpu/$1/msr" bs=8 count=1 skip=$(( $2 )) iflag=skip_bytes 2>/dev/null | od -An -tx8 | tr -d ' \n'
}

# msr_write CPU REG VALUE(16 hex digits); writes the 8 bytes little-endian
msr_write() {
  local v="$3" b="" i
  for (( i = 14; i >= 0; i -= 2 )); do b+="\\x${v:i:2}"; done
  printf "$b" | dd of="/dev/cpu/$1/msr" bs=8 count=1 seek=$(( $2 )) oflag=seek_bytes conv=notrunc 2>/dev/null
}

msr_tweak() {
  local vendor family model preset regs=() r v cpu n=0 old applied=""
  vendor=$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo)
  family=$(awk -F': ' '/^cpu family/ { print $2; exit }' /proc/cpuinfo)
  model=$(awk -F': ' '/^model[ \t]+:/ { print $2; exit }' /proc/cpuinfo)

  if grep -qw hypervisor /proc/cpuinfo; then
    msr_log "MSR tweak skipped: running in a VM"; return
  fi
  case "$vendor/$family" in
    AuthenticAMD/25)
      if (( (model >= 0x10 && model <= 0x1f) || (model >= 0x60 && model <= 0x7f) || (model >= 0xa0 && model <= 0xaf) )); then
        preset=zen4
        regs=(0xc0011020=0004400000000000 0xc0011021=0004000000000040 0xc0011022=8680000401570000 0xc001102b=000000002040cc10)
      else
        preset=zen3
        regs=(0xc0011020=0004480000000000 0xc0011021=001c000200000040 0xc0011022=c000000401570000 0xc001102b=000000002000cc10)
      fi ;;
    AuthenticAMD/23)
      preset=zen1-2
      regs=(0xc0011020=0000000000000000 0xc0011021=0000000000000040 0xc0011022=0000000001510000 0xc001102b=000000002000cc16) ;;
    GenuineIntel/*)
      preset=intel
      regs=(0x1a4=000000000000000f) ;;
    *)
      msr_log "MSR tweak skipped: no preset for $vendor family $family model $model"; return ;;
  esac

  modprobe msr 2>/dev/null
  if [[ ! -w /dev/cpu/0/msr ]]; then
    msr_log "MSR tweak skipped: /dev/cpu/0/msr not writable (msr module missing?)"; return
  fi

  for cpu in /dev/cpu/[0-9]*; do
    cpu=${cpu##*/}
    for r in "${regs[@]}"; do
      v=${r#*=}
      if [[ $preset == zen3 && ${r%%=*} == 0xc0011021 ]]; then
        # XMRig keeps bit 5 of this register as it is
        old=$(msr_read "$cpu" 0xc0011021)
        [[ ${#old} == 16 ]] || { msr_log "MSR tweak skipped: cannot read 0xc0011021 on CPU $cpu"; return; }
        v="${v:0:14}$(printf '%02x' $(( (0x${v:14:2} & 0xdf) | (0x${old:14:2} & 0x20) )))"
      fi
      msr_write "$cpu" "${r%%=*}" "$v" || { msr_log "MSR tweak skipped: write ${r%%=*} failed on CPU $cpu"; return; }
    done
    (( n++ ))
  done

  for r in "${regs[@]}"; do applied+=" ${r%%=*}=0x$(msr_read 0 "${r%%=*}")"; done
  msr_log "MSR tweak applied ($preset) on $n CPUs:$applied"
}

if [[ $msr == true ]]; then
  msr_tweak
else
  msr_log "MSR tweak off (msr=false); values set earlier stay until reboot"
fi

export LD_LIBRARY_PATH="$PWD${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec ./epic-miner -c "$CUSTOM_CONFIG_FILENAME"
