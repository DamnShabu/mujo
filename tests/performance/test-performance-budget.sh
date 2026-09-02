#!/usr/bin/env bash
# Performance budget acceptance (docs/performance-budget.md §1).
#
# The budget is written as "overhead compared to a non-hardened baseline", and
# this machine has no non-hardened twin to compare against. So rather than
# invent a baseline, every measurement here is a *paired* one taken in the same
# run: the same work, natively and then behind each isolation boundary. That
# ratio is what the isolation actually costs, and it is the number the budget
# is trying to bound.
#
# Two things this suite learned the hard way, both now enforced below:
#   - Pin the binary. Resolving `sha256sum` by name gave coreutils-full on the
#     host and plain coreutils in the sandbox -- different builds with a 4x
#     performance gap -- and the result looked like a catastrophic sandbox
#     regression that did not exist.
#   - Do not time random-number generation. A workload built around
#     /dev/urandom measures RNG throughput, not the boundary.
#
# Host-wide hardening (sysctls, mitigations) is not measurable this way and is
# not claimed to be.
set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib.sh"

echo "=== Running Performance Budget Tests ==="

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ms() {
  local start end
  start=$(date +%s%N)
  "$@" >/dev/null 2>&1 || true
  end=$(date +%s%N)
  echo $(((end - start) / 1000000))
}

# best_of <n> <command...> — the fastest of n runs. A median would need
# sorting; the minimum is the least noisy estimator of a floor and needs none.
best_of() {
  local n="$1"; shift
  local best="" t i
  for ((i = 0; i < n; i++)); do
    t=$(ms "$@")
    if [ -z "$best" ] || [ "$t" -lt "$best" ]; then best=$t; fi
  done
  echo "$best"
}

budget() {
  local label="$1" base="$2" got="$3" allowed="$4"
  if [ "$base" -le 0 ]; then
    skip "$label — native run too fast to measure reliably"
    return
  fi
  local overhead=$(((got - base) * 100 / base))
  if [ "$overhead" -le "$allowed" ]; then
    pass "$label: ${base}ms -> ${got}ms (${overhead}%, budget ${allowed}%)"
  else
    fail "$label: ${base}ms -> ${got}ms (${overhead}%, budget ${allowed}%)"
  fi
}

# The exact same binary on both sides of every boundary. Resolving only the
# directory keeps the file name, because coreutils is a multicall binary that
# dispatches on argv[0] -- fully resolving it would yield `coreutils`, which
# does not hash anything.
if ! HASH_DIR=$(readlink -f "$(dirname "$(type -P sha256sum)")" 2>/dev/null); then
  skip "cannot locate sha256sum"
  report
  exit $?
fi
HASH="$HASH_DIR/sha256sum"

# Ten passes per measurement so a fixed launch cost (11ms native sandbox, ~100ms
# quarantine VM) amortises out of the ratio, which is then about throughput.
# Launch cost has its own budget line below; counting it twice would conflate a
# one-time cost with a per-workload one.
hash_loop() { echo "for i in 1 2 3 4 5 6 7 8 9 10; do $HASH $1 >/dev/null; done"; }

dd if=/dev/urandom of="$WORK/payload" bs=1M count=128 status=none

echo "  (measuring, this takes about a minute)"

native_cpu=$(best_of 3 sh -c "$(hash_loop "$WORK/payload")")
native_spawn=$(best_of 5 true)
echo "  native: ${native_cpu}ms for 10x128MiB, ${native_spawn}ms spawn"

# ── graduated native sandbox ─────────────────────────────────────────────
if command -v mujo-sandbox-run >/dev/null 2>&1; then
  sb_cpu=$(best_of 3 mujo-sandbox-run --ro-dir "$WORK" sh -c "$(hash_loop "$WORK/payload")")
  budget "native sandbox, CPU workload" "$native_cpu" "$sb_cpu" 5

  sb_spawn=$(best_of 5 mujo-sandbox-run true)
  added=$((sb_spawn - native_spawn))
  # A fixed per-launch cost, not a percentage of anything. 250ms is the point
  # where a launch stops feeling instant.
  if [ "$added" -le 250 ]; then
    pass "native sandbox, launch overhead: +${added}ms"
  else
    fail "native sandbox, launch overhead: +${added}ms (over the 250ms interactive budget)"
  fi
else
  skip "mujo-sandbox-run is not installed — rebuild to measure the sandbox"
fi

# ── quarantine MicroVM ───────────────────────────────────────────────────
if command -v mujo-quarantine-run >/dev/null 2>&1 &&
   systemctl is-active --quiet microvm@mujo-quarantine.service; then
  # The Downloads exchange is the one path both sides can see, so it is what
  # lets host and guest hash the same bytes with the same binary. The guest's
  # side of it is virtiofs, so its first pass includes that read; the remaining
  # four come from the guest's page cache.
  EXCHANGE="$HOME/Quarantine"
  if [ -d "$EXCHANGE" ]; then
    cp "$WORK/payload" "$EXCHANGE/perf-payload"
    host_ref=$(best_of 3 sh -c "$(hash_loop "$EXCHANGE/perf-payload")")
    vm_cpu=$(best_of 3 mujo-quarantine-run sh -c \
      "$(hash_loop /home/quarantine/Downloads/perf-payload)")
    rm -f "$EXCHANGE/perf-payload"
    # Sustained CPU work in the guest runs at parity with the host: measured
    # -4% to -5% over repeated runs, comfortably inside the 15% target.
    #
    # An earlier version of this check reported +59% and was simply wrong. It
    # ran five passes, so the domain's ~100ms launch cost was a third of a
    # ~330ms measurement. Ten passes put the launch where it belongs: on its own
    # budget line below, rather than multiplied into a throughput ratio.
    budget "quarantine VM, CPU workload" "$host_ref" "$vm_cpu" 15
  else
    skip "the Downloads exchange is absent — cannot hash identical bytes on both sides"
  fi

  vm_spawn=$(best_of 3 mujo-quarantine-run true)
  # Warm domain only. The cold start is a VM boot, and Phase 37's pre-warmed
  # pool is not built.
  if [ "$vm_spawn" -le 3000 ]; then
    pass "quarantine VM, warm launch: ${vm_spawn}ms"
  else
    fail "quarantine VM, warm launch: ${vm_spawn}ms (over 3s)"
  fi
else
  skip "quarantine domain is not running — start it (mujo-quarantine-run true) to measure it"
fi

# ── storage ──────────────────────────────────────────────────────────────
io_ms=$(best_of 3 sh -c "dd if=/dev/zero of=$WORK/io bs=1M count=512 conv=fsync status=none")
if [ "$io_ms" -gt 0 ]; then
  mbps=$((512 * 1000 / io_ms))
  pass "storage write throughput: ${mbps} MB/s (${io_ms}ms for 512MiB, informational)"
else
  skip "storage write too fast to time"
fi

report
