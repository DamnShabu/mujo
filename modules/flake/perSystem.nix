{
  inputs,
  self,
  ...
}: {
  imports = [
    inputs.wrapper-modules.flakeModules.wrappers
  ];

  config = {
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];

    perSystem = {
      pkgs,
      lib,
      system,
      ...
    }: let
      unstable = import inputs.unstable {
        inherit system;
        config.allowUnfree = true;
      };
      qs = import ../../quickshell/_default.nix {inherit self pkgs;};
    in {
      # `nix fmt` invokes the formatter with no arguments, but alejandra reads
      # stdin when given no paths (i.e. hangs on a terminal); default it to `.`.
      formatter = pkgs.writeShellScriptBin "alejandra" ''
        exec ${lib.getExe pkgs.alejandra} "''${@:-.}"
      '';

      packages.antigravity-cli = unstable.antigravity-cli;
      packages.antigravity-ide = unstable.antigravity-ide;
      packages.claude-code = unstable.claude-code;
      packages.herdr = inputs.herdr.packages.${system}.default;
      packages.cutefetch = pkgs.stdenv.mkDerivation {
        name = "cutefetch";
        src = ../../tools/cutefetch/cutefetch;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/cutefetch
          chmod +x $out/bin/cutefetch
          ln -s cutefetch $out/bin/cf
        '';
      };

      packages.mujo-screenshot = qs.mujo-screenshot;

      packages.skeuos-gtk = let
        src = pkgs.fetchFromGitHub {
          owner = "daniruiz";
          repo = "skeuos-gtk";
          rev = "095e06aa44c637af675850e421057c6f09b9f8d0";
          hash = "sha256-1HXrR9T5bSkLWYud/wMNZv+P9zgcC8xZ+d/RYMlekGc=";
        };
      in
        pkgs.runCommand "skeuos-gtk" {} ''
          mkdir -p $out/share/themes
          cp -a ${src}/themes/Skeuos-Grey-Dark $out/share/themes/
        '';
    };
  };
}
