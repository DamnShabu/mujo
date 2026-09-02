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

# Emergency/rescue must not hand out a root shell without the root password.
# SYSTEMD_SULOGIN_FORCE=1 is exactly the bypass, so its presence is a failure.
if grep -qs SYSTEMD_SULOGIN_FORCE /proc/cmdline /etc/systemd/system.conf; then
  fail "SYSTEMD_SULOGIN_FORCE is set — recovery mode bypasses root authentication"
else
  pass "Recovery mode requires root authentication (no SYSTEMD_SULOGIN_FORCE)"
fi

report
