# shellcheck shell=bash
# mujo-quiet: the machine keeps running with every display dark, every RGB
# LED off and the fans at their floor, and the first key press or mouse
# movement brings all of it back.
#
# Two halves, one script:
#
#   user  (on | off | toggle | status)
#         `on` starts the `mujo-quiet-session` user unit, which starts the
#         system unit, waits until it is armed, then switches the displays
#         off through niri. When the system unit stops it switches them back
#         on. Displays are the session's to change, so they live here.
#   root  (daemon | restore)
#         `daemon` is mujo-quiet.service: it saves fan, RGB, USB and power
#         profile state, quiets all of it, then watches libinput for input
#         and hwmon for heat. Input makes it exit; ExecStopPost runs
#         `restore`, so a crash or a `systemctl stop` restores too.
#
# Fans are watched, not just stopped: above HOT degrees on any sensor in
# SENSOR_CHIPS they go back to firmware control, and come down again once
# everything is under COOL. With no readable sensor they are never touched.
#
# Settings come from /etc/mujo/quiet.env (nixos/services/quiet.nix). The
# MUJO_QUIET_* paths exist for test-mujo-quiet.sh, which runs all of this
# against a fake /sys.

CONF=${MUJO_QUIET_CONF:-/etc/mujo/quiet.env}
SYS=${MUJO_QUIET_SYS:-/sys}
STATE=${MUJO_QUIET_STATE:-/run/mujo-quiet}
UNIT=mujo-quiet.service
SESSION_UNIT=mujo-quiet-session.service

FANS=1
FAN_PWM=0
FAN_EXCLUDE_CHIPS="amdgpu"
FAN_EXCLUDE=""
SENSOR_CHIPS="coretemp amdgpu nvme"
HOT=70
COOL=55
RGB=1
RGB_PORT=6742
USB_DISPLAYS=""
NIRI_OUTPUTS=""
POWER_SAVER=1
GRACE=1
POLL=3
# shellcheck disable=SC1090
[ -r "$CONF" ] && . "$CONF"

log() { printf 'mujo-quiet: %s\n' "$*" >&2; }

