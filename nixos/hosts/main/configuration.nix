{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.main = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs self;
    };
    modules = [
      self.nixosModules.hostMain
    ];
  };

  flake.nixosModules.hostMain = {lib, ...}: {
    imports = [
      ./_boot.nix
      ./_networking.nix
      ./_hardware-and-services.nix
      ./_gpu.nix

      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.ui-overrides

      self.nixosModules.impermanence
      self.nixosModules.user-persistence
      self.nixosModules.system-preferences

      self.nixosModules.flatpak

      self.nixosModules.opencode
      self.nixosModules.claude-code
      self.nixosModules.antigravity-cli
      self.nixosModules.antigravity-ide
      self.nixosModules.cutefetch
      self.nixosModules.herdr
      self.nixosModules.helium
      self.nixosModules.discord
      self.nixosModules.obsidian
      self.nixosModules.steam
      self.nixosModules.telegram
      self.nixosModules.gaming
      self.nixosModules.roblox-manager
      self.nixosModules.vm
      self.nixosModules.user-config
      self.nixosModules.user
      self.nixosModules.mullvad
      self.nixosModules.quiet

      self.nixosModules.notifications
      self.nixosModules.quickshell
      self.nixosModules.ambxst
      self.nixosModules.skwd-wall
      self.nixosModules.keyring-prompter
      self.nixosModules.psst
      self.nixosModules.keyd
      self.nixosModules.greeting

      self.nixosModules.vaultwarden

      # Mujo 2.0 Security Architecture Subsystems
      self.nixosModules.security-baseline
      self.nixosModules.security-kernel
      self.nixosModules.security-boot
      self.nixosModules.security-storage
      self.nixosModules.security-network
      self.nixosModules.security-users
      self.nixosModules.security-devices
      self.nixosModules.security-audit
      self.nixosModules.security-privacy
      self.nixosModules.security-vault
      self.nixosModules.security-broker
      self.nixosModules.security-mineral
      self.nixosModules.app-trust
      self.nixosModules.app-native-sandbox
      self.nixosModules.app-microvm
      self.nixosModules.app-dev-sandbox
      self.nixosModules.app-sandbox

      self.nixosModules.plymouth

      # MicroVM host: provides microvm@<name>.service, virtiofsd and the
      # `microvm` runner user that nixos/apps/microvm.nix builds on.
      inputs.microvm.nixosModules.host

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain

      # flatpak management
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    # ambxst is the shell now (nixos/desktop/ambxst.nix).
    services.qs-bar.enable = false;

    # apps.trust.launcherIntegration stays off, deliberately. With it on, every
    # application the launcher starts goes through `mujo-trust run`, so anything
    # not yet graduated boots the 4 GB quarantine MicroVM the first time it is
    # clicked — on the only machine this config is applied to. Walk
    # docs/application-trust.md §8 (graduate the applications you use daily,
    # confirm `mujo trust list`) before flipping `trust.launcherIntegration` in
    # nixos/core/system-preferences.json, its only definition: a second
    # mkDefault here made that switch a build error.

    # Quiet mode (Mod+Ctrl+P): displays, RGB and fans off until the next input.
    # Board-specific knobs -- a pump header to keep running, a USB screen --
    # are described in nixos/services/quiet.nix.
    services.mujo-quiet.enable = true;

    secrets.vaultwarden.enable = true;
    # Wired but inert until secrets are declared. Usage shape:
    #   secrets.vaultwarden.files.myservice = { item = "my-item"; field = "password"; type = "login"; };
    #   secrets.vaultwarden.sshKeys.main = { item = "real-ssh-item"; field = "notes"; };
    #   secrets.vaultwarden.gpgKeys.main = { item = "real-gpg-item"; field = "notes"; };

    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    system.stateVersion = "25.11";
  };
}
