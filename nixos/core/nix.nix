{inputs, ...}: {
  flake.nixosModules.nix = {pkgs, ...}: {
    imports = [
      inputs.nix-index-database.nixosModules.nix-index
    ];
    programs.nix-index-database.comma.enable = true;
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      # auto-optimise-store is set from the Settings JSON in
      # nixos/core/system-preferences.nix (off). Setting it here as well
      # silently overrode that toggle.
      # max-jobs/cores are left at their defaults on purpose: they resolve to
      # "auto", which already scales down to a weak machine's core count.
    };

    nix.optimise.automatic = true;

    programs.direnv = {
      enable = true;
      silent = false;
      loadInNixShell = true;
      direnvrcExtra = "";
      nix-direnv = {
        enable = true;
      };
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    programs.nix-ld.enable = true;
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      # Nix tooling
      nil
      nixd
      statix
      alejandra
      manix
      nix-inspect
      mcp-nixos
      diffutils
      git
    ];
  };
}
