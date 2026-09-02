#!/usr/bin/env bash
# Self-check for mujo-screenshot.sh's `ocr-lines`, the per-line boxes the
# translate overlay paints onto. Renders a known three-line image, OCRs it, and
# asserts the boxes come back in reading order with geometry that lands inside
# the crop. Offline — tesseract and ImageMagick only, no translation call.
#
# Run through the packaged wrapper so tesseract/jq/magick are on PATH:
#   nix run .#mujo-screenshot -- ...   # or just run it on a NixOS host
set -uo pipefail

# tesseract is not on a bare NixOS PATH; it reaches this script through the
# mujo-screenshot wrapper. Say so, rather than reporting the missing binary as
# an OCR failure.
missing=""
for tool in tesseract magick jq; do
  command -v "$tool" >/dev/null || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  echo "SKIP: not on PATH:$missing -- run via: nix run .#mujo-screenshot"
  exit 0
fi

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mujo-screenshot.sh"
raw=/tmp/mujo-snip-raw.png

magick -size 700x260 xc:white -fill black -pointsize 34 \
  -draw "text 20,60 'Attention is all you need'" \
  -draw "text 20,120 'The second line of text'" \
  -draw "text 20,180 'And a third one below'" "$raw"

out=$(bash "$script" ocr-lines 0 0 700 260) || {
  echo "FAIL: ocr-lines exited non-zero; it printed: ${out:-<nothing>}"
  exit 1
}

fail() {
  echo "FAIL: $1"
  echo "$out" | jq . 2>/dev/null || echo "$out"
  exit 1
}

jq -e '.w == 700 and .h == 260' <<<"$out" >/dev/null || fail "crop dimensions not reported"
jq -e '.lines | length == 3' <<<"$out" >/dev/null || fail "want 3 line boxes"

# Reading order: sorted top to bottom, and each box inside the crop.
jq -e '[.lines[].y] | . == sort' <<<"$out" >/dev/null || fail "lines are not in top-to-bottom order"
jq -e '.lines | all(.w > 0 and .h > 0 and .x >= 0 and .y >= 0
                    and .x + .w <= 700 and .y + .h <= 260)' <<<"$out" >/dev/null ||
  fail "a box escapes the crop"

# The middle line is the one OCR is least likely to mangle; spot-check that the
# words made it through in order rather than asserting all three verbatim.
jq -e '.lines[1].text | test("second line")' <<<"$out" >/dev/null ||
  fail "second line text did not survive OCR"

echo "ok: ocr-lines boxes ($(jq -r '.lines | length' <<<"$out") lines)"
