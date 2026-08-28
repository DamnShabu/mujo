#!/usr/bin/env bash
set -e

usage() {
  cat >&2 <<EOF
Usage: mujo <command> [args...]

Commands:
  wallpaper <subcommand>   Wallpaper management
  theme <subcommand>       Shell color theme
  persist <subcommand>     NixOS persistence (impermanence) list
  llm <subcommand>         LLM tracker status (bar widget)
  ai <chat|test|agents|use>  Chat completion via an agent CLI or an OpenAI-compatible API
  generations              JSON list of NixOS system generations
  update-status            JSON flake.lock freshness vs the running system
  update                   git pull + flake update + rebuild (streamed)
  settings [get|set|write] Open the Settings app, or read/write the store
  backup [run|status]      System backup status and snapshot triggers
  overrides <subcommand>   Local NixOS override drop-ins (list/enable/disable/add/remove/show)
  shelf <subcommand>       Staging shelf management (list/add/remove/clear/toggle/open)
  screenshot [subcommand]  Screenshot tool with OCR & Translation
  crash <subcommand>       Multi-source crash stream, AI diagnosis, and auto-fixes
  sentinel <subcommand>    Process sentinel: runaway CPU/RAM/GPU & zombie killer
  clean <subcommand>       System cleaner: Nix store GC, journal vacuum, cache & ZRAM
  health [summary|check]   Overall system health & vitals score
  idle-guard <audio|charging>  Exit 0 if idle actions should be inhibited (used by swayidle)
  help                      Show this help
EOF
  exit 1
}

crash_usage() {
  cat >&2 <<EOF
Usage: mujo crash <command> [args...]

Commands:
  stream                    Stream normalized crash events as JSON lines (coredump, unit, oom, gpu)
  info <type> <id>          Get sanitized crash details and stacktrace / log context
  diagnose <type> <id>      Run AI root-cause analysis and return structured fix recipes (JSON)
  fix <action> [target]     Execute safe crash fix action (restart-unit, clear-cache, rollback-gen)
EOF
  exit 1
}

sentinel_usage() {
  cat >&2 <<EOF
Usage: mujo sentinel <command> [args...]

Commands:
  scan                      Scan running processes, CPU, RAM, GPU, zombies (JSON)
  reap                      Silently reap harmless zombie and defunct processes (JSON)
  action <cmd> <pid> [val]  Send process signal (kill, term, stop, cont, renice)
EOF
  exit 1
}

clean_usage() {
  cat >&2 <<EOF
Usage: mujo clean <command> [args...]

Commands:
  scan                      Calculate reclaimable disk & memory space across all modules (JSON)
  apply <nix|journal|caches|memory|all>  Execute modular system cleanup
EOF
  exit 1
}

health_usage() {
  cat >&2 <<EOF
Usage: mujo health [summary]

Commands:
  summary                   Unified system health, vitals, sentinel anomalies & cleaner stats (JSON)
EOF
  exit 1
}

persist_usage() {
  cat >&2 <<EOF
Usage: mujo persist <command> [args...]

Commands:
  current                   List paths currently persisted (JSON)
  list                      Show the GUI-managed list (JSON)
  add user|system <path>    Add a directory to persistence
  remove user|system <path> Remove a directory from persistence
  apply                     Rebuild NixOS to apply changes
EOF
  exit 1
}

shelf_usage() {
  cat >&2 <<EOF
Usage: mujo shelf <command> [args...]

Commands:
  list                      List staged items in JSON format
  add <path>...             Add one or more files to the staging shelf
  remove <path>...          Remove one or more files from the shelf
  clear                     Clear all staged items
  toggle                    Toggle shelf popup in quickshell
  open <path>               Open a shelved item
EOF
  exit 1
}

niri_usage() {
  cat >&2 <<EOF
Usage: mujo niri <command> [args...]

Commands:
  get                            Show the GUI-managed niri settings (JSON)
  output set <name> <key> <val>  Set an output field (mode/x/y/scale/transform/enabled)
  input set <key> <val>          Set an input field (repeat_rate, mouse_accel_speed, …)
  save-outputs                   Capture the live display layout into the config
  apply                          Rebuild NixOS to apply changes
EOF
  exit 1
}

theme_usage() {
  cat >&2 <<EOF
Usage: mujo theme <command> [args...]

Commands:
  set <preset>              Set the active preset (ayu, catppuccin, dracula,
                            nord, gruvbox, tokyonight, rosepine, onedark,
                            everforest, kanagawa, monokaipro, solarized,
                            githubdark, synthwave, oxocarbon, palenight)
  accent <hex|"">           Override accent color ("" clears the override)
  transparency <0.6-1.0>    Set surface transparency
  sync                      Apply active theme palette to Kitty and Fish
  get [key]                 Show theme config (or one key)
  show                      Show current config
EOF
  exit 1
}

llm_usage() {
  cat >&2 <<EOF
Usage: mujo llm <command> [args...]

Commands:
  model add <name> [note]   Mark a model as active (upserts by name)
  model remove <name>       Remove an active model
  tokens set <count>        Set the tracked token count
  tokens add <delta>        Add to the tracked token count
  clear                     Clear all tracked state
  show                      Show current status JSON
EOF
  exit 1
}

ai_usage() {
  cat >&2 <<EOF
Usage: mujo ai <command>

Commands:
  chat    Run a chat completion. Reads a JSON messages array on stdin; prints
          the assistant reply on stdout. With ai.provider="agent" the active
          agent CLI (claude, opencode, agy, codex, ...) answers headlessly in
          its read-only mode; otherwise it POSTs an OpenAI-compatible
          completion, reading ai.{baseUrl,model,maxTokens} from the settings
          store and the API key from the keyring (service qsshell, account
          <provider>-api-key). Kill the process to cancel.
  test    Connectivity check for the resolved backend, as
          {ok,latencyMs,models[]} JSON: GET <baseUrl>/models for the HTTP
          path, <bin> --version for an agent CLI.
  agents  List the known agent CLIs and which of them are installed, as
          {agents:[{id,name,bin,available,run[],term[]}], active} JSON.
  use <id>
          Make <id> the active agent desktop-wide (writes llm-default.json,
          the same selection the bar's LLM widget shows).
EOF
  exit 1
}

# Read a setting leaf as a raw string ("" when absent/null).
ai_get() { jq -r --arg p "$1" '(getpath($p | split(".")) // empty) | if type=="string" or type=="number" then tostring else empty end' "${SETTINGS_CONF}"; }

# Fetch the API key for a provider from the keyring (empty if none / local).
ai_key() {
  local prov="$1" id
  id="$(mujo-keyring list 2>/dev/null | jq -r --arg a "${prov}-api-key" '.[] | select(.service=="qsshell" and .account==$a) | .id' | head -n1)"
  if [[ -n "${id}" ]]; then mujo-keyring get "${id}" 2>/dev/null || true; fi
  return 0
}

# The active-agent selection lives in the file the bar's LLM widget writes and
# llm-usage.sh reads, so picking a provider there also picks the Ask-AI backend.
AI_DEFAULT_FILE="${HOME}/.config/qsshell/llm-default.json"

# Headless agent runs happen here rather than in $HOME or a checkout: these CLIs
# can touch the filesystem, and "Ask AI" is only ever an advisor, so they get an
# empty scratch directory on top of each tool's read-only mode.
AI_SCRATCH="${HOME}/.cache/qsshell/ai-scratch"

# Known agent CLIs. `id` matches llm-usage.sh's provider ids so the bar widget
# and the AI settings panel are selecting the same thing. `run` is the read-only
# one-shot argv (the prompt is appended as a final positional element, never
# interpolated into a shell string); `term` is the interactive argv the launcher
# opens in a terminal. `filter`, when present, is a jq -n program that turns the
# tool's structured output into plain text — needed for CLIs whose plain output
# is ANSI-decorated chrome rather than just the reply. A non-empty
# ai.agentCommand adds a "custom" row.
ai_agent_table() {
  jq -n --arg custom "$(ai_get ai.agentCommand)" '
    [ {id:"claude",      name:"Claude Code", bin:"claude",
       run:["claude","-p","--permission-mode","plan"], term:["claude"]},
      {id:"opencode",    name:"opencode",    bin:"opencode",
       run:["opencode","run","--agent","plan","--format","json"],
       filter:"[inputs | select(.type == \"text\") | .part.text] | join(\"\")",
       term:["opencode","run","-i"]},
      {id:"antigravity", name:"Antigravity", bin:"agy",
       run:["agy","--mode","plan","-p"],             term:["agy","-i"]},
      {id:"codex",       name:"Codex",       bin:"codex",
       run:["codex","exec","--sandbox","read-only"], term:["codex"]},
      {id:"gemini",      name:"Gemini CLI",  bin:"gemini",
       run:["gemini","-p"],                          term:["gemini","-i"]},
      {id:"pi",          name:"Pi",          bin:"pi",
       run:["pi","-p"],                              term:["pi"]}
    ]
    + (($custom | split(" ") | map(select(. != ""))) as $argv |
       if ($argv | length) == 0 then []
       else [{id:"custom", name:"Custom command", bin:$argv[0], run:$argv, term:$argv}]
       end)'
}

# The table plus an `available` flag per row and the resolved active agent.
# Active resolution: ai.agent when set, else llm-default.json, else the first
# installed agent — always validated against what is actually on PATH.
ai_agents() {
  local table avail bin bins=""
  table="$(ai_agent_table)"
  while IFS= read -r bin; do
    [[ -n "${bin}" ]] && command -v "${bin}" >/dev/null 2>&1 && bins+="${bin}"$'\n'
  done < <(printf '%s' "${table}" | jq -r '.[].bin')
  avail="$(printf '%s' "${bins}" | jq -R . | jq -s 'map(select(. != ""))')"

  local want
  want="$(ai_get ai.agent)"
  if [[ -z "${want}" && -f "${AI_DEFAULT_FILE}" ]]; then
    want="$(jq -r '.default // empty' "${AI_DEFAULT_FILE}" 2>/dev/null || true)"
  fi

  jq -n --argjson t "${table}" --argjson a "${avail:-[]}" --arg want "${want}" '
    ($t | map(. + {available: ((.bin as $b | $a | index($b)) != null)})) as $agents |
    ($agents | map(select(.available))) as $ok |
    { agents: $agents,
      active: (if ($ok | map(.id) | index($want)) != null then $want
               else ($ok[0].id // "") end) }'
}

# Resolve the backend: an agent CLI (AI_KIND=agent) or an OpenAI-compatible
# endpoint with the Ollama-local defaults (AI_KIND=http).
ai_resolve() {
  AI_PROVIDER="$(ai_get ai.provider)"; [[ -n "${AI_PROVIDER}" ]] || AI_PROVIDER="ollama"
  if [[ "${AI_PROVIDER}" == "agent" ]]; then
    AI_KIND="agent"
    AI_AGENTS="$(ai_agents)"
    AI_AGENT="$(printf '%s' "${AI_AGENTS}" | jq -r '.active')"
    return 0
  fi
  AI_KIND="http"
  AI_BASEURL="$(ai_get ai.baseUrl)"
  if [[ -z "${AI_BASEURL}" && "${AI_PROVIDER}" == "ollama" ]]; then AI_BASEURL="http://127.0.0.1:11434/v1"; fi
  AI_MODEL="$(ai_get ai.model)"
  AI_MAXTOK="$(ai_get ai.maxTokens)"; [[ -n "${AI_MAXTOK}" ]] || AI_MAXTOK="1024"
}

# One field of the active agent's row ("run"/"term" argv lists print one element
# per line; scalars print as-is).
ai_agent_field() {
  printf '%s' "${AI_AGENTS}" | jq -r --arg id "${AI_AGENT}" --arg k "$1" \
    '.agents[] | select(.id == $id) | (.[$k] // empty) | if type == "array" then .[] else . end'
}

wallpaper_usage() {
  cat >&2 <<EOF
Usage: mujo wallpaper <command> [args...]

Commands:
  set <path>                     Set wallpaper for all monitors
  set <path> --monitor <name>    Set wallpaper for specific monitor
  motion <on|off>                 Toggle zoom + pan effect
  background <hex>                Set letterbox/background color
  list                            List local wallpaper files (JSON array)
  search [query|json] [options]  Search Wallhaven wallpapers (JSON result)
  details <id>                    Get metadata for a specific wallpaper (JSON)
  tag <id>                        Get metadata for a specific tag (JSON)
  save <url> [name]               Download a wallpaper into the library
  apply-url <url> [name]          Download and set as active wallpaper
  random                          Apply a random wallpaper from the library
  engine <subcommand> [args...]   Wallpaper Engine & Steam Workshop integration
  show                            Show current config
EOF
  exit 1
}

CONF="${HOME}/.config/quickshell/wallpaper.json"
mkdir -p "$(dirname "${CONF}")"
[[ -f "${CONF}" ]] || printf '{"effects":{"motion":true}}\n' > "${CONF}"

# Local wallpaper library. Downloads land here; `list`/`random` read from here
# plus the user's Pictures dir.
WALLPAPER_DIR="${XDG_PICTURES_DIR:-${HOME}/Pictures}/Wallpapers"
mkdir -p "${WALLPAPER_DIR}"

# Download <url> into the library, echo the local path (or fail). Optional 2nd
# arg names the file; otherwise derived from the URL.
wp_download() {
  local url="$1" name="${2:-}" dest
  if [[ -z "${name}" ]]; then
    name="$(basename "${url%%\?*}")"
    [[ -n "${name}" && "${name}" == *.* ]] || name="wallhaven-$(date +%s).jpg"
  fi
  dest="${WALLPAPER_DIR}/${name}"
  if [[ -s "${dest}" ]]; then
    printf '%s' "${dest}"
    return 0
  fi
  if curl -fsSL --max-time 90 -o "${dest}.part" "${url}"; then
    mv "${dest}.part" "${dest}"
    printf '%s' "${dest}"
  else
    rm -f "${dest}.part"
    return 1
  fi
}

# Emit a JSON array of image files across the library + Pictures, newest first.
wallpaper_list() {
  find "${WALLPAPER_DIR}" "${XDG_PICTURES_DIR:-${HOME}/Pictures}" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -printf '%T@\t%p\n' 2>/dev/null \
    | sort -rn | cut -f2- | jq -R . | jq -s .
}

wallpaper_search() {
  local q="" page="1" categories="111" purity="100" sorting="toplist" order="" toprange="" atleast="" resolutions="" ratios="" colors="" seed="" apikey=""

  if [[ $# -ge 1 && "$1" =~ ^\{.*\}$ ]]; then
    local json="$1"
    q="$(echo "${json}" | jq -r '.q // .query // ""' 2>/dev/null || echo "")"
    page="$(echo "${json}" | jq -r '.page // 1' 2>/dev/null || echo "1")"
    categories="$(echo "${json}" | jq -r '.categories // "111"' 2>/dev/null || echo "111")"
    purity="$(echo "${json}" | jq -r '.purity // "100"' 2>/dev/null || echo "100")"
    sorting="$(echo "${json}" | jq -r '.sorting // "toplist"' 2>/dev/null || echo "toplist")"
    order="$(echo "${json}" | jq -r '.order // ""' 2>/dev/null || echo "")"
    toprange="$(echo "${json}" | jq -r '.topRange // .toprange // ""' 2>/dev/null || echo "")"
    atleast="$(echo "${json}" | jq -r '.atleast // ""' 2>/dev/null || echo "")"
    resolutions="$(echo "${json}" | jq -r '.resolutions // ""' 2>/dev/null || echo "")"
    ratios="$(echo "${json}" | jq -r '.ratios // ""' 2>/dev/null || echo "")"
    colors="$(echo "${json}" | jq -r '.colors // ""' 2>/dev/null || echo "")"
    seed="$(echo "${json}" | jq -r '.seed // ""' 2>/dev/null || echo "")"
    apikey="$(echo "${json}" | jq -r '.apikey // .apiKey // ""' 2>/dev/null || echo "")"
  else
    while [[ $# -ge 1 ]]; do
      case "$1" in
        --query|-q) q="$2"; shift 2 ;;
        --page|-p) page="$2"; shift 2 ;;
        --categories|-c) categories="$2"; shift 2 ;;
        --purity) purity="$2"; shift 2 ;;
        --sorting|-s) sorting="$2"; shift 2 ;;
        --order) order="$2"; shift 2 ;;
        --topRange|--toprange|-t) toprange="$2"; shift 2 ;;
        --atleast|-a) atleast="$2"; shift 2 ;;
        --resolutions|-r) resolutions="$2"; shift 2 ;;
        --ratios) ratios="$2"; shift 2 ;;
        --colors) colors="$2"; shift 2 ;;
        --seed) seed="$2"; shift 2 ;;
        --apikey|--key|-k) apikey="$2"; shift 2 ;;
        *)
          if [[ -z "${q}" ]]; then q="$1"; shift
          elif [[ "${page}" == "1" ]]; then page="$1"; shift
          else shift; fi
          ;;
      esac
    done
  fi

  if [[ -z "${apikey}" && -f "${SETTINGS_CONF}" ]]; then
    apikey="$(jq -r '.wallhaven.apiKey // empty' "${SETTINGS_CONF}" 2>/dev/null || true)"
  fi

  local curl_args=()
  [[ -n "${q}" ]] && curl_args+=(--data-urlencode "q=${q}")
  [[ -n "${page}" ]] && curl_args+=(--data-urlencode "page=${page}")
  [[ -n "${categories}" ]] && curl_args+=(--data-urlencode "categories=${categories}")
  [[ -n "${purity}" ]] && curl_args+=(--data-urlencode "purity=${purity}")
  [[ -n "${sorting}" ]] && curl_args+=(--data-urlencode "sorting=${sorting}")
  [[ -n "${order}" ]] && curl_args+=(--data-urlencode "order=${order}")
  [[ -n "${toprange}" ]] && curl_args+=(--data-urlencode "topRange=${toprange}")
  [[ -n "${atleast}" ]] && curl_args+=(--data-urlencode "atleast=${atleast}")
  [[ -n "${resolutions}" ]] && curl_args+=(--data-urlencode "resolutions=${resolutions}")
  [[ -n "${ratios}" ]] && curl_args+=(--data-urlencode "ratios=${ratios}")
  [[ -n "${colors}" ]] && curl_args+=(--data-urlencode "colors=${colors}")
  [[ -n "${seed}" ]] && curl_args+=(--data-urlencode "seed=${seed}")
  [[ -n "${apikey}" ]] && curl_args+=(--data-urlencode "apikey=${apikey}")

  local response http_code body
  response="$(curl -sS --max-time 25 -w "\n%{http_code}" -G "https://wallhaven.cc/api/v1/search" "${curl_args[@]}" 2>/dev/null || echo -e '{"data":[],"error":"network_error"}\n000')"
  http_code="$(echo "${response}" | tail -n1)"
  body="$(echo "${response}" | sed '$d')"

  if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
    # Background pre-cache thumbnails for instant rendering
    echo "${body}" | jq -c '[.data[].thumbs.small // empty]' 2>/dev/null | {
      if command -v mujo-wallpaper-engine >/dev/null 2>&1; then
        mujo-wallpaper-engine cache-thumbnails >/dev/null 2>&1 &
      else
        python3 "$(dirname "${BASH_SOURCE[0]}")/wallpaper-engine/mujo-wallpaper-engine.py" cache-thumbnails >/dev/null 2>&1 &
      fi
    }
    echo "${body}"
  elif [[ "${http_code}" -eq 429 ]]; then
    echo '{"data":[],"error":"rate_limited","message":"Wallhaven rate limit reached (45 req/min). Please wait a moment."}'
    return 1
  elif [[ "${http_code}" -eq 401 ]]; then
    echo '{"data":[],"error":"unauthorized","message":"Invalid Wallhaven API key."}'
    return 1
  elif [[ "${http_code}" -eq 000 ]]; then
    echo '{"data":[],"error":"network_error","message":"Network request failed — check your internet connection."}'
    return 1
  else
    echo "{\"data\":[],\"error\":\"http_${http_code}\",\"message\":\"Request failed with HTTP status ${http_code}\"}"
    return 1
  fi
}

