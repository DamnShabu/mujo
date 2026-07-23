{inputs, ...}: {
  flake.nixosModules.nix = {pkgs, lib, ...}: {
    imports = [
      inputs.nix-index-database.nixosModules.nix-index
    ];
    programs.nix-index-database.comma.enable = true;

    programs.direnv = {
      enable = true;
      silent = false;
      loadInNixShell = true;
      direnvrcExtra = "";
      nix-direnv = {
        enable = true;
      };
    };

    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
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
    ];

    system.activationScripts.addDiffutilsToActivationPath = {
      text = ''
        if command -v cmp >/dev/null 2>&1; then
          echo "cmp already available" >&2
        else
          export PATH="${pkgs.diffutils}/bin:$PATH"
        fi
      '';
    };

    system.activationScripts.piCodingAgentConfig = {
      deps = lib.mkBefore [ "addDiffutilsToActivationPath" ];
    };
  };
}
