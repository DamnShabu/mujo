#!/usr/bin/env bash
# HW-001: the GPU stack of nixos/hosts/main/_gpu.nix on the RUNNING system.
#
# Reads sysfs, /proc and this boot's kernel journal only, so it runs unprivileged
# as the desktop user (a member of systemd-journal). Run it after a rebuild and
# a reboot; a GPU problem shows up here as a named failure rather than a vague
# "games stutter".
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running GPU Tests ==="

# _gpu.nix describes this card; a different one means that file (and its
# kernel/Mesa minimums) needs a fresh look, not just a passing test.
EXPECTED_DEVICE="0x7550" # Navi 48: RX 9070 XT / RX 9070

gpu=""
for dev in /sys/bus/pci/devices/*; do
  [ "$(cat "$dev/vendor")" = "0x1002" ] || continue
  case "$(cat "$dev/class")" in
    0x03*) gpu="$dev" && break ;;
  esac
done

if [ -z "$gpu" ]; then
  fail "no AMD display controller on the PCI bus"
  report
  exit 1
fi
slot=$(basename "$gpu")
device=$(cat "$gpu/device")

if [ "$device" = "$EXPECTED_DEVICE" ]; then
  pass "RX 9070 XT (Navi 48, 1002:${device#0x}) at $slot"
else
  fail "GPU at $slot is 1002:${device#0x}, not the RX 9070 XT (1002:${EXPECTED_DEVICE#0x}) that nixos/hosts/main/_gpu.nix is written for"
fi

driver=$(basename "$(readlink -f "$gpu/driver" 2>/dev/null || echo none)")
if [ "$driver" = "amdgpu" ]; then
  pass "bound to amdgpu"
else
  fail "bound to '$driver', not amdgpu — check 'journalctl -k -b -g amdgpu' for the probe error"
fi

kernel=$(uname -r)
if [ "$(printf '%s\n' 6.14 "$kernel" | sort -V | head -n1)" = "6.14" ]; then
  pass "kernel $kernel (RDNA4 needs 6.14+)"
else
  fail "kernel $kernel is older than 6.14, which RDNA4 needs"
fi

# A zero version means the block never got its firmware: SMU (power and
# clocks), MES (the RDNA4 queue scheduler), DMCUB (the display engine).
for fw in smc mes dmcub; do
  f="$gpu/fw_version/${fw}_fw_version"
  if [ ! -r "$f" ]; then
    fail "$fw firmware version is not exposed (amdgpu not bound?)"
  elif [ "$(cat "$f")" = "0x00000000" ]; then
    fail "$fw firmware did not load"
  else
    pass "$fw firmware loaded ($(cat "$f"))"
  fi
done

render=""
for n in "$gpu"/drm/renderD*; do
  [ -e "$n" ] && render="/dev/dri/$(basename "$n")"
done
if [ -n "$render" ] && [ -r "$render" ] && [ -w "$render" ]; then
  pass "render node $render is usable by $(id -un)"
else
  fail "no usable render node for $slot (got '${render:-none}')"
fi

for icd in /run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json \
  /run/opengl-driver-32/share/vulkan/icd.d/radeon_icd.i686.json; do
  if [ -e "$icd" ]; then
    pass "RADV ICD present: $icd"
  else
    fail "RADV ICD missing: $icd (hardware.graphics.enable/enable32Bit)"
  fi
done

# Resizable BAR: without it the CPU sees a 256 MiB window into VRAM and every
# larger upload is staged through it.
vram=$(cat "$gpu/mem_info_vram_total" 2>/dev/null || echo 0)
visible=$(cat "$gpu/mem_info_vis_vram_total" 2>/dev/null || echo 0)
if [ "$vram" -gt 0 ] && [ "$visible" = "$vram" ]; then
  pass "Resizable BAR active: all $((vram / 1048576)) MiB of VRAM CPU-visible"
else
  fail "Resizable BAR off: $((visible / 1048576)) of $((vram / 1048576)) MiB CPU-visible — enable Above 4G Decoding and Re-Size BAR in the firmware setup"
fi

# The slot, not the card: Navi cards sit behind their own PCIe switch, so the
# link that matters is the root port's. A capability under x8 means the card is
# in a chipset slot or behind a narrow riser.
# The device path is /sys/devices/pci<domain:bus>/<root port>/<switch>/.../<gpu>.
root_port=$(readlink -f "$gpu" | cut -d/ -f1-5)
root_width=$(cat "$root_port/max_link_width" 2>/dev/null || echo 0)
root_speed=$(cat "$root_port/max_link_speed" 2>/dev/null || echo unknown)
if [ "$root_width" -ge 8 ]; then
  pass "slot $(basename "$root_port"): up to x$root_width at $root_speed"
else
  fail "slot $(basename "$root_port") is only x$root_width — move the card to the CPU's x16 slot"
fi

# The IOMMU follows security.mujo.devices.dmaProtection, whose off value is
# appended last on the command line (nixos/security/devices.nix).
iommu_param=$(tr ' ' '\n' </proc/cmdline | sed -n 's/^intel_iommu=//p' | tail -n1)
iommu_active=$(find /sys/class/iommu -mindepth 1 -maxdepth 1 2>/dev/null | head -n1)
if [ "$iommu_param" = "on" ]; then
  pass "IOMMU requested on (dmaProtection) — ${iommu_active:+active}${iommu_active:-NOT active}"
elif [ -n "$iommu_active" ]; then
  fail "IOMMU is active although dmaProtection is off (intel_iommu=${iommu_param:-unset})"
else
  pass "IOMMU off, as dmaProtection = false asks"
fi

# Monitors are configured by connector name -- `video=DP-1:...` on the kernel
# command line (nixos/hosts/main/_boot.nix) and the output keys of
# modules/wrappers/niri-settings.json. Another card numbers its ports its own
# way, and a name with no monitor behind it is silently ignored: the screen
# comes up at its default mode and position instead.
mapfile -t connected < <(for s in /sys/class/drm/card*-*/status; do
  [ "$(cat "$s" 2>/dev/null)" = "connected" ] && basename "$(dirname "$s")" | sed 's/^card[0-9]*-//'
