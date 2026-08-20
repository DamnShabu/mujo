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

      self.nixosModules.impermanence

      self.nixosModules.preload

      self.nixosModules.flatpak
      
      self.nixosModules.opencode
      self.nixosModules.discord
      self.nixosModules.obsidian
      self.nixosModules.steam
      self.nixosModules.gaming
      self.nixosModules.user-config
      self.nixosModules.user
      self.nixosModules.mullvad

      self.nixosModules.notifications
      self.nixosModules.quickshell

      self.nixosModules.vaultwarden

      self.nixosModules.extra_plymouth

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain

      # flatpak management
      inputs.nix-flatpak.nixosModules.nix-flatpak

    ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    secrets.vaultwarden.enable = true;
    # Vendored package: preload was removed from nixpkgs, see
    # modules/perSystem.nix (packages.preload).
    services.preload.enable = true;
    services.preload.package = self.packages.${pkgs.stdenv.hostPlatform.system}.preload;
    # Wired but inert until secrets are declared. Usage shape:
    #   secrets.vaultwarden.files.myservice = { item = "my-item"; field = "password"; type = "login"; };
    #   secrets.vaultwarden.sshKeys.main = { item = "real-ssh-item"; field = "notes"; };
    #   secrets.vaultwarden.gpgKeys.main = { item = "real-gpg-item"; field = "notes"; };

    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    system.stateVersion = "25.11";
  };
}
