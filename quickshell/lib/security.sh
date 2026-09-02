# mujo security — sourced by mujo.sh, never run on its own.
#
# The dispatcher sources this file only when the subcommand is reached, so an
# unrelated `mujo` call never parses it. Every helper from mujo.sh is in scope,
# because sourcing happens in the same shell.

mujo_security() {
    SUB="${1:-summary}"
    case "${SUB}" in
      summary)
        # The efivar file exists on every UEFI machine whether Secure Boot is on
        # or off, so testing for its presence -- which this did -- reported
        # "ENFORCED" in Settings -> Security on a host booting GRUB with Secure
        # Boot disabled in firmware. Read the value: 4 bytes of EFI variable
        # attributes followed by one byte, 1 = enabled.
        sb_active="false"
        sb_var=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
        if [[ -r ${sb_var} ]]; then
          sb_byte="$(od -An -t u1 -j4 -N1 "${sb_var}" 2>/dev/null | tr -d '[:space:]' || echo "")"
          [[ ${sb_byte} == "1" ]] && sb_active="true"
        fi

        tpm_active="false"
        if [[ -e /dev/tpmrm0 || -e /dev/tpm0 ]]; then
          tpm_active="true"
        fi

        lockdown_mode="none"
        if [[ -f /sys/kernel/security/lockdown ]]; then
          lockdown_mode="$(grep -o '\[[a-z]*\]' /sys/kernel/security/lockdown 2>/dev/null | tr -d '[]' || echo "none")"
        fi

        vault_container="/persist/secure/mujo-vault.luks"
        vault_present="false"
        vault_size=""
        if [[ -f "${vault_container}" ]]; then
          vault_present="true"
          vault_size="$(du -h "${vault_container}" 2>/dev/null | cut -f1 || echo "")"
        fi

        vault_mounted="false"
        mount_point="/run/mujo/vault"
        subdirs="[]"
        if mountpoint -q "${mount_point}"; then
          vault_mounted="true"
          subdirs="$(find "${mount_point}" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | jq -R . | jq -s .)"
        fi

        swap_enc="true"
        swap_count=0
        while read -r dev _; do
          case "$dev" in Filename | "") continue ;; esac
          name="${dev#/dev/}"
          case "$name" in zram*) continue ;; esac
          swap_count=$((swap_count + 1))
          if [[ ! -e "/sys/class/block/$name/dm/uuid" ]] || ! grep -qs '^CRYPT-' "/sys/class/block/$name/dm/uuid"; then
            swap_enc="false"
          fi
        done < /proc/swaps
        if [[ "${swap_count}" -eq 0 ]]; then
          swap_enc="true"
        fi

        coredump_none="false"
        if grep -qs 'Storage=none' /etc/systemd/coredump.conf 2>/dev/null || (systemd-analyze cat-config systemd/coredump.conf 2>/dev/null | grep -qs 'Storage=none'); then
          coredump_none="true"
        fi

        tmpfs_tmp="false"
        if mountpoint -q /tmp && (findmnt -n -o FSTYPE /tmp 2>/dev/null | grep -qs 'tmpfs'); then
          tmpfs_tmp="true"
        fi

        fw_active="true"
        if command -v iptables >/dev/null 2>&1 && ! iptables -S 2>/dev/null | grep -qs '^-P INPUT DROP'; then
          if ! systemctl is-active --quiet nftables 2>/dev/null && ! systemctl is-active --quiet firewall 2>/dev/null; then
            fw_active="false"
          fi
        fi

        trust_reg="/var/lib/mujo-trust/registry.json"
        q_count=0; obs_count=0; grad_count=0; rev_count=0; tot_count=0
        if [[ -f "${trust_reg}" ]]; then
          q_count="$(jq '[.applications[] | select(.state=="QUARANTINE")] | length' "${trust_reg}" 2>/dev/null || echo 0)"
          obs_count="$(jq '[.applications[] | select(.state=="OBSERVING")] | length' "${trust_reg}" 2>/dev/null || echo 0)"
          grad_count="$(jq '[.applications[] | select(.state=="GRADUATED")] | length' "${trust_reg}" 2>/dev/null || echo 0)"
          rev_count="$(jq '[.applications[] | select(.state=="REVOKED")] | length' "${trust_reg}" 2>/dev/null || echo 0)"
          tot_count="$(jq '.applications | length' "${trust_reg}" 2>/dev/null || echo 0)"
        fi

        overall="secure"
        if [[ "${vault_present}" != "true" || "${swap_enc}" != "true" || "${fw_active}" != "true" ]]; then
          overall="attention"
        fi

        jq -n \
          --arg sb "${sb_active}" \
          --arg tpm "${tpm_active}" \
          --arg lockdown "${lockdown_mode}" \
          --arg v_present "${vault_present}" \
          --arg v_size "${vault_size}" \
          --arg v_mount "${vault_mounted}" \
          --arg v_path "${mount_point}" \
          --argjson v_subdirs "${subdirs:-[]}" \
          --arg swap_enc "${swap_enc}" \
          --arg coredump "${coredump_none}" \
          --arg tmpfs "${tmpfs_tmp}" \
          --arg fw "${fw_active}" \
          --argjson q_cnt "${q_count:-0}" \
          --argjson obs_cnt "${obs_count:-0}" \
          --argjson grad_cnt "${grad_count:-0}" \
          --argjson rev_cnt "${rev_count:-0}" \
          --argjson tot_cnt "${tot_count:-0}" \
          --arg overall "${overall}" '
          {
            verifiedBoot: {
              secureBoot: ($sb == "true"),
              tpm: ($tpm == "true"),
              lockdown: $lockdown
            },
            vault: {
              containerPresent: ($v_present == "true"),
              containerSize: $v_size,
              mounted: ($v_mount == "true"),
              mountPoint: $v_path,
              subdirectories: $v_subdirs
            },
            storage: {
              encryptedSwap: ($swap_enc == "true"),
              coredumpDisabled: ($coredump == "true"),
              tmpfsTmp: ($tmpfs == "true")
            },
            network: {
              firewallActive: ($fw == "true")
            },
            trust: {
              quarantinedCount: $q_cnt,
              observingCount: $obs_cnt,
              graduatedCount: $grad_cnt,
              revokedCount: $rev_cnt,
              totalCount: $tot_cnt
            },
            overallStatus: $overall,
            timestamp: (now * 1000 | round)
          }'
        ;;

      inventory|audit)
        if command -v mujo-inventory >/dev/null 2>&1; then
          out="$(mujo-inventory 2>&1 || true)"
          if echo "${out}" | grep -qs 'CLEAN: no sensitive plaintext'; then
            jq -n --arg out "${out}" '{clean: true, findingsCount: 0, output: $out}'
          else
            cnt="$(echo "${out}" | grep -o '[0-9]\+ finding' | awk '{print $1}' | head -n1 || echo 1)"
            jq -n --arg out "${out}" --argjson cnt "${cnt:-1}" '{clean: false, findingsCount: ($cnt | tonumber), output: $out}'
          fi
        else
          jq -n '{clean: true, findingsCount: 0, output: "mujo-inventory not in PATH"}'
        fi
        ;;

      *) security_usage ;;
    esac
}
