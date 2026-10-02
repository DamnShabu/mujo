#!/usr/bin/env bash
# SEC-001 & SEC-002: kernel hardening sysctls on the RUNNING system.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Kernel Hardening Security Tests ==="

check_sysctl "kernel.kptr_restrict" "2"
check_sysctl "kernel.dmesg_restrict" "1"
check_sysctl "kernel.unprivileged_bpf_disabled" "1"
check_sysctl "net.core.bpf_jit_harden" "2"
check_sysctl "fs.protected_fifos" "2"
check_sysctl "fs.protected_regular" "2"
check_sysctl "fs.protected_symlinks" "1"
check_sysctl "fs.protected_hardlinks" "1"
check_sysctl "kernel.sysrq" "16"
check_sysctl "dev.tty.ldisc_autoload" "0"
check_sysctl "kernel.kexec_load_disabled" "1"

if [ -e /proc/sys/kernel/yama/ptrace_scope ]; then
  scope=$(cat /proc/sys/kernel/yama/ptrace_scope)
  if [ "$scope" -ge 1 ]; then
    pass "kernel.yama.ptrace_scope = $scope (restricted)"
  else
    fail "kernel.yama.ptrace_scope = $scope (expected >= 1)"
  fi
else
  fail "Yama LSM is not active — ptrace is unrestricted"
fi

# init_on_alloc/init_on_free (nixos/security/kernel.nix) are easy to defeat
# from the same command line: requesting page poisoning makes the kernel switch
# both off. The boot log's "mem auto-init" line states what actually ran.
if grep -qw 'page_poison=1' /proc/cmdline; then
  fail "page_poison=1 is on the command line; it switches init_on_alloc and init_on_free off"
fi
if autoinit=$(journalctl -k -b 0 -q --no-pager -o cat -g 'mem auto-init: stack' 2>/dev/null) && [ -n "$autoinit" ]; then
  if grep -q 'heap alloc:on, heap free:on' <<<"$autoinit"; then
    pass "heap memory is zeroed on allocation and on free"
  else
    fail "heap auto-init is not fully on: ${autoinit##*mem auto-init: }"
  fi
elif [ -z "$(journalctl -k -b 0 -q --no-pager -n 1 2>/dev/null)" ]; then
  skip "kernel journal unreadable as $(id -un); re-run as a systemd-journal member or root to confirm init_on_alloc/init_on_free"
else
  skip "this boot's 'mem auto-init' line is no longer in the journal (rotated out); re-check after a reboot"
fi

# Emergency/rescue must not hand out a root shell without the root password.
# SYSTEMD_SULOGIN_FORCE=1 is exactly the bypass, so its presence is a failure.
if grep -qs SYSTEMD_SULOGIN_FORCE /proc/cmdline /etc/systemd/system.conf; then
  fail "SYSTEMD_SULOGIN_FORCE is set — recovery mode bypasses root authentication"
else
  pass "Recovery mode requires root authentication (no SYSTEMD_SULOGIN_FORCE)"
fi

report
