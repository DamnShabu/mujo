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

  flake.nixosModules.hostMain = {
    pkgs,
    config,
    lib,
    ...
  }: {
    imports = [
      ./_boot.nix
      ./_networking.nix
      ./_hardware-and-services.nix

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
      self.nixosModules.discord
      self.nixosModules.obsidian
      self.nixosModules.steam
      self.nixosModules.telegram
      self.nixosModules.gaming
      self.nixosModules.user-config
      self.nixosModules.user
      self.nixosModules.mullvad

      self.nixosModules.notifications
      self.nixosModules.quickshell
      self.nixosModules.keyring-prompter

      self.nixosModules.vaultwarden

      self.nixosModules.plymouth

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain

      # flatpak management
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

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
