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

# The 7-day bucket window every per-day breakdown is summed into: one
# {start,end,label} object per day, oldest first, "Today" last.
day_window() {
  local midnight days start label i
  midnight="$(date -d 'today 00:00:00' +%s)"
  days='[]'
  for i in 6 5 4 3 2 1 0; do
    start=$((midnight - i * 86400))
    if [[ "${i}" -eq 0 ]]; then label="Today"; else label="$(date -d "@${start}" +%a)"; fi
    days="$(jq -c --argjson s "${start}" --arg l "${label}" \
      '. + [{start:$s, end:($s+86400), label:$l}]' <<<"${days}")"
  done
  printf '%s\n' "${days}"
}

# Sum transcript tokens into per-day (last 7 days) and per-model buckets.
claude_tokens() {
  local dir="${HOME_DIR}/.claude/projects" days
  if [[ ! -d "${dir}" ]]; then echo '{"tokensByDay":[],"tokensByModel":[]}'; return 0; fi

  days="$(day_window)"

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
# Antigravity ships as three separate products that each keep their own state
# tree under ~/.gemini (the IDE, the standalone app, and antigravity-cli). They
# share one Google account, so the widget reports them as a single provider and
# scans all three roots. Scanning only ~/.gemini/antigravity — as this used to —
# reported zero for anyone using the CLI or the IDE build.
#
# Two data sources per conversation:
#   1. conversations/<id>.db — the `gen_metadata` table holds one protobuf blob
#      per model generation. The blobs are not parsed; the model name is a plain
#      string inside them, so the blobs are dumped to a temp dir and grepped.
#      This yields the *model mix* of a conversation, not a per-response label.
#   2. brain/<id>/.system_generated/logs/transcript.jsonl — one JSON object per
#      step. MODEL/PLANNER_RESPONSE steps carry `created_at` and the generated
#      `content`/`thinking`, whose character length is the token proxy (÷ 4).
#
# Per-day totals therefore come from the transcript timestamps (exact), while
# per-model totals split each conversation's tokens across the models it used,
# weighted by how often each appears in gen_metadata. The UI only ever shows
# both breakdowns in aggregate, so a weighted split is indistinguishable from
# per-response attribution while costing one grep instead of a protobuf parser.
ANTIGRAVITY_ROOTS=(
  "${HOME_DIR}/.gemini/antigravity"
  "${HOME_DIR}/.gemini/antigravity-ide"
  "${HOME_DIR}/.gemini/antigravity-cli"
)

# Newest mtime across every file the scan reads. Used as a cache key: while it
# is unchanged there is provably no new usage, so the scan can be skipped
# entirely — and the moment Antigravity writes a step, it changes and the next
# poll recomputes. That is what keeps the widget both cheap and live.
antigravity_stamp() {
  local root
  for root in "${ANTIGRAVITY_ROOTS[@]}"; do
    [[ -d "${root}" ]] || continue
    find "${root}/conversations" -maxdepth 1 -name '*.db' -printf '%T@\n' 2>/dev/null
    find "${root}/brain" -maxdepth 4 -name 'transcript.jsonl' -printf '%T@\n' 2>/dev/null
  done | sort -rn | head -1
}

# {"<model name>": <occurrences>} for one conversation database.
# Empty object when sqlite3 is unavailable or the table holds no model strings;
# the caller then still counts the conversation's tokens, just without a
# per-model split.
antigravity_models() {
  local db="$1" dir
  dir="$(mktemp -d)" || { echo '{}'; return 0; }
  sqlite3 "${db}" "SELECT writefile('${dir}/'||idx, data) FROM gen_metadata" >/dev/null 2>&1 || true
  # The blobs also embed conversation text, so the raw vendor-prefixed matches
  # include prose and file paths. A real model id has at least two segments
  # after the vendor, carries a version digit, and never contains a filename
  # extension — that rejects "claude-code.nix", "claude-code-2.1.238.drv" and
  # "/tmp/claude-1000" while keeping gemini-3.7-flash-control,
  # claude-opus-4-6-thinking and gpt-4o-mini.
  grep -rhoaE '(gemini|claude|gpt)-[0-9A-Za-z._-]*' "${dir}" 2>/dev/null \
    | sed 's/[._-]*$//' \
    | grep -E -e '^(gemini|claude|gpt)(-[0-9A-Za-z.]+){2,}$' \
    | grep -E -e '-[0-9]' \
    | grep -v -E -e '\.[A-Za-z]' \
    | sort | uniq -c \
    | jq -Rn '[inputs | capture("^ *(?<c>[0-9]+) +(?<n>.+)$") | {(.n): (.c | tonumber)}] | add // {}'
  rm -rf "${dir}"
}

antigravity_tokens() {
  local cache="${HOME_DIR}/.cache/qsshell/llm-antigravity.json" stamp
  mkdir -p "$(dirname "${cache}")"
  # Midnight is part of the key: the day buckets are labelled relative to today,
  # so a cache written yesterday must not be replayed as today's numbers.
  stamp="$(antigravity_stamp)|$(date -d 'today 00:00:00' +%s)"

  # Nothing on disk changed since the last scan — replay it.
  if [[ -n "${stamp}" && -f "${cache}" ]] \
     && [[ "$(jq -r '.stamp // ""' "${cache}" 2>/dev/null)" == "${stamp}" ]]; then
    jq -c '.data' "${cache}" 2>/dev/null && return 0
  fi

  local days ndjson root db cid transcript models result
  days="$(day_window)"
  ndjson="$(mktemp)"

  for root in "${ANTIGRAVITY_ROOTS[@]}"; do
    [[ -d "${root}/conversations" ]] || continue
    for db in "${root}/conversations"/*.db; do
      [[ -f "${db}" ]] || continue
      cid="$(basename "${db}" .db)"
      transcript="${root}/brain/${cid}/.system_generated/logs/transcript.jsonl"
      [[ -f "${transcript}" ]] || continue
      # Skip conversations untouched in the last 8 days (outside the window).
      [[ -n "$(find "${db}" "${transcript}" -mtime -8 -print -quit 2>/dev/null)" ]] || continue

      models="$(antigravity_models "${db}")"
      [[ -n "${models}" ]] || models='{}'
      jq -c --argjson m "${models}" '
        select(.source == "MODEL" and .type == "PLANNER_RESPONSE")
        | {ts: .created_at,
           len: (((.content // "") | length) + ((.thinking // "") | length)),
           models: $m}' "${transcript}" >> "${ndjson}" 2>/dev/null
    done
  done

  result="$(jq -c -n --argjson days "${days}" '
    # "gemini-3.7-flash-control" → "Gemini 3.7 Flash"
    # "claude-opus-4-6-thinking" → "Claude Opus 4.6 Thinking"
    def pretty(m):
      (m | gsub("-control$"; "") | gsub("-thinking$"; " Thinking")) as $s
      | ($s | split("-"))
      | [ .[] | if test("^[0-9]") then . else (.[0:1] | ascii_upcase) + .[1:] end ]
      | join(" ")
      | gsub(" (?<a>[0-9]+) (?<b>[0-9]+)"; " \(.a).\(.b)");

    reduce inputs as $e ({day:{}, model:{}};
      (try (($e.ts | sub("\\.[0-9]+"; "") | sub("[+][0-9]{2}:[0-9]{2}$"; "Z"))
            | fromdateiso8601) catch null) as $ts
      # chars ÷ 4 ≈ tokens; a step that logged no text still cost a generation.
      | (if $e.len > 0 then (($e.len / 4) | floor) else 250 end) as $t
      | ([$e.models[]] | add // 0) as $weight
      | (if $weight > 0
         then reduce ($e.models | to_entries[]) as $m (.;
                .model[pretty($m.key)] += (($t * $m.value / $weight) | floor))
         else . end)
      | if $ts == null then .
        else reduce range(0; $days | length) as $i (.;
               if ($ts >= $days[$i].start and $ts < $days[$i].end)
               then .day[$days[$i].label] += $t else . end)
        end
    ) as $acc
    | { tokensByDay: [ $days[] | {label: .label, tokens: (($acc.day[.label]) // 0)} ],
        tokensByModel: [ $acc.model | to_entries | sort_by(-.value)[]
                         | {name: .key, tokens: .value} ] }
  ' "${ndjson}" 2>/dev/null)"
  rm -f "${ndjson}"

  [[ -n "${result}" ]] || result='{"tokensByDay":[],"tokensByModel":[]}'
  jq -cn --arg stamp "${stamp}" --argjson data "${result}" '{stamp:$stamp, data:$data}' \
    > "${cache}.tmp" 2>/dev/null && mv "${cache}.tmp" "${cache}" 2>/dev/null || true
  printf '%s\n' "${result}"
}

# Antigravity keeps no account email on disk (~/.gemini/google_accounts.json,
# which this used to read, is never written). The only local identity is the
# Google OAuth token in the login keyring under service=gemini,
# username=antigravity, so the address has to be resolved through the userinfo
# endpoint — the same call Antigravity itself makes, visible as the
# googleapis.com/oauth2/v2/userinfo line in ~/.gemini/antigravity-cli/log/*.log.
#
# Cached for a day: the address only changes when the user signs in as someone
# else, and every failure path (no secret-tool, locked keyring, expired token,
# offline) falls back to the cached value and then to "", which is exactly the
# blank header the widget already renders.
EMAIL_TTL=86400
antigravity_email() {
  local cache="${HOME_DIR}/.cache/qsshell/llm-antigravity-email.json"
  mkdir -p "$(dirname "${cache}")"

  local cached="" cached_ts=0 now
  if [[ -f "${cache}" ]]; then
    cached="$(jq -r '.email // ""' "${cache}" 2>/dev/null || echo "")"
    cached_ts="$(jq -r '.ts // 0' "${cache}" 2>/dev/null || echo 0)"
  fi
  now="$(date +%s)"
  if [[ $((now - cached_ts)) -lt ${EMAIL_TTL} ]]; then
    printf '%s\n' "${cached}"; return 0
  fi

  command -v secret-tool >/dev/null 2>&1 || { printf '%s\n' "${cached}"; return 0; }

  local tok email
  tok="$(secret-tool lookup service gemini username antigravity 2>/dev/null \
         | jq -r '.token.access_token // empty' 2>/dev/null || true)"
  [[ -n "${tok}" ]] || { printf '%s\n' "${cached}"; return 0; }

  email="$(curl -s -m 8 https://www.googleapis.com/oauth2/v2/userinfo \
             -H "Authorization: Bearer ${tok}" 2>/dev/null \
           | jq -r '.email // empty' 2>/dev/null || true)"
  [[ -n "${email}" ]] || { printf '%s\n' "${cached}"; return 0; }

  jq -cn --arg email "${email}" --argjson ts "${now}" '{ts:$ts, email:$email}' \
    > "${cache}.tmp" 2>/dev/null && mv "${cache}.tmp" "${cache}" 2>/dev/null || true
  printf '%s\n' "${email}"
}

antigravity_provider() {
  local root found=""
  for root in "${ANTIGRAVITY_ROOTS[@]}"; do
    [[ -d "${root}" ]] && found=1
  done
  [[ -n "${found}" ]] || return 0

  local email tokens
  email="$(antigravity_email)"
  tokens="$(antigravity_tokens)"

  jq -n --arg email "${email}" --argjson tokens "${tokens}" '
    {
      id: "antigravity", name: "Antigravity", icon: "rocket_launch",
      email: $email,
      plan: "",
      limits: [],
      # Antigravity logs no token counts anywhere — not in the gen_metadata
      # protobufs, not in the step metadata, not in any state file. These
      # numbers are the generated-character proxy from antigravity_tokens(),
      # which counts output only and so lands orders of magnitude under a
      # provider that reports real usage. The flag makes the widget say so
      # rather than let the bars read as measured.
      approx: true,
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
# opencode keeps every message as a JSON blob in a sqlite `message` table, and
# the blob already carries exact usage:
#
#   {"role":"assistant","cost":0.0108,"modelID":"gemini-3.7-flash",
#    "tokens":{"input":11950,"output":243,"reasoning":147,
#              "cache":{"write":0,"read":0}},
#    "time":{"created":<epoch ms>}}
#
# So the whole per-day/per-model breakdown is one JSON1 query — no transcript
# scanning, no heuristics, and the same five token components claude_tokens()
# sums, which is what keeps the two providers comparable on the same chart.

# The database moved to the store root; a stale zero-byte file is left behind
# at storage/opencode-stable.db, so pick the largest non-empty candidate rather
# than the first path that exists.
opencode_db() {
  local root="${HOME_DIR}/.local/share/opencode" db
  for db in "${root}"/opencode-*.db "${root}"/storage/opencode-*.db; do
    [[ -s "${db}" ]] && printf '%s\n' "${db}"
  done | xargs -r -d '\n' du -b 2>/dev/null | sort -rn | head -1 | cut -f2-
}

# Model names are left as opencode reports them ("gemini-3.7-flash",
# "big-pickle"): unlike Claude's, they span several providers, so stripping or
# title-casing the vendor half would lose information rather than tidy it.
#
# No cache here, deliberately: `time_created` is indexed, so the window filter
# is a range scan of ~800 rows rather than a table walk, and runs in ~0.1s —
# cheaper than the stat-and-compare a cache would cost. Contrast
# antigravity_tokens(), which forks sqlite3 and mktemp per conversation and
# therefore has to be cached.
opencode_tokens() {
  local db since
  db="$(opencode_db)"
  [[ -n "${db}" ]] || { echo '{"tokensByDay":[],"tokensByModel":[],"cost":0}'; return 0; }
  command -v sqlite3 >/dev/null 2>&1 || { echo '{"tokensByDay":[],"tokensByModel":[],"cost":0}'; return 0; }

  since=$(( ($(date -d 'today 00:00:00' +%s) - 6 * 86400) * 1000 ))

  sqlite3 -readonly "${db}" "
    SELECT json_object(
      'ts',    json_extract(data, '\$.time.created') / 1000,
      'model', COALESCE(json_extract(data, '\$.modelID'), 'unknown'),
      'tok',   COALESCE(json_extract(data, '\$.tokens.input'), 0)
             + COALESCE(json_extract(data, '\$.tokens.output'), 0)
             + COALESCE(json_extract(data, '\$.tokens.reasoning'), 0)
             + COALESCE(json_extract(data, '\$.tokens.cache.write'), 0)
             + COALESCE(json_extract(data, '\$.tokens.cache.read'), 0),
      'cost',  COALESCE(json_extract(data, '\$.cost'), 0))
    FROM message
    WHERE json_extract(data, '\$.role') = 'assistant'
      AND time_created >= ${since};" 2>/dev/null \
  | jq -c -n --argjson days "$(day_window)" '
      reduce inputs as $e ({day:{}, model:{}, cost:0};
        .cost += ($e.cost // 0)
        | .model[$e.model] += $e.tok
        | reduce range(0; $days | length) as $i (.;
            if ($e.ts >= $days[$i].start and $e.ts < $days[$i].end)
            then .day[$days[$i].label] += $e.tok else . end)
      ) as $acc
      | { tokensByDay: [ $days[] | {label: .label, tokens: (($acc.day[.label]) // 0)} ],
          tokensByModel: [ $acc.model | to_entries | sort_by(-.value)[]
                           | {name: .key, tokens: .value} ],
          cost: $acc.cost }
    ' 2>/dev/null || echo '{"tokensByDay":[],"tokensByModel":[],"cost":0}'
}

opencode_provider() {
  local f="${HOME_DIR}/.local/share/opencode/auth.json" db
  db="$(opencode_db)"
  [[ -f "${f}" || -n "${db}" ]] || return 0

  # No account/email is stored locally, so the signed-in provider list stands in
  # for a plan badge.
  local provs=""
  [[ -f "${f}" ]] && provs="$(jq -r '[keys[]] | join(", ")' "${f}" 2>/dev/null || echo "")"

  local tokens
  tokens="$(opencode_tokens)"
  [[ -n "${tokens}" ]] || tokens='{"tokensByDay":[],"tokensByModel":[],"cost":0}'

  jq -n --arg provs "${provs}" --argjson tokens "${tokens}" '
    { id: "opencode", name: "opencode", icon: "dashboard",
      email: "", plan: $provs, limits: [],
      tokensByDay: ($tokens.tokensByDay // []),
      tokensByModel: ($tokens.tokensByModel // []),
      cost: ($tokens.cost // 0) }'
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
