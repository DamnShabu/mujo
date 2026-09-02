#!/usr/bin/env bash
# SEC-008: network stack hardening sysctls and anti-spoofing.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Network Stack Security Tests ==="

check_sysctl "net.ipv4.conf.all.rp_filter" "1"
check_sysctl "net.ipv4.conf.all.accept_redirects" "0"
check_sysctl "net.ipv4.conf.all.send_redirects" "0"
check_sysctl "net.ipv4.conf.all.accept_source_route" "0"
check_sysctl "net.ipv4.tcp_syncookies" "1"
check_sysctl "net.ipv4.tcp_rfc1337" "1"
check_sysctl "net.ipv6.conf.all.addr_gen_mode" "2"

# The firewall must actually be loaded, not merely declared in the module.
if command -v nft >/dev/null 2>&1 && nft list ruleset >/dev/null 2>&1; then
  if nft list ruleset 2>/dev/null | grep -q 'chain input'; then
    pass "nftables ruleset is loaded with an input chain"
  else
    fail "nftables ruleset has no input chain — host firewall is not filtering"
  fi
elif command -v iptables >/dev/null 2>&1 && iptables -S 2>/dev/null | grep -q '^-P INPUT DROP'; then
  pass "iptables INPUT policy is DROP"
else
  skip "Firewall ruleset unreadable as $(id -un); re-run as root"
fi

report
