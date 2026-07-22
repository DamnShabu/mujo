set -e

usage() {
  cat >&2 <<EOF
Usage: mujo <command> [args...]

Commands:
  wallpaper <subcommand>   Wallpaper management
  desktop <subcommand>     Desktop management
  help                     Show this help
EOF
  exit 1
}

wallpaper_usage() {
  cat >&2 <<EOF
Usage: mujo wallpaper <command> [args...]

Commands:
  set <path>                     Set wallpaper for all monitors
  set <path> --monitor <name>    Set wallpaper for specific monitor
  zoom <on|off>                  Toggle zoom effect
  pan <on|off>                   Toggle cursor-follow pan effect
  show                           Show current config
EOF
  exit 1
}

desktop_usage() {
  cat >&2 <<EOF
Usage: mujo desktop <command> [args...]

Commands:
  visualizer <on|off|status>  Toggle audio visualizer
  visualizer wrap <on|off>    Toggle full-screen wrap mode
EOF
  exit 1
}

visualizer_usage() {
  cat >&2 <<EOF
Usage: mujo desktop visualizer <command>

Commands:
  on              Enable audio visualizer
  off             Disable audio visualizer
  status          Show current state
  wrap <on|off>   Toggle full-screen wrap mode
EOF
  exit 1
}

CONF="$HOME/.config/quickshell/wallpaper.json"
mkdir -p "$(dirname "$CONF")"
[ -f "$CONF" ] || printf '{"background":"#111111","effects":{"zoom":true,"pan":true}}\n' > "$CONF"

[ $# -ge 1 ] || usage
CMD="$1"; shift

case "$CMD" in
  wallpaper)
    [ $# -ge 1 ] || wallpaper_usage
    SUB="$1"; shift

    case "$SUB" in
      set)
        [ $# -ge 1 ] || wallpaper_usage
        WP="$1"; shift
        MON=""
        while [ $# -ge 1 ]; do
          case "$1" in
            --monitor|-m) MON="$2"; shift 2 ;;
            *) wallpaper_usage ;;
          esac
        done

        if [ ! -f "$WP" ]; then
          echo "Error: file not found: $WP" >&2
          exit 1
        fi

        WP="$(realpath "$WP")"
        IS_VIDEO=0
        case "$WP" in
          *.mp4|*.webm|*.mkv|*.avi|*.mov) IS_VIDEO=1 ;;
        esac

        if [ -n "$MON" ]; then
          if [ "$IS_VIDEO" -eq 1 ]; then
            jq --arg mon "$MON" --arg wp "$WP" '.monitors[$mon] = (.monitors[$mon] // {}) | .monitors[$mon].video = $wp | .monitors[$mon] = (.monitors[$mon] | del(.image))' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
          else
            jq --arg mon "$MON" --arg wp "$WP" '.monitors[$mon] = (.monitors[$mon] // {}) | .monitors[$mon].image = $wp | .monitors[$mon] = (.monitors[$mon] | del(.video))' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
          fi
          echo "Set wallpaper for $MON: $WP"
        else
          if [ "$IS_VIDEO" -eq 1 ]; then
            jq --arg wp "$WP" '.default.video = $wp | .default = (.default | del(.image))' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
          else
            jq --arg wp "$WP" '.default.image = $wp | .default = (.default | del(.video))' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
          fi
          echo "Set wallpaper for all monitors: $WP"
        fi
        ;;

      zoom)
        [ $# -ge 1 ] || wallpaper_usage
        case "$1" in
          on)  jq '.effects.zoom = true' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"; echo "Zoom: on" ;;
          off) jq '.effects.zoom = false' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"; echo "Zoom: off" ;;
          *)   wallpaper_usage ;;
        esac
        ;;

      pan)
        [ $# -ge 1 ] || wallpaper_usage
        case "$1" in
          on)  jq '.effects.pan = true' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"; echo "Pan: on" ;;
          off) jq '.effects.pan = false' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"; echo "Pan: off" ;;
          *)   wallpaper_usage ;;
        esac
        ;;

      show)
        jq . "$CONF"
        ;;

      *) wallpaper_usage ;;
    esac
    ;;

  desktop)
    [ $# -ge 1 ] || desktop_usage
    SUB="$1"; shift

    case "$SUB" in
      visualizer)
        [ $# -ge 1 ] || visualizer_usage
        SUB="$1"; shift

        case "$SUB" in
          on)
            systemctl --user start qs-visualizer.service 2>/dev/null && echo "Visualizer: on" || echo "Failed to start visualizer" >&2
            ;;
          off)
            systemctl --user stop qs-visualizer.service 2>/dev/null && echo "Visualizer: off" || echo "Failed to stop visualizer" >&2
            ;;
          status)
            if systemctl --user is-active qs-visualizer.service >/dev/null 2>&1; then
              echo "Visualizer: on"
            else
              echo "Visualizer: off"
            fi
            ;;
          wrap)
            [ $# -ge 1 ] || visualizer_usage
            case "$1" in
              on)  jq '.effects.visualizerWrap = true' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"; echo "Wrap: on" ;;
              off) jq '.effects.visualizerWrap = false' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"; echo "Wrap: off" ;;
              *)   visualizer_usage ;;
            esac
            ;;
          *) visualizer_usage ;;
        esac
        ;;

      *) desktop_usage ;;
    esac
    ;;

  help|-h|--help) usage ;;
  *) usage ;;
esac
