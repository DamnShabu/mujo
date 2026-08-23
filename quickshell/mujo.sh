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
  settings                 Open the Settings app
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
    [[ $# -ge 1 ]] || { echo "Usage: mujo weather get|set <k> <v>|fetch [--force]" >&2; exit 1; }
    SUB="$1"; shift
    case "${SUB}" in
      get) jq . "${WEATHER_CONF}" ;;
      set)
        [[ $# -ge 2 ]] || { echo "Usage: mujo weather set <key> <val>" >&2; exit 1; }
        K="$1"; V="$2"
        # numbers stay numbers, "null" → null, else string
        jq --arg k "$K" --arg v "$V" \
          '.[$k] = ($v | if . == "null" then null elif test("^-?[0-9]+(\\.[0-9]+)?$") then tonumber else . end)' \
          "${WEATHER_CONF}" > "${WEATHER_CONF}.tmp" && mv "${WEATHER_CONF}.tmp" "${WEATHER_CONF}"
        # Changing location invalidates cached coordinates + data.
        [[ "$K" == "location" ]] && jq '.lat=null|.lon=null' "${WEATHER_CONF}" > "${WEATHER_CONF}.tmp" && mv "${WEATHER_CONF}.tmp" "${WEATHER_CONF}"
        rm -f "${WEATHER_CACHE}"
        echo "${K} = ${V}"
        ;;
      fetch)
        FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1
        INTERVAL="$(jq -r '.interval // 900' "${WEATHER_CONF}")"
        # Serve fresh cache to avoid duplicate API calls across widgets/windows.
        if [[ "${FORCE}" -eq 0 && -f "${WEATHER_CACHE}" ]]; then
          AGE=$(( $(date +%s) - $(jq -r '.updated // 0' "${WEATHER_CACHE}" | cut -d. -f1) ))
          if [[ "${AGE}" -ge 0 && "${AGE}" -lt "${INTERVAL}" ]]; then cat "${WEATHER_CACHE}"; exit 0; fi
        fi
        LAT="$(jq -r '.lat // empty' "${WEATHER_CONF}")"
        LON="$(jq -r '.lon // empty' "${WEATHER_CONF}")"
        LOC="$(jq -r '.location // empty' "${WEATHER_CONF}")"
        CITY="${LOC}"
        if [[ -z "${LAT}" || -z "${LON}" ]]; then
          if [[ -n "${LOC}" ]]; then
            GEO="$(curl -fsSL --max-time 15 -G "https://geocoding-api.open-meteo.com/v1/search" --data-urlencode "name=${LOC}" --data-urlencode "count=1" 2>/dev/null)"
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
        UNITS="$(jq -r '.units // "celsius"' "${WEATHER_CONF}")"
        WIND="$(jq -r '.wind // "kmh"' "${WEATHER_CONF}")"
        FC="$(curl -fsSL --max-time 20 -G "https://api.open-meteo.com/v1/forecast" \
          --data-urlencode "latitude=${LAT}" --data-urlencode "longitude=${LON}" \
          --data-urlencode "current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m" \
          --data-urlencode "daily=temperature_2m_max,temperature_2m_min,weather_code" \
          --data-urlencode "forecast_days=5" --data-urlencode "temperature_unit=${UNITS}" \
          --data-urlencode "wind_speed_unit=${WIND}" --data-urlencode "timezone=auto" 2>/dev/null)"
        if [[ -z "${FC}" ]] || ! jq -e .current >/dev/null 2>&1 <<<"${FC}"; then
          echo '{"error":"weather request failed"}'; exit 1
        fi
        jq -n --argjson f "${FC}" --arg city "${CITY:-Here}" --arg units "${UNITS}" --arg wind "${WIND}" '{
          temp: ($f.current.temperature_2m | round), feels: ($f.current.apparent_temperature | round),
          code: $f.current.weather_code, humidity: $f.current.relative_humidity_2m,
          wind: ($f.current.wind_speed_10m | round), city: $city, units: $units, windUnit: $wind,
          daily: [range(0; ($f.daily.time | length)) as $i | {min: ($f.daily.temperature_2m_min[$i] | round), max: ($f.daily.temperature_2m_max[$i] | round), code: $f.daily.weather_code[$i], date: $f.daily.time[$i]}],
          updated: now
        }' | tee "${WEATHER_CACHE}"
        ;;
      *) echo "Usage: mujo weather get|set <k> <v>|fetch [--force]" >&2; exit 1 ;;
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
          *) echo "usage: lock on|off" >&2; exit 1 ;;
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

  rebuild)
    run_rebuild
    ;;

  settings)
    # Optional panel name routes the app to a section. A running instance watches
    # this file and switches live; otherwise we launch a fresh window.
    TARGET_FILE="${HOME}/.config/qsshell/settings-target"
    mkdir -p "$(dirname "${TARGET_FILE}")"
    printf '%s\n' "${1:-appearance}" > "${TARGET_FILE}"
    if pgrep -f 'bar/settings.qml' >/dev/null 2>&1; then
      exit 0
    fi
    exec qs -p /etc/xdg/quickshell/bar/settings.qml
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

  help|-h|--help) usage ;;
  *) usage ;;
esac
