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
      formatter = pkgs.alejandra;

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
      packages.quicksnip = qs.mujo-screenshot;

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

      # preload 0.6.4 was removed from nixpkgs ("removed due to lack of usage
      # and being broken"), so it is vendored here. Base: the last nixpkgs
      # derivation before removal (pkgs/by-name/pr/preload at
      # ee09932cedcef15aaf476f9343d1dea2cb77e261, 2025-11-23), which builds
      # against modern glibc/glib. The patch prevents the install rules from
      # creating /var directories during the build. Added (vs. upstream): a
      # $out/bin/preloadd symlink, the Debian-style daemon name used by
      # nixos/features/preload.nix.
      packages.preload = pkgs.stdenv.mkDerivation rec {
        pname = "preload";
        version = "0.6.4";

        src = pkgs.fetchzip {
          url = "mirror://sourceforge/preload/preload-${version}.tar.gz";
          hash = "sha256-vAIaSwvbUFyTl6DflFhuSaMuX9jPVBah+Nl6c/fUbAM=";
        };

        patches = [
          # Prevents creation of /var directories on build
          ../preload/0001-prevent-building-to-var-directories.patch
        ];

        nativeBuildInputs = with pkgs; [
          autoconf
          automake
          pkg-config
        ];
        buildInputs = [pkgs.glib];

        configureFlags = ["--localstatedir=/var"];

        postInstall = ''
          make sysconfigdir=$out/etc/conf.d install
          mkdir -p $out/bin
          ln -s ../sbin/preload $out/bin/preloadd
        '';

        meta = with lib; {
          description = "Makes applications run faster by prefetching binaries and shared objects";
          homepage = "https://sourceforge.net/projects/preload";
          license = licenses.gpl2Only;
          platforms = lib.platforms.linux;
          mainProgram = "preload";
        };
      };
    };
  };
}
