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
      packages.helium = inputs.helium.packages.${system}.default.overrideAttrs (old: {
        buildInputs = (old.buildInputs or []) ++ [pkgs.libpulseaudio];
        postFixup =
          (old.postFixup or "")
          + ''
            patchelf --add-rpath ${pkgs.libpulseaudio}/lib $out/opt/helium/helium
          '';
        preFixup =
          (old.preFixup or "")
          + ''
            gappsWrapperArgs+=(
              --prefix LD_LIBRARY_PATH : "${pkgs.libpulseaudio}/lib"
            )
          '';
      });
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

      # monocraft ships plain, no-ligature and nerd-patched .ttc files that all
      # claim the family "Monocraft"; keep only the nerd one so the family
      # always resolves to the variant with icon glyphs.
      packages.monocraft-nerd = pkgs.runCommand "monocraft-nerd-${pkgs.monocraft.version}" {} ''
        install -Dm444 ${pkgs.monocraft}/share/fonts/truetype/*-nerd-fonts-patched.ttc \
          $out/share/fonts/truetype/Monocraft-nerd-fonts-patched.ttc
      '';
      packages.mujo-screenshot = qs.mujo-screenshot;

      packages.skwd-deck-steamworks =lib.mkIf (system == "x86_64-linux") (let
        version = inputs.skwd-wall.packages.${system}.deck.version;
        sources = {
          "1.0.0-beta.17" = {
            url = "https://github.com/liixini/skwd-wall/releases/download/v1.0.0-beta.17/skwd-deck-steamworks-1.0.0_beta.17-1-x86_64.pkg.tar.zst";
            hash = "sha256-XRp9P4/BSTnO7L8KdMYpNgooirjmljJRptHkUQct6QI=";
          };
          "1.0.0-beta.18" = {
            url = "https://github.com/liixini/skwd-wall/releases/download/v1.0.0-beta.18/skwd-deck-steamworks-1.0.0_beta.18-1-x86_64.pkg.tar.zst";
            hash = "sha256-UT8CEDhV4iIG6qSz8xRyFTxL3ZROacn2vjaE6ee5QcM=";
          };
          "1.0.0-beta.23" = {
            url = "https://github.com/liixini/skwd-wall/releases/download/v1.0.0-beta.23/skwd-deck-steamworks-1.0.0_beta.23-1-x86_64.pkg.tar.zst";
            hash = "sha256-Jl0SOytpZyuKyQLmduexVC+seRVwINhza9vBcUTeOIo=";
          };
        };
        source = sources.${version} or (throw "Unsupported skwd-deck-steamworks version: ${version}");
      in
        unstable.stdenvNoCC.mkDerivation {
          pname = "skwd-deck-steamworks";
          inherit version;
          src = pkgs.fetchurl {
            inherit (source) url hash;
          };
          nativeBuildInputs = with pkgs; [autoPatchelfHook zstd];
          buildInputs = with pkgs; [stdenv.cc.cc.lib];
          unpackPhase = ''
            mkdir package
            tar --zstd -xf "$src" -C package
          '';
          installPhase = ''
            mkdir -p "$out"
            cp -a package/usr/. "$out/"
          '';
          meta = {
            description = "Steam Client Workshop backend for Skwd Deck";
            homepage = "https://github.com/liixini/skwd-wall";
            license = lib.licenses.unfree // {free = true;};
            platforms = ["x86_64-linux"];
            mainProgram = "skwd-steam";
          };
        });

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