done)
check_connector() {
  local name="$1" where="$2" c
  for c in "${connected[@]}"; do
    [ "$c" = "$name" ] && pass "$where names $name, which has a monitor" && return
  done
  fail "$where names $name, but no monitor is on it (connected: ${connected[*]:-none})"
}
for p in $(tr ' ' '\n' </proc/cmdline | sed -n 's/^video=\([^:]*\):.*/\1/p'); do
  check_connector "$p" "kernel video= parameter"
done
niri_settings="$(dirname -- "${BASH_SOURCE[0]}")/../../modules/wrappers/niri-settings.json"
if command -v jq >/dev/null && [ -r "$niri_settings" ]; then
  for o in $(jq -r '.outputs // {} | to_entries[] | select(.value.enabled != false) | .key' "$niri_settings"); do
    check_connector "$o" "niri-settings.json"
  done
else
  skip "jq or $niri_settings unavailable; niri output names not checked"
fi

check_sysctl "kernel.panic_on_oops" "0"

if systemctl is-active --quiet lactd; then
  pass "lactd (GPU monitoring) is running"
else
  fail "lactd is not running (services.lact.enable)"
fi

# Hangs, resets, VM faults and firmware errors since boot. These are the
# events behind a frozen game or a black screen; each line names the ring or
# block involved.
if journal=$(journalctl -k -b 0 -q --no-pager -o cat 2>/dev/null) && [ -n "$journal" ]; then
  mapfile -t errors < <(printf '%s\n' "$journal" |
    grep -E 'amdgpu.*(ring [^ ]+ timeout|GPU reset|page fault|\*ERROR\*|failed to load|Fatal error)|Direct firmware load for amdgpu/.* failed' || true)
  if [ "${#errors[@]}" -eq 0 ]; then
    pass "no amdgpu hangs, resets, faults or firmware errors this boot"
  else
    fail "${#errors[@]} amdgpu error line(s) this boot:"
    list_findings "${errors[@]}"
  fi
else
  skip "kernel journal unreadable as $(id -un); re-run as a systemd-journal member or root"
fi

report
