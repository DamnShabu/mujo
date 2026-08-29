#!/usr/bin/env bash
set -euo pipefail

# mujo-screenshot.sh - Backend engine for screenshot capture, cropping, OCR, and translation

TMP_BASE="/tmp/mujo-snip"
RAW_SHOT="${TMP_BASE}-raw.png"
CROPPED_SHOT="${TMP_BASE}-crop.png"
OCR_PREPROC="${TMP_BASE}-ocr.png"
CONFIG_FILE="${HOME}/.config/qsshell/screenshot.json"
LOCK_FILE="/run/user/${UID:-1000}/mujo-screenshot.lock"

# Created lazily in cmd_save — get_config runs on every screenshot-overlay open.

get_config() {
  local key="$1"
  local def="$2"
  if [[ -f "$CONFIG_FILE" ]]; then
    jq -r --arg k "$key" --arg d "$def" '.[$k] // $d' "$CONFIG_FILE" 2>/dev/null || echo "$def"
  else
    echo "$def"
  fi
}

set_config() {
  local key="$1"
  local val="$2"
  local tmp
  tmp=$(mktemp)
  if [[ -f "$CONFIG_FILE" ]]; then
    jq --arg k "$key" --arg v "$val" '.[$k] = $v' "$CONFIG_FILE" > "$tmp" 2>/dev/null || echo "{\"$key\": \"$val\"}" > "$tmp"
  else
    echo "{\"$key\": \"$val\"}" > "$tmp"
  fi
  [[ -d "${CONFIG_FILE%/*}" ]] || mkdir -p "${CONFIG_FILE%/*}"
  mv "$tmp" "$CONFIG_FILE"
}

cmd_freeze() {
  # Instant full virtual desktop capture with 0 compression for maximum speed (~30ms)
  rm -f "${TMP_BASE}"*
  grim -l 0 "$RAW_SHOT"
  echo "$RAW_SHOT"
}

cmd_crop() {
  local x="$1" y="$2" w="$3" h="$4"
  if [[ "$w" -le 0 || "$h" -le 0 ]]; then
    echo "Invalid dimensions: ${w}x${h}" >&2
    return 1
  fi
  # An offset outside the capture only makes `magick -crop` *warn* — it still
  # exits 0 and writes a 1x1 placeholder, which cmd_save then cheerfully files
  # away and announces as a screenshot. Refuse instead, so a coordinate bug is
  # a visible failure rather than a folder of blank PNGs.
  local rw rh
  read -r rw rh < <(magick identify -format '%w %h\n' "$RAW_SHOT")
  if ((x < 0 || y < 0 || x >= rw || y >= rh)); then
    echo "Selection ${w}x${h}+${x}+${y} lies outside the ${rw}x${rh} capture" >&2
    return 1
  fi
  magick "$RAW_SHOT" -crop "${w}x${h}+${x}+${y}" +repage "$CROPPED_SHOT"
  echo "$CROPPED_SHOT"
}

cmd_copy() {
  local x="$1" y="$2" w="$3" h="$4"
  cmd_crop "$x" "$y" "$w" "$h" >/dev/null
  wl-copy -t image/png < "$CROPPED_SHOT"
  echo "Copied to clipboard"
}

cmd_save() {
  local x="$1" y="$2" w="$3" h="$4"
  cmd_crop "$x" "$y" "$w" "$h" >/dev/null
  local out_dir
  out_dir=$(get_config "saveDirectory" "${HOME}/Pictures/Screenshots")
  mkdir -p "$out_dir"
  local filename="Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
  local dest="${out_dir}/${filename}"
  cp "$CROPPED_SHOT" "$dest"
  wl-copy -t image/png < "$CROPPED_SHOT"
  notify-send -a "Mujō Screenshot" -i "$dest" "Screenshot Saved" "Saved to ~/Pictures/Screenshots/${filename}"
  echo "$dest"
}