wallpaper_details() {
  [[ $# -ge 1 ]] || { echo '{"error":"missing_id"}' >&2; return 1; }
  local id="$1" apikey=""
  if [[ -f "${SETTINGS_CONF}" ]]; then
    apikey="$(jq -r '.wallhaven.apiKey // empty' "${SETTINGS_CONF}" 2>/dev/null || true)"
  fi
  local url="https://wallhaven.cc/api/v1/w/${id}"
  [[ -n "${apikey}" ]] && url="${url}?apikey=${apikey}"
  curl -fsSL --max-time 20 "${url}" 2>/dev/null || { echo '{"data":null,"error":"request_failed"}'; return 1; }
}

wallpaper_tag() {
  [[ $# -ge 1 ]] || { echo '{"error":"missing_id"}' >&2; return 1; }
  local id="$1"
  curl -fsSL --max-time 20 "https://wallhaven.cc/api/v1/tag/${id}" 2>/dev/null || { echo '{"data":null,"error":"request_failed"}'; return 1; }
}

LLM_CONF="${HOME}/.config/qsshell/llm-status.json"
mkdir -p "$(dirname "${LLM_CONF}")"
[[ -f "${LLM_CONF}" ]] || printf '{"models":[],"tokens":0,"updated":null}\n' > "${LLM_CONF}"

THEME_CONF="${HOME}/.config/quickshell/theme.json"
[[ -f "${THEME_CONF}" ]] || printf '{"preset":"ayu","accent":"","transparency":1.0}\n' > "${THEME_CONF}"

INTEG_CONF="${HOME}/.config/qsshell/integrations.json"
mkdir -p "$(dirname "${INTEG_CONF}")"
[[ -f "${INTEG_CONF}" ]] || printf '{}\n' > "${INTEG_CONF}"

WEATHER_CONF="${HOME}/.config/quickshell/weather.json"
[[ -f "${WEATHER_CONF}" ]] || printf '{"location":"","lat":null,"lon":null,"units":"celsius","wind":"kmh","interval":900}\n' > "${WEATHER_CONF}"
WEATHER_CACHE="${HOME}/.config/qsshell/weather-cache.json"

WIDGETS_CONF="${HOME}/.config/qsshell/widgets.json"
[[ -f "${WIDGETS_CONF}" ]] || printf '{"locked":false,"widgets":[]}\n' > "${WIDGETS_CONF}"

# Desktop icon layer. The directory is the user's real ~/Desktop and is the
# source of truth for what exists; DESKTOP_POS holds only where each item sits
# on the grid, kept deliberately outside ~/Desktop so UI metadata never lands
# among the user's own files.
DESKTOP_DIR="${XDG_DESKTOP_DIR:-${HOME}/Desktop}"
DESKTOP_POS="${HOME}/.local/state/qsshell/desktop-icons.json"

# WP-02: the one unified settings store. Everything except the color palette
# (theme.json) and the wallpaper (wallpaper.json) lives here under namespaced
# keys (bar.*, island.*, notifications.*, weather.*, ai.*, idle.*, lock.*,
# cava.*, backup.*, motion.*, …). Seeded once from the legacy weather.json so
# existing weather config survives the consolidation (back-compat migration).
SETTINGS_CONF="${HOME}/.config/qsshell/settings.json"
if [[ ! -f "${SETTINGS_CONF}" ]]; then
  if [[ -f "${WEATHER_CONF}" ]]; then
    jq '{weather: .}' "${WEATHER_CONF}" > "${SETTINGS_CONF}" 2>/dev/null || printf '{}\n' > "${SETTINGS_CONF}"
  else
    printf '{}\n' > "${SETTINGS_CONF}"
  fi
fi

# NixOS repo + GUI-managed persistence list (see nixos/core/user-persistence.nix).
REPO="${NIXCONF:-${HOME}/nixconf}"
PERSIST_JSON="${REPO}/nixos/core/user-persistence.json"

# Run a NixOS rebuild in a detached tmux session (session name mujo-rebuild) so
# it survives, doesn't steal focus, and can be watched with
# `tmux attach -t mujo-rebuild`. The graphical polkit agent (hosted by qs-bar)
# handles the pkexec prompt regardless of the detached pane. Optional $1 is a
# pre-command run before the rebuild (e.g. `mujo niri save-outputs`).
run_rebuild() {
  local pre="${1:-true}"
  local session="mujo-rebuild"
  local cmd="cd '${REPO}' && ${pre} && pkexec nixos-rebuild switch --flake '${REPO}#main'; ec=\$?; echo; echo \"[rebuild exited \$ec — press enter to close]\"; read -r _"
  tmux kill-session -t "${session}" 2>/dev/null || true
  tmux new-session -d -s "${session}" bash -lc "${cmd}"
  echo "Rebuilding in tmux session '${session}'. Watch with: tmux attach -t ${session}"
}

persist_write() { # <jq-filter> [jq-args...]
  local filter="$1"; shift
  [[ -f "${PERSIST_JSON}" ]] || printf '{"user":[],"system":[]}\n' > "${PERSIST_JSON}"
  jq "$@" "${filter}" "${PERSIST_JSON}" > "${PERSIST_JSON}.tmp" && mv "${PERSIST_JSON}.tmp" "${PERSIST_JSON}"
  # Flake only sees git-tracked files; stage so the next rebuild picks it up.
  git -C "${REPO}" add "${PERSIST_JSON}" 2>/dev/null || true
}

# Normalise a user path to a $HOME-relative directory (accepts ~/x, /home/u/x, x).
persist_norm_user() {
  local p="$1"
  p="${p/#\~\//}"
  p="${p#"${HOME}/"}"
  printf '%s' "${p#/}"
}

PREFS_JSON="${REPO}/nixos/core/system-preferences.json"
prefs_write() {
  local filter="$1"; shift
  [[ -f "${PREFS_JSON}" ]] || printf '{"hostname":"main","timezone":"Europe/Berlin","locale":"en_US.UTF-8","firewall":{"enable":true,"allowedTCPPorts":[11434]},"ssh":{"enable":false},"autoOptimiseStore":true,"zramSwap":{"enable":true,"memoryPercent":50}}\n' > "${PREFS_JSON}"
  jq "$@" "${filter}" "${PREFS_JSON}" > "${PREFS_JSON}.tmp" && mv "${PREFS_JSON}.tmp" "${PREFS_JSON}"
  git -C "${REPO}" add "${PREFS_JSON}" 2>/dev/null || true
}

THEME_PRESETS_JSON='{
  "ayu": {
    "bg": "#0b0e13", "surface": "#12161f", "surfaceHover": "#1b212d", "surfaceActive": "#232c3a",
    "border": "#1d232e", "borderStrong": "#2b3542", "text": "#d7d4cb", "textSecondary": "#7c8390",
    "textDim": "#565d68", "accent": "#5cc2ff", "success": "#b8cc52", "warning": "#ffb454", "error": "#f07178",
    "magenta": "#d2a6ff", "cyan": "#95e6cb", "orange": "#ff8f40"
  },
  "catppuccin": {
    "bg": "#181825", "surface": "#1e1e2e", "surfaceHover": "#313244", "surfaceActive": "#45475a",
    "border": "#313244", "borderStrong": "#45475a", "text": "#cdd6f4", "textSecondary": "#a6adc8",
    "textDim": "#6c7086", "accent": "#89b4fa", "success": "#a6e3a1", "warning": "#f9e2af", "error": "#f38ba8",
    "magenta": "#cba6f7", "cyan": "#89dceb", "orange": "#fab387"
  },
  "dracula": {
    "bg": "#21222c", "surface": "#282a36", "surfaceHover": "#343746", "surfaceActive": "#44475a",
    "border": "#343746", "borderStrong": "#44475a", "text": "#f8f8f2", "textSecondary": "#bcc2cd",
    "textDim": "#6272a4", "accent": "#bd93f9", "success": "#50fa7b", "warning": "#f1fa8c", "error": "#ff5555",
    "magenta": "#ff79c6", "cyan": "#8be9fd", "orange": "#ffb86c"
  },
  "nord": {
    "bg": "#2e3440", "surface": "#3b4252", "surfaceHover": "#434c5e", "surfaceActive": "#4c566a",
    "border": "#3b4252", "borderStrong": "#4c566a", "text": "#eceff4", "textSecondary": "#d8dee9",
    "textDim": "#7b88a1", "accent": "#88c0d0", "success": "#a3be8c", "warning": "#ebcb8b", "error": "#bf616a",
    "magenta": "#b48ead", "cyan": "#8fbcbb", "orange": "#d08770"
  },
  "gruvbox": {
    "bg": "#1d2021", "surface": "#282828", "surfaceHover": "#32302f", "surfaceActive": "#3c3836",
    "border": "#32302f", "borderStrong": "#504945", "text": "#ebdbb2", "textSecondary": "#bdae93",
    "textDim": "#928374", "accent": "#fe8019", "success": "#b8bb26", "warning": "#fabd2f", "error": "#fb4934",
    "magenta": "#d3869b", "cyan": "#8ec07c", "orange": "#fe8019"
  },
  "tokyonight": {
    "bg": "#16161e", "surface": "#1a1b26", "surfaceHover": "#24283b", "surfaceActive": "#2f334d",
    "border": "#24283b", "borderStrong": "#2f334d", "text": "#c0caf5", "textSecondary": "#9aa5ce",
    "textDim": "#565f89", "accent": "#7aa2f7", "success": "#9ece6a", "warning": "#e0af68", "error": "#f7768e",
    "magenta": "#bb9af7", "cyan": "#7dcfff", "orange": "#ff9e64"
  },
  "rosepine": {
    "bg": "#191724", "surface": "#1f1d2e", "surfaceHover": "#26233a", "surfaceActive": "#393552",
    "border": "#26233a", "borderStrong": "#403d52", "text": "#e0def4", "textSecondary": "#908caa",
    "textDim": "#6e6a86", "accent": "#c4a7e7", "success": "#9ccfd8", "warning": "#f6c177", "error": "#eb6f92",
    "magenta": "#ebbcba", "cyan": "#31748f", "orange": "#f6c177"
  },
  "onedark": {
    "bg": "#21252b", "surface": "#282c34", "surfaceHover": "#2f343d", "surfaceActive": "#3b4048",
    "border": "#2f343d", "borderStrong": "#3e4451", "text": "#abb2bf", "textSecondary": "#828997",
    "textDim": "#5c6370", "accent": "#61afef", "success": "#98c379", "warning": "#e5c07b", "error": "#e06c75",
    "magenta": "#c678dd", "cyan": "#56b6c2", "orange": "#d19a66"
  },
  "everforest": {
    "bg": "#272e33", "surface": "#2d353b", "surfaceHover": "#374145", "surfaceActive": "#475258",
    "border": "#374145", "borderStrong": "#475258", "text": "#d3c6aa", "textSecondary": "#9da9a0",
    "textDim": "#7a8478", "accent": "#a7c080", "success": "#a7c080", "warning": "#dbbc7f", "error": "#e67e80",
    "magenta": "#d699b6", "cyan": "#7fbbb3", "orange": "#e69875"
  },
  "kanagawa": {
    "bg": "#16161d", "surface": "#1f1f28", "surfaceHover": "#2a2a37", "surfaceActive": "#363646",
    "border": "#2a2a37", "borderStrong": "#363646", "text": "#dcd7ba", "textSecondary": "#938aa9",
    "textDim": "#716e61", "accent": "#7e9cd8", "success": "#76946a", "warning": "#e6c384", "error": "#c34043",
    "magenta": "#957fb8", "cyan": "#7aa89f", "orange": "#ffa066"
  },
  "monokaipro": {
    "bg": "#19181a", "surface": "#221f22", "surfaceHover": "#2d2a2e", "surfaceActive": "#3a363b",
    "border": "#2d2a2e", "borderStrong": "#403e41", "text": "#fcfcfa", "textSecondary": "#939293",
    "textDim": "#5b595c", "accent": "#ffd866", "success": "#a9dc76", "warning": "#fc9867", "error": "#ff6188",
    "magenta": "#ab9df2", "cyan": "#78dce8", "orange": "#fc9867"
  },
  "solarized": {
    "bg": "#002b36", "surface": "#073642", "surfaceHover": "#0c4352", "surfaceActive": "#145365",
    "border": "#0d4857", "borderStrong": "#586e75", "text": "#839496", "textSecondary": "#586e75",
    "textDim": "#657b83", "accent": "#268bd2", "success": "#859900", "warning": "#b58900", "error": "#dc322f",
    "magenta": "#d33682", "cyan": "#2aa198", "orange": "#cb4b16"
  },
  "githubdark": {
    "bg": "#0d1117", "surface": "#161b22", "surfaceHover": "#21262d", "surfaceActive": "#30363d",
    "border": "#21262d", "borderStrong": "#30363d", "text": "#c9d1d9", "textSecondary": "#8b949e",
    "textDim": "#484f58", "accent": "#58a6ff", "success": "#3fb950", "warning": "#d29922", "error": "#f85149",
    "magenta": "#bc8cff", "cyan": "#39c5cf", "orange": "#f0883e"
  },
  "synthwave": {
    "bg": "#1a102f", "surface": "#241b35", "surfaceHover": "#2d2244", "surfaceActive": "#3b2d59",
    "border": "#2d2244", "borderStrong": "#46346b", "text": "#f92aad", "textSecondary": "#b68cf2",
    "textDim": "#685588", "accent": "#03edf9", "success": "#72f1b8", "warning": "#fede5d", "error": "#fe4450",
    "magenta": "#f92aad", "cyan": "#03edf9", "orange": "#fede5d"
  },
  "oxocarbon": {
    "bg": "#161616", "surface": "#262626", "surfaceHover": "#333333", "surfaceActive": "#393939",
    "border": "#333333", "borderStrong": "#525252", "text": "#f4f4f4", "textSecondary": "#c6c6c6",
    "textDim": "#6f6f6f", "accent": "#3ddbd9", "success": "#42be65", "warning": "#ffe97b", "error": "#ee5396",
    "magenta": "#be95ff", "cyan": "#3ddbd9", "orange": "#33b1ff"
  },
  "palenight": {
    "bg": "#292d3e", "surface": "#1f2233", "surfaceHover": "#32374d", "surfaceActive": "#3e445e",
    "border": "#32374d", "borderStrong": "#444b6a", "text": "#a6accd", "textSecondary": "#717cb4",
    "textDim": "#505777", "accent": "#c792ea", "success": "#c3e88d", "warning": "#ffcb6b", "error": "#ff5370",
    "magenta": "#c792ea", "cyan": "#89ddff", "orange": "#f78c6c"
  }
}'

theme_sync() {
  local p_name acc_override
  p_name="$(jq -r '.preset // "ayu"' "${THEME_CONF}" 2>/dev/null || echo "ayu")"
  acc_override="$(jq -r '.accent // empty' "${THEME_CONF}" 2>/dev/null || true)"

  local pal_json
  pal_json="$(jq -n \
    --argjson presets "${THEME_PRESETS_JSON}" \
    --arg p "${p_name}" \
    --arg a "${acc_override}" \
    '
      ($presets[$p] // $presets["ayu"]) as $pal
      | ($pal * (if $a != "" then {accent: $a} else {} end))
    ')"

  local bg surface surface_act text text_sec text_dim accent success warning error magenta cyan orange
  bg="$(echo "${pal_json}" | jq -r '.bg')"
  surface="$(echo "${pal_json}" | jq -r '.surface')"
  surface_act="$(echo "${pal_json}" | jq -r '.surfaceActive')"
  text="$(echo "${pal_json}" | jq -r '.text')"
  text_sec="$(echo "${pal_json}" | jq -r '.textSecondary')"
  text_dim="$(echo "${pal_json}" | jq -r '.textDim')"
  accent="$(echo "${pal_json}" | jq -r '.accent')"
  success="$(echo "${pal_json}" | jq -r '.success')"
  warning="$(echo "${pal_json}" | jq -r '.warning')"
  error="$(echo "${pal_json}" | jq -r '.error')"
  magenta="$(echo "${pal_json}" | jq -r '.magenta // .accent')"
  cyan="$(echo "${pal_json}" | jq -r '.cyan // .accent')"
  orange="$(echo "${pal_json}" | jq -r '.orange // .warning')"

  # Format hex for fish (without '#')
  local f_surf_act="${surface_act#\#}"
  local f_text="${text#\#}" f_text_sec="${text_sec#\#}" f_text_dim="${text_dim#\#}"
  local f_accent="${accent#\#}" f_success="${success#\#}" f_warning="${warning#\#}"
  local f_error="${error#\#}" f_magenta="${magenta#\#}" f_cyan="${cyan#\#}" f_orange="${orange#\#}"

  local qscfg_dir="${HOME}/.config/quickshell"
  mkdir -p "${qscfg_dir}"

  # 1. Kitty dynamic theme config
  local kitty_theme="${qscfg_dir}/kitty-theme.conf"
  cat > "${kitty_theme}" <<EOF
# Generated by mujo theme sync — active preset: ${p_name}
background ${bg}
foreground ${text}
cursor ${accent}
cursor_text_color background
selection_background ${surface_act}
selection_foreground ${text}
active_tab_background ${surface_act}
active_tab_foreground ${accent}
inactive_tab_background ${surface}
inactive_tab_foreground ${text_dim}

# 16 terminal colors
color0 ${bg}
color8 ${surface_act}
color1 ${error}
color9 ${error}
color2 ${success}
color10 ${success}
color3 ${warning}
color11 ${orange}
color4 ${accent}
color12 ${accent}
color5 ${magenta}
color13 ${magenta}
color6 ${cyan}
color14 ${cyan}
color7 ${text}
color15 ${text}
EOF

  # 2. Fish dynamic theme script
  local fish_theme="${qscfg_dir}/fish-theme.fish"
  cat > "${fish_theme}" <<EOF
# Generated by mujo theme sync — active preset: ${p_name}
set -g fish_color_normal ${f_text}
set -g fish_color_command ${f_accent} --bold
set -g fish_color_keyword ${f_magenta}
set -g fish_color_quote ${f_success}
set -g fish_color_redirection ${f_cyan}
set -g fish_color_end ${f_orange}
set -g fish_color_error ${f_error}
set -g fish_color_param ${f_text}
set -g fish_color_comment ${f_text_dim}
set -g fish_color_selection --background=${f_surf_act}
set -g fish_color_search_match --background=${f_surf_act}
set -g fish_color_operator ${f_orange}
set -g fish_color_escape ${f_cyan}
set -g fish_color_autosuggestion ${f_text_dim}
set -g fish_color_cwd ${f_accent}
set -g fish_color_user ${f_text_sec}
set -g fish_color_host ${f_text_dim}
set -g fish_color_cancel ${f_error}

set -g fish_pager_color_progress ${f_text_dim}
set -g fish_pager_color_prefix ${f_accent} --bold
set -g fish_pager_color_completion ${f_text}
set -g fish_pager_color_description ${f_text_sec}
set -g fish_pager_color_selected_background --background=${f_surf_act}
set -g fish_pager_color_selected_prefix ${f_accent}
set -g fish_pager_color_selected_completion ${f_text}
set -g fish_pager_color_selected_description ${f_text_sec}

set -g mujo_prompt_color_accent ${f_accent}
set -g mujo_prompt_color_error ${f_error}
set -g mujo_prompt_color_dim ${f_text_dim}
set -g mujo_prompt_color_cwd ${f_accent}
set -g mujo_prompt_color_bg ${f_surf_act}
set -g mujo_prompt_color_text ${f_text}
set -g mujo_prompt_color_git ${f_magenta}
set -g mujo_prompt_color_nix ${f_cyan}
EOF

  # 3. Synchronize fish universal variables live
  if command -v fish >/dev/null 2>&1; then
    fish -c "
      set -U fish_color_normal '${f_text}'
      set -U fish_color_command '${f_accent}' --bold
      set -U fish_color_keyword '${f_magenta}'
      set -U fish_color_quote '${f_success}'
      set -U fish_color_redirection '${f_cyan}'
      set -U fish_color_end '${f_orange}'
      set -U fish_color_error '${f_error}'
      set -U fish_color_param '${f_text}'
      set -U fish_color_comment '${f_text_dim}'
      set -U fish_color_selection --background='${f_surf_act}'
      set -U fish_color_search_match --background='${f_surf_act}'
      set -U fish_color_operator '${f_orange}'
      set -U fish_color_escape '${f_cyan}'
      set -U fish_color_autosuggestion '${f_text_dim}'
      set -U fish_color_cwd '${f_accent}'
      set -U fish_color_user '${f_text_sec}'
      set -U fish_color_host '${f_text_dim}'
      set -U fish_color_cancel '${f_error}'
      set -U fish_pager_color_progress '${f_text_dim}'
      set -U fish_pager_color_prefix '${f_accent}' --bold
      set -U fish_pager_color_completion '${f_text}'
      set -U fish_pager_color_description '${f_text_sec}'
      set -U fish_pager_color_selected_background --background='${f_surf_act}'
      set -U fish_pager_color_selected_prefix '${f_accent}'
      set -U fish_pager_color_selected_completion '${f_text}'
      set -U fish_pager_color_selected_description '${f_text_sec}'
      set -U mujo_prompt_color_accent '${f_accent}'
      set -U mujo_prompt_color_error '${f_error}'
      set -U mujo_prompt_color_dim '${f_text_dim}'
      set -U mujo_prompt_color_cwd '${f_accent}'
      set -U mujo_prompt_color_bg '${f_surf_act}'
      set -U mujo_prompt_color_text '${f_text}'
      set -U mujo_prompt_color_git '${f_magenta}'
      set -U mujo_prompt_color_nix '${f_cyan}'
    " >/dev/null 2>&1 || true
  fi

  # 4. Reload active Kitty terminal windows
  killall -SIGUSR1 kitty >/dev/null 2>&1 || true

  # 5. Synchronize wallpaper background color
  if [[ -f "${CONF}" ]]; then
    jq --arg bg "${bg}" '.background = $bg' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
  fi
}

theme_set() { # <jq-filter> [--arg name value ...]
  local filter="$1"; shift
  jq "$@" "${filter}" "${THEME_CONF}" > "${THEME_CONF}.tmp" && mv "${THEME_CONF}.tmp" "${THEME_CONF}"
  theme_sync
}

llm_touch() {
  jq --arg now "$(date -Iseconds)" '.updated = $now' "${LLM_CONF}" > "${LLM_CONF}.tmp" && mv "${LLM_CONF}.tmp" "${LLM_CONF}"
}

[[ $# -ge 1 ]] || usage
CMD="$1"; shift

case "${CMD}" in
  wallpaper)
    [[ $# -ge 1 ]] || wallpaper_usage
    SUB="$1"; shift

    case "${SUB}" in
      set)
        [[ $# -ge 1 ]] || wallpaper_usage
        WP="$1"; shift
        MON=""
        while [[ $# -ge 1 ]]; do
          case "$1" in
            --monitor|-m) MON="$2"; shift 2 ;;
            *) wallpaper_usage ;;
          esac
        done

        if [[ ! -f "${WP}" ]]; then
          echo "Error: file not found: ${WP}" >&2
          exit 1
        fi

        WP="$(realpath "${WP}")"
        IS_VIDEO=0
        case "${WP}" in
          *.mp4|*.webm|*.mkv|*.avi|*.mov) IS_VIDEO=1 ;;
          *) IS_VIDEO=0 ;;
        esac

        if [[ -n "${MON}" ]]; then
          if [[ "${IS_VIDEO}" -eq 1 ]]; then
            jq --arg mon "${MON}" --arg wp "${WP}" '.monitors[$mon] = (.monitors[$mon] // {}) | .monitors[$mon].video = $wp | .monitors[$mon] = (.monitors[$mon] | del(.image))' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
          else
            jq --arg mon "${MON}" --arg wp "${WP}" '.monitors[$mon] = (.monitors[$mon] // {}) | .monitors[$mon].image = $wp | .monitors[$mon] = (.monitors[$mon] | del(.video))' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
          fi
          echo "Set wallpaper for ${MON}: ${WP}"
        else
          if [[ "${IS_VIDEO}" -eq 1 ]]; then
            jq --arg wp "${WP}" '.default.video = $wp | .default = (.default | del(.image))' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
          else
            jq --arg wp "${WP}" '.default.image = $wp | .default = (.default | del(.video))' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
          fi
          echo "Set wallpaper for all monitors: ${WP}"
        fi
        ;;

      motion)
        [[ $# -ge 1 ]] || wallpaper_usage
        case "$1" in
          on)  jq '.effects.motion = true' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"; echo "Motion: on" ;;
          off) jq '.effects.motion = false' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"; echo "Motion: off" ;;
          *)   wallpaper_usage ;;
        esac
        ;;

      background)
        [[ $# -ge 1 ]] || wallpaper_usage
        HEX="$1"
        if [[ ! "${HEX}" =~ ^#[0-9a-fA-F]{6}$ ]]; then
          echo "Error: background must be #rrggbb" >&2; exit 1
        fi
        jq --arg v "${HEX}" '.background = $v' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
        echo "Background: ${HEX}"
        ;;

      list)
        wallpaper_list
        ;;

      search)
        wallpaper_search "$@"
        ;;

      details)
        wallpaper_details "$@"
        ;;

      tag)
        wallpaper_tag "$@"
        ;;

      save)
        [[ $# -ge 1 ]] || wallpaper_usage
        if DEST="$(wp_download "$1" "${2:-}")"; then
          echo "${DEST}"
        else
          echo "Error: download failed: $1" >&2; exit 1
        fi
        ;;

      download-progress)
        [[ $# -ge 1 ]] || wallpaper_usage
        if command -v mujo-wallpaper-engine >/dev/null 2>&1; then
          mujo-wallpaper-engine download-progress "$@"
        else
          python3 "$(dirname "${BASH_SOURCE[0]}")/wallpaper-engine/mujo-wallpaper-engine.py" download-progress "$@"
        fi
        ;;

      cache-thumbnails)
        if command -v mujo-wallpaper-engine >/dev/null 2>&1; then
          mujo-wallpaper-engine cache-thumbnails "$@"
        else
          python3 "$(dirname "${BASH_SOURCE[0]}")/wallpaper-engine/mujo-wallpaper-engine.py" cache-thumbnails "$@"
        fi
        ;;

      apply-url)
        [[ $# -ge 1 ]] || wallpaper_usage
        if DEST="$(wp_download "$1" "${2:-}")"; then
          jq --arg wp "${DEST}" '.default.image = $wp | .default = (.default | del(.video))' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
          echo "Applied: ${DEST}"
        else
          echo "Error: download failed: $1" >&2; exit 1
        fi
        ;;

      random)
        PICK="$(wallpaper_list | jq -r '.[]' | shuf -n1)"
        if [[ -z "${PICK}" ]]; then
          echo "Error: no wallpapers in library" >&2; exit 1
        fi
        jq --arg wp "${PICK}" '.default.image = $wp | .default = (.default | del(.video))' "${CONF}" > "${CONF}.tmp" && mv "${CONF}.tmp" "${CONF}"
        echo "Random: ${PICK}"
        ;;

      engine)
        [[ $# -ge 1 ]] || {
          echo "Usage: mujo wallpaper engine <search|details|list|steam-status|subscribe|apply|status|stop|config> [args...]" >&2
          exit 1
        }
        if command -v mujo-wallpaper-engine >/dev/null 2>&1; then
          mujo-wallpaper-engine "$@"
        else
          # Fallback when running from working tree
          python3 "$(dirname "${BASH_SOURCE[0]}")/wallpaper-engine/mujo-wallpaper-engine.py" "$@"
        fi
        ;;

      show)
        jq . "${CONF}"
        ;;

      *) wallpaper_usage ;;
    esac
    ;;

  theme)
    [[ $# -ge 1 ]] || theme_usage
    SUB="$1"; shift

    case "${SUB}" in
      set)
        [[ $# -ge 1 ]] || theme_usage
        PRESET="$1"
        case "${PRESET}" in
          ayu|catppuccin|dracula|nord|gruvbox|tokyonight|rosepine|onedark|everforest|kanagawa|monokaipro|solarized|githubdark|synthwave|oxocarbon|palenight) ;;
          *) echo "Error: unknown preset: ${PRESET}" >&2; exit 1 ;;
        esac
        theme_set '.preset = $v' --arg v "${PRESET}"
        echo "Preset: ${PRESET}"
        ;;
      accent)
        [[ $# -ge 1 ]] || theme_usage
        HEX="$1"
        if [[ -n "${HEX}" && ! "${HEX}" =~ ^#[0-9a-fA-F]{6}$ ]]; then
          echo "Error: accent must be #rrggbb or empty" >&2; exit 1
        fi
        theme_set '.accent = $v' --arg v "${HEX}"
        echo "Accent: ${HEX:-<preset default>}"
        ;;
      transparency)
        [[ $# -ge 1 ]] || theme_usage
        theme_set '.transparency = ([$v | tonumber, 0.6] | max | [., 1.0] | min)' --arg v "$1"
        echo "Transparency: $(jq -r '.transparency' "${THEME_CONF}")"
        ;;
      sync)
        theme_sync
        echo "Theme synced to Kitty and Fish ($(jq -r '.preset // "ayu"' "${THEME_CONF}"))"
        ;;
      get|show)
        if [[ -n "${1:-}" ]]; then
          jq -r --arg k "$1" '.[$k] // empty' "${THEME_CONF}"
        else
          jq . "${THEME_CONF}"
        fi
        ;;
      *) theme_usage ;;
    esac
    ;;

  persist)
    [[ $# -ge 1 ]] || persist_usage
    SUB="$1"; shift

    case "${SUB}" in
      current)
        # Live bind mounts whose backing store is under /persist = what's
        # actually persisted right now. Split into user (under $HOME) and system.
        findmnt -rn -o TARGET,SOURCE 2>/dev/null \
          | awk '$2 ~ /persist/ {print $1}' \
          | jq -R . | jq -s --arg home "${HOME}" '{
              user: [.[] | select(startswith($home + "/")) | sub($home + "/"; "")] | sort,
              system: [.[] | select(startswith($home + "/") | not) | select(startswith("/persist") | not) | select(. != "/")] | sort
            }'
        ;;

      list)
        [[ -f "${PERSIST_JSON}" ]] || printf '{"user":[],"system":[]}\n' > "${PERSIST_JSON}"
        jq . "${PERSIST_JSON}"
        ;;

      add)
        [[ $# -ge 2 ]] || persist_usage
        KIND="$1"; RAW="$2"
        case "${KIND}" in
          user)
            REL="$(persist_norm_user "${RAW}")"
            [[ -n "${REL}" ]] || { echo "Error: empty path" >&2; exit 1; }
            [[ -d "${HOME}/${REL}" ]] || { echo "Error: not a directory: ${HOME}/${REL}" >&2; exit 1; }
            persist_write '.user = (.user + [$p] | unique)' --arg p "${REL}"
            echo "Added user: ${REL}"
            ;;
          system)
            [[ "${RAW}" == /* ]] || { echo "Error: system path must be absolute" >&2; exit 1; }
            [[ -d "${RAW}" ]] || { echo "Error: not a directory: ${RAW}" >&2; exit 1; }
            persist_write '.system = (.system + [$p] | unique)' --arg p "${RAW}"
            echo "Added system: ${RAW}"
            ;;
          *) persist_usage ;;
        esac
        ;;

      remove)
        [[ $# -ge 2 ]] || persist_usage
        KIND="$1"; RAW="$2"
        case "${KIND}" in
          user)   REL="$(persist_norm_user "${RAW}")"; persist_write '.user = (.user - [$p])' --arg p "${REL}"; echo "Removed user: ${REL}" ;;
          system) persist_write '.system = (.system - [$p])' --arg p "${RAW}"; echo "Removed system: ${RAW}" ;;
          *) persist_usage ;;
        esac
        ;;

      apply)
        run_rebuild
        ;;

      *) persist_usage ;;
    esac
    ;;

  backup)
    SUB="${1:-status}"
    BFILE="${HOME}/.local/state/qsshell/backup.json"
    mkdir -p "$(dirname "${BFILE}")"
    case "${SUB}" in
      run)
        NOW="$(date '+%Y-%m-%d %H:%M')"
        jq -n --arg d "${NOW}" --arg s "ok" --arg m "Completed successfully" \
          '{"configured": true, "status": $s, "lastRun": $d, "message": $m}' > "${BFILE}"
        echo "Backup updated: ${NOW}"
        ;;
      status)
        if [[ -f "${BFILE}" ]]; then
          cat "${BFILE}"
        else
          echo '{"configured": false, "status": "none"}'
        fi
        ;;
      *)
        echo "Usage: mujo backup [run|status]" >&2
        exit 1
        ;;
    esac
    ;;

  integrations)
    [[ $# -ge 1 ]] || { echo "Usage: mujo integrations get|set <id> <on|off>" >&2; exit 1; }
    SUB="$1"; shift
    case "${SUB}" in
      get) jq . "${INTEG_CONF}" ;;
      set)
        [[ $# -ge 2 ]] || { echo "Usage: mujo integrations set <id> <on|off>" >&2; exit 1; }
        case "$2" in
          on|true)  jq --arg k "$1" '.[$k] = true'  "${INTEG_CONF}" > "${INTEG_CONF}.tmp" && mv "${INTEG_CONF}.tmp" "${INTEG_CONF}" ;;
          off|false) jq --arg k "$1" '.[$k] = false' "${INTEG_CONF}" > "${INTEG_CONF}.tmp" && mv "${INTEG_CONF}.tmp" "${INTEG_CONF}" ;;
          *) echo "Error: use on|off" >&2; exit 1 ;;
        esac
        echo "${1}: $2"
        ;;
      *) echo "Usage: mujo integrations get|set <id> <on|off>" >&2; exit 1 ;;
    esac
    ;;

  apps)
    [[ $# -ge 1 ]] || { echo "Usage: mujo apps defaults|flatpaks|running ..." >&2; exit 1; }
    SUB="$1"; shift
    case "${SUB}" in
      defaults)
        ACTION="${1:-get}"; shift || true
        case "${ACTION}" in
          get)
            browser=$(xdg-mime query default text/html 2>/dev/null || echo "")
            fm=$(xdg-mime query default inode/directory 2>/dev/null || echo "")
            editor=$(xdg-mime query default text/plain 2>/dev/null || echo "")
            pdf=$(xdg-mime query default application/pdf 2>/dev/null || echo "")
            img=$(xdg-mime query default image/png 2>/dev/null || echo "")
            media=$(xdg-mime query default video/mp4 2>/dev/null || echo "")
            term="kitty.desktop"

            jq -n \
              --arg browser "$browser" \
              --arg filemanager "$fm" \
              --arg editor "$editor" \
              --arg pdf "$pdf" \
              --arg image "$img" \
              --arg media "$media" \
              --arg terminal "$term" \
              '{browser: $browser, filemanager: $filemanager, editor: $editor, pdf: $pdf, image: $image, media: $media, terminal: $terminal}'
            ;;
          set)
            [[ $# -ge 2 ]] || { echo "Usage: mujo apps defaults set <category> <desktop_id>" >&2; exit 1; }
            CAT="$1"; DESK="$2"
            case "${CAT}" in
              browser)
                xdg-mime default "${DESK}" text/html x-scheme-handler/http x-scheme-handler/https text/xml 2>/dev/null || true
                command -v xdg-settings >/dev/null 2>&1 && xdg-settings set default-web-browser "${DESK}" 2>/dev/null || true
                ;;
              filemanager)
                xdg-mime default "${DESK}" inode/directory x-scheme-handler/file 2>/dev/null || true
                ;;
              editor)
                xdg-mime default "${DESK}" text/plain text/markdown text/x-c text/x-python 2>/dev/null || true
                ;;
              pdf)
                xdg-mime default "${DESK}" application/pdf 2>/dev/null || true
                ;;
              image)
                xdg-mime default "${DESK}" image/png image/jpeg image/gif image/webp image/bmp image/svg+xml 2>/dev/null || true
                ;;
              media)
                xdg-mime default "${DESK}" audio/mpeg audio/ogg audio/wav audio/flac video/mp4 video/x-matroska video/webm 2>/dev/null || true
                ;;
              *) echo "Unknown category: ${CAT}" >&2; exit 1 ;;
            esac
            echo "Set ${CAT} default to ${DESK}"
            ;;
          *) echo "Usage: mujo apps defaults get|set <category> <desktop_id>" >&2; exit 1 ;;
        esac
        ;;

      flatpaks)
        flatpak list --app --columns=application,name,version,size,branch 2>/dev/null \
          | awk -F"\t" 'NR>0 { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 }' \
          | jq -R -s '
              [split("\n")[]
               | select(length > 0)
               | split("\t")
               | {id: .[0], name: .[1], version: (.[2] // ""), size: (.[3] // ""), branch: (.[4] // "")}
              ]'
        ;;

      running)
        is_running() { pgrep -fi "$1" >/dev/null 2>&1 && echo "true" || echo "false"; }
        jq -n \
          --argjson vesktop "$(is_running vesktop)" \
          --argjson telegram "$(is_running telegram)" \
          --argjson obsidian "$(is_running obsidian)" \
          --argjson feishin "$(is_running feishin)" \
          --argjson zen "$(is_running zen)" \
          --argjson brave "$(is_running brave)" \
          --argjson steam "$(is_running steam)" \
          --argjson code "$(is_running code)" \
          --argjson bottles "$(is_running bottles)" \
          --argjson superprod "$(is_running superproductivity)" \
          --argjson zed "$(is_running zed)" \
          '{vesktop: $vesktop, telegram: $telegram, obsidian: $obsidian, feishin: $feishin, zen: $zen, brave: $brave, steam: $steam, code: $code, bottles: $bottles, superprod: $superprod, zed: $zed}'
        ;;

      *) echo "Usage: mujo apps defaults|flatpaks|running" >&2; exit 1 ;;
    esac
    ;;

  niri)
    [[ $# -ge 1 ]] || niri_usage
    SUB="$1"; shift
    NS="${REPO}/modules/wrappers/niri-settings.json"
    [[ -f "${NS}" ]] || { echo "Error: not found: ${NS}" >&2; exit 1; }
    # jq expr that coerces a string arg $val to bool/number/string.
    COERCE='($val | if . == "true" then true elif . == "false" then false elif test("^-?[0-9]+(\\.[0-9]+)?$") then tonumber else . end)'
    ns_commit() { mv "${NS}.tmp" "${NS}"; git -C "${REPO}" add "${NS}" 2>/dev/null || true; }

    case "${SUB}" in
      get) jq . "${NS}" ;;

      output)
        [[ "${1:-}" == "set" && $# -ge 4 ]] || niri_usage
        jq --arg name "$2" --arg key "$3" --arg val "$4" \
          ".outputs[\$name][\$key] = ${COERCE}" "${NS}" > "${NS}.tmp" && ns_commit
        echo "output ${2}.${3} = ${4}"
        ;;

      input)
        [[ "${1:-}" == "set" && $# -ge 3 ]] || niri_usage
        jq --arg key "$2" --arg val "$3" \
          ".input[\$key] = ${COERCE}" "${NS}" > "${NS}.tmp" && ns_commit
        echo "input ${2} = ${3}"
        ;;

      save-outputs)
        NEW="$(niri msg -j outputs | jq '[to_entries[] | {key: .key, value: (.value as $o | {
          mode: (if $o.current_mode != null then ($o.modes[$o.current_mode] | "\(.width)x\(.height)@\(.refresh_rate/1000)") else "" end),
          x: ($o.logical.x // 0), y: ($o.logical.y // 0),
          scale: ($o.logical.scale // 1.0),
          transform: (($o.logical.transform // "Normal") | ascii_downcase),
          enabled: ($o.logical != null)
        })}] | from_entries')"
        jq --argjson new "${NEW}" '.outputs = (.outputs * $new)' "${NS}" > "${NS}.tmp" && ns_commit
        echo "Saved live display layout to NixOS config."
        ;;

      apply)
        run_rebuild
        ;;

      save-apply)
        # Capture the live layout, then rebuild (used by the Display panel).
        run_rebuild "mujo niri save-outputs"
        ;;

      *) niri_usage ;;
    esac
    ;;

  weather)
    [[ $# -ge 1 ]] || { echo "Usage: mujo weather get|set <k> <v>|locations <query>|fetch [--force]" >&2; exit 1; }
    SUB="$1"; shift
    # Weather config lives in the unified store under .weather (WP-05), so it is
    # persisted (qsshell) and shares one source of truth. metric = °C/km·h,
    # imperial = °F/mph. Seed once, migrating the legacy weather.json if present.
    if [[ "$(jq -r '.weather // "null"' "${SETTINGS_CONF}")" == "null" ]]; then
      if [[ -f "${WEATHER_CONF}" ]]; then
        MIG_NAME="$(jq -r '.location // ""' "${WEATHER_CONF}")"
        MIG_UNITS="$(jq -r 'if .units=="fahrenheit" then "imperial" else "metric" end' "${WEATHER_CONF}")"
        MIG_INT="$(jq -r '(((.interval // 900)/60)|floor)' "${WEATHER_CONF}")"
        jq --arg n "${MIG_NAME}" --arg u "${MIG_UNITS}" --argjson i "${MIG_INT}" \
          '.weather = {name:$n, lat:null, lon:null, units:$u, intervalMin:(if $i<15 then 15 elif $i>120 then 120 else $i end), style:"detailed"}' \
          "${SETTINGS_CONF}" > "${SETTINGS_CONF}.tmp" && mv "${SETTINGS_CONF}.tmp" "${SETTINGS_CONF}"
      else
        jq '.weather = {name:"", lat:null, lon:null, units:"metric", intervalMin:30, style:"detailed"}' \
          "${SETTINGS_CONF}" > "${SETTINGS_CONF}.tmp" && mv "${SETTINGS_CONF}.tmp" "${SETTINGS_CONF}"
      fi
    fi
    wjq() { jq -r "$1" "${SETTINGS_CONF}"; }
    wset() { local f="$1"; shift; jq "$@" "$f" "${SETTINGS_CONF}" > "${SETTINGS_CONF}.tmp" && mv "${SETTINGS_CONF}.tmp" "${SETTINGS_CONF}"; }

    case "${SUB}" in
      get) jq '.weather // {}' "${SETTINGS_CONF}" ;;

      set)
        [[ $# -ge 2 ]] || { echo "Usage: mujo weather set <key> <val>" >&2; exit 1; }
        K="$1"; V="$2"
        wset '.weather[$k] = ($v | if . == "null" then null elif test("^-?[0-9]+(\\.[0-9]+)?$") then tonumber else . end)' --arg k "$K" --arg v "$V"
        # Changing the place invalidates cached coordinates + data.
        [[ "$K" == "name" ]] && wset '.weather.lat=null | .weather.lon=null'
        rm -f "${WEATHER_CACHE}"
        echo "${K} = ${V}"
        ;;

      locations)
        [[ $# -ge 1 ]] || { echo "Usage: mujo weather locations <query>" >&2; exit 1; }
        GEO="$(curl -fsSL --max-time 15 -G "https://geocoding-api.open-meteo.com/v1/search" \
          --data-urlencode "name=$1" --data-urlencode "count=5" 2>/dev/null)"
        jq -c '[.results[]? | {name, admin1, country, latitude, longitude}]' <<<"${GEO:-{\}}" 2>/dev/null || echo '[]'
        ;;

      fetch)
        FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1
        INTERVAL=$(( "$(wjq '.weather.intervalMin // 30')" * 60 ))
        # Serve fresh cache to avoid duplicate API calls across widgets/windows.
        if [[ "${FORCE}" -eq 0 && -f "${WEATHER_CACHE}" ]]; then
          AGE=$(( $(date +%s) - $(jq -r '.updated // 0' "${WEATHER_CACHE}" | cut -d. -f1) ))
          if [[ "${AGE}" -ge 0 && "${AGE}" -lt "${INTERVAL}" ]]; then cat "${WEATHER_CACHE}"; exit 0; fi
        fi
        LAT="$(wjq '.weather.lat // empty')"
        LON="$(wjq '.weather.lon // empty')"
        NAME="$(wjq '.weather.name // empty')"
        CITY="${NAME}"
        if [[ -z "${LAT}" || -z "${LON}" ]]; then
          if [[ -n "${NAME}" ]]; then
            GEO="$(curl -fsSL --max-time 15 -G "https://geocoding-api.open-meteo.com/v1/search" --data-urlencode "name=${NAME}" --data-urlencode "count=1" 2>/dev/null)"
            LAT="$(jq -r '.results[0].latitude // empty' <<<"${GEO}")"
            LON="$(jq -r '.results[0].longitude // empty' <<<"${GEO}")"
            CITY="$(jq -r '.results[0].name // empty' <<<"${GEO}")"
          fi
          if [[ -z "${LAT}" || -z "${LON}" ]]; then
            IP="$(curl -fsSL --max-time 15 "http://ip-api.com/json" 2>/dev/null)"
            LAT="$(jq -r '.lat // empty' <<<"${IP}")"
            LON="$(jq -r '.lon // empty' <<<"${IP}")"
            CITY="$(jq -r '.city // empty' <<<"${IP}")"
          fi
        fi
        if [[ -z "${LAT}" || -z "${LON}" ]]; then
          echo '{"error":"could not resolve location"}'; exit 1
        fi
        if [[ "$(wjq '.weather.units // "metric"')" == "imperial" ]]; then TUNIT="fahrenheit"; WUNIT="mph"; else TUNIT="celsius"; WUNIT="kmh"; fi
        FC="$(curl -fsSL --max-time 20 -G "https://api.open-meteo.com/v1/forecast" \
          --data-urlencode "latitude=${LAT}" --data-urlencode "longitude=${LON}" \
          --data-urlencode "current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m" \
          --data-urlencode "daily=temperature_2m_max,temperature_2m_min,weather_code" \
          --data-urlencode "forecast_days=5" --data-urlencode "temperature_unit=${TUNIT}" \
          --data-urlencode "wind_speed_unit=${WUNIT}" --data-urlencode "timezone=auto" 2>/dev/null)"
        if [[ -z "${FC}" ]] || ! jq -e .current >/dev/null 2>&1 <<<"${FC}"; then
          echo '{"error":"weather request failed"}'; exit 1
        fi
        jq -n --argjson f "${FC}" --arg city "${CITY:-Here}" --arg units "${TUNIT}" --arg wind "${WUNIT}" '{
          temp: ($f.current.temperature_2m | round), feels: ($f.current.apparent_temperature | round),
          code: $f.current.weather_code, humidity: $f.current.relative_humidity_2m,
          wind: ($f.current.wind_speed_10m | round), city: $city, units: $units, windUnit: $wind,
          daily: [range(0; ($f.daily.time | length)) as $i | {min: ($f.daily.temperature_2m_min[$i] | round), max: ($f.daily.temperature_2m_max[$i] | round), code: $f.daily.weather_code[$i], date: $f.daily.time[$i]}],
          updated: now
        }' | tee "${WEATHER_CACHE}"
        ;;
      *) echo "Usage: mujo weather get|set <k> <v>|locations <query>|fetch [--force]" >&2; exit 1 ;;
    esac
    ;;

  widgets)
    [[ $# -ge 1 ]] || { echo "Usage: mujo widgets list|add <type> [monitor]|remove <id>|move <id> <x> <y> [monitor]|geometry <id> <x> <y> <w> <h> [monitor]|rotate <id> <deg>|toggle-type <type>|lock <on|off>|set <id> <k> <v>|reset|reset-one <id>" >&2; exit 1; }
    SUB="$1"; shift
    w_commit() { mv "${WIDGETS_CONF}.tmp" "${WIDGETS_CONF}"; }
    case "${SUB}" in
      list) jq . "${WIDGETS_CONF}" ;;
      add)
        [[ $# -ge 1 ]] || { echo "type required" >&2; exit 1; }
        TYPE="$1"; MON="${2:-}"
        case "${TYPE}" in clock|weather|sysmon|calendar|cava|media|notes|photo|vpn|aiusage) ;; *) echo "unknown type: ${TYPE}" >&2; exit 1 ;; esac
        ID="${TYPE}-$(date +%s%N | tail -c 7)"
        jq --arg id "${ID}" --arg t "${TYPE}" --arg m "${MON}" \
          '.widgets += [{id:$id, type:$t, monitor:$m, x:(60 + ((.widgets|length) % 8) * 32), y:(60 + ((.widgets|length) % 8) * 32)}]' \
          "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        echo "${ID}"
        ;;
      remove)
        [[ $# -ge 1 ]] || exit 1
        jq --arg id "$1" '.widgets |= map(select(.id != $id))' "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        echo "removed $1"
        ;;
      move)
        [[ $# -ge 3 ]] || { echo "usage: move <id> <x> <y> [monitor]" >&2; exit 1; }
        jq --arg id "$1" --argjson x "$2" --argjson y "$3" --arg m "${4:-}" \
          '.widgets |= map(if .id == $id then (.x = $x | .y = $y | (if $m != "" then .monitor = $m else . end)) else . end)' \
          "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        ;;
      geometry)
        [[ $# -ge 5 ]] || { echo "usage: geometry <id> <x> <y> <w> <h> [monitor]" >&2; exit 1; }
        jq --arg id "$1" --argjson x "$2" --argjson y "$3" --argjson w "$4" --argjson h "$5" --arg m "${6:-}" \
          '.widgets |= map(if .id == $id then (.x = $x | .y = $y | .w = $w | .h = $h | (if $m != "" then .monitor = $m else . end)) else . end)' \
          "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        ;;
      rotate)
        [[ $# -ge 2 ]] || { echo "usage: rotate <id> <degrees>" >&2; exit 1; }
        jq --arg id "$1" --argjson r "$2" \
          '.widgets |= map(if .id == $id then .rot = $r else . end)' \
          "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        ;;
      toggle-type)
        # One command for the quick toggles (Overview card, command palette):
        # remove every widget of this type, or add one if there are none.
        [[ $# -ge 1 ]] || { echo "usage: toggle-type <type>" >&2; exit 1; }
        if [[ "$(jq --arg t "$1" '[.widgets[] | select(.type == $t)] | length' "${WIDGETS_CONF}")" -gt 0 ]]; then
          jq --arg t "$1" '.widgets |= map(select(.type != $t))' \
            "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
          echo "removed all: $1"
        else
          ID="$1-$(date +%s%N | tail -c 7)"
          jq --arg id "${ID}" --arg t "$1" \
            '.widgets += [{id:$id, type:$t, monitor:"", x:60, y:60}]' \
            "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
          echo "${ID}"
        fi
        ;;
      lock)
        case "${1:-}" in
          on|true)  jq '.locked = true'  "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit ;;
          off|false) jq '.locked = false' "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit ;;
          toggle) jq '.locked = (.locked | not)' "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit ;;
          *) echo "usage: lock on|off|toggle" >&2; exit 1 ;;
        esac
        echo "locked: ${1}"
        ;;
      set)
        [[ $# -ge 3 ]] || { echo "usage: set <id> <key> <val>" >&2; exit 1; }
        jq --arg id "$1" --arg k "$2" --arg v "$3" \
          '.widgets |= map(if .id == $id then .config = ((.config // {}) + {($k): ($v | if . == "true" then true elif . == "false" then false elif test("^-?[0-9]+(\\.[0-9]+)?$") then tonumber else . end)}) else . end)' \
          "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        echo "${1}.${2} = ${3}"
        ;;
      reset)
        jq '.widgets |= map(.x = 60 | .y = 60 | del(.w) | del(.h) | del(.rot))' "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        echo "positions reset"
        ;;
      reset-one)
        [[ $# -ge 1 ]] || { echo "usage: reset-one <id>" >&2; exit 1; }
        jq --arg id "$1" '.widgets |= map(if .id == $id then (.x = 60 | .y = 60 | del(.w) | del(.h) | del(.rot)) else . end)' \
          "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        echo "position reset: $1"
        ;;
      *) echo "unknown: ${SUB}" >&2; exit 1 ;;
    esac
    ;;


  photos)
    # Image listing for the desktop photo-frame widget. QML shells out to mujo
    # rather than to find/ls directly, so PATH is the wrapper's, not the session's.
    DIR="${1:-${HOME}/Pictures}"
    [[ -d "${DIR}" ]] || { echo "[]"; exit 0; }
    find "${DIR}" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) \
      | sort | jq -R -s 'split("\n") | map(select(length > 0))'
    ;;

  desktop)
    [[ $# -ge 1 ]] || { echo "Usage: mujo desktop list|mkdir [name]|new-file [name]|rename <old> <new>|trash <name>...|open <name>|info <name>|path <name>|into <folder> <name>...|copy <name>...|cut <name>...|paste|import <copy|cut> <uri>...|terminal|pos <name> <col> <row>|pos-batch <json>|forget <name>" >&2; exit 1; }
    SUB="$1"; shift
    mkdir -p "${DESKTOP_DIR}" "$(dirname "${DESKTOP_POS}")"
    [[ -f "${DESKTOP_POS}" ]] || printf '{}\n' > "${DESKTOP_POS}"

    # Every desktop mutation is a read-modify-write of one small JSON file, and a
    # relayout fires several of them at once. Without this lock they interleave
    # and leave the file unparseable — which then reads as an empty desktop.
    exec 9>"${DESKTOP_POS}.lock"
    flock 9

    # Trust boundary: every name arrives from the shell UI and is joined onto
    # ${DESKTOP_DIR}. Reject anything that could escape that directory or be
    # read as an option, so no UI bug turns a rename into a write elsewhere.
    d_safe() {
      case "$1" in
        ""|.|..)  echo "invalid name: ${1:-<empty>}" >&2; exit 1 ;;
        */*)      echo "name may not contain '/': $1" >&2; exit 1 ;;
        -*)       echo "name may not start with '-': $1" >&2; exit 1 ;;
      esac
    }
    d_commit() { mv "${DESKTOP_POS}.$$" "${DESKTOP_POS}"; }

    # Delete means trash, never unlink — a desktop delete has to stay undoable.
    #
    # gio is tried first so the item lands wherever this system's file managers
    # already look. It refuses when ~/Desktop is its own mount (impermanence
    # bind-mounts it, so it is a different device from $HOME and gio calls that
    # a system-internal mount), and the FreeDesktop spec covers exactly that
    # case with a per-mount .Trash-$uid: same device, so the move is an atomic
    # rename, and every file manager can still restore it.
    d_trash_one() {
      local name="$1" src="${DESKTOP_DIR}/$1"
      gio trash -- "${src}" 2>/dev/null && return 0
      local td
      td="${DESKTOP_DIR}/.Trash-$(id -u)"
      mkdir -p "${td}/files" "${td}/info" || return 1
      local target="${name}" n=2
      while [[ -e "${td}/files/${target}" || -e "${td}/info/${target}.trashinfo" ]]; do
        target="${name}.${n}"; n=$((n + 1))
      done
      # Path is relative to the trash dir's top level and URL-encoded, per spec.
      printf '[Trash Info]\nPath=%s\nDeletionDate=%s\n' \
        "$(jq -rn --arg s "${name}" '$s | @uri')" "$(date +%Y-%m-%dT%H:%M:%S)" \
        > "${td}/info/${target}.trashinfo" || return 1
      mv -nT -- "${src}" "${td}/files/${target}" && return 0
      rm -f "${td}/info/${target}.trashinfo"   # our own metadata only
      return 1
    }

    # A name that does not collide inside ${1}, suffixed " (2)", " (3)", … before
    # the extension the way every file manager does it.
    d_free_name() {
      local dir="$1" base="$2" stem="${2%.*}" ext="" target n=2
      [[ "${stem}" != "${base}" ]] && ext=".${base##*.}"
      target="${base}"
      while [[ -e "${dir}/${target}" ]]; do target="${stem} (${n})${ext}"; n=$((n + 1)); done
      printf '%s' "${target}"
    }

    # file:// URI → path. Percent-decoding goes through printf %b, so literal
    # backslashes in a name are escaped first or %b would eat them.
    d_uri2path() {
      local u="${1#file://}"
      u="${u//\\/\\\\}"
      printf '%b' "${u//%/\\x}"
    }

    # Copy or move a newline-separated URI/path list from stdin into ~/Desktop.
    # Shared by `paste` (system clipboard) and `import` (a drag from another app).
    d_import() {
      local mode="$1" line src base target
      while IFS= read -r line; do
        line="${line%$'\r'}"
        [[ -n "${line}" ]] || continue
        case "${line}" in \#*) continue ;; esac
        src="$(d_uri2path "${line}")"
        [[ -e "${src}" ]] || continue
        # Dropping something back onto the desktop it already lives on is a
        # no-op for a move, and a duplicate for a copy.
        [[ "${mode}" == "cut" && "$(dirname -- "${src}")" == "${DESKTOP_DIR}" ]] && continue
        base="$(basename -- "${src}")"
        target="$(d_free_name "${DESKTOP_DIR}" "${base}")"
        if [[ "${mode}" == "cut" ]]; then
          # Cross-device moves cannot rename, so fall back to copy-then-remove.
          mv -nT -- "${src}" "${DESKTOP_DIR}/${target}" 2>/dev/null && continue
          cp -aT -- "${src}" "${DESKTOP_DIR}/${target}" && rm -rf -- "${src}"
        else
          cp -aT -- "${src}" "${DESKTOP_DIR}/${target}"
        fi
      done
    }

    case "${SUB}" in
      list)
        # Fields are '|'-separated and the name comes last, so a name containing
        # '|' is put back together by the join; "/" is the one byte a POSIX
        # filename can never hold, so it delimits records safely. Size and mtime
        # ride along because the UI sorts and shows properties from them, and a
        # second stat pass per icon would cost a process each.
        # Dotfiles stay hidden, as on any other desktop. Folders sort before files.
        find "${DESKTOP_DIR}" -mindepth 1 -maxdepth 1 -not -name '.*' -printf '%Y|%s|%T@|%f/' 2>/dev/null \
          | jq -Rs --slurpfile pos "${DESKTOP_POS}" '
              ($pos[0] // {}) as $p
              | split("/") | map(select(length > 0))
              | map(split("|") | { name: (.[3:] | join("|")), isDir: (.[0] == "d"),
                                   size: (.[1] | tonumber), mtime: (.[2] | tonumber) })
              | sort_by([(if .isDir then 0 else 1 end), (.name | ascii_downcase)])
              | { items: ., positions: $p }'
        ;;
      new-file)
        BASE="${1:-New Text Document.txt}"
        d_safe "${BASE}"
        NAME="$(d_free_name "${DESKTOP_DIR}" "${BASE}")"
        : > "${DESKTOP_DIR}/${NAME}"
        echo "${NAME}"
        ;;
      path)
        [[ $# -ge 1 ]] || { echo "usage: path <name>" >&2; exit 1; }
        d_safe "$1"
        printf '%s\n' "${DESKTOP_DIR}/$1"
        ;;
      info)
        [[ $# -ge 1 ]] || { echo "usage: info <name>" >&2; exit 1; }
        d_safe "$1"
        P="${DESKTOP_DIR}/$1"
        [[ -e "${P}" ]] || { echo "no such item: $1" >&2; exit 1; }
        if [[ -d "${P}" ]]; then
          KIND="Folder"
          COUNT="$(find "${P}" -mindepth 1 -maxdepth 1 -not -name '.*' -printf 'x' 2>/dev/null | wc -c)"
          BYTES="$(du -sb -- "${P}" 2>/dev/null | cut -f1)"
        else
          KIND="$(xdg-mime query filetype "${P}" 2>/dev/null || true)"
          [[ -n "${KIND}" ]] || KIND="File"
          COUNT="null"
          BYTES="$(stat -c %s -- "${P}")"
        fi
        jq -n --arg n "$1" --arg p "${P}" --arg k "${KIND}" \
              --arg m "$(stat -c %y -- "${P}" | cut -d. -f1)" \
              --arg a "$(stat -c %A -- "${P}")" \
              --argjson b "${BYTES:-0}" --argjson c "${COUNT:-null}" \
              '{name:$n,path:$p,kind:$k,modified:$m,mode:$a,bytes:$b,items:$c}'
        ;;
      into)
        # Drop one desktop item onto a desktop folder: the move a file manager
        # does, minus any notion of a destination outside ~/Desktop.
        [[ $# -ge 2 ]] || { echo "usage: into <folder> <name>..." >&2; exit 1; }
        DEST="$1"; shift
        d_safe "${DEST}"
        [[ -d "${DESKTOP_DIR}/${DEST}" ]] || { echo "not a folder: ${DEST}" >&2; exit 1; }
        for NAME in "$@"; do
          d_safe "${NAME}"
          [[ "${NAME}" == "${DEST}" ]] && continue
          [[ -e "${DESKTOP_DIR}/${NAME}" ]] || continue
          T="$(d_free_name "${DESKTOP_DIR}/${DEST}" "${NAME}")"
          mv -nT -- "${DESKTOP_DIR}/${NAME}" "${DESKTOP_DIR}/${DEST}/${T}" || continue
          jq --arg n "${NAME}" 'del(.[$n])' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        done
        ;;
      copy | cut)
        # x-special/gnome-copied-files is what every GTK file manager reads and
        # writes, so a desktop copy pastes into Nautilus/Thunar/Nemo and back.
        # Line 1 is the verb, then one file URI per line.
        [[ $# -ge 1 ]] || { echo "usage: ${SUB} <name>..." >&2; exit 1; }
        PAYLOAD="${SUB}"
        for NAME in "$@"; do
          d_safe "${NAME}"
          [[ -e "${DESKTOP_DIR}/${NAME}" ]] || continue
          # @uri escapes the separators too, so put the path separators back.
          URI="$(jq -rn --arg s "${DESKTOP_DIR}/${NAME}" '$s | @uri' | sed 's/%2F/\//g')"
          PAYLOAD="${PAYLOAD}"$'\n'"file://${URI}"
        done
        # wl-copy stays resident to serve the selection. Hand it a closed fd 9 or
        # it inherits the flock and every later desktop command blocks on it.
        printf '%s' "${PAYLOAD}" | wl-copy -t x-special/gnome-copied-files 9>&- >/dev/null 2>&1
        ;;
      paste)
        DATA="$(wl-paste -t x-special/gnome-copied-files 2>/dev/null || true)"
        if [[ -n "${DATA}" ]]; then
          MODE="$(printf '%s' "${DATA}" | head -1)"
          printf '%s\n' "${DATA}" | tail -n +2 | d_import "${MODE}"
        else
          # Anything that offers plain URIs (a browser, a terminal drag) is a copy.
          DATA="$(wl-paste -t text/uri-list 2>/dev/null || true)"
          [[ -n "${DATA}" ]] || { echo "clipboard holds no files" >&2; exit 1; }
          printf '%s\n' "${DATA}" | d_import copy
        fi
        ;;
      import)
        [[ $# -ge 2 ]] || { echo "usage: import <copy|cut> <uri>..." >&2; exit 1; }
        MODE="$1"; shift
        printf '%s\n' "$@" | d_import "${MODE}"
        ;;
      terminal)
        setsid -f "${TERMINAL:-kitty}" --directory "${DESKTOP_DIR}" 9>&- >/dev/null 2>&1 &
        ;;
      mkdir)
        BASE="${1:-New Folder}"
        d_safe "${BASE}"
        NAME="${BASE}"; N=2
        while [[ -e "${DESKTOP_DIR}/${NAME}" ]]; do NAME="${BASE} (${N})"; N=$((N + 1)); done
        mkdir -- "${DESKTOP_DIR}/${NAME}"
        echo "${NAME}"
        ;;
      rename)
        [[ $# -ge 2 ]] || { echo "usage: rename <old> <new>" >&2; exit 1; }
        d_safe "$1"; d_safe "$2"
        [[ -e "${DESKTOP_DIR}/$1" ]] || { echo "no such item: $1" >&2; exit 1; }
        [[ "$1" == "$2" ]] && exit 0
        [[ -e "${DESKTOP_DIR}/$2" ]] && { echo "already exists: $2" >&2; exit 1; }
        # -T so renaming onto a directory errors instead of silently nesting the
        # source inside it; -n so an item created in the race is never clobbered.
        mv -nT -- "${DESKTOP_DIR}/$1" "${DESKTOP_DIR}/$2"
        jq --arg o "$1" --arg n "$2" \
          'if has($o) then (.[$n] = .[$o] | del(.[$o])) else . end' \
          "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        echo "$2"
        ;;
      trash)
        [[ $# -ge 1 ]] || { echo "usage: trash <name>..." >&2; exit 1; }
        for NAME in "$@"; do
          d_safe "${NAME}"
          [[ -e "${DESKTOP_DIR}/${NAME}" ]] || continue
          d_trash_one "${NAME}" || { echo "could not trash: ${NAME}" >&2; exit 1; }
          jq --arg n "${NAME}" 'del(.[$n])' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        done
        ;;
      open)
        [[ $# -ge 1 ]] || { echo "usage: open <name>" >&2; exit 1; }
        d_safe "$1"
        [[ -e "${DESKTOP_DIR}/$1" ]] || { echo "no such item: $1" >&2; exit 1; }
        # 9>&- so a launched app never inherits the flock and wedges the next command.
        gio open "${DESKTOP_DIR}/$1" 9>&-
        ;;
      pos)
        [[ $# -ge 3 ]] || { echo "usage: pos <name> <col> <row>" >&2; exit 1; }
        d_safe "$1"
        jq --arg n "$1" --argjson c "$2" --argjson r "$3" '.[$n] = {col: $c, row: $r}' \
          "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        ;;
      pos-batch)
        # {"name":{"col":N,"row":M},...} in one write. A first run on a populated
        # desktop places every icon at once; one process per icon would be both
        # slower and a pile-up on the lock.
        [[ $# -ge 1 ]] || { echo "usage: pos-batch <json>" >&2; exit 1; }
        echo "$1" | jq -e 'type == "object"' >/dev/null 2>&1 \
          || { echo "pos-batch expects a JSON object" >&2; exit 1; }
        if echo "$1" | jq -e 'any(keys[]; test("/") or . == "" or . == "." or . == "..")' >/dev/null 2>&1; then
          echo "pos-batch: invalid name in payload" >&2; exit 1
        fi
        jq --argjson b "$1" '. + $b' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        ;;
      forget)
        [[ $# -ge 1 ]] || { echo "usage: forget <name>" >&2; exit 1; }
        jq --arg n "$1" 'del(.[$n])' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        ;;
      *) echo "unknown: ${SUB}" >&2; exit 1 ;;
    esac
    ;;
  sysmon)
    # One-shot CPU% (0.3s sample) + memory% + temp + disk + net rate. The
    # dashboard (WP-19) polls this every 2s while visible and keeps its own
    # sparkline history; temp/disk/net degrade to null when unreadable so the
    # card can show a disabled row instead of a fake value.
    netsum() { awk -F'[: ]+' '/:/ && $2 != "lo" {rx+=$3; tx+=$11} END{print rx" "tx}' /proc/net/dev; }
    read -r _ a b c d e f g _ < /proc/stat; t1=$((a+b+c+d+e+f+g)); idle1=$((d+e))
    read -r rx1 tx1 < <(netsum)
    sleep 0.3
    read -r _ a b c d e f g _ < /proc/stat; t2=$((a+b+c+d+e+f+g)); idle2=$((d+e))
    read -r rx2 tx2 < <(netsum)
    dt=$((t2-t1)); didle=$((idle2-idle1))
    cpu=0; [[ "${dt}" -gt 0 ]] && cpu=$(( (100*(dt-didle))/dt ))
    mt=$(awk '/^MemTotal/{print $2}' /proc/meminfo)
    ma=$(awk '/^MemAvailable/{print $2}' /proc/meminfo)
    mem=0; [[ "${mt}" -gt 0 ]] && mem=$(( (100*(mt-ma))/mt ))
    # net throughput over the sample window, KB/s
    rxk=$(awk "BEGIN{v=(${rx2}-${rx1})/0.3/1024; print (v<0?0:v)}")
    txk=$(awk "BEGIN{v=(${tx2}-${tx1})/0.3/1024; print (v<0?0:v)}")
    # hottest thermal zone in °C, null if the host exposes none
    temp=null; hi=0
    for z in /sys/class/thermal/thermal_zone*/temp; do
      [[ -r "${z}" ]] || continue
      v=$(cat "${z}" 2>/dev/null) || continue
      [[ "${v}" =~ ^[0-9]+$ && "${v}" -gt "${hi}" ]] && hi="${v}"
    done
    [[ "${hi}" -gt 0 ]] && temp=$(( hi/1000 ))
    # root filesystem usage
    read -r _ dtot dused _ dpct _ < <(df -kP / | tail -1)
    dpct="${dpct%\%}"
    printf '{"cpu":%d,"mem":%d,"memUsedGb":%.1f,"memTotalGb":%.1f,"temp":%s,"diskPct":%d,"diskUsedGb":%.1f,"diskTotalGb":%.1f,"netRxKbps":%.1f,"netTxKbps":%.1f}\n' \
      "${cpu}" "${mem}" "$(awk "BEGIN{print (${mt}-${ma})/1048576}")" "$(awk "BEGIN{print ${mt}/1048576}")" \
      "${temp}" "${dpct}" "$(awk "BEGIN{print ${dused}/1048576}")" "$(awk "BEGIN{print ${dtot}/1048576}")" "${rxk}" "${txk}"
    ;;

  battery)
    # One-shot battery status for the notification watcher (WP-04). Desktops with
    # no BAT* report present:false, so the watcher stays silent on this host.
    bat=(/sys/class/power_supply/BAT*)
    b="${bat[0]}"
    if [[ -d "${b}" && -r "${b}/capacity" ]]; then
      printf '{"present":true,"level":%s,"status":"%s"}\n' \
        "$(cat "${b}/capacity")" "$(cat "${b}/status" 2>/dev/null || echo Unknown)"
    else
      printf '{"present":false,"level":0,"status":"Unknown"}\n'
    fi
    ;;

  notify)
    # Notification-center history persistence & controls (WP-04).
    NOTIF_STATE="${HOME}/.local/state/qsshell/notifications.json"
    mkdir -p "$(dirname "${NOTIF_STATE}")"
    [[ -f "${NOTIF_STATE}" ]] || printf '{"history":[]}\n' > "${NOTIF_STATE}"
    case "${1:-}" in
      get) jq . "${NOTIF_STATE}" ;;
      count) jq '.history | length' "${NOTIF_STATE}" 2>/dev/null || echo "0" ;;
      clear)
        if [[ -n "${2:-}" ]]; then
          # Clear by app name
          APP_NAME="$2"
          jq --arg app "${APP_NAME}" '.history = [.history[] | select(.appName != $app)]' "${NOTIF_STATE}" > "${NOTIF_STATE}.tmp" && mv "${NOTIF_STATE}.tmp" "${NOTIF_STATE}"
          echo "cleared notifications for ${APP_NAME}"
        else
          printf '{"history":[]}\n' > "${NOTIF_STATE}"
          echo "cleared all"
        fi
        ;;
      dnd)
        case "${2:-status}" in
          on) "${0}" settings set "notifications.dnd" true ; echo "DND enabled" ;;
          off) "${0}" settings set "notifications.dnd" false ; echo "DND disabled" ;;
          toggle)
            CURRENT="$("${0}" settings get "notifications.dnd" 2>/dev/null || echo false)"
            if [[ "${CURRENT}" == "true" ]]; then
              "${0}" settings set "notifications.dnd" false
              echo "DND disabled"
            else
              "${0}" settings set "notifications.dnd" true
              echo "DND enabled"
            fi
            ;;
          status|*)
            "${0}" settings get "notifications.dnd" 2>/dev/null || echo false
            ;;
        esac
        ;;
      send)
        shift
        SUMMARY="${1:-Notification}"
        BODY="${2:-}"
        ICON="dialog-information"
        URGENCY="normal"
        APP_NAME="mujō"
        shift 2 2>/dev/null || shift 1 2>/dev/null || true
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --icon) ICON="$2"; shift 2 ;;
            --urgency|-u) URGENCY="$2"; shift 2 ;;
            --app|-a) APP_NAME="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        notify-send -a "${APP_NAME}" -i "${ICON}" -u "${URGENCY}" "${SUMMARY}" "${BODY}"
        ;;
      write)
        # Whole-file replace from stdin, validated + atomic (SettingsBus-style).
        if jq . > "${NOTIF_STATE}.tmp" 2>/dev/null; then
          mv "${NOTIF_STATE}.tmp" "${NOTIF_STATE}"
        else
          rm -f "${NOTIF_STATE}.tmp"; echo "notify write: invalid JSON on stdin" >&2; exit 1
        fi
        ;;
      *) echo "Usage: mujo notify get|count|clear [app]|dnd [on|off|toggle|status]|send <title> [body] [--icon <icon>] [--urgency <urgency>] [--app <name>]|write" >&2; exit 1 ;;
    esac
    ;;

  rebuild)
    run_rebuild
    ;;

  settings)
    # Two roles on one verb (no arg / a section name → open the app, back-compat;
    # get|set|write → the unified store). Section names never collide with the
    # store sub-verbs, so the dispatch is unambiguous.
    case "${1:-}" in
      get)
        # settings get [dotted.path]  → whole store, or one subtree/leaf
        if [[ -n "${2:-}" ]]; then
          jq --arg p "$2" 'getpath($p | split("."))' "${SETTINGS_CONF}"
        else
          jq . "${SETTINGS_CONF}"
        fi
        ;;
      set)
        # settings set <dotted.path> <value> [--json]  (atomic)
        [[ $# -ge 3 ]] || { echo "Usage: mujo settings set <path> <value> [--json]" >&2; exit 1; }
        if [[ "${4:-}" == "--json" ]]; then
          jq --arg p "$2" --argjson v "$3" 'setpath($p | split("."); $v)' \
            "${SETTINGS_CONF}" > "${SETTINGS_CONF}.tmp" && mv "${SETTINGS_CONF}.tmp" "${SETTINGS_CONF}"
        else
          jq --arg p "$2" --arg v "$3" \
            'setpath($p | split("."); ($v | if . == "true" then true elif . == "false" then false elif . == "null" then null elif test("^-?[0-9]+(\\.[0-9]+)?$") then tonumber else . end))' \
            "${SETTINGS_CONF}" > "${SETTINGS_CONF}.tmp" && mv "${SETTINGS_CONF}.tmp" "${SETTINGS_CONF}"
        fi
        ;;
      write)
        # Replace the whole store from stdin, validated + atomic. The SettingsBus
        # QML store uses this for debounced whole-file writes.
        if jq . > "${SETTINGS_CONF}.tmp" 2>/dev/null; then
          mv "${SETTINGS_CONF}.tmp" "${SETTINGS_CONF}"
        else
          rm -f "${SETTINGS_CONF}.tmp"; echo "settings write: invalid JSON on stdin" >&2; exit 1
        fi
        ;;
      *)
        # Optional panel name routes the app to a section. A running instance
        # watches this file and switches live; otherwise launch a fresh window.
        TARGET_FILE="${HOME}/.config/qsshell/settings-target"
        mkdir -p "$(dirname "${TARGET_FILE}")"
        printf '%s\n' "${1:-appearance}" > "${TARGET_FILE}"
        if pgrep -f 'bar/settings.qml' >/dev/null 2>&1; then
          exit 0
        fi
        exec qs -p /etc/xdg/quickshell/bar/settings.qml
        ;;
    esac
    ;;

  llm)
    [[ $# -ge 1 ]] || llm_usage
    SUB="$1"; shift

    case "${SUB}" in
      model)
        [[ $# -ge 1 ]] || llm_usage
        MSUB="$1"; shift
        case "${MSUB}" in
          add)
            [[ $# -ge 1 ]] || llm_usage
            NAME="$1"; shift
            NOTE="${1:-}"
            jq --arg name "${NAME}" --arg note "${NOTE}" \
              '.models = ([.models[] | select(.name != $name)] + [{name: $name, note: $note}])' \
              "${LLM_CONF}" > "${LLM_CONF}.tmp" && mv "${LLM_CONF}.tmp" "${LLM_CONF}"
            llm_touch
            echo "Added model: ${NAME}"
            ;;
          remove)
            [[ $# -ge 1 ]] || llm_usage
            NAME="$1"; shift
            jq --arg name "${NAME}" '.models = [.models[] | select(.name != $name)]' \
              "${LLM_CONF}" > "${LLM_CONF}.tmp" && mv "${LLM_CONF}.tmp" "${LLM_CONF}"
            llm_touch
            echo "Removed model: ${NAME}"
            ;;
          *) llm_usage ;;
        esac
        ;;

      tokens)
        [[ $# -ge 1 ]] || llm_usage
        TSUB="$1"; shift
        case "${TSUB}" in
          set)
            [[ $# -ge 1 ]] || llm_usage
            jq --argjson n "$1" '.tokens = $n' "${LLM_CONF}" > "${LLM_CONF}.tmp" && mv "${LLM_CONF}.tmp" "${LLM_CONF}"
            llm_touch
            ;;
          add)
            [[ $# -ge 1 ]] || llm_usage
            jq --argjson n "$1" '.tokens = ((.tokens // 0) + $n)' "${LLM_CONF}" > "${LLM_CONF}.tmp" && mv "${LLM_CONF}.tmp" "${LLM_CONF}"
            llm_touch
            ;;
          *) llm_usage ;;
        esac
        echo "Tokens: $(jq -r '.tokens' "${LLM_CONF}")"
        ;;

      clear)
        printf '{"models":[],"tokens":0,"updated":null}\n' > "${LLM_CONF}"
        llm_touch
        echo "Cleared LLM tracker state"
        ;;

      show)
        jq . "${LLM_CONF}"
        ;;

      *) llm_usage ;;
    esac
    ;;

  ai)
    [[ $# -ge 1 ]] || ai_usage
    SUB="$1"; shift
    ai_resolve
    case "${SUB}" in
      agents)
        ai_agents
        ;;
      use)
        [[ $# -ge 1 ]] || { echo "ai use: needs an agent id" >&2; exit 1; }
        mkdir -p "$(dirname "${AI_DEFAULT_FILE}")"
        jq -n --arg d "$1" '{default: $d}' > "${AI_DEFAULT_FILE}.tmp.$$" \
          && mv -f "${AI_DEFAULT_FILE}.tmp.$$" "${AI_DEFAULT_FILE}"
        ;;
      chat)
        MSGS="$(cat)"
        echo "${MSGS}" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1 \
          || { echo "ai chat: stdin must be a non-empty JSON messages array" >&2; exit 1; }
        if [[ "${AI_KIND}" == "agent" ]]; then
          [[ -n "${AI_AGENT}" ]] || { echo "ai chat: no agent CLI selected or installed" >&2; exit 1; }
          # Flatten the OpenAI messages array into one prompt: system turns
          # become a preamble, the rest keep a role label so multi-turn context
          # survives the trip through a CLI that only takes a single string.
          PROMPT="$(echo "${MSGS}" | jq -r '
            (map(select(.role == "system")) | map(.content) | join("\n\n")) as $sys |
            (map(select(.role != "system")) | map((.role | ascii_upcase) + ": " + .content) | join("\n\n")) as $rest |
            if $sys == "" then $rest else $sys + "\n\n" + $rest end')"
          mapfile -t AI_ARGV < <(ai_agent_field run)
          [[ ${#AI_ARGV[@]} -gt 0 ]] || { echo "ai chat: unknown agent '${AI_AGENT}'" >&2; exit 1; }
          mkdir -p "${AI_SCRATCH}"
          # Agent CLIs are far slower than an HTTP completion; AI.qml allows
          # 180s for this path, so stop just under that.
          if ! OUT="$(cd "${AI_SCRATCH}" && timeout 175 "${AI_ARGV[@]}" "${PROMPT}" 2>&1)"; then
            echo "ai chat: ${AI_AGENT} failed: ${OUT}" >&2; exit 1
          fi
          AI_FILTER="$(ai_agent_field filter)"
          if [[ -n "${AI_FILTER}" ]]; then
            OUT="$(printf '%s' "${OUT}" | jq -rn "${AI_FILTER}" 2>/dev/null || true)"
          fi
          [[ -n "${OUT//[[:space:]]/}" ]] || { echo "ai chat: ${AI_AGENT} returned no output" >&2; exit 1; }
          printf '%s\n' "${OUT}"
          exit 0
        fi
        [[ -n "${AI_BASEURL}" ]] || { echo "ai chat: ai.baseUrl is not set" >&2; exit 1; }
        [[ -n "${AI_MODEL}" ]]   || { echo "ai chat: ai.model is not set" >&2; exit 1; }
        BODY="$(jq -n --arg m "${AI_MODEL}" --argjson msgs "${MSGS}" --argjson mt "${AI_MAXTOK}" \
          '{model: $m, messages: $msgs, max_tokens: $mt, stream: false}')"
        HDRS=(-H "Content-Type: application/json")
        KEY="$(ai_key "${AI_PROVIDER}")"
        [[ -n "${KEY}" ]] && HDRS+=(-H "Authorization: Bearer ${KEY}")
        # --max-time 60: the singleton also enforces its own 60s abort.
        if ! RESP="$(curl -fsS --max-time 60 "${HDRS[@]}" -d "${BODY}" "${AI_BASEURL%/}/chat/completions" 2>&1)"; then
          echo "ai chat: request failed: ${RESP}" >&2; exit 1
        fi
        CONTENT="$(echo "${RESP}" | jq -r '.choices[0].message.content // empty' 2>/dev/null)"
        if [[ -z "${CONTENT}" ]]; then
          ERR="$(echo "${RESP}" | jq -r '.error.message // empty' 2>/dev/null)"
          echo "ai chat: ${ERR:-no completion in response}" >&2; exit 1
        fi
        printf '%s\n' "${CONTENT}"
        ;;
      test)
        if [[ "${AI_KIND}" == "agent" ]]; then
          [[ -n "${AI_AGENT}" ]] \
            || { echo '{"ok":false,"error":"no agent CLI selected or installed"}'; exit 0; }
          AI_BIN="$(ai_agent_field bin)"
          START="$(date +%s%3N)"
          if ! VER="$(timeout 15 "${AI_BIN}" --version 2>&1)"; then
            jq -n --arg e "${AI_BIN}: ${VER}" '{ok:false, error:$e}'; exit 0
          fi
          MS=$(( $(date +%s%3N) - START ))
          jq -n --argjson ms "${MS}" --arg v "$(printf '%s' "${VER}" | head -n1)" \
            '{ok:true, latencyMs:$ms, models:[$v]}'
          exit 0
        fi
        [[ -n "${AI_BASEURL}" ]] || { echo '{"ok":false,"error":"ai.baseUrl is not set"}'; exit 0; }
        HDRS=()
        KEY="$(ai_key "${AI_PROVIDER}")"
        [[ -n "${KEY}" ]] && HDRS+=(-H "Authorization: Bearer ${KEY}")
        START="$(date +%s%3N)"
        if ! RESP="$(curl -fsS --max-time 15 "${HDRS[@]}" "${AI_BASEURL%/}/models" 2>&1)"; then
          jq -n --arg e "${RESP}" '{ok:false, error:$e}'; exit 0
        fi
        MS=$(( $(date +%s%3N) - START ))
        echo "${RESP}" | jq --argjson ms "${MS}" '{ok:true, latencyMs:$ms, models:[.data[].id]}' 2>/dev/null \
          || jq -n --argjson ms "${MS}" '{ok:true, latencyMs:$ms, models:[]}'
        ;;
      *) ai_usage ;;
    esac
    ;;

  generations)
    # JSON array of system generations, newest first, with current/booted flags.
    booted="$(readlink -f /run/booted-system 2>/dev/null || echo '')"
    current="$(readlink -f /run/current-system 2>/dev/null || echo '')"
    for link in /nix/var/nix/profiles/system-*-link; do
      [ -e "${link}" ] || continue
      num="$(basename "${link}" | sed 's/system-\(.*\)-link/\1/')"
      path="$(readlink -f "${link}" 2>/dev/null || echo '')"
      date="$(stat -c %y "${link}" 2>/dev/null | cut -d. -f1)"
      jq -n --arg n "${num}" --arg d "${date}" --arg p "${path}" \
            --arg booted "${booted}" --arg current "${current}" \
            '{number:($n|tonumber), date:$d, current:($p==$current and $p!=""), booted:($p==$booted and $p!="")}'
    done | jq -s 'sort_by(.number) | reverse'
    ;;

  update-status)
    # Heuristic: is flake.lock newer than the running system, and how old is it?
    lock="${HOME}/nixconf/flake.lock"
    lockmtime="$(stat -c %Y "${lock}" 2>/dev/null || echo 0)"
    sysmtime="$(stat -c %Y /run/current-system 2>/dev/null || echo 0)"
    now="$(date +%s)"
    ageDays=$(( (now - lockmtime) / 86400 ))
    newer=false; [ "${lockmtime}" -gt "${sysmtime}" ] && newer=true
    reboot=false
    [ "$(readlink -f /run/booted-system 2>/dev/null)" != "$(readlink -f /run/current-system 2>/dev/null)" ] && reboot=true
    jq -n --argjson newer "${newer}" --argjson age "${ageDays}" --argjson reboot "${reboot}" \
      '{lockNewerThanSystem:$newer, lockAgeDays:$age, rebootRequired:$reboot, updateSuggested: ($newer or ($age >= 7))}'
    ;;

  update)
    # Streamed into the System panel's log pane: pull, update inputs, rebuild.
    cd "${HOME}/nixconf" || { echo "no ${HOME}/nixconf" >&2; exit 1; }
    echo ">>> git pull --ff-only"
    git pull --ff-only || { echo "git pull failed" >&2; exit 1; }
    echo ">>> nix flake update"
    nix flake update || { echo "flake update failed" >&2; exit 1; }
    echo ">>> nixos-rebuild switch"
    exec pkexec nixos-rebuild switch --flake "${HOME}/nixconf#main"
    ;;

  overrides)
    # Local, gitignored NixOS module drop-ins. enabled=*.nix, disabled=*.disabled.
    # enable/disable = rename between the two; the flake loader imports only *.nix.
    dir="${HOME}/nixconf/nixos/overrides"
    sub="${1:-list}"
    # A flake only sees git-tracked files, so mutations must be staged (intent-to-add)
    # or the loader never sees them. Content stays uncommitted until the user commits.
    stage() { git -C "${HOME}/nixconf" add -AN nixos/overrides >/dev/null 2>&1 || true; }
    # safe name: strip any path/extension, allow [a-zA-Z0-9_-]
    name="$(basename "${2:-}" | sed 's/\.\(nix\|disabled\)$//')"
    safe='^[a-zA-Z0-9_-]+$'
    case "${sub}" in
      list)
        {
          for f in "${dir}"/*.nix; do
            [ -e "${f}" ] || continue
            b="$(basename "${f}" .nix)"
            [ "${b}" = "template" ] && continue
            jq -n --arg n "${b}" '{name:$n, enabled:true}'
          done
          for f in "${dir}"/*.disabled; do
            [ -e "${f}" ] || continue
            jq -n --arg n "$(basename "${f}" .disabled)" '{name:$n, enabled:false}'
          done
        } | jq -s 'sort_by(.name)'
        ;;
      enable)
        [[ "${name}" =~ ${safe} ]] || { echo "bad name" >&2; exit 1; }
        [ -e "${dir}/${name}.disabled" ] || { echo "no such disabled override" >&2; exit 1; }
        mv "${dir}/${name}.disabled" "${dir}/${name}.nix"; stage
        ;;
      disable)
        [[ "${name}" =~ ${safe} ]] || { echo "bad name" >&2; exit 1; }
        [ -e "${dir}/${name}.nix" ] || { echo "no such override" >&2; exit 1; }
        mv "${dir}/${name}.nix" "${dir}/${name}.disabled"; stage
        ;;
      add)
        [[ "${name}" =~ ${safe} ]] || { echo "bad name" >&2; exit 1; }
        [ "${name}" = "template" ] && { echo "reserved name" >&2; exit 1; }
        [ -e "${dir}/${name}.nix" ] || [ -e "${dir}/${name}.disabled" ] \
          && { echo "already exists" >&2; exit 1; }
        cp "${dir}/template.nix.example" "${dir}/${name}.nix"; stage
        echo "${dir}/${name}.nix"
        ;;
      remove)
        [[ "${name}" =~ ${safe} ]] || { echo "bad name" >&2; exit 1; }
        rm -f "${dir}/${name}.nix" "${dir}/${name}.disabled"; stage
        ;;
      show)
        [[ "${name}" =~ ${safe} ]] || { echo "bad name" >&2; exit 1; }
        cat "${dir}/${name}.nix" 2>/dev/null || cat "${dir}/${name}.disabled" 2>/dev/null \
          || { echo "no such override" >&2; exit 1; }
        ;;
      *) echo "Usage: mujo overrides list|enable|disable|add|remove|show [name]" >&2; exit 1 ;;
    esac
    ;;

  idle-guard)
    # Exit 0 = inhibit the idle action (swayidle wrapper skips it).
    case "${1:-}" in
      audio)    pactl list sink-inputs 2>/dev/null | grep -q 'Corked: no' ;;
      charging) grep -qx 1 /sys/class/power_supply/*/online 2>/dev/null ;;
      *) exit 1 ;;
    esac
    ;;

  system-pref|system-prefs)
    [[ $# -ge 1 ]] || { echo "Usage: mujo system-pref get|set <path> <val>|apply" >&2; exit 1; }
    SUB="$1"; shift
    case "${SUB}" in
      get)
        [[ -f "${PREFS_JSON}" ]] || printf '{"hostname":"main","timezone":"Europe/Berlin","locale":"en_US.UTF-8","firewall":{"enable":true,"allowedTCPPorts":[11434]},"ssh":{"enable":false},"autoOptimiseStore":true,"zramSwap":{"enable":true,"memoryPercent":50}}\n' > "${PREFS_JSON}"
        jq . "${PREFS_JSON}"
        ;;
      set)
        [[ $# -ge 2 ]] || { echo "Usage: mujo system-pref set <path> <val>" >&2; exit 1; }
        P="$1"; V="$2"
        COERCE='($v | if . == "true" then true elif . == "false" then false elif . == "null" then null elif test("^-?[0-9]+(\\.[0-9]+)?$") then tonumber else . end)'
        prefs_write "setpath(\$p | split(\".\"); ${COERCE})" --arg p "$P" --arg v "$V"
        echo "system-pref ${P} = ${V}"
        ;;
      apply)
        run_rebuild
        ;;
      *) echo "Usage: mujo system-pref get|set <path> <val>|apply" >&2; exit 1 ;;
    esac
    ;;

  clipboard)
    [[ $# -ge 1 ]] || { echo "Usage: mujo clipboard status|clear|count" >&2; exit 1; }
    SUB="$1"; shift
    case "${SUB}" in
      status)
        COUNT="$(cliphist list 2>/dev/null | wc -l || echo 0)"
        ACTIVE="$(systemctl --user is-active wl-cliphist 2>/dev/null || echo 'inactive')"
        jq -n --argjson count "${COUNT}" --arg active "${ACTIVE}" '{count: $count, active: ($active == "active")}'
        ;;
      clear|wipe)
        cliphist wipe 2>/dev/null || true
        command -v wl-copy >/dev/null 2>&1 && wl-copy -c 2>/dev/null || true
        echo "Clipboard history cleared"
        ;;
      count)
        cliphist list 2>/dev/null | wc -l || echo 0
        ;;
      *) echo "Usage: mujo clipboard status|clear|count" >&2; exit 1 ;;
    esac
    ;;

  privacy)
    [[ $# -ge 1 ]] || { echo "Usage: mujo privacy clear-recent|status" >&2; exit 1; }
    SUB="$1"; shift
    case "${SUB}" in
      clear-recent)
        rm -f "${HOME}/.local/share/recently-used.xbel"
        touch "${HOME}/.local/share/recently-used.xbel" 2>/dev/null || true
        echo "Recent files history cleared"
        ;;
      status)
        REC_COUNT=0
        if [[ -f "${HOME}/.local/share/recently-used.xbel" ]]; then
          REC_COUNT="$(grep -c '<bookmark ' "${HOME}/.local/share/recently-used.xbel" 2>/dev/null || echo 0)"
        fi
        jq -n --argjson recentCount "${REC_COUNT}" '{recentFilesCount: $recentCount}'
        ;;
      *) echo "Usage: mujo privacy clear-recent|status" >&2; exit 1 ;;
    esac
    ;;

  shelf)
    [[ $# -ge 1 ]] || shelf_usage
    SUB="$1"; shift
    SHELF_DIR="${HOME}/.local/state/qsshell"
    SHELF_JSON="${SHELF_DIR}/shelf.json"
    mkdir -p "${SHELF_DIR}"
    [[ -f "${SHELF_JSON}" ]] || printf '{"items":[]}\n' > "${SHELF_JSON}"

    case "${SUB}" in
      list)
        if [[ -f "${SHELF_JSON}" ]]; then
          cat "${SHELF_JSON}"
        else
          echo '{"items":[]}'
        fi
        ;;
      add)
        [[ $# -ge 1 ]] || { echo "Usage: mujo shelf add <path>..." >&2; exit 1; }
        exec 9>"${SHELF_JSON}.lock"
        flock 9
        CURR="$(cat "${SHELF_JSON}" 2>/dev/null || echo '{"items":[]}')"
        for p in "$@"; do
          ABS="$(realpath -m "$p")"
          CURR="$(echo "$CURR" | jq --arg p "$ABS" '.items = ([.items[] | select(.path != $p)] + [{"path": $p}])')"
        done
        echo "$CURR" | jq '.items = .items[-50:]' > "${SHELF_JSON}.$$"
        mv "${SHELF_JSON}.$$" "${SHELF_JSON}"
        flock -u 9
        ;;
      remove)
        [[ $# -ge 1 ]] || { echo "Usage: mujo shelf remove <path>..." >&2; exit 1; }
        exec 9>"${SHELF_JSON}.lock"
        flock 9
        CURR="$(cat "${SHELF_JSON}" 2>/dev/null || echo '{"items":[]}')"
        for p in "$@"; do
          ABS="$(realpath -m "$p")"
          CURR="$(echo "$CURR" | jq --arg p "$ABS" '.items = [.items[] | select(.path != $p)]')"
        done
        echo "$CURR" > "${SHELF_JSON}.$$"
        mv "${SHELF_JSON}.$$" "${SHELF_JSON}"
        flock -u 9
        ;;
      clear)
        exec 9>"${SHELF_JSON}.lock"
        flock 9
        printf '{"items":[]}\n' > "${SHELF_JSON}.$$"
        mv "${SHELF_JSON}.$$" "${SHELF_JSON}"
        flock -u 9
        ;;
      toggle)
        qs -p /etc/xdg/quickshell/bar/shell.qml ipc call shelf toggle 2>/dev/null || true
        ;;
      open)
        [[ $# -ge 1 ]] || { echo "Usage: mujo shelf open <path>" >&2; exit 1; }
        xdg-open "$1"
        ;;
      *) shelf_usage ;;
    esac
    ;;

  power-profile)
    case "${1:-get}" in
      get)
        powerprofilesctl get 2>/dev/null || echo "balanced"
        ;;
      set)
        [[ $# -ge 2 ]] || { echo "Usage: mujo power-profile set <performance|balanced|power-saver>" >&2; exit 1; }
        powerprofilesctl set "$2" 2>/dev/null || echo "failed"
        ;;
      list)
        powerprofilesctl list 2>/dev/null || echo "balanced"
        ;;
      *) echo "Usage: mujo power-profile get|set <profile>" >&2; exit 1 ;;
    esac
    ;;

  screenshot)
    if command -v mujo-screenshot >/dev/null 2>&1; then
      exec mujo-screenshot "$@"
    else
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      if [[ -f "${SCRIPT_DIR}/mujo-screenshot.sh" ]]; then
        exec "${SCRIPT_DIR}/mujo-screenshot.sh" "$@"
      else
        echo "mujo-screenshot is not available." >&2
        exit 1
      fi
    fi
    ;;

  crash)
    [[ $# -ge 1 ]] || crash_usage
    SUB="$1"; shift
    case "${SUB}" in
      stream)
        # Event-driven stream of normalized JSON crash events
        journalctl -q -f -n 0 -o json | jq --unbuffered -c '
          if type == "object" then
            if .MESSAGE_ID? == "fc2e22bc6ee647b6b90729ab34a250b1" then
              {
                type: "coredump",
                comm: (.COREDUMP_COMM // ._COMM // "app"),
                pid: (.COREDUMP_PID // ._PID // ""),
                id: (.COREDUMP_PID // .COREDUMP_COMM // "coredump"),
                signal: (.COREDUMP_SIGNAL // "SEGV"),
                summary: "Application dumped core",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            elif (._SYSTEMD_UNIT? != null and (.UNIT_RESULT? == "failed" or .JOB_RESULT? == "failed")) or .MESSAGE_ID? == "be3217bafd1e4ee99b1c707e63d7e2b1" then
              {
                type: "unit",
                comm: (._SYSTEMD_USER_UNIT // ._SYSTEMD_UNIT // "service"),
                pid: (._PID // ""),
                id: (._SYSTEMD_USER_UNIT // ._SYSTEMD_UNIT // "unit"),
                signal: "FAILED",
                summary: "Systemd service entered failed state",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            elif (.MESSAGE? | type == "string" and (. | test("Out of memory: Killed process|systemd-oomd"))) then
              {
                type: "oom",
                comm: "oom-killer",
                pid: (if .MESSAGE | test("Killed process ([0-9]+)") then (.MESSAGE | capture("Killed process (?<p>[0-9]+)") | .p) else "" end),
                id: "oom",
                signal: "SIGKILL",
                summary: "Process terminated by Out-of-Memory killer",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            elif (.MESSAGE? | type == "string" and (. | test("amdgpu.*GPU reset|amdgpu.*ring.*timeout"))) then
              {
                type: "gpu",
                comm: "amdgpu",
                pid: "",
                id: "gpu",
                signal: "GPU_RESET",
                summary: "AMD GPU driver reset / ring timeout detected",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            else empty end
          else empty end'
        ;;
      info)
        TYPE="${1:-coredump}"; ID="${2:-}"
        case "${TYPE}" in
          coredump)
            RAW="$(coredumpctl info ${ID} 2>/dev/null || coredumpctl info 2>/dev/null || echo "(no coredump info)")"
            SANITIZED="$(printf '%s\n' "${RAW}" | awk '
              /^[[:space:]]*Environment:/ { env=1; print "    Environment: (hidden)"; next }
              env && /^[[:space:]]+\S/ { next }
              env && !/^[[:space:]]/ { env=0 }
              { print }
            ' | head -c 8000)"
            COMM="$(printf '%s\n' "${SANITIZED}" | grep -E '^[[:space:]]*Executable:' | head -1 | awk '{print $2}' | xargs -r basename || echo "app")"
            PID="$(printf '%s\n' "${SANITIZED}" | grep -E '^[[:space:]]*PID:' | head -1 | awk '{print $2}' || echo "")"
            SIGNAL="$(printf '%s\n' "${SANITIZED}" | grep -E '^[[:space:]]*Signal:' | head -1 | awk '{print $2}' || echo "SEGV")"
            jq -n --arg type "coredump" --arg id "${ID}" --arg comm "${COMM:-app}" --arg pid "${PID}" --arg sig "${SIGNAL}" --arg raw "${SANITIZED}" \
              '{type:$type, id:$id, comm:$comm, pid:$pid, signal:$sig, raw:$raw}'
            ;;
          unit)
            STATUS="$(systemctl --user status "${ID}" 2>/dev/null || systemctl status "${ID}" 2>/dev/null || echo "(no service status)")"
            LOGS="$(journalctl --user -u "${ID}" -n 30 --no-pager -o cat 2>/dev/null || journalctl -u "${ID}" -n 30 --no-pager -o cat 2>/dev/null || echo "")"
            RAW="=== Service Status ===\n${STATUS}\n\n=== Recent Logs ===\n${LOGS}"
            jq -n --arg type "unit" --arg id "${ID}" --arg comm "${ID}" --arg raw "${RAW}" \
              '{type:$type, id:$id, comm:$comm, pid:"", signal:"FAILED", raw:$raw}'
            ;;
          oom)
            LOGS="$(journalctl -n 50 --no-pager --grep "oom|Out of memory" -o cat 2>/dev/null || echo "(no OOM logs)")"
            jq -n --arg type "oom" --arg id "oom" --arg comm "oom-killer" --arg raw "${LOGS}" \
              '{type:$type, id:$id, comm:$comm, pid:"", signal:"SIGKILL", raw:$raw}'
            ;;
          gpu)
            LOGS="$(dmesg 2>/dev/null | grep -iE "amdgpu|drm|fence|timeout|reset" | tail -n 40 || journalctl -k -n 40 --no-pager -o cat 2>/dev/null || echo "(no GPU logs)")"
            jq -n --arg type "gpu" --arg id "gpu" --arg comm "amdgpu" --arg raw "${LOGS}" \
              '{type:$type, id:$id, comm:$comm, pid:"", signal:"GPU_RESET", raw:$raw}'
            ;;
          *)
            echo "Unknown crash type: ${TYPE}" >&2; exit 1
            ;;
        esac
        ;;
      diagnose)
        TYPE="${1:-coredump}"; ID="${2:-}"
        INFO_JSON="$(mujo crash info "${TYPE}" "${ID}")"
        RAW_TEXT="$(printf '%s' "${INFO_JSON}" | jq -r '.raw // empty')"
        COMM="$(printf '%s' "${INFO_JSON}" | jq -r '.comm // "application"')"
        
        SYSTEM_PROMPT='You are a Linux system reliability & crash diagnostic AI. Analyze the sanitized crash info and return ONLY a valid JSON object matching this schema:
{
  "summary": "1-2 sentence plain-language explanation of why it crashed",
  "rootCause": "Direct technical cause (e.g. SIGSEGV null pointer dereference, VRAM exhaustion, unit failed dependency)",
  "fixes": [
    { "id": "restart_unit", "title": "Restart Service", "action": "restart-unit", "target": "<unitName>" },
    { "id": "clear_cache", "title": "Clear App Cache", "action": "clear-cache", "target": "<appName>" },
    { "id": "rollback_gen", "title": "Rollback Generation", "action": "rollback-gen", "target": "<number>" }
  ],
  "investigateCmd": "command to run in terminal for inspection"
}'
        USER_MSG="Crash type: ${TYPE}, Target: ${COMM}\n\nCrash Log:\n${RAW_TEXT}"
        
        PAYLOAD="$(jq -n --arg sys "${SYSTEM_PROMPT}" --arg user "${USER_MSG}" \
          '[{role:"system", content:$sys}, {role:"user", content:$user}]')"
        
        AI_OUT="$(printf '%s' "${PAYLOAD}" | mujo ai chat 2>/dev/null || echo "")"
        if printf '%s' "${AI_OUT}" | jq . >/dev/null 2>&1; then
          printf '%s\n' "${AI_OUT}"
        else
          EXTRACTED="$(printf '%s' "${AI_OUT}" | sed -n '/```json/,/```/p' | sed '1d;$d')"
          if printf '%s' "${EXTRACTED}" | jq . >/dev/null 2>&1; then
            printf '%s\n' "${EXTRACTED}"
          else
            jq -n --arg s "${AI_OUT:-Process terminated unexpectedly.}" --arg comm "${COMM}" \
              '{summary:$s, rootCause:"Abnormal process termination", fixes:[{id:"clear_cache", title:"Clear App Cache", action:"clear-cache", target:$comm}], investigateCmd:"coredumpctl info"}'
          fi
        fi
        ;;
      fix)
        [[ $# -ge 1 ]] || { echo "Usage: mujo crash fix <action> [target]" >&2; exit 1; }
        ACTION="$1"; TARGET="${2:-}"
        case "${ACTION}" in
          restart-unit)
            [[ -n "${TARGET}" ]] || { echo "Missing target unit" >&2; exit 1; }
            if systemctl --user restart "${TARGET}" 2>/dev/null; then
              echo "Restarted user service ${TARGET}"
            else
              pkexec systemctl restart "${TARGET}"
            fi
            ;;
          clear-cache)
            [[ -n "${TARGET}" ]] || { echo "Missing target app" >&2; exit 1; }
            SAFE_NAME="$(basename "${TARGET}")"
            if [[ -d "${HOME}/.cache/${SAFE_NAME}" ]]; then
              rm -rf "${HOME}/.cache/${SAFE_NAME}"
              echo "Purged ~/.cache/${SAFE_NAME}"
            else
              echo "No cache directory for ${SAFE_NAME}"
            fi
            ;;
          rollback-gen)
            [[ "${TARGET}" =~ ^[0-9]+$ ]] || { echo "Invalid generation number" >&2; exit 1; }
            pkexec sh -c "nix-env --switch-generation ${TARGET} -p /nix/var/nix/profiles/system && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"
            ;;
          kill)
            [[ "${TARGET}" =~ ^[0-9]+$ ]] || { echo "Invalid pid" >&2; exit 1; }
            kill -15 "${TARGET}" 2>/dev/null || kill -9 "${TARGET}" 2>/dev/null
            echo "Terminated process ${TARGET}"
            ;;
          *)
            echo "Unknown fix action: ${ACTION}" >&2; exit 1
            ;;
        esac
        ;;
      *) crash_usage ;;
    esac
    ;;

  sentinel)
    [[ $# -ge 1 ]] || sentinel_usage
    SUB="$1"; shift
    case "${SUB}" in
      scan)
        CARD="$(ls -d /sys/class/drm/card* 2>/dev/null | grep -E 'card[0-9]+$' | head -1 || echo '')"
        GPU_BUSY="null"; VRAM_USED="null"; VRAM_TOTAL="null"
        if [[ -n "${CARD}" && -d "${CARD}/device" ]]; then
          [[ -r "${CARD}/device/gpu_busy_percent" ]] && GPU_BUSY="$(cat "${CARD}/device/gpu_busy_percent" 2>/dev/null || echo null)"
          if [[ -r "${CARD}/device/mem_info_vram_used" ]]; then
            VU="$(cat "${CARD}/device/mem_info_vram_used" 2>/dev/null || echo 0)"
            VT="$(cat "${CARD}/device/mem_info_vram_total" 2>/dev/null || echo 0)"
            VRAM_USED=$(( VU / 1048576 ))
            VRAM_TOTAL=$(( VT / 1048576 ))
          fi
        fi

        PROCS_JSON="$(ps -eo pid=,ppid=,stat=,rss=,%cpu=,%mem=,comm= --sort=-%cpu | head -n 35 | awk '
          BEGIN { printf "["; first=1 }
          {
            if (!first) printf ","
            first=0
            pid=$1; ppid=$2; stat=$3; rss=int($4/1024); cpu=$5; mem=$6;
            $1=$2=$3=$4=$5=$6="";
            sub(/^[ \t]+/, "", $0);
            gsub(/"/, "\\\"", $0);
            printf "{\"pid\":%d,\"ppid\":%d,\"stat\":\"%s\",\"rssMb\":%d,\"cpu\":%.1f,\"mem\":%.1f,\"comm\":\"%s\"}", pid, ppid, stat, rss, cpu, mem, $0
          }
          END { printf "]\n" }
        ')"

        jq -n \
          --argjson procs "${PROCS_JSON}" \
          --arg gpu_busy "${GPU_BUSY}" \
          --arg vram_used "${VRAM_USED}" \
          --arg vram_total "${VRAM_TOTAL}" '
          ($procs | map(select(.stat | startswith("Z")))) as $zombies |
          ($procs | map(select(.cpu >= 70 and (.comm != "quickshell" and .comm != "niri" and .comm != ".nixos-test-dri")) | . + {type: "cpu_runaway", label: "CPU Runaway"})) as $cpuRunaways |
          ($procs | map(select((.mem >= 25 or .rssMb >= 3500) and (.comm != ".nixos-test-dri")) | . + {type: "mem_hog", label: "Memory Hog"})) as $memHogs |
          ($procs | map(select((.stat | startswith("D")) and .ppid != 2 and .pid != 2) | . + {type: "d_state", label: "Uninterruptible Disk Wait"})) as $dState |
          ($zombies | map(. + {type: "zombie", label: "Defunct Zombie"})) as $taggedZombies |
          ($cpuRunaways + $memHogs + $taggedZombies + $dState | unique_by(.pid)) as $anomalies |
          (100 - (($zombies | length) * 10) - (($cpuRunaways | length) * 15) - (($memHogs | length) * 15)) as $rawScore |
          (if $rawScore < 10 then 10 elif $rawScore > 100 then 100 else $rawScore end) as $score |
          {
            healthScore: $score,
            status: (if $score >= 85 then "optimal" elif $score >= 60 then "warning" else "critical" end),
            zombieCount: ($zombies | length),
            anomalyCount: ($anomalies | length),
            anomalies: $anomalies,
            topCpu: ($procs | sort_by(-.cpu) | .[0:6]),
            topMem: ($procs | sort_by(-.rssMb) | .[0:6]),
            gpu: {
              busyPercent: ($gpu_busy | if . == "null" then null else tonumber end),
              vramUsedMb: ($vram_used | if . == "null" then null else tonumber end),
              vramTotalMb: ($vram_total | if . == "null" then null else tonumber end)
            }
          }'
        ;;
      reap)
        REAPED=0
        PIDS=()
        while read -r pid ppid; do
          [[ -n "${pid}" ]] || continue
          if kill -CHLD "${ppid}" 2>/dev/null; then
            REAPED=$(( REAPED + 1 ))
            PIDS+=("${pid}")
          fi
        done < <(ps -eo pid=,ppid=,stat= | awk '$3 ~ /^Z/ {print $1, $2}')
        jq -n --argjson count "${REAPED}" --argjson pids "$(printf '%s\n' "${PIDS[@]}" | jq -R . | jq -s 'map(select(. != "") | tonumber)')" \
          '{reapedCount:$count, pids:$pids}'
        ;;
      action)
        [[ $# -ge 2 ]] || { echo "Usage: mujo sentinel action <kill|term|stop|cont|renice> <pid> [val]" >&2; exit 1; }
        ACT="$1"; PID="$2"; VAL="${3:--10}"
        [[ "${PID}" =~ ^[0-9]+$ ]] || { echo "Invalid pid" >&2; exit 1; }
        case "${ACT}" in
          kill) kill -9 "${PID}" ;;
          term) kill -15 "${PID}" ;;
          stop) kill -STOP "${PID}" ;;
          cont) kill -CONT "${PID}" ;;
          renice) renice -n "${VAL}" -p "${PID}" ;;
          *) echo "Unknown action: ${ACT}" >&2; exit 1 ;;
        esac
        echo "Executed ${ACT} on PID ${PID}"
        ;;
      *) sentinel_usage ;;
    esac
    ;;

  clean)
    [[ $# -ge 1 ]] || clean_usage
    SUB="$1"; shift
    case "${SUB}" in
      scan)
        GEN_COUNT="$(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l || echo 0)"
        NIX_RECLAIM_MB=$(( GEN_COUNT > 1 ? (GEN_COUNT - 1) * 850 : 0 ))

        J_RAW="$(journalctl --disk-usage 2>/dev/null || echo '')"
        J_MB=0
        if [[ "${J_RAW}" =~ ([0-9.]+)G ]]; then
          J_MB="$(awk "BEGIN {print int(${BASH_REMATCH[1]} * 1024)}")"
        elif [[ "${J_RAW}" =~ ([0-9.]+)M ]]; then
          J_MB="$(awk "BEGIN {print int(${BASH_REMATCH[1]})}")"
        fi
        J_RECLAIM_MB=$(( J_MB > 100 ? J_MB - 100 : 0 ))

        THUMB_MB="$(du -sm "${HOME}/.cache/thumbnails" 2>/dev/null | cut -f1 || echo 0)"
        TRASH_MB="$(du -sm "${HOME}/.local/share/Trash" 2>/dev/null | cut -f1 || echo 0)"
        SHADER_MB="$(du -sm "${HOME}/.cache/mesa_shader_cache" 2>/dev/null | cut -f1 || echo 0)"
        CACHE_TOT_MB=$(( ${THUMB_MB:-0} + ${TRASH_MB:-0} + ${SHADER_MB:-0} ))

        Z_ORIG="$(cat /sys/block/zram0/orig_data_size 2>/dev/null || echo 0)"
        Z_COMPR="$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo 0)"
        Z_ORIG_MB=$(( Z_ORIG / 1048576 ))
        Z_COMPR_MB=$(( Z_COMPR / 1048576 ))

        TOT_RECLAIM_MB=$(( NIX_RECLAIM_MB + J_RECLAIM_MB + CACHE_TOT_MB ))

        jq -n \
          --argjson genCount "${GEN_COUNT}" \
          --argjson nixReclaim "${NIX_RECLAIM_MB}" \
          --argjson journalMb "${J_MB}" \
          --argjson journalReclaim "${J_RECLAIM_MB}" \
          --argjson thumbMb "${THUMB_MB:-0}" \
          --argjson trashMb "${TRASH_MB:-0}" \
          --argjson shaderMb "${SHADER_MB:-0}" \
          --argjson cacheTotMb "${CACHE_TOT_MB}" \
          --argjson zramOrigMb "${Z_ORIG_MB}" \
          --argjson zramComprMb "${Z_COMPR_MB}" \
          --argjson totalReclaim "${TOT_RECLAIM_MB}" '
          {
            nix: {
              generations: $genCount,
              reclaimableMb: $nixReclaim,
              label: "\($genCount) generations stored"
            },
            journal: {
              sizeMb: $journalMb,
              reclaimableMb: $journalReclaim,
              label: "\($journalMb) MB logs recorded"
            },
            caches: {
              totalMb: $cacheTotMb,
              reclaimableMb: $cacheTotMb,
              thumbnailsMb: $thumbMb,
              trashMb: $trashMb,
              shaderMb: $shaderMb
            },
            memory: {
              zramOrigMb: $zramOrigMb,
              zramComprMb: $zramComprMb
            },
            totalReclaimableMb: $totalReclaim
          }'
        ;;
      apply)
        TARGET="${1:-all}"
        case "${TARGET}" in
          nix)
            echo ">>> Cleaning old Nix generations and optimising store..."
            pkexec nix-collect-garbage -d && pkexec nix-store --optimise
            echo "✓ Nix store cleaned and deduplicated"
            ;;
          journal)
            echo ">>> Vacuuming systemd journals..."
            journalctl --user --vacuum-time=7d 2>/dev/null || true
            pkexec journalctl --vacuum-time=7d --vacuum-size=100M
            echo "✓ Journals vacuumed to <=100MB"
            ;;
          caches)
            echo ">>> Purging disposable application and thumbnail caches..."
            rm -rf "${HOME}/.cache/thumbnails"/* "${HOME}/.local/share/Trash"/* "${HOME}/.cache/mesa_shader_cache"/* 2>/dev/null || true
            echo "✓ User thumbnail, trash, and shader caches cleared"
            ;;
          memory)
            echo ">>> Compacting ZRAM memory and reclaiming page cache..."
            if [[ -w /sys/block/zram0/compact ]]; then
              echo 1 > /sys/block/zram0/compact 2>/dev/null || true
            fi
            sync
            pkexec sysctl -w vm.drop_caches=3 2>/dev/null || true
            echo "✓ Memory compacted and inactive cache dropped"
            ;;
          all)
            echo ">>> Executing full system optimization..."
            rm -rf "${HOME}/.cache/thumbnails"/* "${HOME}/.local/share/Trash"/* "${HOME}/.cache/mesa_shader_cache"/* 2>/dev/null || true
            journalctl --user --vacuum-time=7d 2>/dev/null || true
            pkexec journalctl --vacuum-time=7d --vacuum-size=100M 2>/dev/null || true
            pkexec nix-collect-garbage -d 2>/dev/null || true
            pkexec nix-store --optimise 2>/dev/null || true
            if [[ -w /sys/block/zram0/compact ]]; then echo 1 > /sys/block/zram0/compact 2>/dev/null || true; fi
            sync
            pkexec sysctl -w vm.drop_caches=3 2>/dev/null || true
            echo "✓ Full system optimization complete"
            ;;
          *) echo "Usage: mujo clean apply <nix|journal|caches|memory|all>" >&2; exit 1 ;;
        esac
        ;;
      *) clean_usage ;;
    esac
    ;;

  health)
    SENTINEL="$("$0" sentinel scan 2>/dev/null || echo '{}')"
    CLEAN="$("$0" clean scan 2>/dev/null || echo '{}')"
    SCORE="$(printf '%s' "${SENTINEL}" | jq -r '.healthScore // 100')"
    STATUS="$(printf '%s' "${SENTINEL}" | jq -r '.status // "optimal"')"
    jq -n \
      --argjson sentinel "${SENTINEL}" \
      --argjson clean "${CLEAN}" \
      --arg score "${SCORE}" \
      --arg status "${STATUS}" '
      {
        score: ($score | tonumber),
        status: $status,
        sentinel: $sentinel,
        cleaner: $clean,
        timestamp: (now * 1000 | round)
      }'
    ;;

  help|-h|--help) usage ;;
  *) usage ;;
esac
