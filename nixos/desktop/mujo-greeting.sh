#!/usr/bin/env bash
# mujo-greeting -- the centred greeting popup (nixos/desktop/greeting.nix).
#   mujo-greeting boot                      gate, then open the popup
#   mujo-greeting unlock <away-seconds>     same, after the lock screen goes away
#   mujo-greeting stream <trigger> <away>   NDJSON the popup renders: {head,screen} {t}... {done,text}
#   mujo-greeting gate|facts|headline ...   the pieces, for test-mujo-greeting.sh
set -euo pipefail

state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/mujo-greeting
state=$state_dir/state.json
url=${OLLAMA_URL:-http://127.0.0.1:11434}
model=${MUJO_GREETING_MODEL:-qwen3:4b-instruct}
name=${MUJO_GREETING_NAME:-${USER:-there}}
factors=${MUJO_GREETING_FACTORS:-failed-units return time disk rebuild-age streak}
min_away=${MUJO_GREETING_MIN_AWAY:-900}
now=${MUJO_GREETING_NOW:-$(date +%s)}

mkdir -p "$state_dir"
st=$(jq -c 'if type == "object" then . else {} end' "$state" 2>/dev/null || echo '{}')

field() { jq -r --arg k "$1" '.[$k] // empty' <<<"$st"; }

last=$(field last)
last=${last:-0}
today=$(date -d "@$now" +%F)
hour=$(date -d "@$now" +%-H)
count_today=0
if [[ $(field day) == "$today" ]]; then count_today=$(field count); fi

duration() {
  local s=$1
  if ((s < 90)); then
    echo "a minute"
  elif ((s < 5400)); then
    echo "$(((s + 30) / 60)) minutes"
  elif ((s < 129600)); then
    echo "$(((s + 1800) / 3600)) hours"
  else
    echo "$(((s + 43200) / 86400)) days"
  fi
}

part_of_day() {
  if ((hour >= 5 && hour < 12)); then
    echo morning
  elif ((hour >= 12 && hour < 17)); then
    echo afternoon
  elif ((hour >= 17)); then
    echo evening
  else
    echo night
  fi
}

headline() {
  if [[ $1 == unlock ]] && ((count_today > 0)); then
    echo "Welcome back, $name"
    return
  fi
  case $(part_of_day) in
    morning) echo "Good morning, $name" ;;
    afternoon) echo "Good afternoon, $name" ;;
    evening) echo "Good evening, $name" ;;
    *) echo "Still up, $name?" ;;
  esac
}

# One factor -> one line, or nothing when it is not worth mentioning right now.
fact() {
  local trigger=$1 away=$2 kind pct built days units
  case $3 in
    return)
      if [[ $trigger == unlock ]]; then
        echo "Back at the desk after $(duration "$away") away"
      elif ((last > 0)); then
        echo "Just started the computer; the previous greeting was $(duration $((now - last))) ago"
      else
        echo "Just started the computer"
      fi
      ;;
    time)
      kind=weekday
      if (($(date -d "@$now" +%u) >= 6)); then kind=weekend; fi
      echo "It is $(date -d "@$now" +%A) $(part_of_day), $(date -d "@$now" +%H:%M), a $kind"
      ;;
    failed-units)
      units=$({
        systemctl list-units --failed -o json 2>/dev/null || echo '[]'
        systemctl --user list-units --failed -o json 2>/dev/null || echo '[]'
      } | jq -rs 'add | map(.unit) | unique | .[:3] | join(", ")' 2>/dev/null || true)
      if [[ -n $units ]]; then echo "PROBLEM: failed background services: $units"; fi
      ;;
    disk)
      pct=$(df --output=pcent /persist 2>/dev/null | tail -n 1 | tr -dc 0-9 || true)
      if ((${pct:-0} >= 85)); then echo "PROBLEM: persistent storage is ${pct}% full"; fi
      ;;
    rebuild-age)
      built=$(stat -c %Y /nix/var/nix/profiles/system 2>/dev/null || echo "$now")
      days=$(((now - built) / 86400))
      if ((days >= 14)); then echo "PROBLEM: the system has not been rebuilt for $days days"; fi
      ;;
    streak)
      if ((count_today == 0)); then
        echo "First time at the computer today"
      elif ((count_today >= 3)); then
        echo "Greeting number $((count_today + 1)) today"
      fi
      ;;
  esac
}

facts() {
  local list f line i=1
  read -ra list <<<"$factors"
  for f in "${list[@]}"; do
    line=$(fact "$1" "$2" "$f")
    if [[ -n $line ]]; then
      echo "$i. $line"
      i=$((i + 1))
    fi
  done
}

gate() {
  case $1 in
    boot) ((now - last >= 120)) ;;
    unlock) ((${2:-0} >= min_away)) ;;
    *) return 1 ;;
  esac
}

