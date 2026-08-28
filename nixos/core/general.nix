{self, ...}: {
  flake.nixosModules.general = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.hjem
      self.nixosModules.nix
    ];

    users.users.${config.preferences.user.name} = {
      isNormalUser = true;
      description = "${config.preferences.user.name}'s account";
      extraGroups = ["wheel" "networkmanager" "input" "docker" "systemd-journal"];
      shell = self.packages.${pkgs.stdenv.hostPlatform.system}.environment;

      hashedPasswordFile = "/persist/passwd";
    };

    # ponytail: allow passwordless activation for nh (nixos-rebuild activate)
    security.sudo.extraRules = [
      {
        users = [config.preferences.user.name];
        runAs = "root";
        commands = [
          {
            command = "/nix/store/*-nixos-system-*/bin/nixos-rebuild";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    environment.shells = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.environment
    ];

    documentation.info.enable = false;

    persistence.data.directories = [
      "nixconf"

      "Pictures"
      "Videos"
      "Documents"
      "Downloads"
      "Projects"
      "Desktop"

      ".ssh"

      ".local/share/applications"
      ".config/quickshell"
      ".local/state/quickshell"
      ".config/Code"
      ".gemini"
      ".agents"
      ".var/app"

      ".config/dconf"
      ".config/gtk-3.0"
      ".config/gtk-4.0"
      ".config/qt6ct"
    ];

    system.activationScripts."create-initial-face" = {
      deps = ["createPersistentStorageDirs"];
      text = ''
        targetDir="/persist/userdata/home/${config.preferences.user.name}"
        mkdir -p "$targetDir"
        chown "${config.preferences.user.name}" "$targetDir"
      '';
    };

    persistence.cache.directories = [
      ".local/share/zoxide"
      ".local/share/direnv"
      ".local/share/fish"
    ];
  };
}
