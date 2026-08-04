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
      packages.cursor-tracker = pkgs.stdenv.mkDerivation {
        pname = "cursor-tracker";
        version = "0.1";
        src = ../quickshell/cursor-tracker;
        nativeBuildInputs = [pkgs.linuxHeaders];
        buildPhase = "cc -O2 -o cursor-tracker cursor-tracker.c";
        installPhase = "mkdir -p $out/bin && cp cursor-tracker $out/bin/";
      };

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

      packages.phisch-psst = pkgs.rustPlatform.buildRustPackage rec {
        pname = "psst";
        version = "0.2.0";
        src = pkgs.fetchFromGitHub {
          owner = "phisch";
          repo = "psst";
          rev = "v${version}";
          hash = "sha256-yZ0oHKQ4VEZRXxNCVFIumKMT/wIfGt+o/gwubk8u4sU=";
        };
        cargoLock.lockFile = "${src}/Cargo.lock";
        nativeBuildInputs = with pkgs; [
          pkg-config
          makeWrapper
          cmake
          clang
        ];
        buildInputs = with pkgs; [
          wayland
          wayland-protocols
          libxkbcommon
          fontconfig
          freetype
          libGL
          vulkan-loader
          openssl
          systemd
        ] ++ lib.optionals pkgs.stdenv.isLinux [
          pkgs.alsa-lib
        ];
        postFixup = let
          libPath = lib.makeLibraryPath [pkgs.wayland pkgs.libglvnd pkgs.mesa pkgs.vulkan-loader];
        in ''
          for bin in $out/bin/*; do
            wrapProgram "$bin" --prefix LD_LIBRARY_PATH : "${libPath}"
          done
        '';
        meta.platforms = lib.platforms.linux;
      };
    };
  };
}
