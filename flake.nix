{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Fast-moving packages (claude-code, antigravity); bump alone with
    # `nix flake lock --update-input unstable`.
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # The framework I use to structure the flake, module imports are automatic via custom function below
    flake-parts.url = "github:hercules-ci/flake-parts";

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    # Secure Boot: signs the kernel/initrd/stub with our own PKI so the firmware
    # will only load a boot chain we produced. Replaces GRUB (which let anyone at
    # the machine press "e" and boot init=/bin/sh).
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative NixOS MicroVMs. Backs the QUARANTINE trust state: an
    # untrusted application runs behind a KVM boundary rather than a namespace
    # one. See nixos/apps/microvm.nix.
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    herdr = {
      url = "github:herdrdev/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
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
        [./modules/flake/theme.nix ./modules/flake/perSystem.nix]
        ++ importTree ./nixos
        ++ importTree ./modules/wrappers;
    };
}
