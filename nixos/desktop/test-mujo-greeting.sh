#!/usr/bin/env bash
# Self-check for mujo-greeting.sh: gating, headlines, fact ranking, state, and
# the fallback line when Ollama is unreachable. Offline; needs jq and curl.
#   bash nixos/desktop/test-mujo-greeting.sh
set -uo pipefail

script=$(dirname "$0")/mujo-greeting.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail=0

g() {
  XDG_STATE_HOME=$dir OLLAMA_URL=http://127.0.0.1:9 MUJO_GREETING_NAME=Test \
    MUJO_GREETING_MIN_AWAY=900 MUJO_GREETING_NOW=${NOW:-1790000000} PATH=$PATH \
    bash "$script" "$@"
}
check() {
  if [[ $2 == "$3" ]]; then echo "PASS $1"; else
    echo "FAIL $1: got '$2', want '$3'"
    fail=1
  fi
}
ok() { if g "$@" >/dev/null; then echo yes; else echo no; fi; }

# 1790000000 is a Monday, 14:13 UTC.
export TZ=UTC

check "boot greets with no state" "$(ok gate boot)" yes
check "short unlock stays quiet" "$(ok gate unlock 60)" no
check "long unlock greets" "$(ok gate unlock 1800)" yes
check "first headline is time-based" "$(g headline unlock)" "Good afternoon, Test"
check "late-night headline" "$(NOW=1789956000 g headline boot)" "Still up, Test?"

out=$(g stream boot 0)
check "stream sends the headline first" "$(head -n1 <<<"$out" | jq -r .head)" "Good afternoon, Test"
check "stream ends with done" "$(tail -n1 <<<"$out" | jq -r .done)" true
check "every line is JSON" "$(jq -e . <<<"$out" >/dev/null && echo yes)" yes
check "fallback line when Ollama is down" "$(tail -n1 <<<"$out" | jq -r .text)" "Plenty of the day left for something good."
check "state records the greeting" "$(jq -r '.count, .last, .style' "$dir/mujo-greeting/state.json" | paste -sd' ')" "1 1790000000 fallback"

check "boot right after a greeting stays quiet" "$(NOW=1790000060 ok gate boot)" no
check "second greeting of the day welcomes back" "$(NOW=1790003600 g headline unlock)" "Welcome back, Test"

facts=$(NOW=1790003600 MUJO_GREETING_FACTORS="streak return time" g facts unlock 3600)
check "facts follow the importance order" "$(cut -c1-30 <<<"$facts" | paste -sd'|')" \
  "1. Back at the desk after 60 m|2. It is Monday afternoon, 15:"
check "unnotable facts are left out" "$(grep -c . <<<"$facts")" 2

for _ in 1 2 3 4; do NOW=1790007200 g stream unlock 3600 >/dev/null; done
check "streak shows from the fourth greeting" \
  "$(NOW=1790007200 MUJO_GREETING_FACTORS=streak g facts boot 0)" "1. Greeting number 6 today"

echo '{broken' >"$dir/mujo-greeting/state.json"
check "corrupt state is treated as empty" "$(ok gate boot)" yes

exit $fail
