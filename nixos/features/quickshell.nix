{self, inputs, ...}: {
  flake.nixosModules.quickshell = {pkgs, config, lib, ...}: let
    qs = import ../../quickshell/_default.nix {inherit self pkgs;};

    qmlDeps = with pkgs.qt6; [qtmultimedia qtdeclarative qtwayland qt5compat] ++ [pkgs.quickshell inputs.qml-niri.packages.${pkgs.stdenv.hostPlatform.system}.default];
    qmlPath = pkgs.lib.makeSearchPath "lib/qt-6/qml" qmlDeps;
    mkDaemon = {
      command,
      path ? [],
      environment ? {},
    }: {
      # Quickshell is a Wayland shell client; wait for niri.service in the
      # user systemd instance so the compositor is ready before quickshell
      # tries to connect (avoids silent crash on early boot).
      after = ["niri.service"];
      serviceConfig = {
        ExecStart = command;
        Restart = "always";
        RestartSec = 2;
      };
      environment = {QML2_IMPORT_PATH = qmlPath;} // environment;
      inherit path;
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      restartTriggers = ["/run/current-system"];
    };

    # Steam flatpak writes "create desktop shortcut" .desktop files into its
    # sandbox home (~/.var/app/com.valvesoftware.Steam/.local/share/applications)
    # with Exec=steam steam://rungameid/<id>, which vicinae cannot launch (no
    # steam binary on PATH). Rewrite them into ~/.local/share/applications as
    # `flatpak run ...` so vicinae indexes and launches them.
    steamShortcutSync = pkgs.writeShellScript "steam-shortcuts-sync" ''
      set -euo pipefail
      src="/home/${user}/.var/app/com.valvesoftware.Steam/.local/share/applications"
      dst="/home/${user}/.local/share/applications"
      mkdir -p "$dst"
      [[ -d "$src" ]] || exit 0
      for f in "$src"/*.desktop; do
        [[ -f "$f" ]] || continue
        # Skip the Steam client's own entry; only sync game shortcuts.
        name=$(awk '/^Name=/{sub(/^Name=/, ""); print; exit}' "$f")
        [[ "$name" != "Steam" ]] || continue
        id=$(awk '/steam:\/\/rungameid\/[0-9][0-9]*/ {id=$0; sub(/^.*steam:\/\/rungameid\//, "", id); sub(/[^0-9].*/, "", id); print id; exit}' "$f")
        [[ -n "$id" ]] || continue
        out="$dst/$(basename "$f")"
        tmp="$out.tmp"
        icon="/home/${user}/.var/app/com.valvesoftware.Steam/.local/share/icons/hicolor/128x128/apps/steam_icon_$id.png"
        if [[ -f "$icon" ]]; then
          sed -e "s|^Exec=.*|Exec=flatpak run com.valvesoftware.Steam steam://rungameid/$id|" -e "s|^Icon=.*|Icon=$icon|" "$f" > "$tmp"
        else
          sed "s|^Exec=.*|Exec=flatpak run com.valvesoftware.Steam steam://rungameid/$id|" "$f" > "$tmp"
        fi
        if cmp -s "$out" "$tmp"; then
          rm -f "$tmp"
        else
          mv -f "$tmp" "$out"
        fi
      done
      # Prune previously synced entries whose source shortcut no longer exists.
      for out in "$dst"/*.desktop; do
        [[ -f "$out" ]] || continue
        [[ -e "$src/$(basename "$out")" ]] && continue
        grep -q '^Exec=flatpak run com.valvesoftware.Steam steam://rungameid/' "$out" && rm -f "$out"
      done
    '';
    daemons = ["qs-combined" "qs-bar" "vicinae" "pibble" "steam-shortcuts"];
    user = config.preferences.user.name;
    uid = toString config.users.users.${user}.uid;
  in {
    environment.sessionVariables.QML2_IMPORT_PATH = lib.mkForce qmlPath;

    environment.systemPackages = [qs.mujo self.packages.${pkgs.stdenv.hostPlatform.system}.quicksnip self.packages.${pkgs.stdenv.hostPlatform.system}.pibble];

    services.udev.extraRules = ''
      KERNEL=="event*", SUBSYSTEM=="input", MODE="0666"
    '';

    persistence.data.directories = [
      ".config/qsshell"
    ];

    systemd.user.services = {
      qs-combined = mkDaemon {
        command = "${pkgs.quickshell}/bin/quickshell -p ${qs.combined}/Shell.qml";
        path = with pkgs; [bash coreutils self.packages.${pkgs.stdenv.hostPlatform.system}.cursor-tracker];
        environment = {
          QS_ICON_THEME = "Colloid-Dark";
          XDG_DATA_DIRS = "/run/current-system/sw/share";
        };
      };
      # Bar shell: workspaces, launcher (Super tap via super-monitor.pl),
      # tray, settings UI, weather. Needs perl (super-monitor), qs on PATH
      # (its IPC toggle), curl (weather), wl-copy + xdg-open (launcher).
      qs-bar = mkDaemon {
        command = "${pkgs.quickshell}/bin/quickshell -p ${qs.bar}/shell.qml";
        path = with pkgs; [bash coreutils perl curl wl-clipboard xdg-utils quickshell];
        environment = {
          QS_ICON_THEME = "Colloid-Dark";
          XDG_DATA_DIRS = "/run/current-system/sw/share";
        };
      };
      pibble = mkDaemon {
        command = "${self.packages.${pkgs.stdenv.hostPlatform.system}.pibble}/bin/pibble";
        path = with pkgs; [bash coreutils procps systemd quickshell curl cliphist imagemagick matugen jq gtk3 flatpak wl-clipboard] ++ [qs.mujo];
        environment = {
          XDG_DATA_DIRS = pkgs.lib.concatStringsSep ":" [
            "/run/current-system/sw/share"
            "/var/lib/flatpak/exports/share"
            "/home/${user}/.local/share/flatpak/exports/share"
          ];
        };
      };
      wl-cliphist = {
        after = ["niri.service"];
        serviceConfig = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
          Restart = "always";
          RestartSec = 2;
        };
        wantedBy = ["graphical-session.target"];
        restartTriggers = ["/run/current-system"];
      };
      vicinae = mkDaemon {
        command = "${pkgs.coreutils}/bin/nice -n 19 ${pkgs.util-linux}/bin/ionice -c 3 ${pkgs.vicinae}/bin/vicinae server --replace";
        path = with pkgs; [bash coreutils findutils gnugrep gnused flatpak mullvad-vpn python3];
        environment.XDG_DATA_DIRS = pkgs.lib.concatStringsSep ":" [
          "/run/current-system/sw/share"
          "/var/lib/flatpak/exports/share"
          "/home/${user}/.local/share/flatpak/exports/share"
        ];
      };
      steam-shortcuts = {
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = steamShortcutSync;
          Restart = "on-failure";
          RestartSec = 30;
        };
        path = with pkgs; [coreutils gnused gnugrep gawk];
        before = ["vicinae.service"];
        partOf = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];
        restartTriggers = ["/run/current-system"];
      };
    };
    system.activationScripts.quickshell = pkgs.lib.mkAfter ''
      if [ -d /run/user/${uid} ] && \
         systemctl --machine=${user}@ --user is-active graphical-session.target >/dev/null 2>&1; then
        systemctl --machine=${user}@ --user daemon-reload 2>/dev/null || true
        ${pkgs.lib.concatMapStringsSep "\n" (svc: ''
          systemctl --machine=${user}@ --user restart ${svc}.service 2>/dev/null || true
        '') daemons}
      fi
    '';
  };
}
