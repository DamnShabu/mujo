# mujo sentinel — sourced by mujo.sh, never run on its own.
#
# The dispatcher sources this file only when the subcommand is reached, so an
# unrelated `mujo` call never parses it. Every helper from mujo.sh is in scope,
# because sourcing happens in the same shell.

mujo_sentinel() {
    [[ $# -ge 1 ]] || sentinel_usage
    SUB="$1"; shift
    case "${SUB}" in
      scan)
        CARD="$(ls -d /sys/class/drm/card* 2>/dev/null | grep -E 'card[0-9]+$' | head -1 || echo '')"
        GPU_BUSY="null"; VRAM_USED="null"; VRAM_TOTAL="null"
        if [[ -n "${CARD}" && -d "${CARD}/device" ]]; then
          [[ -r "${CARD}/device/gpu_busy_percent" ]] && GPU_BUSY="$(cat "${CARD}/device/gpu_busy_percent" 2>/dev/null || echo null)"
          if [[ -r "${CARD}/device/mem_info_vram_used" ]]; then
            VU="$(cat "${CARD}/device/mem_info_vram_used" 2>/dev/null || echo 0)"
            VT="$(cat "${CARD}/device/mem_info_vram_total" 2>/dev/null || echo 0)"
            VRAM_USED=$(( VU / 1048576 ))
            VRAM_TOTAL=$(( VT / 1048576 ))
          fi
        fi

        PROCS_JSON="$(ps -eo pid=,ppid=,stat=,rss=,%cpu=,%mem=,comm= --sort=-%cpu | head -n 35 | awk '
          BEGIN { printf "["; first=1 }
          {
            if (!first) printf ","
            first=0
            pid=$1; ppid=$2; stat=$3; rss=int($4/1024); cpu=$5; mem=$6;
            $1=$2=$3=$4=$5=$6="";
            sub(/^[ \t]+/, "", $0);
            gsub(/"/, "\\\"", $0);
            printf "{\"pid\":%d,\"ppid\":%d,\"stat\":\"%s\",\"rssMb\":%d,\"cpu\":%.1f,\"mem\":%.1f,\"comm\":\"%s\"}", pid, ppid, stat, rss, cpu, mem, $0
          }
          END { printf "]\n" }
        ')"

        # Identify orphaned / reparented VMs and orphaned helper processes
        USER_SYS_PID="$(pgrep -u "$(id -u)" -x systemd 2>/dev/null | head -1 || echo 1)"
        STEAM_RUNNING="$(pgrep -u "$(id -u)" -x steam 2>/dev/null | head -1 || echo '')"

        # Stale/Orphaned helper processes (e.g. steamwebhelper running with no steam parent process)
        ORPHAN_HELPERS="$(ps -eo pid=,ppid=,comm=,args= | awk -v usys="${USER_SYS_PID}" -v steam="${STEAM_RUNNING}" '
          ($3 ~ /steamwebhelper/ && steam == "" && ($2 == 1 || $2 == usys)) { print $1 }
        ')"
        ORPHAN_HELPERS_JSON="$(printf '%s\n' "${ORPHAN_HELPERS}" | jq -Rs '[split("\n")[] | select(. != "") | tonumber]')"

        SCAN_JSON="$(
          jq -n \
            --argjson procs "${PROCS_JSON}" \
            --argjson orphanHelpers "${ORPHAN_HELPERS_JSON}" \
            --arg gpu_busy "${GPU_BUSY}" \
            --arg vram_used "${VRAM_USED}" \
            --arg vram_total "${VRAM_TOTAL}" '
            def is_exempt: .comm | test("(^|\\.)(quickshell|niri|agy|claude|opencode|codex|gemini|pi|kitty|ghostty|foot|alacritty|wezterm|zen|firefox|chromium|chrome|brave|systemd|dbus-daemon|wireplumber|pipewire|Xwayland|qemu|qemu-system|nixos-test|nix-test|bash|sh|fish|zsh|ps|awk|jq|sed|grep|rg|ripgrep|rtk|git|nix|nix-daemon)(-|$|\\.)");
            ($procs | map(select(.stat | startswith("Z")))) as $zombies |
            ($procs | map(select((.stat | startswith("Z") | not) and (.pid as $p | ($orphanHelpers | index($p) != null))) | . + {type: "orphaned_process", label: "Orphaned Process"})) as $orphans |
            ($procs | map(select((.stat | startswith("Z") | not) and .cpu >= 70 and (is_exempt | not)) | . + {type: "cpu_runaway", label: "CPU Runaway"})) as $cpuRunaways |
            ($procs | map(select((.stat | startswith("Z") | not) and (.mem >= 25 or .rssMb >= 3500) and (is_exempt | not)) | . + {type: "mem_hog", label: "Memory Hog"})) as $memHogs |
            ($procs | map(select((.stat | startswith("Z") | not) and (.stat | startswith("D")) and .ppid != 2 and .pid != 2) | . + {type: "d_state", label: "Uninterruptible Disk Wait"})) as $dState |
            ($zombies | map(. + {type: "zombie", label: "Defunct Zombie"})) as $taggedZombies |
            ($cpuRunaways + $memHogs + $taggedZombies + $orphans + $dState | unique_by(.pid)) as $anomalies |
            (100 - (($zombies | length) * 10) - (($orphans | length) * 15) - (($cpuRunaways | length) * 15) - (($memHogs | length) * 15)) as $rawScore |
            (if $rawScore < 10 then 10 elif $rawScore > 100 then 100 else $rawScore end) as $score |
            {
              healthScore: $score,
              status: (if $score >= 85 then "optimal" elif $score >= 60 then "warning" else "critical" end),
              zombieCount: ($zombies | length),
              orphanCount: ($orphans | length),
              anomalyCount: ($anomalies | length),
              anomalies: $anomalies,
              topCpu: ($procs | sort_by(-.cpu) | .[0:6]),
              topMem: ($procs | sort_by(-.rssMb) | .[0:6]),
              gpu: {
                busyPercent: ($gpu_busy | if . == "null" then null else tonumber end),
                vramUsedMb: ($vram_used | if . == "null" then null else tonumber end),
                vramTotalMb: ($vram_total | if . == "null" then null else tonumber end)
              }
            }'
        )"

        # --- 3-flag escalation: 1 flag per process per minute, auto-kill after 3 sustained
        # flags unless the process went down, shows live children, active I/O, or is protected.
        NOW="$(date +%s)"
        FLAGS_FILE="${HOME}/.local/state/qsshell/sentinel-flags.json"
        [[ -d "${FLAGS_FILE%/*}" ]] || mkdir -p "${FLAGS_FILE%/*}" 2>/dev/null
        PREV_FLAGS="$(cat "${FLAGS_FILE}" 2>/dev/null || printf '{"flags":{}}')"
        
        # Read user setting for auto-killing runaways (default true)
        SETTINGS_CONF="${HOME}/.config/qsshell/settings.json"
        AUTO_KILL_ENABLED="true"
        if [[ -f "${SETTINGS_CONF}" ]]; then
          AUTO_KILL_ENABLED="$(jq -r '."sentinel.autoKillRunaways" // true' "${SETTINGS_CONF}" 2>/dev/null || echo true)"
        fi

        # Extract actionable runaway anomalies (CPU runaways >=75%, mem hogs, uninterruptible D-states)
        RUNAWAYS_RAW="$(printf '%s' "${SCAN_JSON}" | jq -c '[.anomalies[] | select(.type == "cpu_runaway" or .type == "mem_hog" or .type == "d_state") | {pid, comm, type, rssMb, cpu}]')"
        
        # Enrich with current I/O bytes from /proc/<pid>/io if available
        RUNAWAYS_WITH_IO="$(
          printf '%s' "${RUNAWAYS_RAW}" | jq -c '.[]' 2>/dev/null | while read -r r; do
            [[ -n "${r}" ]] || continue
            PID_R="$(printf '%s' "${r}" | jq -r '.pid')"
            IO_BYTES=0
            if [[ -r "/proc/${PID_R}/io" ]]; then
              IO_BYTES="$(awk '/^(rchar|wchar):/ {s += $2} END {print s+0}' "/proc/${PID_R}/io" 2>/dev/null || echo 0)"
            fi
            printf '%s' "${r}" | jq --argjson io "${IO_BYTES}" '. + {io: $io}'
          done | jq -s '.'
        )"
        [[ -n "${RUNAWAYS_WITH_IO}" ]] || RUNAWAYS_WITH_IO="[]"

        # Parents with at least one live (non-zombie) child = still doing work underneath
        LIVE_CHILD_JSON="$(ps -eo ppid=,stat= | awk '$2 !~ /^Z/ && $1 != 2 {print $1}' | sort -u | jq -Rs '[split("\n")[] | select(. != "") | tonumber]')"
        PROTECTED_RE='(^|\.)(quickshell|niri|agy|claude|opencode|codex|gemini|pi|kitty|ghostty|foot|alacritty|wezterm|zen|firefox|chromium|chrome|brave|systemd|dbus-daemon|wireplumber|pipewire|Xwayland|qemu|qemu-system|nixos-test|nix-test|bash|sh|fish|zsh|ps|awk|jq|sed|grep|rg|ripgrep|rtk|git|nix|nix-daemon)(-|$|\.)'

        # Advance flags for current runaways (max 1/min), drop recovered pids.
        FLAGS_UPDATED="$(printf '%s' "${PREV_FLAGS}" | jq \
          --argjson ru "${RUNAWAYS_WITH_IO}" \
          --argjson live "${LIVE_CHILD_JSON}" \
          --argjson now "${NOW}" '
            .flags = (.flags // {})
            # Drop recovered pids (went down or exited)
            | .flags |= with_entries(.key as $k | select($ru | any(.pid == ($k | tonumber))))
            | reduce $ru[] as $r (.;
                ($r.pid | tostring) as $k |
                ($live | index($r.pid) != null) as $hasLiveChild |
                .flags[$k] = (
                  if .flags[$k] then
                    .flags[$k] as $prev |
                    ($r.io - ($prev.prevIo // 0)) as $ioDelta |
                    # Meaningful work: active live child processes or >= 10MB I/O delta in past minute
                    ($hasLiveChild or $ioDelta >= 10485760) as $isMeaningful |
                    if ($now - ($prev.last // 0)) >= 60 then
                      if $isMeaningful then
                        $prev + {count: 1, last: $now, comm: $r.comm, type: $r.type, prevIo: $r.io, warned: false}
                      else
                        $prev + {count: ($prev.count + 1), last: $now, comm: $r.comm, type: $r.type, prevIo: $r.io}
                      end
                    else
                      $prev + {comm: $r.comm, type: $r.type}
                    end
                  else
                    {
                      count: 1,
                      first: $now,
                      last: $now,
                      comm: $r.comm,
                      type: $r.type,
                      prevIo: $r.io,
                      warned: false
                    }
                  end
                )
              )'
        )"

        # Emit Flag 2 warnings for processes that sustained 2 minutes and have not been warned yet
        WARNINGS="$(
          printf '%s' "${FLAGS_UPDATED}" | jq -c \
            '[ .flags | to_entries[]
               | select(.value.count == 2 and (.value.warned != true))
               | {pid: (.key | tonumber), comm: .value.comm, type: .value.type, count: 2} ]'
        )"

        # Mark warned flags so we don'\''t spam toasts every 10s
        FLAGS_UPDATED="$(
          printf '%s' "${FLAGS_UPDATED}" | jq \
            '.flags |= with_entries(if .value.count == 2 then .value.warned = true else . end)'
        )"

        # Candidates to kill: >=3 flags, still a runaway, no live children.
        KILL_CANDIDATES="$(
          printf '%s' "${FLAGS_UPDATED}" | jq -c \
            --argjson live "${LIVE_CHILD_JSON}" \
            --argjson ru "${RUNAWAYS_WITH_IO}" '
              [ .flags | to_entries[]
                | .key as $k
                | select(.value.count >= 3)
                | select($ru | any(.pid == ($k | tonumber)))
                | select(($live | index($k | tonumber)) == null)
                | {pid: ($k | tonumber), comm: .value.comm, type: .value.type} ]'
        )"

        AUTO_KILLED='[]'
        while IFS= read -r cand; do
          [[ -n "${cand}" ]] || continue
          PID_K="$(printf '%s' "${cand}" | jq -r '.pid')"
          COMM_K="$(printf '%s' "${cand}" | jq -r '.comm')"
          TYPE_K="$(printf '%s' "${cand}" | jq -r '.type')"
          if grep -qE "${PROTECTED_RE}" <<<"${COMM_K}"; then
            # Protected agent/shell: never auto-kill, reset its streak.
            FLAGS_UPDATED="$(printf '%s' "${FLAGS_UPDATED}" | jq ".flags[\"${PID_K}\"].count = 1 | .flags[\"${PID_K}\"].warned = false")"
            continue
          fi
          if [[ "${AUTO_KILL_ENABLED}" == "true" ]]; then
            kill -15 "${PID_K}" 2>/dev/null
            sleep 1
            kill -9 "${PID_K}" 2>/dev/null
            AUTO_KILLED="$(printf '%s' "${AUTO_KILLED}" | jq --arg pid "${PID_K}" --arg comm "${COMM_K}" --arg type "${TYPE_K}" '. + [{pid: ($pid | tonumber), comm: $comm, type: $type, reason: "sustained 3 flags without progress", timestamp: '"${NOW}"'}]')"
            FLAGS_UPDATED="$(printf '%s' "${FLAGS_UPDATED}" | jq "del(.flags[\"${PID_K}\"])")"
          fi
        done < <(printf '%s' "${KILL_CANDIDATES}" | jq -c '.[]') 2>/dev/null

        # Meaningful runaways (live children) that hit 3 flags: reset rather than kill.
        FLAGS_UPDATED="$(printf '%s' "${FLAGS_UPDATED}" | jq --argjson live "${LIVE_CHILD_JSON}" '
          .flags |= with_entries(
            if .value.count >= 3 and ($live | index(.key | tonumber)) != null
            then .value.count = 1 | .value.warned = false else . end)')"
        printf '%s\n' "${FLAGS_UPDATED}" > "${FLAGS_FILE}"

        printf '%s' "${SCAN_JSON}" | jq \
          --argjson ak "${AUTO_KILLED}" \
          --argjson warn "${WARNINGS:-[]}" \
          --argjson flags "${FLAGS_UPDATED}" \
          '. + {autoKilled: $ak, warnings: $warn, activeFlags: ($flags.flags // {})}'
        ;;
      reap)
        REAPED=0
        PIDS=()
        # 1. Send SIGCHLD to parents of zombie processes
        while read -r pid ppid; do
          [[ -n "${pid}" ]] || continue
          if kill -CHLD "${ppid}" 2>/dev/null; then
            REAPED=$(( REAPED + 1 ))
            PIDS+=("${pid}")
          fi
        done < <(ps -eo pid=,ppid=,stat= | awk '$3 ~ /^Z/ {print $1, $2}')

        # 2. Terminate dead helpers (e.g. steamwebhelper running with no steam parent process)
        USER_SYS_PID="$(pgrep -u "$(id -u)" -x systemd 2>/dev/null | head -1 || echo 1)"
        STEAM_RUNNING="$(pgrep -u "$(id -u)" -x steam 2>/dev/null | head -1 || echo '')"
        while read -r opid; do
          [[ -n "${opid}" ]] || continue
          kill -15 "${opid}" 2>/dev/null || true
          REAPED=$(( REAPED + 1 ))
          PIDS+=("${opid}")
        done < <(ps -eo pid=,ppid=,comm=,args= | awk -v usys="${USER_SYS_PID}" -v steam="${STEAM_RUNNING}" '
          ($3 ~ /steamwebhelper/ && steam == "" && ($2 == 1 || $2 == usys)) { print $1 }
        ')

        jq -n --argjson count "${REAPED}" --argjson pids "$(printf '%s\n' "${PIDS[@]}" | jq -R . | jq -s 'map(select(. != "") | tonumber)')" \
          '{reapedCount:$count, pids:$pids}'
        ;;
      action)
        [[ $# -ge 2 ]] || { echo "Usage: mujo sentinel action <kill|term|stop|cont|renice> <pid> [val]" >&2; exit 1; }
        ACT="$1"; PID="$2"; VAL="${3:--10}"
        [[ "${PID}" =~ ^[0-9]+$ ]] || { echo "Invalid pid" >&2; exit 1; }
        case "${ACT}" in
          kill) kill -9 "${PID}" ;;
          term) kill -15 "${PID}" ;;
          stop) kill -STOP "${PID}" ;;
          cont) kill -CONT "${PID}" ;;
          renice) renice -n "${VAL}" -p "${PID}" ;;
          *) echo "Unknown action: ${ACT}" >&2; exit 1 ;;
        esac
        echo "Executed ${ACT} on PID ${PID}"
        ;;
      *) sentinel_usage ;;
    esac
}