pick_style() {
  local styles=(warm witty wise playful calm nudge) prev pick
  prev=$(field style)
  while :; do
    pick=${styles[RANDOM % ${#styles[@]}]}
    if [[ $pick != "$prev" ]]; then break; fi
  done
  echo "$pick"
}

fallback() {
  case $(part_of_day) in
    morning) echo "Fresh start. Pick one thing worth finishing today." ;;
    afternoon) echo "Plenty of the day left for something good." ;;
    evening) echo "Evening mode: wrap things up, or dive into something fun." ;;
    *) echo "The quiet hours. Just remember that sleep is also a feature." ;;
  esac
}

record() {
  local out
  out=$(mktemp "$state_dir/.state.XXXXXX")
  jq --argjson now "$now" --arg day "$today" --arg style "$1" '
    .count = (if .day == $day then (.count // 0) + 1 else 1 end)
    | .day = $day | .last = $now | .style = $style' <<<"$st" >"$out"
  mv "$out" "$state"
}

tmp=""
trap 'rm -f "$tmp"' EXIT

stream() {
  local trigger=$1 away=$2 screen="" style system prompt body text
  if command -v niri >/dev/null; then
    screen=$(niri msg --json focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null || true)
  fi
  # The headline goes out before the model is asked anything: the popup is on
  # screen at once, and the model's line streams in underneath it.
  jq -nc --arg head "$(headline "$trigger")" --arg screen "$screen" '{head: $head, screen: $screen}'

  style=$(pick_style)
  local tone context problem
  context=$(facts "$trigger" "$away")
  if grep -q "PROBLEM:" <<<"$context"; then
    problem="The line marked PROBLEM is the point of your sentence: mention it plainly and kindly."
  else
    problem="Nothing needs fixing right now, so say nothing about services, storage, updates or maintenance."
  fi
  case $style in
    warm) tone="warm, like a friend who is genuinely glad they are back" ;;
    witty) tone="witty, with one light, clever twist" ;;
    wise) tone="a short original aphorism that fits the moment, worth keeping on a sticky note" ;;
    playful) tone="playful and a little cheeky" ;;
    calm) tone="calm and grounding, unhurried" ;;
    *) tone="a gentle nudge toward one good thing to do next" ;;
  esac
  # No example lines: a 4B model copies them nearly verbatim.
  system="You are the voice of a personal computer, speaking to its owner the moment they sit down. A headline above you already says hello; you write the single line under it.

Write one sentence of 6 to 16 words. Tone: $tone.

The context is ranked by importance. $problem Everything else is only mood: let it colour the line, never recite it. No numbers, clock times, dates or durations.

Sound like a person, not a notification, and fit this exact moment rather than any day. Avoid stock phrases such as: is yours, awaits, fresh start, new day, dive in, make it count, offline, let's get.
Do not greet and do not use a name. No emojis, hashtags or quotation marks. Never claim anything the context does not say. Output only the line."
  prompt="Context, most important first:"$'\n'"$context"
  body=$(jq -nc --arg model "$model" --arg system "$system" --arg prompt "$prompt" \
    '{model: $model, system: $system, prompt: $prompt, stream: true,
      options: {temperature: 0.85, num_predict: 40, stop: ["\n"]}}')

  tmp=$(mktemp)
  { curl -sN --connect-timeout 1 --max-time 12 "$url/api/generate" -d "$body" 2>/dev/null || true; } |
    { jq --unbuffered -c 'select((.response // "") != "") | {t: .response}' 2>/dev/null || true; } |
    tee "$tmp"
  text=$(jq -rjs 'map(.t) | add // "" | gsub("\\s+"; " ") | gsub("^[\\s\"“”]+|[\\s\"“”]+$"; "")' "$tmp")
  if [[ -z $text ]]; then
    text=$(fallback)
    style=fallback
    jq -nc --arg t "$text" '{t: $t}'
  fi
  record "$style"
  jq -nc --arg text "$text" '{done: true, text: $text}'
}

case ${1:-} in
  boot | unlock)
    gate "$1" "${2:-0}" || exit 0
    MUJO_GREETING_BIN=$(readlink -f "$0")
    export MUJO_GREETING_BIN MUJO_GREETING_TRIGGER="$1" MUJO_GREETING_AWAY="${2:-0}"
    # -n: a second trigger while the popup is up is dropped, not queued.
    exec flock -n "$state_dir/popup.lock" quickshell -p "${MUJO_GREETING_QML:?}"
    ;;
  stream) stream "${2:-boot}" "${3:-0}" ;;
  gate) gate "${2:-}" "${3:-0}" ;;
  facts) facts "${2:-boot}" "${3:-0}" ;;
  headline) headline "${2:-boot}" ;;
  *)
    echo "usage: mujo-greeting boot | unlock <away-seconds> | stream <trigger> <away>" >&2
    exit 2
    ;;
esac
