{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # force rebuild 1784607705
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # The framework I use to structure the flake, module imports are automatic via custom function below
    flake-parts.url = "github:hercules-ci/flake-parts";

    impermanence.url = "github:nix-community/impermanence";
    persist-retro.url = "github:Geometer1729/persist-retro";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming.url = "github:fufexan/nix-gaming";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    sops-nix.url = "github:Mic92/sops-nix";

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi-flake.url = "github:ChauDucToan/pi-flake";

  };

  # Import flake-parts modules from specific directories for clarity and safety
  outputs = inputs: let
    inherit (inputs.nixpkgs) lib;
    inherit (lib.fileset) toList fileFilter;

    isNixModule = file:
      file.hasExt "nix"
      && file.name != "flake.nix"
      && !lib.hasPrefix "_" file.name;

    importTree = path:
      toList (fileFilter isNixModule path);

    mkFlake = inputs.flake-parts.lib.mkFlake {inherit inputs;};
  in
    mkFlake {
      imports =
        [ ./modules/theme.nix ./modules/perSystem.nix ]
        ++ importTree ./nixos
        ++ importTree ./modules/wrappers;
    };
}
