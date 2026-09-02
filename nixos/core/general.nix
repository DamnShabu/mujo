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

    # Passwordless `nh os switch`.
    #
    # Ceiling, stated plainly because it is easy to read this as narrower than
    # it is: `nixos-rebuild` is root-equivalent by construction. Anything that
    # can run it without a password can build and activate a generation
    # containing a root shell, so this rule grants the user passwordless root,
    # not merely passwordless rebuild. Narrowing the glob would not change that
    # -- and the glob is not much of a fence either, since any user who can talk
    # to the nix daemon can realise a store path matching `*-nixos-system-*`.
    #
    # What it costs: the sudo password prompt is the boundary that stands
    # between an application running as this user and root. docs/threat-model.md
    # A3 (a graduated application that is later compromised) is weaker for it,
    # and the sudo hardening in nixos/security/users.nix -- timestamp_timeout=5,
    # passwd_tries=3 -- does not apply on this path.
    #
    # Kept because it is a deliberate convenience trade for the machine's only
    # user, not because it is safe. Delete this block to take the prompt back;
    # nothing else depends on it.
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

    # The NixOS + Nix HTML manuals are ~50 MB and are rebuilt on every switch;
    # man pages stay, since those are what actually gets read at the terminal.
    documentation.info.enable = false;
    documentation.nixos.enable = false;
    documentation.doc.enable = false;

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
