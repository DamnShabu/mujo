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

      self.nixosModules.flatpak

      self.nixosModules.opencode
      self.nixosModules.pi-coding-agent
      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.obsidian
      self.nixosModules.steam
      self.nixosModules.telegram
      self.nixosModules.gaming
      self.nixosModules.virt
      self.nixosModules.searxng
      self.nixosModules.user-config
      self.nixosModules.user
      self.nixosModules.sops
      self.nixosModules.keys
      self.nixosModules.mullvad
      self.nixosModules.connections
      self.nixosModules.notifications

      self.nixosModules.quickshell

      self.nixosModules.extra_plymouth

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain

      # flatpak management
      inputs.nix-flatpak.nixosModules.nix-flatpak

    ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    programs.corectrl.enable = true;
    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    system.stateVersion = "25.11";
  };
}
