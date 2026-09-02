# mujo clean — sourced by mujo.sh, never run on its own.
#
# The dispatcher sources this file only when the subcommand is reached, so an
# unrelated `mujo` call never parses it. Every helper from mujo.sh is in scope,
# because sourcing happens in the same shell.

mujo_clean() {
    [[ $# -ge 1 ]] || clean_usage
    SUB="$1"; shift
    case "${SUB}" in
      scan)
        GEN_COUNT="$(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l || echo 0)"
        NIX_RECLAIM_MB=$(( GEN_COUNT > 1 ? (GEN_COUNT - 1) * 850 : 0 ))

        J_RAW="$(journalctl --disk-usage 2>/dev/null || echo '')"
        J_MB=0
        if [[ "${J_RAW}" =~ ([0-9.]+)G ]]; then
          J_MB="$(awk "BEGIN {print int(${BASH_REMATCH[1]} * 1024)}")"
        elif [[ "${J_RAW}" =~ ([0-9.]+)M ]]; then
          J_MB="$(awk "BEGIN {print int(${BASH_REMATCH[1]})}")"
        fi
        J_RECLAIM_MB=$(( J_MB > 100 ? J_MB - 100 : 0 ))

        THUMB_MB="$(du -sm "${HOME}/.cache/thumbnails" 2>/dev/null | cut -f1 || echo 0)"
        TRASH_MB="$(du -sm "${HOME}/.local/share/Trash" 2>/dev/null | cut -f1 || echo 0)"
        SHADER_MB="$(du -sm "${HOME}/.cache/mesa_shader_cache" 2>/dev/null | cut -f1 || echo 0)"
        CACHE_TOT_MB=$(( ${THUMB_MB:-0} + ${TRASH_MB:-0} + ${SHADER_MB:-0} ))

        Z_ORIG="$(cat /sys/block/zram0/orig_data_size 2>/dev/null || echo 0)"
        Z_COMPR="$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo 0)"
        Z_ORIG_MB=$(( Z_ORIG / 1048576 ))
        Z_COMPR_MB=$(( Z_COMPR / 1048576 ))

        TOT_RECLAIM_MB=$(( NIX_RECLAIM_MB + J_RECLAIM_MB + CACHE_TOT_MB ))

        jq -n \
          --argjson genCount "${GEN_COUNT}" \
          --argjson nixReclaim "${NIX_RECLAIM_MB}" \
          --argjson journalMb "${J_MB}" \
          --argjson journalReclaim "${J_RECLAIM_MB}" \
          --argjson thumbMb "${THUMB_MB:-0}" \
          --argjson trashMb "${TRASH_MB:-0}" \
          --argjson shaderMb "${SHADER_MB:-0}" \
          --argjson cacheTotMb "${CACHE_TOT_MB}" \
          --argjson zramOrigMb "${Z_ORIG_MB}" \
          --argjson zramComprMb "${Z_COMPR_MB}" \
          --argjson totalReclaim "${TOT_RECLAIM_MB}" '
          {
            nix: {
              generations: $genCount,
              reclaimableMb: $nixReclaim,
              label: "\($genCount) generations stored"
            },
            journal: {
              sizeMb: $journalMb,
              reclaimableMb: $journalReclaim,
              label: "\($journalMb) MB logs recorded"
            },
            caches: {
              totalMb: $cacheTotMb,
              reclaimableMb: $cacheTotMb,
              thumbnailsMb: $thumbMb,
              trashMb: $trashMb,
              shaderMb: $shaderMb
            },
            memory: {
              zramOrigMb: $zramOrigMb,
              zramComprMb: $zramComprMb
            },
            totalReclaimableMb: $totalReclaim
          }'
        ;;
      apply)
        TARGET="${1:-all}"
        case "${TARGET}" in
          nix)
            echo ">>> Cleaning old Nix generations and optimising store..."
            pkexec nix-collect-garbage -d && pkexec nix-store --optimise
            echo "✓ Nix store cleaned and deduplicated"
            ;;
          journal)
            echo ">>> Vacuuming systemd journals..."
            journalctl --user --vacuum-time=7d 2>/dev/null || true
            pkexec journalctl --vacuum-time=7d --vacuum-size=100M
            echo "✓ Journals vacuumed to <=100MB"
            ;;
          caches)
            echo ">>> Purging disposable application and thumbnail caches..."
            rm -rf "${HOME}/.cache/thumbnails"/* "${HOME}/.local/share/Trash"/* "${HOME}/.cache/mesa_shader_cache"/* 2>/dev/null || true
            echo "✓ User thumbnail, trash, and shader caches cleared"
            ;;
          memory)
            echo ">>> Compacting ZRAM memory and reclaiming page cache..."
            if [[ -w /sys/block/zram0/compact ]]; then
              echo 1 > /sys/block/zram0/compact 2>/dev/null || true
            fi
            sync
            pkexec sysctl -w vm.drop_caches=3 2>/dev/null || true
            echo "✓ Memory compacted and inactive cache dropped"
            ;;
          all)
            echo ">>> Executing full system optimization..."
            rm -rf "${HOME}/.cache/thumbnails"/* "${HOME}/.local/share/Trash"/* "${HOME}/.cache/mesa_shader_cache"/* 2>/dev/null || true
            journalctl --user --vacuum-time=7d 2>/dev/null || true
            pkexec journalctl --vacuum-time=7d --vacuum-size=100M 2>/dev/null || true
            pkexec nix-collect-garbage -d 2>/dev/null || true
            pkexec nix-store --optimise 2>/dev/null || true
            if [[ -w /sys/block/zram0/compact ]]; then echo 1 > /sys/block/zram0/compact 2>/dev/null || true; fi
            sync
            pkexec sysctl -w vm.drop_caches=3 2>/dev/null || true
            echo "✓ Full system optimization complete"
            ;;
          *) echo "Usage: mujo clean apply <nix|journal|caches|memory|all>" >&2; exit 1 ;;
        esac
        ;;
      *) clean_usage ;;
    esac
}
