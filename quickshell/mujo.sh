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
  ai <chat|test>           OpenAI-compatible chat completion / connectivity test
  generations              JSON list of NixOS system generations
  update-status            JSON flake.lock freshness vs the running system
  update                   git pull + flake update + rebuild (streamed)
  settings [get|set|write] Open the Settings app, or read/write the store
  overrides <subcommand>   Local NixOS override drop-ins (list/enable/disable/add/remove/show)
  idle-guard <audio|charging>  Exit 0 if idle actions should be inhibited (used by swayidle)
  help                      Show this help
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
                            nord, gruvbox, tokyonight, rosepine, onedark)
  accent <hex|"">           Override accent color ("" clears the override)
  transparency <0.6-1.0>    Set surface transparency
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
  chat    POST an OpenAI-compatible chat completion. Reads a JSON messages
          array on stdin; prints the assistant reply on stdout. Reads
          ai.{provider,baseUrl,model,maxTokens} from the settings store and
          the API key from the keyring (service qsshell, account
          <provider>-api-key). 60s timeout; kill the process to cancel.
  test    GET <baseUrl>/models. Prints {ok,latencyMs,models[]} JSON.
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

# Resolve provider/baseUrl/model/maxTokens with the Ollama-local defaults.
ai_resolve() {
  AI_PROVIDER="$(ai_get ai.provider)"; [[ -n "${AI_PROVIDER}" ]] || AI_PROVIDER="ollama"
  AI_BASEURL="$(ai_get ai.baseUrl)"
  if [[ -z "${AI_BASEURL}" && "${AI_PROVIDER}" == "ollama" ]]; then AI_BASEURL="http://127.0.0.1:11434/v1"; fi
  AI_MODEL="$(ai_get ai.model)"
  AI_MAXTOK="$(ai_get ai.maxTokens)"; [[ -n "${AI_MAXTOK}" ]] || AI_MAXTOK="1024"
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
  search <query> [page]           Search Wallhaven (raw JSON result)
  save <url> [name]               Download a wallpaper into the library
  random                          Apply a random wallpaper from the library
  show                            Show current config
EOF
  exit 1
}

CONF="${HOME}/.config/quickshell/wallpaper.json"
mkdir -p "$(dirname "${CONF}")"
[[ -f "${CONF}" ]] || printf '{"background":"#111111","effects":{"motion":true}}\n' > "${CONF}"

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
  if curl -fsSL --max-time 60 -o "${dest}.part" "${url}"; then
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

# NixOS repo + GUI-managed persistence list (see nixos/features/user-persistence.nix).
REPO="${NIXCONF:-${HOME}/nixconf}"
PERSIST_JSON="${REPO}/nixos/user-persistence.json"

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

