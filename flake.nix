{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The framework I use to structure the flake, module imports are automatic via custom function below
    flake-parts.url = "github:hercules-ci/flake-parts";

    impermanence.url = "github:nix-community/impermanence";
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

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri IPC QML plugin for quickshell shells; exposed on the QML import
    # path in nixos/features/quickshell.nix.
    qml-niri = {
      url = "github:imiric/qml-niri/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
    };

    thyx = {
      url = "github:rccyx/thyx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # cachix/secretspec ships no flake.nix (devenv only), so this is a source
    # input; the binary is built from it via rustPlatform.buildRustPackage in
    # nixos/features/vaultwarden.nix with only the `cli` + `bw` features.
    secretspec = {
      url = "github:cachix/secretspec/v0.18.0";
      flake = false;
    };

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
