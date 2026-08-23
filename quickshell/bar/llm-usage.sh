#!/usr/bin/env bash
# Detects locally-installed AI coding assistants and reports each as a
# provider entry for LlmTrackerMenu.qml. Output is a single JSON object:
#
#   { "providers": [ { id, name, icon, plan, email, limits[],
#                      tokensByDay[], tokensByModel[] }, ... ],
#     "default": "<provider id>" }
#
# Only providers actually present on disk are emitted.
#
#   limits[]        {label, percent, resetsAt, severity} rate-limit gauges,
#                   fetched live from the provider's usage API (currently only
#                   Claude — the same session/weekly meters shown on
#                   claude.ai/usage). Empty when offline or unsupported.
#   tokensByDay[]   {label, tokens} — one bucket per day of the last week
#                   ("Today" last), summed from the local session transcripts.
#   tokensByModel[] {name, tokens} — per-model totals from the same transcripts.
#
# `default` is the id of the provider the user selected as active in the widget
# (persisted at ~/.config/qsshell/llm-default.json); defaults to the first
# detected provider.
set -euo pipefail

HOME_DIR="${HOME}"
DEFAULT_FILE="${HOME_DIR}/.config/qsshell/llm-default.json"

# Decode a JWT payload (2nd dot-separated segment) to JSON on stdout, or
# nothing on failure. base64url -> base64 (+ padding) so `base64 -d` accepts it.
decode_jwt_payload() {
  local jwt="$1" payload
  payload="${jwt#*.}"
  payload="${payload%%.*}"
  [[ -n "${payload}" && "${payload}" != "${jwt}" ]] || return 0
  payload="${payload//-/+}"
  payload="${payload//_//}"
  case $((${#payload} % 4)) in
    2) payload="${payload}==" ;;
    3) payload="${payload}=" ;;
  esac
  printf '%s' "${payload}" | base64 -d 2>/dev/null || true
}

# ---- Claude Code -----------------------------------------------------------
# Limits come from the live OAuth usage endpoint (the canonical source that
# claude.ai/usage renders); the old ~/.claude.json cachedUsageUtilization field
# was removed upstream, which is why the widget used to sit at 0%. Per-day and
# per-model token totals are summed from the JSONL session transcripts under
# ~/.claude/projects.

# Fetch {label,percent,resetsAt,severity} gauges from the usage API.
#
# The endpoint rate-limits aggressively (HTTP 429), so the result is cached at
# ~/.cache/qsshell/llm-limits.json and only refreshed when the cache is older
# than LIMITS_TTL. On any failure (429, offline, expired token) the last good
# cached value is served rather than blanking the gauges.
LIMITS_TTL=180
claude_limits() {
  local cache="${HOME_DIR}/.cache/qsshell/llm-limits.json"
  mkdir -p "$(dirname "${cache}")"

  local cached='[]' cached_ts=0 now
  if [[ -f "${cache}" ]]; then
    cached="$(jq -c '.data // []' "${cache}" 2>/dev/null || echo '[]')"
    cached_ts="$(jq -r '.ts // 0' "${cache}" 2>/dev/null || echo 0)"
  fi
  now="$(date +%s)"

  # Serve a fresh cache without touching the network.
  if [[ $((now - cached_ts)) -lt ${LIMITS_TTL} && "${cached}" != "[]" ]]; then
    echo "${cached}"; return 0
  fi

  local creds="${HOME_DIR}/.claude/.credentials.json" tok
  [[ -f "${creds}" ]] || { echo "${cached}"; return 0; }
  tok="$(jq -r '.claudeAiOauth.accessToken // empty' "${creds}" 2>/dev/null || true)"
  [[ -n "${tok}" ]] || { echo "${cached}"; return 0; }

  local resp code body
  resp="$(curl -s -m 8 -w '\n%{http_code}' https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer ${tok}" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "anthropic-version: 2023-06-01" 2>/dev/null || true)"
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"

  # On anything but a clean 200, keep serving the previous good value.
  [[ "${code}" == "200" && -n "${body}" ]] || { echo "${cached}"; return 0; }

  local parsed
  parsed="$(jq -c '
    def lbl(k):
      { session: "Session", weekly_all: "Weekly",
        weekly_opus: "Opus Weekly", weekly_sonnet: "Sonnet Weekly" }[k]
      // (k | gsub("_"; " ") | split(" ") | map(ascii_upcase[0:1] + .[1:]) | join(" "));
    ((.limits // []) | map({
        label: lbl(.kind),
        percent: ((.percent // 0) | floor),
        resetsAt: .resets_at,
        severity: (.severity // "normal")
      }))
    // []' <<<"${body}" 2>/dev/null || echo "")"
  [[ -n "${parsed}" && "${parsed}" != "null" ]] || { echo "${cached}"; return 0; }

  jq -cn --argjson data "${parsed}" --argjson ts "${now}" '{ts:$ts, data:$data}' \
    > "${cache}.tmp" 2>/dev/null && mv "${cache}.tmp" "${cache}" 2>/dev/null || true
  echo "${parsed}"
}

# Sum transcript tokens into per-day (last 7 days) and per-model buckets.
claude_tokens() {
  local dir="${HOME_DIR}/.claude/projects" midnight days start label i
  if [[ ! -d "${dir}" ]]; then echo '{"tokensByDay":[],"tokensByModel":[]}'; return 0; fi

  midnight="$(date -d 'today 00:00:00' +%s)"
  days='[]'
  for i in 6 5 4 3 2 1 0; do
    start=$((midnight - i * 86400))
    if [[ "${i}" -eq 0 ]]; then label="Today"; else label="$(date -d "@${start}" +%a)"; fi
    days="$(jq -c --argjson s "${start}" --arg l "${label}" \
      '. + [{start:$s, end:($s+86400), label:$l}]' <<<"${days}")"
  done

  # Only touch files modified within the window; slurp lines through one jq.
  find "${dir}" -name '*.jsonl' -mtime -8 -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null \
    | jq -c -n --argjson days "${days}" '
        def tok(u): (u.input_tokens//0)+(u.output_tokens//0)
                    +(u.cache_creation_input_tokens//0)+(u.cache_read_input_tokens//0);
        # claude-opus-4-8 -> "Opus 4.8"; drop trailing -YYYYMMDD date stamps.
        def pretty(m):
          (m | ltrimstr("claude-") | gsub("-[0-9]{8}$"; "")) as $s
          | ($s | split("-")) as $p
          | ((($p[0] // "") | ascii_upcase[0:1]) + ($p[0][1:] // ""))
            + (if ($p | length) > 1 then " " + ($p[1:] | join(".")) else "" end);
        (reduce (inputs?
            | select((.message.usage != null) and (.message.model != null)
                     and (.message.model != "<synthetic>"))) as $e
          ({day:{}, model:{}};
            (try (($e.timestamp | sub("\\.[0-9]+"; "") | sub("[+][0-9]{2}:[0-9]{2}$"; "Z"))
                  | fromdateiso8601) catch null) as $ts
            | tok($e.message.usage) as $t
            | .model[pretty($e.message.model)] += $t
            | if $ts == null then .
              else reduce range(0; $days|length) as $i (.;
                     if ($ts >= $days[$i].start and $ts < $days[$i].end)
                     then .day[$days[$i].label] += $t else . end)
              end)
        ) as $acc
        | { tokensByDay: [ $days[] | {label:.label, tokens: (($acc.day[.label]) // 0)} ],
            tokensByModel: [ $acc.model | to_entries | sort_by(-.value)[]
                             | {name:.key, tokens:.value} ] }
      ' 2>/dev/null || echo '{"tokensByDay":[],"tokensByModel":[]}'
}

# ~/.claude.json: oauthAccount carries the email and plan tier.
claude_provider() {
  local f="${HOME_DIR}/.claude.json" creds="${HOME_DIR}/.claude/.credentials.json"
  [[ -f "${f}" || -f "${creds}" ]] || return 0

  local account='{}' sub=""
  [[ -f "${f}" ]] && account="$(jq -c '.oauthAccount // {}' "${f}" 2>/dev/null || echo '{}')"
  [[ -f "${creds}" ]] && sub="$(jq -r '.claudeAiOauth.subscriptionType // empty' "${creds}" 2>/dev/null || true)"

  local limits tokens
  limits="$(claude_limits)"
  tokens="$(claude_tokens)"

  jq -n --argjson account "${account}" --arg sub "${sub}" \
        --argjson limits "${limits}" --argjson tokens "${tokens}" '
    ($account.organizationType // "") as $org |
    (if $sub != "" then ($sub | ascii_upcase | gsub("_"; " "))
     else ({
       claude_pro: "PRO", claude_free: "FREE",
       claude_max_5x: "MAX 5X", claude_max_20x: "MAX 20X",
       claude_team: "TEAM", claude_enterprise: "ENTERPRISE"
     }[$org] // (if $org == "" then "" else ($org | ascii_upcase | gsub("_"; " ")) end))
     end) as $plan |
    {
      id: "claude", name: "Claude Code", icon: "auto_awesome",
      email: ($account.emailAddress // ""),
      plan: $plan,
      limits: $limits,
      tokensByDay: ($tokens.tokensByDay // []),
      tokensByModel: ($tokens.tokensByModel // [])
    }'
}

# ---- OpenAI Codex ----------------------------------------------------------
# ~/.codex/auth.json: JWT id_token carries the account email and ChatGPT plan.
codex_provider() {
  local f="${HOME_DIR}/.codex/auth.json"
  [[ -f "${f}" ]] || return 0
  local idtok claims='{}'
  idtok="$(jq -r '.tokens.id_token // .id_token // empty' "${f}" 2>/dev/null || true)"
  [[ -n "${idtok}" ]] && claims="$(decode_jwt_payload "${idtok}")"
  [[ -n "${claims}" ]] || claims='{}'
  jq -n --argjson c "${claims}" '
    ($c["https://api.openai.com/auth"].chatgpt_plan_type // "") as $plan |
    {
      id: "codex", name: "Codex", icon: "terminal",
      email: ($c.email // ""),
      plan: (if $plan == "" then "" else ($plan | ascii_upcase) end),
      limits: [], tokensByDay: [], tokensByModel: []
    }'
}

# ---- Google Antigravity ----------------------------------------------------
# Token totals are derived from two data sources inside
# ~/.gemini/antigravity:
#   1. conversations/*.db  — SQLite databases whose `gen_metadata` table holds
#      protobuf blobs.  Field 19 of each blob is the model name string
#      (e.g. "gemini-3.7-flash-control", "claude-opus-4-6-thinking").  We hex-
#      dump the blobs and decode the ASCII model names from the hex stream.
#   2. brain/<id>/.system_generated/logs/transcript.jsonl — one JSON object per
#      step.  MODEL-sourced steps carry `created_at` timestamps and `content`
#      whose character length is a reasonable proxy for output tokens (÷ 4).
#
# Because the conversation DBs don't expose token counts as plain integers
# (they're packed inside protobuf), we estimate output tokens from transcript
# content length and count each model generation (PLANNER_RESPONSE) as one
# unit for the per-model breakdown.

antigravity_tokens() {
  local base="${HOME_DIR}/.gemini/antigravity"
  local convos="${base}/conversations" brains="${base}/brain"
  if [[ ! -d "${convos}" || ! -d "${brains}" ]]; then
    echo '{"tokensByDay":[],"tokensByModel":[]}'
    return 0
  fi

  # Build the same 7-day window as claude_tokens().
  local midnight days start label i
  midnight="$(date -d 'today 00:00:00' +%s)"
  days='[]'
  for i in 6 5 4 3 2 1 0; do
    start=$((midnight - i * 86400))
    if [[ "${i}" -eq 0 ]]; then label="Today"; else label="$(date -d "@${start}" +%a)"; fi
    days="$(jq -c --argjson s "${start}" --arg l "${label}" \
      '. + [{start:$s, end:($s+86400), label:$l}]' <<<"${days}")"
  done

  # Collect {model, ts, len} tuples from every conversation, emitted as NDJSON
  # into a temp file to avoid O(n²) array-append in a loop.
  local ndjson_file
  ndjson_file="$(mktemp)"

  local db cid transcript models_file entries_file
  for db in "${convos}"/*.db; do
    [[ -f "${db}" ]] || continue
    cid="$(basename "${db}" .db)"
    transcript="${brains}/${cid}/.system_generated/logs/transcript.jsonl"
    [[ -f "${transcript}" ]] || continue

    # Skip conversations not modified in the last 8 days.
    if [[ "$(find "${db}" -mtime -8 2>/dev/null)" == "" && \
          "$(find "${transcript}" -mtime -8 2>/dev/null)" == "" ]]; then
      continue
    fi

    # a) Extract model names (one per gen_metadata row, ordered by idx).
    #    hex(data) outputs pure hex; we decode model-name byte sequences.
    models_file="$(mktemp)"
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 "${db}" "SELECT hex(data) FROM gen_metadata ORDER BY idx" 2>/dev/null \
        | while IFS= read -r hexline; do
            echo "${hexline}" \
              | sed 's/../\\x&/g' \
              | xargs -0 printf '%b' 2>/dev/null \
              | grep -oaP '(?:gemini|claude|gpt)-[a-z0-9._-]+' \
              | head -1 || echo ""
          done > "${models_file}" 2>/dev/null
    fi

    # b) Extract MODEL-sourced transcript entries (ts + content length).
    entries_file="$(mktemp)"
    jq -c 'select(.source == "MODEL" and .type == "PLANNER_RESPONSE")
           | {ts: .created_at, len: ((.content // "") | length)}' \
      "${transcript}" > "${entries_file}" 2>/dev/null

    # c) Zip: paste model names alongside transcript entries, emit NDJSON.
    paste -d$'\t' "${models_file}" "${entries_file}" 2>/dev/null \
      | while IFS=$'\t' read -r model entry; do
          [[ -z "${entry}" ]] && continue
          [[ -z "${model}" ]] && model="unknown"
          jq -c --arg m "${model}" '. + {model: $m}' <<<"${entry}"
        done >> "${ndjson_file}"

    rm -f "${models_file}" "${entries_file}"
  done

  # Aggregate into tokensByDay and tokensByModel (one jq invocation).
  jq -c -s -n --argjson days "${days}" '
    # Prettify model names: "gemini-3.7-flash-control" → "Gemini 3.7 Flash"
    # "claude-opus-4-6-thinking" → "Claude Opus 4.6 Thinking"
    def pretty(m):
      (m | gsub("-control$"; "") | gsub("-thinking$"; " Thinking")) as $s
      | ($s | split("-")) as $p
      | [$p[] | if test("^[0-9]") then . else
          (.[0:1] | ascii_upcase) + .[1:] end]
      | join(" ")
      | gsub(" (?<a>[0-9]+) (?<b>[0-9]+)"; " \(.a).\(.b)");

    # Estimate tokens from content length (chars ÷ 4 ≈ tokens).
    reduce ([inputs] | .[]) as $e ({day:{}, model:{}};
      (try (($e.ts | sub("\\.[0-9]+"; "") | sub("[+][0-9]{2}:[0-9]{2}$"; "Z"))
            | fromdateiso8601) catch null) as $ts
      | (if $e.len > 0 then (($e.len / 4) | floor) else 250 end) as $t
      | .model[pretty($e.model)] += $t
      | if $ts == null then .
        else reduce range(0; $days|length) as $i (.;
               if ($ts >= $days[$i].start and $ts < $days[$i].end)
               then .day[$days[$i].label] += $t else . end)
        end
    ) as $acc
    | { tokensByDay: [ $days[] | {label:.label, tokens: (($acc.day[.label]) // 0)} ],
        tokensByModel: [ $acc.model | to_entries | sort_by(-.value)[]
                         | {name:.key, tokens:.value} ] }
  ' "${ndjson_file}" 2>/dev/null || echo '{"tokensByDay":[],"tokensByModel":[]}'

  rm -f "${ndjson_file}"
}

antigravity_provider() {
  local d="${HOME_DIR}/.gemini/antigravity"
  [[ -d "${d}" ]] || return 0

  # Try to pick up a Google account email if logged in via Gemini CLI
  # (shared OAuth under ~/.gemini).
  local email=""
  local g="${HOME_DIR}/.gemini/google_accounts.json"
  [[ -f "${g}" ]] && email="$(jq -r '.active // (.accounts[0].email) // ""' "${g}" 2>/dev/null || true)"

  local tokens
  tokens="$(antigravity_tokens)"

  jq -n --arg email "${email}" --argjson tokens "${tokens}" '
    {
      id: "antigravity", name: "Antigravity", icon: "rocket_launch",
      email: $email,
      plan: "",
      limits: [],
      tokensByDay: ($tokens.tokensByDay // []),
      tokensByModel: ($tokens.tokensByModel // [])
    }'
}

# ---- Gemini CLI ------------------------------------------------------------
gemini_provider() {
  local f="${HOME_DIR}/.gemini/oauth_creds.json" g="${HOME_DIR}/.gemini/google_accounts.json"
  [[ -f "${f}" || -f "${g}" ]] || return 0
  local email=""
  [[ -f "${g}" ]] && email="$(jq -r '.active // (.accounts[0].email) // ""' "${g}" 2>/dev/null || true)"
  jq -n --arg email "${email}" '{ id: "gemini", name: "Gemini CLI", icon: "auto_awesome",
           email: $email, plan: "", limits: [], tokensByDay: [], tokensByModel: [] }'
}

# ---- opencode --------------------------------------------------------------
opencode_provider() {
  local f="${HOME_DIR}/.local/share/opencode/auth.json"
  [[ -f "${f}" ]] || return 0
  local provs
  provs="$(jq -r '[keys[]] | join(", ")' "${f}" 2>/dev/null || echo "")"
  jq -n --arg provs "${provs}" '{ id: "opencode", name: "opencode", icon: "dashboard",
           email: "", plan: $provs, limits: [], tokensByDay: [], tokensByModel: [] }'
}

providers="$(
  {
    claude_provider
    codex_provider
    antigravity_provider
    gemini_provider
    opencode_provider
  } | jq -s '.'
)"

# Persisted "default"/active provider selection (written by the widget tabs).
selected=""
[[ -f "${DEFAULT_FILE}" ]] && selected="$(jq -r '.default // empty' "${DEFAULT_FILE}" 2>/dev/null || true)"

jq -n --argjson providers "${providers:-[]}" --arg selected "${selected}" '
  ($providers | map(.id)) as $ids |
  {
    providers: $providers,
    default: (if ($selected != "" and ($ids | index($selected))) then $selected
              else ($ids[0] // "") end)
  }'
