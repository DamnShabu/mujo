#!/usr/bin/env bash
# Self-check for mujo-quiet.sh's root half: runs `daemon` and `restore` against
# a fake /sys, with openrgb, powerprofilesctl and libinput stubbed out, and
# checks that every fan, LED, USB screen and power profile comes back exactly
# as it was. No root, no hardware.
#
#   bash nixos/services/test-mujo-quiet.sh
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d)
trap 'kill "$dpid" 2>/dev/null; rm -rf "$t"' EXIT
dpid=

fails=0
pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  fails=$((fails + 1))
}
check() { # name expected actual
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (want '$2', got '$3')"; fi
}
eventually() { # name command...: poll up to 10s
  local name=$1 i
  shift
  for ((i = 0; i < 100; i++)); do
    "$@" && {
      pass "$name"
      return
    }
    sleep 0.1
  done
  fail "$name"
}

sys=$t/sys state=$t/state bin=$t/bin
mkdir -p "$sys/class/hwmon" "$sys/bus/usb/devices" "$state" "$bin"

hwmon() { # dir name
  mkdir -p "$sys/class/hwmon/$1"
  echo "$2" >"$sys/class/hwmon/$1/name"
}
w() { printf '%s\n' "$2" >"$sys/class/hwmon/$1"; }
r() { cat "$sys/class/hwmon/$1"; }
fan_mode_is() { [ "$(r hwmon0/pwm1_enable)" = "$1" ]; }

hwmon hwmon0 nct6798 # the board: two fans and a pump header
w hwmon0/pwm1_enable 5
w hwmon0/pwm1 120
w hwmon0/pwm2_enable 5
w hwmon0/pwm2 255
w hwmon0/pwm3_enable 2
w hwmon0/pwm3 90
w hwmon0/temp7_input 127000 # an unconnected AUXTIN, ignored as a sensor
hwmon hwmon1 coretemp
w hwmon1/temp1_input 40000
hwmon hwmon2 amdgpu
w hwmon2/pwm1_enable 2
w hwmon2/pwm1 60
w hwmon2/temp1_input 38000

usb() { # dev vendor product class
  local d=$sys/bus/usb/devices/$1
  mkdir -p "$d"
  echo "$2" >"$d/idVendor"
  echo "$3" >"$d/idProduct"
  echo "$4" >"$d/bDeviceClass"
  echo 1 >"$d/authorized"
}
usb 1-4 1a86 5722 00                                       # a sensor panel
usb 1-5 1a86 5722 09                                       # same id, but a hub
usb 1-6 1a86 5722 00                                       # same id, with touch input
mkdir -p "$sys/bus/usb/devices/1-6/1-6:1.0/0003:1A86:5722.0001/input/input9"
usb 1-7 046d c52b 00                                       # not listed

cat >"$t/quiet.env" <<EOF
FAN_PWM=0
FAN_EXCLUDE="nct6798/pwm2"
HOT=70
COOL=55
USB_DISPLAYS="1a86:5722"
GRACE=0
POLL=1
EOF

# Stubs. Each records what it was asked to do.
cat >"$bin/openrgb" <<EOF
#!$BASH
echo "\$*" >>"$t/openrgb.log"
EOF
cat >"$bin/powerprofilesctl" <<EOF
#!$BASH
case "\$1" in
  get) cat "$t/profile" ;;
  set) echo "\$2" >"$t/profile" ;;
