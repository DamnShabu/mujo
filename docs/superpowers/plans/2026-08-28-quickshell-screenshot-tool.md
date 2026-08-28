# Quickshell Screenshot, OCR & Translation Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, theme-integrated Quickshell screenshot tool triggered by `Super+Shift+S` with interactive region selection, floating action bar, OCR text extraction via Tesseract, translation via translate-shell, annotations, and system clipboard/file saving.

**Architecture:** A standalone Quickshell application in `quickshell/screenshot/` sharing Mujō's `Theme.qml` design tokens, driven by a performant background CLI helper `quickshell/mujo-screenshot.sh` using `grim`, `imagemagick`, `tesseract`, `translate-shell`, and `wl-clipboard`.

**Tech Stack:** Quickshell 0.3.0, QML/QtQuick (Wayland Overlay layer), Bash/ImageMagick, Tesseract OCR, Translate-shell, Niri compositor.

**Spec:** `docs/superpowers/specs/2026-08-28-screenshot-tool-design.md`

## Global Constraints

- **Theme Consistency**: Must import and use `Theme.qml`, `Icons.qml`, and `Anim.qml` from `quickshell/bar/theme/` — never use hardcoded color literals.
- **Pure Wayland & Niri**: Use layer-shell overlay (`WlrLayer.Overlay`) with exclusive focus during selection.
- **Never hardcode paths**: Use `$HOME` / `Quickshell.env("HOME")` for user directories; save images to `~/Pictures/Screenshots/`.
- **Packaging Integrity**: Ensure all runtime dependencies (`tesseract`, `translate-shell`, `grim`, `imagemagick`, `wl-clipboard`) are correctly wrapped in Nix.
- **Codebase Conventions**: Every new directory must have a valid `qmldir`.

---

### Task 1: Backend Helper Script & CLI Wrapper

**Files:**
- Create: `quickshell/mujo-screenshot.sh`
- Modify: `quickshell/mujo.sh:1-100`

**Interfaces:**
- Produces: `mujo screenshot [capture|crop|ocr|translate|save|copy]` CLI subcommands.

- [ ] **Step 1: Write helper script `quickshell/mujo-screenshot.sh`**