cmd_ocr() {
  local x="$1" y="$2" w="$3" h="$4"
  cmd_crop "$x" "$y" "$w" "$h" >/dev/null
  # Preprocess for OCR: convert to grayscale, normalize contrast, slight sharpening
  magick "$CROPPED_SHOT" -colorspace Gray -normalize -sharpen 0x1 "$OCR_PREPROC"
  local lang
  lang=$(get_config "ocrLanguages" "eng+ukr")
  local text
  text=$(tesseract "$OCR_PREPROC" stdout -l "$lang" 2>/dev/null || tesseract "$OCR_PREPROC" stdout 2>/dev/null || echo "")
  # Trim whitespace
  text=$(echo "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [[ -n "$text" ]]; then
    echo "$text" | wl-copy || true
  fi
  echo "$text"
}

# Same crop and preprocessing as cmd_ocr — both are geometry-preserving, so the
# boxes tesseract reports are in cropped-image pixels and the overlay can place
# them by scaling against the selection rectangle. Emits one object per text
# line so the translation can be painted where the original text sits:
#
#   {"w":700,"h":260,"lines":[{"x":23,"y":36,"w":185,"h":31,"text":"…"}, …]}
#
# tesseract's TSV puts the box on the level-4 (line) row and the words on level-5
# rows underneath it. Rather than correlate the two, take only the words and
# union their boxes per (block, par, line) — same rectangle, one pass.
cmd_ocr_lines() {
  local x="$1" y="$2" w="$3" h="$4"
  cmd_crop "$x" "$y" "$w" "$h" >/dev/null
  magick "$CROPPED_SHOT" -colorspace Gray -normalize -sharpen 0x1 "$OCR_PREPROC"
  local lang cw ch
  lang=$(get_config "ocrLanguages" "eng+ukr")
  read -r cw ch < <(magick identify -format '%w %h\n' "$OCR_PREPROC")
  tesseract "$OCR_PREPROC" stdout -l "$lang" tsv 2>/dev/null |
    jq -c -R -s --argjson cw "$cw" --argjson ch "$ch" '
      [ split("\n")[]
        | select(length > 0)
        | split("\t")
        | select(length > 11 and .[0] == "5")
        | select((.[11] | gsub("\\s"; "")) != "")
        | select((.[10] | tonumber) >= 40)
        | { key: (.[2] + "/" + .[3] + "/" + .[4]),
            word: (.[5] | tonumber),
            x: (.[6] | tonumber), y: (.[7] | tonumber),
            w: (.[8] | tonumber), h: (.[9] | tonumber),
            text: .[11] }
      ]
      | group_by(.key)
      | map(sort_by(.word)
        | { x:    (map(.x) | min),
            y:    (map(.y) | min),
            w:    ((map(.x + .w) | max) - (map(.x) | min)),
            h:    ((map(.y + .h) | max) - (map(.y) | min)),
            text: (map(.text) | join(" ")) })
      | sort_by(.y, .x)
      | { w: $cw, h: $ch, lines: . }
    '
}

cmd_translate() {
  local target_lang="$1"
  shift
  local text="$*"
  if [[ -z "$text" ]]; then
    echo "No text provided"
    return 1
  fi
  set_config "targetLanguage" "$target_lang"
  trans -b -s auto -t "$target_lang" "$text" 2>/dev/null || echo "Translation failed"
}

cmd_close() {
  local bar_qml="/etc/xdg/quickshell/bar/shell.qml"
  if command -v quickshell >/dev/null 2>&1; then
    quickshell -p "$bar_qml" ipc call screenshot close >/dev/null 2>&1 || true
  elif command -v qs >/dev/null 2>&1; then
    qs -p "$bar_qml" ipc call screenshot close >/dev/null 2>&1 || true
  fi
}

cmd_launch() {
  # Prevent concurrent launches / duplicate instances
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    echo "mujo-screenshot: Another instance is already launching." >&2
    exit 0
  fi

  cmd_freeze >/dev/null

  # 1. Fast path: IPC call to the running qs-bar daemon (<30ms)
  local bar_qml="/etc/xdg/quickshell/bar/shell.qml"
  if command -v quickshell >/dev/null 2>&1; then
    if quickshell -p "$bar_qml" ipc call screenshot open >/dev/null 2>&1; then
      exit 0
    fi
  fi
  if command -v qs >/dev/null 2>&1; then
    if qs -p "$bar_qml" ipc call screenshot open >/dev/null 2>&1; then
      exit 0
    fi
  fi

  # 2. Fallback to standalone quickshell instance if qs-bar daemon is not running
  local qml_path="${MUJO_SCREENSHOT_QML:-}"
  if [[ -z "$qml_path" || ! -f "$qml_path" ]]; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/bar/screenshot.qml" ]]; then
      qml_path="${script_dir}/bar/screenshot.qml"
    elif [[ -f "/etc/xdg/quickshell/bar/screenshot.qml" ]]; then
      qml_path="/etc/xdg/quickshell/bar/screenshot.qml"
    fi
  fi

  if [[ -n "$qml_path" && -f "$qml_path" ]]; then
    export QT_SCALE_FACTOR=1
    export QT_AUTO_SCREEN_SCALE_FACTOR=0
    exec quickshell -n -p "$qml_path"
  else
    echo "Error: screenshot.qml not found at $qml_path" >&2
    exit 1
  fi
}

case "${1:-launch}" in
  freeze) cmd_freeze ;;
  crop) cmd_crop "$2" "$3" "$4" "$5" ;;
  copy) cmd_copy "$2" "$3" "$4" "$5" ;;
  save) cmd_save "$2" "$3" "$4" "$5" ;;
  ocr) cmd_ocr "$2" "$3" "$4" "$5" ;;
  ocr-lines) cmd_ocr_lines "$2" "$3" "$4" "$5" ;;
  translate) cmd_translate "$2" "${@:3}" ;;
  config-get) get_config "$2" "${3:-}" ;;
  config-set) set_config "$2" "$3" ;;
  close) cmd_close ;;
  launch|open) cmd_launch ;;
  *)
    echo "Usage: $0 {launch|open|close|freeze|crop|copy|save|ocr|ocr-lines|translate|config-get|config-set}" >&2
    exit 1
    ;;
esac
