{inputs, ...}: {
  imports = [
    inputs.wrapper-modules.flakeModules.wrappers
  ];

  config = {
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];

    perSystem = {pkgs, lib, system, ...}: {
      packages.quicksnip = let
        src = builtins.fetchGit {
          url = "https://github.com/DamnShabu/QuickSnip";
          ref = "refs/heads/main";
          rev = "3e1a3130ff36bf2f009dabedbe3d3edb1da7b62e";
        };
      in pkgs.writeShellApplication {
        name = "quicksnip";
        runtimeInputs = with pkgs; [
          quickshell
          grim
          imagemagick
          tesseract
          wl-clipboard
          curl
          libnotify
          xdg-utils
          wlrctl
          wtype
        ];
        text = ''
          export QT_SCALE_FACTOR=1
          export QT_AUTO_SCREEN_SCALE_FACTOR=0
          export QML2_IMPORT_PATH="${pkgs.lib.makeSearchPath "lib/qt-6/qml" (with pkgs.qt6; [qtmultimedia qtdeclarative qtwayland qt5compat] ++ [pkgs.quickshell])}"
          exec quickshell -p ${src} -n "$@"
        '';
      };

      packages.pibble = let
        src = pkgs.fetchgit {
          url = "https://github.com/kianblakley/pibble";
          rev = "a42dfb68a054edef3c8da214caaed6090a529ef1";
          hash = "sha256-LF/shphWEYDZj8JhChG76CCZ5fksqkBx/MHsE3qC2Xg=";
        };
        qmlPath = pkgs.lib.makeSearchPath "lib/qt-6/qml" (with pkgs.qt6; [qtmultimedia qtdeclarative qtwayland qt5compat] ++ [pkgs.quickshell]);
      in pkgs.runCommand "pibble" {} ''
        mkdir -p $out/bin
        cp -r ${src}/* $out/
        chmod +x $out/pibble
        echo '#!${pkgs.bash}/bin/bash' > $out/bin/pibble
        echo 'export QML2_IMPORT_PATH="${qmlPath}"' >> $out/bin/pibble
        echo 'export PIBBLE_DIR="${src}"' >> $out/bin/pibble
        echo 'exec "$PIBBLE_DIR/pibble" "$@"' >> $out/bin/pibble
        chmod +x $out/bin/pibble
      '';

      packages.skeuos-gtk = let
        src = pkgs.fetchFromGitHub {
          owner = "daniruiz";
          repo = "skeuos-gtk";
          rev = "095e06aa44c637af675850e421057c6f09b9f8d0";
          hash = "sha256-1HXrR9T5bSkLWYud/wMNZv+P9zgcC8xZ+d/RYMlekGc=";
        };
      in pkgs.runCommand "skeuos-gtk" {} ''
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
          ./preload/0001-prevent-building-to-var-directories.patch
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
