{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.ambxst = {
    pkgs,
    config,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
    cfg = config.programs.ambxst;
    generationTrigger = self.rev or self.dirtyRev or "unknown";
    origPkg = inputs.ambxst.packages.${pkgs.stdenv.hostPlatform.system}.default;
    patchedShellSrc = pkgs.applyPatches {
      name = "ambxst-shell-patched";
      src = inputs.ambxst;
      patches = [
        ./ambxst-autosave.patch
      ];
      # Default fonts for a fresh ~/.config/ambxst; an existing theme.json wins.
      postPatch =
        ''
          substituteInPlace config/defaults/theme.js config/Config.qml \
            --replace-fail '"Roboto Condensed"' '"Monocraft"' \
            --replace-fail '"Iosevka Nerd Font Mono"' '"Monocraft"'
        ''
        # Unlock hook for the greeting popup (nixos/desktop/greeting.nix).
        + lib.optionalString (config.desktop.greeting.enable or false) ''
          substituteInPlace modules/globals/GlobalStates.qml \
            --replace-fail "    property bool lockscreenVisible: false" \
            "$(cat ${pkgs.replaceVars ./ambxst-greeting-hook.qml.in {
            greeting = "${config.desktop.greeting.package}/bin/mujo-greeting";
          }})"
        '';
    };
  in {
    imports = [
      inputs.ambxst.nixosModules.default
    ];

    programs.ambxst.package = lib.mkForce (pkgs.symlinkJoin {
      name = "ambxst-${origPkg.version or "1.3.8"}";
      paths = [origPkg];
      postBuild = ''
        rm $out/bin/ambxst
        sed "s|export AMBXST_SHELL=.*|export AMBXST_SHELL=\"${patchedShellSrc}\"|" ${origPkg}/bin/ambxst > $out/bin/ambxst
        chmod +x $out/bin/ambxst
        # Drop the nm-applet/blueman tray widgets; the binaries stay installed.
        rm -rf $out/etc
        cp -rs --no-preserve=mode ${origPkg}/etc/ $out/etc
        rm $out/etc/xdg/autostart/{nm-applet,blueman}.desktop
      '';
    });

    persistence.data.directories = [
      ".config/ambxst"
      ".local/share/ambxst"
      ".local/state/ambxst"
      ".local/share/ambxst-notes"
    ];

    persistence.cache.directories = [
      ".cache/ambxst"
    ];

    # niri's config includes ~/.local/share/ambxst/niri.kdl, and a missing
    # include makes niri reject the *whole* config and run on its built-in
    # defaults (alacritty/fuzzel binds, none of ours). ambxst only writes the
    # file once it runs, so a stub has to exist before niri starts.
    #
    # It goes into the persisted copy: ~/.local/share/ambxst is bind-mounted
    # from /persist after activation, so a stub created in the tmpfs home was
    # covered by an empty directory on every fresh install.
    system.activationScripts.ambxstInit = lib.stringAfter ["users" "createPersistentStorageDirs"] ''
      for d in /home/${user}/.local/share/ambxst ${lib.optionalString config.persistence.enable "/persist/userdata/home/${user}/.local/share/ambxst"}; do
        mkdir -p "$d"
        [ -e "$d/niri.kdl" ] || touch "$d/niri.kdl"
        chown ${user}:users "$d" "$d/niri.kdl"
      done
    '';

    systemd.user.services.ambxst = {
      description = "Ambxst Shell Daemon";
      after = ["niri.service" "graphical-session.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      path = with pkgs; [
        "/run/wrappers"
        "/run/current-system/sw"
      ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/ambxst";
        Restart = "always";
        RestartSec = 2;
      };
      restartTriggers = [generationTrigger];
    };

    systemd.user.targets.graphical-session.upholds = ["ambxst.service"];
  };
}
