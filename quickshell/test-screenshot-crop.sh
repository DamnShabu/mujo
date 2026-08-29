#!/usr/bin/env bash
# Self-check for mujo-screenshot.sh's crop bounds guard. Needs only ImageMagick
# — no compositor, no running shell. Run it directly: ./test-screenshot-crop.sh
#
# The bug it pins down: grim writes one frame spanning the bounding box of all
# outputs, so its pixel (0,0) is the top-left-most output corner. Niri puts this
# host's monitors at 3610,1330, and the overlay used to hand those raw
# compositor coordinates to `magick -crop`, which only *warns* on an offset past
# the edge and still exits 0 with a 1x1 placeholder — a saved "screenshot" that
# is one grey pixel.
set -uo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mujo-screenshot.sh"
raw=/tmp/mujo-snip-raw.png
crop=/tmp/mujo-snip-crop.png

magick -size 1920x2160 gradient:red-blue "$raw"
run() { bash "$script" crop "$@" >/dev/null 2>&1; }

run 10 20 300 200 || {
  echo "FAIL: in-range crop was rejected"
  exit 1
}
size=$(magick identify -format '%wx%h' "$crop")
[[ $size == 300x200 ]] || {
  echo "FAIL: in-range crop produced $size, want 300x200"
  exit 1
}

rm -f "$crop"
if run 3710 1430 300 200 || [[ -e $crop ]]; then
  echo "FAIL: offset outside the frame was accepted (this is the 1x1-image bug)"
  exit 1
fi

if run 10 20 0 200; then
  echo "FAIL: zero-width selection was accepted"
  exit 1
fi

echo "ok: crop bounds guard"
