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
  in {
    imports = [
      inputs.ambxst.nixosModules.default
    ];

    persistence.data.directories = [
      ".config/ambxst"
      ".local/share/ambxst"
    ];

    # Safeguard: ensure ~/.local/share/ambxst/niri.kdl stub exists before Niri starts
    system.activationScripts.ambxstInit = lib.stringAfter ["users"] ''
      mkdir -p /home/${user}/.local/share/ambxst
      touch /home/${user}/.local/share/ambxst/niri.kdl
      chown -R ${user}:users /home/${user}/.local/share/ambxst
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