```bash
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

cmd_freeze() {
  # Instant full virtual desktop capture
  rm -f "${TMP_BASE}"*
  grim "$RAW_SHOT"
  echo "$RAW_SHOT"
}

cmd_crop() {
  local x="$1" y="$2" w="$3" h="$4"
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
  local dest="${out_dir}/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
  cp "$CROPPED_SHOT" "$dest"
  wl-copy -t image/png < "$CROPPED_SHOT"
  notify-send -a "Mujō Screenshot" -i "$dest" "Screenshot Saved" "Saved to $(basename "$dest")"
  echo "$dest"
}

cmd_ocr() {
  local x="$1" y="$2" w="$3" h="$4"
  cmd_crop "$x" "$y" "$w" "$h" >/dev/null
  # Preprocess for better OCR accuracy (grayscale + contrast stretch + slight unsharp)
  magick "$CROPPED_SHOT" -colorspace Gray -normalize -unsharp 0x1 "$OCR_PREPROC"
  local lang
  lang=$(get_config "ocrLanguages" "eng+ukr")
  local text
  text=$(tesseract "$OCR_PREPROC" stdout -l "$lang" --psm 6 2>/dev/null || tesseract "$OCR_PREPROC" stdout 2>/dev/null || echo "")
  echo "$text" | wl-copy || true
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
  trans -b -s auto -t "$target_lang" "$text" 2>/dev/null || echo "Translation failed"
}

case "${1:-}" in
  freeze) cmd_freeze ;;
  crop) cmd_crop "$2" "$3" "$4" "$5" ;;
  copy) cmd_copy "$2" "$3" "$4" "$5" ;;
  save) cmd_save "$2" "$3" "$4" "$5" ;;
  ocr) cmd_ocr "$2" "$3" "$4" "$5" ;;
  translate) cmd_translate "$2" "${@:3}" ;;
  *)
    echo "Usage: $0 {freeze|crop|copy|save|ocr|translate}" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Make `quickshell/mujo-screenshot.sh` executable and test commands**

Run:
```bash
chmod +x quickshell/mujo-screenshot.sh
```

- [ ] **Step 3: Wire `screenshot` command into `quickshell/mujo.sh`**

Modify `quickshell/mujo.sh` to add `screenshot` subcommand dispatching to quickshell screenshot tool.

- [ ] **Step 4: Commit**

```bash
git add quickshell/mujo-screenshot.sh quickshell/mujo.sh
git commit -m "feat(screenshot): add backend helper script for capture, crop, ocr, and translation"
```

---

### Task 2: Nix Flake Derivation & Keybinding Configuration

**Files:**
- Modify: `quickshell/_default.nix`
- Modify: `modules/flake/perSystem.nix`
- Modify: `nixos/desktop/quickshell.nix`
- Modify: `modules/wrappers/niri.nix`

- [ ] **Step 1: Add `mujo-screenshot` derivation in `quickshell/_default.nix`**

Define `mujo-screenshot` wrapping `quickshell`, `grim`, `imagemagick`, `tesseract`, `translate-shell`, `wl-clipboard`, `libnotify`, `jq`, `coreutils`, `bash`.

- [ ] **Step 2: Export `mujo-screenshot` in `modules/flake/perSystem.nix`**

- [ ] **Step 3: Update `nixos/desktop/quickshell.nix` to include `qs.mujo-screenshot`**

- [ ] **Step 4: Update `modules/wrappers/niri.nix`**

Change:
`"Mod+Shift+S".spawn-sh = "quicksnip";`
To:
`"Mod+Shift+S".spawn-sh = "mujo screenshot";` (or direct path).

- [ ] **Step 5: Verify flake evaluation**

Run: `nix flake check`

- [ ] **Step 6: Commit**

```bash
git add quickshell/_default.nix modules/flake/perSystem.nix nixos/desktop/quickshell.nix modules/wrappers/niri.nix
git commit -m "feat(nix): package mujo-screenshot and bind to Mod+Shift+S"
```

---

### Task 3: Core Selection Overlay, Loupe & Keyboard Navigation

**Files:**
- Create: `quickshell/screenshot/qmldir`
- Create: `quickshell/screenshot/Loupe.qml`
- Create: `quickshell/screenshot/SelectionArea.qml`
- Create: `quickshell/screenshot/screenshot.qml`

- [ ] **Step 1: Create `quickshell/screenshot/qmldir`**

```
module quickshell.screenshot
Loupe 1.0 Loupe.qml
SelectionArea 1.0 SelectionArea.qml
FloatingToolbar 1.0 FloatingToolbar.qml
OcrCard 1.0 OcrCard.qml
TranslateCard 1.0 TranslateCard.qml
AnnotationCanvas 1.0 AnnotationCanvas.qml
```

- [ ] **Step 2: Create `quickshell/screenshot/Loupe.qml`**

Circular magnifier showing 3x zoom of pixels under cursor with dimension badge `(W × H px)`.

- [ ] **Step 3: Create `quickshell/screenshot/SelectionArea.qml`**

Bounding box rectangle with `Theme.accent` border, 8 resize handles (top-left, top, top-right, right, bottom-right, bottom, bottom-left, left), interior drag area for moving selection, and dimension chip.

- [ ] **Step 4: Create `quickshell/screenshot/screenshot.qml`**

Full-screen layer shell window on `Quickshell.screens` (`WlrLayer.Overlay`, `WlrKeyboardFocus.Exclusive`):
- Loads frozen screenshot buffer `/tmp/mujo-snip-raw.png`.
- Renders dimmed mask outside the active selection.
- Handles keyboard shortcuts (`Escape`, `Enter`, `Ctrl+C`, `Ctrl+S`, `Ctrl+O`, `Ctrl+T`, `Ctrl+Z`).
- Coordinates state between selection, toolbar, OCR, translation, and canvas.

- [ ] **Step 5: Test standalone QML evaluation**

Run: `qs -p quickshell/screenshot/screenshot.qml`

- [ ] **Step 6: Commit**

```bash
git add quickshell/screenshot/
git commit -m "feat(screenshot): implement full-screen overlay, selection box, and loupe"
```

---

### Task 4: Floating Action Toolbar

**Files:**
- Create: `quickshell/screenshot/FloatingToolbar.qml`
- Modify: `quickshell/screenshot/screenshot.qml`

- [ ] **Step 1: Implement `FloatingToolbar.qml`**

Pill-shaped action bar anchored below (or above if close to edge) the selection box:
- Actions:
  - Copy (`content_copy`)
  - Save (`save`)
  - OCR (`document_scanner`)
  - Translate (`translate`)
  - Annotate (`draw`)
  - Pin (`push_pin`)
  - Close (`close`)
- Uses `Theme.surface`, `Theme.borderStrong`, `Theme.cornerRadius`, `Theme.accent` highlight on hover.

- [ ] **Step 2: Wire toolbar actions to backend execution and modal triggers**

- [ ] **Step 3: Commit**

```bash
git add quickshell/screenshot/FloatingToolbar.qml quickshell/screenshot/screenshot.qml
git commit -m "feat(screenshot): add floating action toolbar with copy, save, ocr, and translate actions"
```

---

### Task 5: OCR Card Popover

**Files:**
- Create: `quickshell/screenshot/OcrCard.qml`
- Modify: `quickshell/screenshot/screenshot.qml`

- [ ] **Step 1: Implement `OcrCard.qml`**

- Features:
  - Header with OCR icon, character count, and title.
  - Spinner while tesseract processes.
  - Scrollable editable `TextArea` displaying extracted text.
  - Action buttons: `[Copy Text]`, `[Translate]`, `[Close]`.
  - Automatic copy to clipboard on completion.

- [ ] **Step 2: Test OCR extraction flow on test image**

- [ ] **Step 3: Commit**

```bash
git add quickshell/screenshot/OcrCard.qml quickshell/screenshot/screenshot.qml
git commit -m "feat(screenshot): add OCR text recognition card popover"
```

---

### Task 6: Translation Card Popover

**Files:**
- Create: `quickshell/screenshot/TranslateCard.qml`
- Modify: `quickshell/screenshot/screenshot.qml`

- [ ] **Step 1: Implement `TranslateCard.qml`**

- Features:
  - Source text preview.
  - Target language selector chips / dropdown (`en`, `uk`, `de`, `es`, `fr`, `ja`, `zh`).
  - Spinner while `trans` translates.
  - Translated output text view.
  - Action buttons: `[Copy Translation]`, `[Ask AI]`, `[Close]`.
  - Reads & saves default target language to `~/.config/qsshell/screenshot.json`.

- [ ] **Step 2: Test translation flow**

- [ ] **Step 3: Commit**

```bash
git add quickshell/screenshot/TranslateCard.qml quickshell/screenshot/screenshot.qml
git commit -m "feat(screenshot): add live translation card popover with language switcher"
```

---

### Task 7: Annotation & Drawing Canvas

**Files:**
- Create: `quickshell/screenshot/AnnotationCanvas.qml`
- Modify: `quickshell/screenshot/screenshot.qml`

- [ ] **Step 1: Implement `AnnotationCanvas.qml`**

- Features:
  - Tool palette: Pen, Arrow, Rectangle, Highlighter, Blur/Pixelate, Color picker, Undo.
  - QtQuick Canvas drawing strokes and geometric primitives.
  - Undo stack for strokes.
  - Flatten onto cropped image during Copy / Save.

- [ ] **Step 2: Test drawing tools**

- [ ] **Step 3: Commit**

```bash
git add quickshell/screenshot/AnnotationCanvas.qml quickshell/screenshot/screenshot.qml
git commit -m "feat(screenshot): add drawing annotation canvas and shape tools"
```

---

### Task 8: End-to-End Verification & Formatting

**Files:**
- Modify: Any files needing cleanup

- [ ] **Step 1: Check Nix flake**

Run: `nix flake check`

- [ ] **Step 3: Verify live interaction**

Run interactive test: `mujo-screenshot.sh freeze && qs -p quickshell/screenshot/screenshot.qml`

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "feat(screenshot): complete quickshell screenshot tool with ocr and translation"
```
