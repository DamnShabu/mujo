{self, ...}: {
  flake.nixosModules.mullvad = {pkgs, config, ...}: let
    # Declarative daemon settings, merged into the persisted settings.json by
    # mergeSettings below. DNS content blocking = the six booleans under
    # tunnel_options.dns_options.default_options, and they only apply while
    # state = "default". "Custom lists" here are relay-location lists: the
    # daemon needs stable UUIDs, non-empty unique names, and one
    # { country = "xx"; } entry per location.
    mullvadFragment = pkgs.writeText "mullvad-settings-fragment.json" (builtins.toJSON {
      tunnel_options.dns_options = {
        state = "default";
        # Re-asserted to empty so a stale custom DNS server from the GUI is
        # not left advertised in the file while silently ignored in Default
        # state.
        custom_options.addresses = [ ];
        default_options = {
          block_ads = true;
          block_trackers = true;
          block_malware = true;
          block_adult_content = false;
          block_gambling = false;
          block_social_media = false;
        };
      };
      custom_lists.custom_lists = [
        {
          id = "00000000-0000-0000-0000-000000000001";
          name = "Europe";
          locations = [
            { country = "de"; }
            { country = "fr"; }
            { country = "nl"; }
            { country = "se"; }
            { country = "ch"; }
            { country = "gb"; }
          ];
        }
        {
          id = "00000000-0000-0000-0000-000000000002";
          name = "United States";
          locations = [
            { country = "us"; }
          ];
        }
        {
          id = "00000000-0000-0000-0000-000000000003";
          name = "Canada";
          locations = [
            { country = "ca"; }
          ];
        }
        {
          id = "00000000-0000-0000-0000-000000000004";
          name = "Asia";
          locations = [
            { country = "jp"; }
            { country = "sg"; }
            { country = "hk"; }
          ];
        }
        {
          id = "00000000-0000-0000-0000-000000000005";
          name = "Oceania";
          locations = [
            { country = "au"; }
            { country = "nz"; }
          ];
        }
        {
          id = "00000000-0000-0000-0000-000000000006";
          name = "South America";
          locations = [
            { country = "br"; }
            { country = "ar"; }
            { country = "cl"; }
          ];
        }
        {
          id = "00000000-0000-0000-0000-000000000007";
          name = "Africa";
          locations = [
            { country = "za"; }
            { country = "ng"; }
          ];
        }
      ];
    });

    # Merges the fragment into the persisted settings.json on every daemon
    # start. The daemon reads its settings only at startup (no file watching),
    # so ExecStartPre re-asserts these values on each start and restart, even
    # if the GUI rewrote the file while the daemon was running. jq's `*` merge
    # is key-wise for objects and replace-wholesale for arrays. jq and
    # coreutils are build-time dependencies of the script (referenced by store
    # path; the daemon unit's own PATH is otherwise minimal), so they are
    # always available here.
    mergeSettings = pkgs.writeShellScript "mullvad-merge-settings" ''
      set -euo pipefail
      export PATH=${pkgs.coreutils}/bin:${pkgs.jq}/bin:$PATH
      settings=/var/lib/mullvad-vpn/settings.json
      fragment=${mullvadFragment}
      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT
      # First boot: no settings.json yet, start from an empty object. A
      # corrupt existing file (the daemon tolerates it and re-saves defaults)
      # is treated the same way; `set -e` would otherwise kill the unit on
      # jq's parse error.
      if [[ -f "$settings" ]] && jq -e . "$settings" >/dev/null 2>&1; then
        existing=$(cat "$settings")
      else
        existing={}
      fi
      jq -s 'reduce .[] as $x ({}; . * $x)' <(printf '%s' "$existing") "$fragment" > "$tmp"
      chown root:root "$tmp"
      chmod 0600 "$tmp"
      mv -f "$tmp" "$settings"
    '';
  in {
    # Requires the impermanence module (defines persistence.*): the settings
    # dir below is only persisted across reboots when it is active.
    # services.mullvad-vpn.enable adds cfg.package to systemPackages; we set
    # it to pkgs.mullvad-vpn below so daemon, CLI, and GUI stay in sync. The
    # GUI is also shipped here via the autostart entry.
    environment.systemPackages = with pkgs; [
        # Home is tmpfs, so mullvad's own ~/.config/autostart is wiped on
        # reboot; ship a system-wide autostart entry instead.
        (makeAutostartItem {
          name = "mullvad-vpn";
          package = mullvad-vpn;
        })
    ];
    services.mullvad-vpn = {
      enable = true;
      # Default is pkgs.mullvad (CLI-only, one release behind the GUI). Pin
      # daemon, CLI, and GUI to the same package so the gRPC versions match.
      package = pkgs.mullvad-vpn;
    };
    # The daemon writes account/device/settings state to MULLVAD_SETTINGS_DIR
    # (default /etc/mullvad-vpn), but /etc is tmpfs. Redirect it to a
    # root-owned dir persisted at system level so the account survives reboot.
    systemd.services."mullvad-daemon".environment.MULLVAD_SETTINGS_DIR = "/var/lib/mullvad-vpn";
    # Re-assert the declarative settings above before every daemon start (the
    # daemon only reads settings.json at startup). Caveats:
    # - custom_lists is replaced wholesale on every start, so lists created in
    #   the GUI are dropped; redeclare them here instead.
    # - All fragment-owned DNS settings are re-asserted on every start too:
    #   state, the six default_options booleans, and custom_options.addresses.
    #   GUI toggle changes are silently discarded, so edit them in the
    #   fragment, not the GUI.
    # - DNS blocking only applies while Mullvad DNS is active (state =
    #   "default", as enforced by the fragment).
    systemd.services."mullvad-daemon".serviceConfig.ExecStartPre = [mergeSettings];
    # No `mode` here on purpose: impermanence applies an entry's mode to the
    # backing dir (/persist/system/var/lib/mullvad-vpn) at creation with
    # mkdir --mode and chmods the ephemeral target to match, so it would be
    # visible through the bind mount. The default 0755 root:root is fine, and
    # mergeSettings writes settings.json 0600 (it holds the plaintext
    # account_number), so nothing is left world-readable.
    persistence.directories = [
      { directory = "/var/lib/mullvad-vpn"; }
    ];
  };
}