theme_set() { # <jq-filter> [--arg name value ...]
  local filter="$1"; shift
  jq "$@" "${filter}" "${THEME_CONF}" > "${THEME_CONF}.tmp" && mv "${THEME_CONF}.tmp" "${THEME_CONF}"
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
        [[ $# -ge 1 ]] || wallpaper_usage
        QUERY="$1"; shift
        PAGE="${1:-1}"
        # SFW general/anime/people, no login/API key required.
        curl -fsSL --max-time 30 -G "https://wallhaven.cc/api/v1/search" \
          --data-urlencode "q=${QUERY}" \
          --data-urlencode "page=${PAGE}" \
          --data-urlencode "categories=111" \
          --data-urlencode "purity=100" \
          --data-urlencode "sorting=relevance" \
          || { echo '{"data":[],"error":"request failed"}'; exit 1; }
        ;;

      save)
        [[ $# -ge 1 ]] || wallpaper_usage
        if DEST="$(wp_download "$1" "${2:-}")"; then
          echo "${DEST}"
        else
          echo "Error: download failed: $1" >&2; exit 1
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
          ayu|catppuccin|dracula|nord|gruvbox|tokyonight|rosepine|onedark) ;;
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
      show)
        jq . "${THEME_CONF}"
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
    [[ $# -ge 1 ]] || { echo "Usage: mujo widgets list|add <type> [monitor]|remove <id>|move <id> <x> <y> [monitor]|geometry <id> <x> <y> <w> <h> [monitor]|lock <on|off>|set <id> <k> <v>|reset|reset-one <id>" >&2; exit 1; }
    SUB="$1"; shift
    w_commit() { mv "${WIDGETS_CONF}.tmp" "${WIDGETS_CONF}"; }
    case "${SUB}" in
      list) jq . "${WIDGETS_CONF}" ;;
      add)
        [[ $# -ge 1 ]] || { echo "type required" >&2; exit 1; }
        TYPE="$1"; MON="${2:-}"
        case "${TYPE}" in clock|weather|sysmon|calendar) ;; *) echo "unknown type: ${TYPE}" >&2; exit 1 ;; esac
        ID="${TYPE}-$(date +%s%N | tail -c 7)"
        jq --arg id "${ID}" --arg t "${TYPE}" --arg m "${MON}" \
          '.widgets += [{id:$id, type:$t, monitor:$m, x:60, y:60}]' \
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
        jq '.widgets |= map(.x = 60 | .y = 60 | del(.w) | del(.h))' "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        echo "positions reset"
        ;;
      reset-one)
        [[ $# -ge 1 ]] || { echo "usage: reset-one <id>" >&2; exit 1; }
        jq --arg id "$1" '.widgets |= map(if .id == $id then (.x = 60 | .y = 60 | del(.w) | del(.h)) else . end)' \
          "${WIDGETS_CONF}" > "${WIDGETS_CONF}.tmp" && w_commit
        echo "position reset: $1"
        ;;
      *) echo "unknown: ${SUB}" >&2; exit 1 ;;
    esac
    ;;

  sysmon)
    # One-shot CPU% (0.3s sample) + memory% for desktop widgets.
    read -r _ a b c d e f g _ < /proc/stat; t1=$((a+b+c+d+e+f+g)); idle1=$((d+e))
    sleep 0.3
    read -r _ a b c d e f g _ < /proc/stat; t2=$((a+b+c+d+e+f+g)); idle2=$((d+e))
    dt=$((t2-t1)); didle=$((idle2-idle1))
    cpu=0; [[ "${dt}" -gt 0 ]] && cpu=$(( (100*(dt-didle))/dt ))
    mt=$(awk '/^MemTotal/{print $2}' /proc/meminfo)
    ma=$(awk '/^MemAvailable/{print $2}' /proc/meminfo)
    mem=0; [[ "${mt}" -gt 0 ]] && mem=$(( (100*(mt-ma))/mt ))
    printf '{"cpu":%d,"mem":%d,"memUsedGb":%.1f,"memTotalGb":%.1f}\n' "${cpu}" "${mem}" "$(awk "BEGIN{print (${mt}-${ma})/1048576}")" "$(awk "BEGIN{print ${mt}/1048576}")"
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
    # Notification-center history persistence (WP-04). Lives under state (not
    # config): ~/.local/state/qsshell/notifications.json.
    NOTIF_STATE="${HOME}/.local/state/qsshell/notifications.json"
    mkdir -p "$(dirname "${NOTIF_STATE}")"
    [[ -f "${NOTIF_STATE}" ]] || printf '{"history":[]}\n' > "${NOTIF_STATE}"
    case "${1:-}" in
      get) jq . "${NOTIF_STATE}" ;;
      clear) printf '{"history":[]}\n' > "${NOTIF_STATE}"; echo "cleared" ;;
      write)
        # Whole-file replace from stdin, validated + atomic (SettingsBus-style).
        if jq . > "${NOTIF_STATE}.tmp" 2>/dev/null; then
          mv "${NOTIF_STATE}.tmp" "${NOTIF_STATE}"
        else
          rm -f "${NOTIF_STATE}.tmp"; echo "notify write: invalid JSON on stdin" >&2; exit 1
        fi
        ;;
      *) echo "Usage: mujo notify get|clear|write" >&2; exit 1 ;;
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
      chat)
        MSGS="$(cat)"
        echo "${MSGS}" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1 \
          || { echo "ai chat: stdin must be a non-empty JSON messages array" >&2; exit 1; }
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

  help|-h|--help) usage ;;
  *) usage ;;
esac
