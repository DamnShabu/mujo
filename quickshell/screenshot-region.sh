#!/usr/bin/env bash
# grim + slurp → clipboard screenshot (wayland)
set -euo pipefail

region=$(slurp) || true
if [ -n "${region}" ]; then
  grim -g "$region" - | wl-copy
fi
