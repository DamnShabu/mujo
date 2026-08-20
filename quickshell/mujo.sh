#!/usr/bin/env bash
set -e

usage() {
  cat >&2 <<EOF
Usage: mujo <command> [args...]

Commands:
  wallpaper <subcommand>   Wallpaper management
  log <subcommand>         Trigger log-daemon capture
  help                      Show this help
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
  show                            Show current config
EOF
  exit 1
}

log_usage() {
  cat >&2 <<EOF
Usage: mujo log <command> [args...]

Commands:
  generate                      Run log capture now and generate a note
EOF
  exit 1
}

CONF="${HOME}/.config/quickshell/wallpaper.json"
mkdir -p "$(dirname "${CONF}")"
[[ -f "${CONF}" ]] || printf '{"background":"#111111","effects":{"motion":true}}\n' > "${CONF}"

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

      show)
        jq . "${CONF}"
        ;;

      *) wallpaper_usage ;;
    esac
    ;;

  log)
    [[ $# -ge 1 ]] || log_usage
    case "$1" in
      generate)
        systemctl --user start log-daemon-capture-now.service
        echo "Log capture complete"
        ;;
      *) log_usage ;;
    esac
    ;;

  help|-h|--help) usage ;;
  *) usage ;;
esac