esac
EOF
echo balanced >"$t/profile"
mkfifo "$t/input"
cat >"$bin/libinput" <<EOF
#!$BASH
exec cat "$t/input"
EOF
chmod +x "$bin"/*

export MUJO_QUIET_CONF=$t/quiet.env MUJO_QUIET_SYS=$sys MUJO_QUIET_STATE=$state
export PATH="$bin:$PATH"
# writeShellApplication runs the script under these, so the test does too.
quiet() { bash -euo pipefail "$here/mujo-quiet.sh" "$@"; }

quiet daemon 2>"$t/daemon.log" &
dpid=$!
# Read-write, so opening never blocks on a daemon that died before reading.
exec 3<>"$t/input"

eventually "daemon arms" test -e "$state/armed"
check "fan channel goes manual" 1 "$(r hwmon0/pwm1_enable)"
check "fan channel goes to the floor" 0 "$(r hwmon0/pwm1)"
check "second fan goes manual" 1 "$(r hwmon0/pwm3_enable)"
check "excluded channel (pump) untouched" "5 255" "$(r hwmon0/pwm2_enable) $(r hwmon0/pwm2)"
check "GPU fans untouched" "2 60" "$(r hwmon2/pwm1_enable) $(r hwmon2/pwm1)"
check "RGB snapshot taken, then LEDs off" \
  "save-profile color" \
  "$(grep -o -e '--save-profile' -e '--color 000000' "$t/openrgb.log" | sed 's/^--//; s/ 000000//' | xargs)"
grep -q -- '--client 127.0.0.1:6742' "$t/openrgb.log" && pass "RGB goes through the server" || fail "RGB goes through the server"
check "USB screen de-authorised" 0 "$(cat "$sys/bus/usb/devices/1-4/authorized")"
check "hub with a matching id left alone" 1 "$(cat "$sys/bus/usb/devices/1-5/authorized")"
check "screen with an input interface left alone" 1 "$(cat "$sys/bus/usb/devices/1-6/authorized")"
check "unlisted USB device left alone" 1 "$(cat "$sys/bus/usb/devices/1-7/authorized")"
check "power-saver selected" power-saver "$(cat "$t/profile")"

printf ' event2   DEVICE_ADDED     keyd virtual keyboard   seat0 default group1\n' >&3
printf ' event2   KEYBOARD_KEY     +0.100s	*** (-1) released\n' >&3
sleep 1.5
kill -0 "$dpid" 2>/dev/null && pass "device list and key release do not wake" || fail "device list and key release do not wake"

w hwmon1/temp1_input 82000
eventually "hot CPU hands the fans back to firmware" fan_mode_is 5
check "  with their original duty" 120 "$(r hwmon0/pwm1)"
w hwmon1/temp1_input 60000
sleep 2.5
check "hysteresis: 60°C keeps firmware control" 5 "$(r hwmon0/pwm1_enable)"
w hwmon1/temp1_input 50000
eventually "cool again: fans back down" fan_mode_is 1

printf ' event2   KEYBOARD_KEY     +3.000s	*** (-1) pressed\n' >&3
eventually "a key press wakes the daemon" bash -c "! kill -0 $dpid 2>/dev/null"
wait "$dpid"
check "  and it exits cleanly" 0 "$?"
exec 3>&-

quiet restore 2>>"$t/daemon.log"
check "fans restored (value and mode)" "5 120 5 255 2 90" \
  "$(r hwmon0/pwm1_enable) $(r hwmon0/pwm1) $(r hwmon0/pwm2_enable) $(r hwmon0/pwm2) $(r hwmon0/pwm3_enable) $(r hwmon0/pwm3)"
check "RGB profile loaded back" 1 "$(grep -c -- '--profile mujo-quiet-restore' "$t/openrgb.log")"
check "USB screen re-authorised" 1 "$(cat "$sys/bus/usb/devices/1-4/authorized")"
check "power profile restored" balanced "$(cat "$t/profile")"
check "state cleared" "" "$(ls "$state")"

quiet restore 2>>"$t/daemon.log"
check "restore twice is harmless" "5 120" "$(r hwmon0/pwm1_enable) $(r hwmon0/pwm1)"

# No readable sensor: the fans must not be stopped blind.
for f in "$sys"/class/hwmon/hwmon{1,2}/temp1_input; do echo 0 >"$f"; done
quiet daemon 2>>"$t/daemon.log" &
dpid=$!
exec 3<>"$t/input"
eventually "daemon arms without sensors" test -e "$state/armed"
check "no sensors: fans left alone" "5 120" "$(r hwmon0/pwm1_enable) $(r hwmon0/pwm1)"
exec 3>&- # the watcher dies
eventually "a dead input watcher ends quiet mode" bash -c "! kill -0 $dpid 2>/dev/null"
wait "$dpid"
check "  as a failure" 1 "$?"
quiet restore 2>>"$t/daemon.log"

if ((fails)); then
  echo "--- daemon log"
  cat "$t/daemon.log"
  echo "$fails check(s) failed"
  exit 1
fi
echo "all checks passed"
