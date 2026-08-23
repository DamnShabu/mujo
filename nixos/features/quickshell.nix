{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.quickshell = {
    pkgs,
    config,
    lib,
    ...
  }: let
    qs = import ../../quickshell/_default.nix {inherit self pkgs;};

    qmlDeps = with pkgs.qt6; [qtmultimedia qtdeclarative qtwayland qt5compat] ++ [pkgs.quickshell inputs.qml-niri.packages.${pkgs.stdenv.hostPlatform.system}.default];
    qmlPath = pkgs.lib.makeSearchPath "lib/qt-6/qml" qmlDeps;
    qtPluginPath = pkgs.lib.makeSearchPath "lib/qt-6/plugins" qmlDeps;
    # Forces a restart on every switch where the flake's revision changed.
    # Can't use config.system.build.toplevel here: these services are part
    # of the toplevel closure, so referencing it back would be a cycle.
    generationTrigger = self.rev or self.dirtyRev or "unknown";
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
      environment =
        {
          QML2_IMPORT_PATH = qmlPath;
          QT_PLUGIN_PATH = qtPluginPath;
        }
        // environment;
      inherit path;
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      restartTriggers = [generationTrigger];
    };

    # Steam flatpak writes "create desktop shortcut" .desktop files into its
    # sandbox home (~/.var/app/com.valvesoftware.Steam/.local/share/applications)
    # with Exec=steam steam://rungameid/<id>, which no launcher can run (no
    # steam binary on PATH). Rewrite them into ~/.local/share/applications as
    # `flatpak run ...` so they get indexed and launched.
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
    daemons = ["qs-bar" "steam-shortcuts"];
    user = config.preferences.user.name;
    # Stable path the qs-bar shell is launched from. Both the systemd daemon and
    # the niri Mod+Space keybind (`qs -p <this> ipc call launcher toggle`)
    # reference it, so the launcher toggle reliably targets the running instance
    # regardless of the qs.bar store path, which changes on every rebuild. It is
    # an /etc symlink to qs.bar (see environment.etc below).
    barConfig = "/etc/xdg/quickshell/bar/shell.qml";
    # Where DesktopEntries / the launcher look for .desktop files. Must include the
    # flatpak export dirs, otherwise flatpak apps never show up in the launcher,
    # and the nix profile dirs so system + per-user nix apps show too. We set it
    # explicitly rather than inherit the session value because on early boot the
    # systemd user manager environment can still be truncated when qs-bar
    # starts, which silently drops most apps from the launcher. XDG_DATA_HOME
    # (~/.local/share) is scanned implicitly by Quickshell, covering user +
    # synced steam entries.
    appDataDirs = pkgs.lib.concatStringsSep ":" [
      "/run/current-system/sw/share"
      "/etc/profiles/per-user/${user}/share"
      "/home/${user}/.nix-profile/share"
      "/var/lib/flatpak/exports/share"
      "/home/${user}/.local/share/flatpak/exports/share"
    ];
  in {
    environment.sessionVariables.QML2_IMPORT_PATH = lib.mkForce qmlPath;
    environment.sessionVariables.QT_PLUGIN_PATH = lib.mkForce qtPluginPath;

    environment.systemPackages = [qs.mujo qs.mujo-keyring self.packages.${pkgs.stdenv.hostPlatform.system}.quicksnip];

    # PAM service the lock-screen helper (qs.unlock) authenticates against. A
    # bare service gets NixOS's default unix auth (pam_unix → setuid unix_chkpwd),
    # which is all the lock needs — same shape swaylock/hyprlock use.
    security.pam.services.qsshell-lock = {};

    # Expose the bar tree at a stable, rebuild-invariant path so the launcher
    # toggle keybind can address the running instance by config path, and the
    # Settings app (bar/settings.qml, spawned by `mujo settings` / Mod+,) can be
    # reached by path too.
    environment.etc."xdg/quickshell/bar".source = qs.bar;

    services.udev.extraRules = ''
      KERNEL=="event*", SUBSYSTEM=="input", MODE="0666"
    '';

    persistence.data.directories = [
      ".config/qsshell"
    ];

    systemd.user.services = {
      # The one shell: workspaces, launcher (Mod+Space via niri → qs ipc),
      # tray, settings UI, weather. Needs qs on PATH
      # (its IPC toggle), curl (weather), wl-copy + xdg-open (launcher), jq
      # (llm-usage.sh reads cached usage from provider config files).
      qs-bar = mkDaemon {
        command = "${pkgs.quickshell}/bin/quickshell -p ${barConfig}";
        # findutils (find/xargs) and sqlite (sqlite3) are required by
        # llm-usage.sh's Antigravity token-transcript scan — without them the
        # "Tokens by day/model" charts silently stay empty under the service
        # even though they work under an interactive `qs -p` (whose shell PATH
        # masks the gap).  gnugrep is needed for grep -oaP (PCRE).
        # systemd provides systemd-run, used by Launch.qml to spawn launched apps
        # in their own transient user scope (so they survive qs-bar restarts
        # instead of dying inside qs-bar's cgroup on every rebuild).
        # /run/current-system/sw must be on PATH (NixOS appends /bin to each
        # entry): systemd-run resolves the launched app's binary against this
        # service's PATH, and without it every app outside the package list
        # below (i.e. all normal desktop apps) silently fails with
        # "Failed to find executable <app>".
        path = with pkgs; [bash coreutils findutils gnugrep jq curl sqlite wl-clipboard cliphist xdg-utils systemd swayidle brightnessctl cava quickshell qs.cursor-tracker qs.unlock] ++ ["/run/current-system/sw"];
        environment = {
          QS_ICON_THEME = "Colloid-Dark";
          XDG_DATA_DIRS = appDataDirs;
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
        restartTriggers = [generationTrigger];
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
        partOf = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];
        restartTriggers = [generationTrigger];
      };
    };
    # Start (and keep started) the graphical daemons whenever
    # graphical-session.target is active. wantedBy alone only fires at login;
    # switch-to-configuration does not start brand-new user units mid-session,
    # and the previous root->user activation hook never worked. Upholds= is
    # re-evaluated on every user-manager daemon-reload, i.e. on every switch.
    systemd.user.targets.graphical-session.upholds = map (svc: "${svc}.service") daemons;
  };
}