in_list() {
  local needle=$1 x
  shift
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

# Write a sysfs attribute; a refusal is logged, never fatal, so one stubborn
# channel cannot stop the rest from being restored.
put() {
  { printf '%s\n' "$2" >"$1"; } 2>/dev/null || log "cannot write $2 to $1"
}

hwmon_name() { cat "$1/name" 2>/dev/null || true; }

# --- fans --------------------------------------------------------------------

# One "<hwmon dir> <pwmN>" line per channel this mode may drive.
fan_channels() {
  local d name en ch
  for d in "$SYS"/class/hwmon/hwmon*; do
    name=$(hwmon_name "$d")
    [ -n "$name" ] || continue
    # shellcheck disable=SC2086
    in_list "$name" $FAN_EXCLUDE_CHIPS && continue
    for en in "$d"/pwm[0-9]*_enable; do
      [ -e "$en" ] || continue
      ch=${en##*/}
      ch=${ch%_enable}
      [ -e "$d/$ch" ] || continue
      # shellcheck disable=SC2086
      in_list "$name/$ch" $FAN_EXCLUDE && continue
      printf '%s %s\n' "$d" "$ch"
    done
  done
}

# Hottest reading, in whole degrees, across SENSOR_CHIPS; -1 when none reads.
# 0 and >=125 are what unconnected Super I/O inputs report, not temperatures.
max_temp() {
  local max=-1 d name t v
  for d in "$SYS"/class/hwmon/hwmon*; do
    name=$(hwmon_name "$d")
    # shellcheck disable=SC2086
    in_list "$name" $SENSOR_CHIPS || continue
    for t in "$d"/temp[0-9]*_input; do
      v=$(cat "$t" 2>/dev/null) || continue
      [[ $v =~ ^-?[0-9]+$ ]] || continue
      v=$((v / 1000))
      ((v > 0 && v < 125)) || continue
      ((v > max)) && max=$v
    done
  done
  printf '%s\n' "$max"
}

# Saved once per quiet period, so the hot/cool cycle never records its own
# quiet values as the ones to go back to.
fans_save() {
  local d ch en pwm
  [ -e "$STATE/fans" ] && return 0
  : >"$STATE/fans.tmp"
  while read -r d ch; do
    en=$(cat "$d/${ch}_enable" 2>/dev/null) || continue
    pwm=$(cat "$d/$ch" 2>/dev/null) || continue
    printf '%s %s %s %s\n' "$d" "$ch" "$en" "$pwm" >>"$STATE/fans.tmp"
  done < <(fan_channels)
  mv "$STATE/fans.tmp" "$STATE/fans"
}

fans_down() {
  local d ch en pwm
  [ -s "$STATE/fans" ] || return 0
  while read -r d ch en pwm; do
    put "$d/${ch}_enable" 1
    put "$d/$ch" "$FAN_PWM"
  done <"$STATE/fans"
  echo quiet >"$STATE/fan-state"
}

fans_restore() {
  local d ch en pwm
  [ -s "$STATE/fans" ] || return 0
  while read -r d ch en pwm; do
    # Value first, mode last: a mode of 2+ hands the channel back to the
    # chip's own curve, and that should be the final word.
    put "$d/$ch" "$pwm"
    put "$d/${ch}_enable" "$en"
  done <"$STATE/fans"
}

# --- RGB ---------------------------------------------------------------------

# Always through the openrgb server, never a second detection run: two
# processes driving the same SMBus at once is how RGB controllers get bricked.
# Bounded, because a client with no server to reach keeps retrying.
orgb() {
  timeout 20 openrgb --config "$STATE/openrgb" --noautoconnect --nodetect \
    --client "127.0.0.1:$RGB_PORT" "$@" >/dev/null 2>&1
}

rgb_off() {
  [ "$RGB" = 1 ] || return 0
  mkdir -p "$STATE/openrgb"
  orgb --save-profile mujo-quiet-restore || log "could not snapshot RGB state"
  orgb --color 000000 || {
    log "openrgb did not turn the LEDs off"
    return 0
  }
  : >"$STATE/rgb"
}

rgb_restore() {
  [ -e "$STATE/rgb" ] || return 0
  orgb --profile mujo-quiet-restore || log "could not restore the RGB profile"
}

# --- USB displays ------------------------------------------------------------

# Displays niri does not drive (a USB sensor panel, an AIO's screen) are
# switched off by de-authorising the device. Never a hub and never anything
# with an input interface: that could be the keyboard meant to wake this up.
usb_off() {
  local id dev vp
  [ -n "$USB_DISPLAYS" ] || return 0
  : >"$STATE/usb"
  for dev in "$SYS"/bus/usb/devices/*; do
    [ -r "$dev/idVendor" ] && [ -r "$dev/idProduct" ] || continue
    vp="$(cat "$dev/idVendor"):$(cat "$dev/idProduct")"
    for id in $USB_DISPLAYS; do
      [ "$id" = "$vp" ] || continue
      if [ "$(cat "$dev/bDeviceClass" 2>/dev/null)" = 09 ]; then
        log "$vp at ${dev##*/} is a hub; leaving it on"
      elif [ -n "$(find "$dev/" -maxdepth 5 -type d -path '*/input/input*' -print -quit 2>/dev/null)" ]; then
        log "$vp at ${dev##*/} has an input interface; leaving it on"
      else
        put "$dev/authorized" 0
        printf '%s\n' "$dev" >>"$STATE/usb"
      fi
    done
  done
}

usb_restore() {
  local dev
  [ -s "$STATE/usb" ] || return 0
  while read -r dev; do put "$dev/authorized" 1; done <"$STATE/usb"
}

# --- power profile -----------------------------------------------------------

profile_down() {
  local p
  [ "$POWER_SAVER" = 1 ] || return 0
  p=$(powerprofilesctl get 2>/dev/null) || {
    log "power-profiles-daemon is not answering"
    return 0
  }
  printf '%s\n' "$p" >"$STATE/profile"
  powerprofilesctl set power-saver 2>/dev/null || log "could not select power-saver"
}

profile_restore() {
  [ -s "$STATE/profile" ] || return 0
  powerprofilesctl set "$(cat "$STATE/profile")" 2>/dev/null || log "could not restore the power profile"
}

# --- root side ---------------------------------------------------------------

# A key counts on press only: the keys of the bind that started quiet mode
# are still coming up when it arms.
WAKE_RE='KEYBOARD_KEY.*pressed|POINTER_MOTION|POINTER_BUTTON.*pressed|POINTER_SCROLL|POINTER_AXIS|TOUCH_DOWN|TABLET_TOOL_TIP|GESTURE_.*_BEGIN'

thermal() {
  local t
  t=$(max_temp)
  if [ "$(cat "$STATE/fan-state" 2>/dev/null)" = quiet ]; then
    if ((t < 0 || t >= HOT)); then
      log "hottest sensor at ${t}°C; fans back to firmware control"
      fans_restore
      echo hot >"$STATE/fan-state"
    fi
  elif [ "$(cat "$STATE/fan-state" 2>/dev/null)" = hot ] && ((t >= 0 && t <= COOL)); then
    log "cooled to ${t}°C; fans down again"
    fans_down
  fi
}

cmd_daemon() {
  local line wake next=0
  mkdir -p "$STATE"
  rm -f "$STATE/armed"

  if [ "$FANS" = 1 ]; then
    fans_save
    if (($(max_temp) < 0)); then
      log "no readable temperature in: $SENSOR_CHIPS; leaving the fans alone"
    elif [ -s "$STATE/fans" ]; then
      fans_down
    else
      log "no controllable fan channel (is the Super I/O driver loaded?)"
    fi
  fi
  rgb_off
  usb_off
  profile_down

  sleep "$GRACE"
  coproc WAKE { exec stdbuf -oL libinput debug-events 2>/dev/null; }
  # bash closes and unsets WAKE when the watcher exits; a copy of the fd
  # outlives it, so that ends as EOF below instead of an unbound variable.
  if [ -z "${WAKE[0]-}" ]; then
    log "input watcher did not start; leaving quiet mode"
    return 1
  fi
  exec {wake}<&"${WAKE[0]}"
  : >"$STATE/armed"
  log "armed"

  while :; do
    if ((SECONDS >= next)); then
      thermal
      next=$((SECONDS + POLL))
    fi
    if read -r -t "$POLL" line <&"$wake"; then
      if [[ $line =~ $WAKE_RE ]]; then
        log "woken by input"
        return 0
      fi
    elif (($? <= 128)); then
      # The watcher is gone, so nothing could wake the machine: give up
      # quiet mode rather than leave it dark.
      log "input watcher exited; leaving quiet mode"
      return 1
    fi
  done
}

cmd_restore() {
  fans_restore
  rgb_restore
  usb_restore
  profile_restore
  rm -rf "${STATE:?}/fans" "$STATE/fan-state" "$STATE/rgb" "$STATE/openrgb" \
    "$STATE/usb" "$STATE/profile" "$STATE/armed"
}

# --- user side ---------------------------------------------------------------

niri_outputs() {
  local o
  for o in $NIRI_OUTPUTS; do niri msg output "$o" "$1" || log "niri refused output $o $1"; done
}

cmd_session() {
  local pid i
  systemctl start --wait "$UNIT" &
  pid=$!
  # Darken only once the watcher is listening, so no input can slip between
  # the two and leave the displays dark with nothing left to wake them.
  for ((i = 0; i < 300; i++)); do
    [ -e "$STATE/armed" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  if [ -e "$STATE/armed" ]; then
    niri_outputs off
    niri msg action power-off-monitors
  fi
  wait "$pid" || true
  niri_outputs on
  niri msg action power-on-monitors
}

cmd_on() {
  local env=()
  if systemctl --user is-active -q "$SESSION_UNIT"; then
    echo "quiet mode is already on"
    return 0
  fi
  [ -n "${NIRI_SOCKET:-}" ] && env+=(--setenv=NIRI_SOCKET="$NIRI_SOCKET")
  [ -n "${WAYLAND_DISPLAY:-}" ] && env+=(--setenv=WAYLAND_DISPLAY="$WAYLAND_DISPLAY")
  systemd-run --user --quiet --collect --unit="${SESSION_UNIT%.service}" \
    "${env[@]}" -- "$0" _session
}

cmd_off() {
  systemctl stop "$UNIT"
  # The session unit turns the displays back on when the system unit stops;
  # this is for when it is not there to do it.
  systemctl --user is-active -q "$SESSION_UNIT" || niri msg action power-on-monitors
}

cmd_status() {
  if systemctl is-active -q "$UNIT"; then
    echo "on"
    [ -e "$STATE/fan-state" ] && echo "fans: $(cat "$STATE/fan-state")"
    echo "hottest sensor: $(max_temp)°C"
  else
    echo "off"
  fi
}

usage() {
  echo "usage: mujo-quiet on | off | toggle | status" >&2
  exit 2
}

case "${1:-}" in
  on) cmd_on ;;
  off) cmd_off ;;
  toggle) if systemctl is-active -q "$UNIT"; then cmd_off; else cmd_on; fi ;;
  status) cmd_status ;;
  _session) cmd_session ;;
  daemon) cmd_daemon ;;
  restore) cmd_restore ;;
  *) usage ;;
esac
