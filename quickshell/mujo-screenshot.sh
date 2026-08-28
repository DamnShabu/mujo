#!/usr/bin/env bash
set -euo pipefail

# mujo-screenshot.sh - Backend engine for screenshot capture, cropping, OCR, and translation

TMP_BASE="/tmp/mujo-snip"
RAW_SHOT="${TMP_BASE}-raw.png"
CROPPED_SHOT="${TMP_BASE}-crop.png"
OCR_PREPROC="${TMP_BASE}-ocr.png"
CONFIG_FILE="${HOME}/.config/qsshell/screenshot.json"

mkdir -p "${HOME}/Pictures/Screenshots"
mkdir -p "${HOME}/.config/qsshell"

get_config() {
  local key="$1"
  local def="$2"
  if [[ -f "$CONFIG_FILE" ]]; then
    jq -r ".$key // \"$def\"" "$CONFIG_FILE" 2>/dev/null || echo "$def"
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
  mv "$tmp" "$CONFIG_FILE"
}

cmd_freeze() {
  # Instant full virtual desktop capture
  rm -f "${TMP_BASE}"*
  grim "$RAW_SHOT"
  echo "$RAW_SHOT"
}

cmd_crop() {
  local x="$1" y="$2" w="$3" h="$4"
  if [[ "$w" -le 0 || "$h" -le 0 ]]; then
    echo "Invalid dimensions: ${w}x${h}" >&2
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

cmd_launch() {
  cmd_freeze >/dev/null
  local qml_path="${MUJO_SCREENSHOT_QML:-}"
  if [[ -z "$qml_path" || ! -f "$qml_path" ]]; then
    # Fallback to relative script path if running in dev mode
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/screenshot/screenshot.qml" ]]; then
      qml_path="${script_dir}/screenshot/screenshot.qml"
    elif [[ -f "/etc/xdg/quickshell/screenshot/screenshot.qml" ]]; then
      qml_path="/etc/xdg/quickshell/screenshot/screenshot.qml"
    fi
  fi

  if [[ -n "$qml_path" && -f "$qml_path" ]]; then
    exec quickshell -p "$qml_path"
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
  translate) cmd_translate "$2" "${@:3}" ;;
  config-get) get_config "$2" "${3:-}" ;;
  config-set) set_config "$2" "$3" ;;
  launch) cmd_launch ;;
  *)
    echo "Usage: $0 {launch|freeze|crop|copy|save|ocr|translate|config-get|config-set}" >&2
    exit 1
    ;;
esac
