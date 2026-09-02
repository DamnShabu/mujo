# mujo crash — sourced by mujo.sh, never run on its own.
#
# The dispatcher sources this file only when the subcommand is reached, so an
# unrelated `mujo` call never parses it. Every helper from mujo.sh is in scope,
# because sourcing happens in the same shell.

mujo_crash() {
    [[ $# -ge 1 ]] || crash_usage
    SUB="$1"; shift
    case "${SUB}" in
      stream)
        # Event-driven stream of normalized JSON crash events
        journalctl -q -f -n 0 -o json | jq --unbuffered -c '
          if type == "object" then
            if .MESSAGE_ID? == "fc2e22bc6ee647b6b90729ab34a250b1" then
              {
                type: "coredump",
                comm: (.COREDUMP_COMM // ._COMM // "app"),
                pid: (.COREDUMP_PID // ._PID // ""),
                id: (.COREDUMP_PID // .COREDUMP_COMM // "coredump"),
                signal: (.COREDUMP_SIGNAL // "SEGV"),
                summary: "Application dumped core",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            elif (._SYSTEMD_UNIT? != null and (.UNIT_RESULT? == "failed" or .JOB_RESULT? == "failed")) or .MESSAGE_ID? == "be3217bafd1e4ee99b1c707e63d7e2b1" then
              {
                type: "unit",
                comm: (._SYSTEMD_USER_UNIT // ._SYSTEMD_UNIT // "service"),
                pid: (._PID // ""),
                id: (._SYSTEMD_USER_UNIT // ._SYSTEMD_UNIT // "unit"),
                signal: "FAILED",
                summary: "Systemd service entered failed state",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            elif (.MESSAGE? | type == "string" and (. | test("Out of memory: Killed process|systemd-oomd"))) then
              {
                type: "oom",
                comm: "oom-killer",
                pid: (if .MESSAGE | test("Killed process ([0-9]+)") then (.MESSAGE | capture("Killed process (?<p>[0-9]+)") | .p) else "" end),
                id: "oom",
                signal: "SIGKILL",
                summary: "Process terminated by Out-of-Memory killer",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            elif (.MESSAGE? | type == "string" and (. | test("amdgpu.*GPU reset|amdgpu.*ring.*timeout"))) then
              {
                type: "gpu",
                comm: "amdgpu",
                pid: "",
                id: "gpu",
                signal: "GPU_RESET",
                summary: "AMD GPU driver reset / ring timeout detected",
                timestamp: ((.__REALTIME_TIMESTAMP // 0 | tonumber) / 1000)
              }
            else empty end
          else empty end'
        ;;
      info)
        TYPE="${1:-coredump}"; ID="${2:-}"
        case "${TYPE}" in
          coredump)
            RAW="$(coredumpctl info ${ID} 2>/dev/null || coredumpctl info 2>/dev/null || echo "(no coredump info)")"
            SANITIZED="$(printf '%s\n' "${RAW}" | awk '
              /^[[:space:]]*Environment:/ { env=1; print "    Environment: (hidden)"; next }
              env && /^[[:space:]]+\S/ { next }
              env && !/^[[:space:]]/ { env=0 }
              { print }
            ' | head -c 8000)"
            COMM="$(printf '%s\n' "${SANITIZED}" | grep -E '^[[:space:]]*Executable:' | head -1 | awk '{print $2}' | xargs -r basename || echo "app")"
            PID="$(printf '%s\n' "${SANITIZED}" | grep -E '^[[:space:]]*PID:' | head -1 | awk '{print $2}' || echo "")"
            SIGNAL="$(printf '%s\n' "${SANITIZED}" | grep -E '^[[:space:]]*Signal:' | head -1 | awk '{print $2}' || echo "SEGV")"
            jq -n --arg type "coredump" --arg id "${ID}" --arg comm "${COMM:-app}" --arg pid "${PID}" --arg sig "${SIGNAL}" --arg raw "${SANITIZED}" \
              '{type:$type, id:$id, comm:$comm, pid:$pid, signal:$sig, raw:$raw}'
            ;;
          unit)
            STATUS="$(systemctl --user status "${ID}" 2>/dev/null || systemctl status "${ID}" 2>/dev/null || echo "(no service status)")"
            LOGS="$(journalctl --user -u "${ID}" -n 30 --no-pager -o cat 2>/dev/null || journalctl -u "${ID}" -n 30 --no-pager -o cat 2>/dev/null || echo "")"
            RAW="=== Service Status ===\n${STATUS}\n\n=== Recent Logs ===\n${LOGS}"
            jq -n --arg type "unit" --arg id "${ID}" --arg comm "${ID}" --arg raw "${RAW}" \
              '{type:$type, id:$id, comm:$comm, pid:"", signal:"FAILED", raw:$raw}'
            ;;
          oom)
            LOGS="$(journalctl -n 50 --no-pager --grep "oom|Out of memory" -o cat 2>/dev/null || echo "(no OOM logs)")"
            jq -n --arg type "oom" --arg id "oom" --arg comm "oom-killer" --arg raw "${LOGS}" \
              '{type:$type, id:$id, comm:$comm, pid:"", signal:"SIGKILL", raw:$raw}'
            ;;
          gpu)
            LOGS="$(dmesg 2>/dev/null | grep -iE "amdgpu|drm|fence|timeout|reset" | tail -n 40 || journalctl -k -n 40 --no-pager -o cat 2>/dev/null || echo "(no GPU logs)")"
            jq -n --arg type "gpu" --arg id "gpu" --arg comm "amdgpu" --arg raw "${LOGS}" \
              '{type:$type, id:$id, comm:$comm, pid:"", signal:"GPU_RESET", raw:$raw}'
            ;;
          *)
            echo "Unknown crash type: ${TYPE}" >&2; exit 1
            ;;
        esac
        ;;
      diagnose)
        TYPE="${1:-coredump}"; ID="${2:-}"
        INFO_JSON="$(mujo crash info "${TYPE}" "${ID}")"
        RAW_TEXT="$(printf '%s' "${INFO_JSON}" | jq -r '.raw // empty')"
        COMM="$(printf '%s' "${INFO_JSON}" | jq -r '.comm // "application"')"
        
        SYSTEM_PROMPT='You are a Linux system reliability & crash diagnostic AI. Analyze the sanitized crash info and return ONLY a valid JSON object matching this schema:
{
  "summary": "1-2 sentence plain-language explanation of why it crashed",
  "rootCause": "Direct technical cause (e.g. SIGSEGV null pointer dereference, VRAM exhaustion, unit failed dependency)",
  "fixes": [
    { "id": "restart_unit", "title": "Restart Service", "action": "restart-unit", "target": "<unitName>" },
    { "id": "clear_cache", "title": "Clear App Cache", "action": "clear-cache", "target": "<appName>" },
    { "id": "rollback_gen", "title": "Rollback Generation", "action": "rollback-gen", "target": "<number>" }
  ],
  "investigateCmd": "command to run in terminal for inspection"
}'
        USER_MSG="Crash type: ${TYPE}, Target: ${COMM}\n\nCrash Log:\n${RAW_TEXT}"
        
        PAYLOAD="$(jq -n --arg sys "${SYSTEM_PROMPT}" --arg user "${USER_MSG}" \
          '[{role:"system", content:$sys}, {role:"user", content:$user}]')"
        
        AI_OUT="$(printf '%s' "${PAYLOAD}" | mujo ai chat 2>/dev/null || echo "")"
        if printf '%s' "${AI_OUT}" | jq . >/dev/null 2>&1; then
          printf '%s\n' "${AI_OUT}"
        else
          EXTRACTED="$(printf '%s' "${AI_OUT}" | sed -n '/```json/,/```/p' | sed '1d;$d')"
          if printf '%s' "${EXTRACTED}" | jq . >/dev/null 2>&1; then
            printf '%s\n' "${EXTRACTED}"
          else
            jq -n --arg s "${AI_OUT:-Process terminated unexpectedly.}" --arg comm "${COMM}" \
              '{summary:$s, rootCause:"Abnormal process termination", fixes:[{id:"clear_cache", title:"Clear App Cache", action:"clear-cache", target:$comm}], investigateCmd:"coredumpctl info"}'
          fi
        fi
        ;;
      fix)
        [[ $# -ge 1 ]] || { echo "Usage: mujo crash fix <action> [target]" >&2; exit 1; }
        ACTION="$1"; TARGET="${2:-}"
        case "${ACTION}" in
          restart-unit)
            [[ -n "${TARGET}" ]] || { echo "Missing target unit" >&2; exit 1; }
            if systemctl --user restart "${TARGET}" 2>/dev/null; then
              echo "Restarted user service ${TARGET}"
            else
              pkexec systemctl restart "${TARGET}"
            fi
            ;;
          clear-cache)
            [[ -n "${TARGET}" ]] || { echo "Missing target app" >&2; exit 1; }
            SAFE_NAME="$(basename "${TARGET}")"
            if [[ -d "${HOME}/.cache/${SAFE_NAME}" ]]; then
              rm -rf "${HOME}/.cache/${SAFE_NAME}"
              echo "Purged ~/.cache/${SAFE_NAME}"
            else
              echo "No cache directory for ${SAFE_NAME}"
            fi
            ;;
          rollback-gen)
            [[ "${TARGET}" =~ ^[0-9]+$ ]] || { echo "Invalid generation number" >&2; exit 1; }
            pkexec sh -c "nix-env --switch-generation ${TARGET} -p /nix/var/nix/profiles/system && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"
            ;;
          kill)
            [[ "${TARGET}" =~ ^[0-9]+$ ]] || { echo "Invalid pid" >&2; exit 1; }
            kill -15 "${TARGET}" 2>/dev/null || kill -9 "${TARGET}" 2>/dev/null
            echo "Terminated process ${TARGET}"
            ;;
          *)
            echo "Unknown fix action: ${ACTION}" >&2; exit 1
            ;;
        esac
        ;;
      *) crash_usage ;;
    esac
}
