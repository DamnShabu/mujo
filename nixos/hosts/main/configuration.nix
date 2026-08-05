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
      self.nixosModules.user-config
      self.nixosModules.user
      # mullvad was deliberately removed from this host in the WIP refactor
      # (commit 3a69f50): re-enable via `self.nixosModules.mullvad` above.
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
    # Wired but inert until secrets are declared. Usage shape:
    #   secrets.vaultwarden.files.myservice = { item = "my-item"; field = "password"; type = "login"; };
    #   secrets.vaultwarden.sshKeys.main = { item = "real-ssh-item"; field = "notes"; };
    #   secrets.vaultwarden.gpgKeys.main = { item = "real-gpg-item"; field = "notes"; };

    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    system.stateVersion = "25.11";
  };
}
