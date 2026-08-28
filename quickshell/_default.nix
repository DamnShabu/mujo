{
  self,
  pkgs,
  inputs ? self.inputs or {},
}: let
  # Upstream `tesseract` ships every traineddata file there is — 1014 MB of OCR
  # models — for a tool whose configured default is `eng+ukr`
  # (mujo-screenshot.sh). Restrict it to the language surface the UI actually
  # offers: the nine translation targets in
  # bar/modules/screenshot/TranslateCard.qml, plus ukr (the OCR default), rus,
  # and osd (orientation/script detection). 1014 MB -> 276 MB, and nothing the
  # user can pick stops working.
  tesseract = pkgs.tesseract.override {
    enableLanguages = [
      "osd"
      "eng"
      "ukr"
      "rus"
      "deu"
      "spa"
      "fra"
      "ita"
      "pol"
      "jpn"
      "chi_sim"
      "chi_tra"
    ];
  };

  # The screenshot / OCR / translate toolset. Only `mujo-screenshot` needs it:
  # `mujo screenshot` just execs mujo-screenshot (mujo.sh:2258), so keeping the
  # OCR stack out of `mujo`'s own PATH costs nothing and saves ~1 GB of closure.
  screenshotTools = [
    pkgs.grim
    pkgs.imagemagick
    tesseract
    pkgs.translate-shell
    pkgs.wl-clipboard
    pkgs.libnotify
  ];

  qmlImportPath = pkgs.lib.makeSearchPath "lib/qt-6/qml" (
    (with pkgs.qt6; [qtmultimedia qtdeclarative qtwayland qt5compat])
    ++ [pkgs.quickshell inputs.qml-niri.packages.${pkgs.stdenv.hostPlatform.system}.default]
  );

  # The shell UI tree: the bar (workspaces, launcher, tray, wallpaper, …) and
  # the standalone Settings app (bar/settings.qml). Whole tree is copied so QML
  # relative imports (./modules/bar/modules) and sibling scripts (llm-usage.sh)
  # resolve next to the entry points. The Settings app lives inside this tree so
  # it reuses the same Theme.qml — one source of truth for the palette.
  bar = pkgs.runCommand "quickshell-bar" {} ''
    mkdir -p "$out"
    cp -r ${./bar}/. "$out/"
  '';
in {
  inherit bar;

  # `mujo` CLI. Wrapped with jq/coreutils on PATH so it works both under the
  # qs-bar systemd unit and when spawned from a niri keybind / interactive shell.
  mujo = pkgs.runCommand "mujo" {nativeBuildInputs = [pkgs.makeWrapper];} ''
    install -Dm755 ${./mujo.sh} $out/bin/mujo
    wrapProgram $out/bin/mujo \
      --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.jq pkgs.gawk pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.curl pkgs.findutils pkgs.procps pkgs.git pkgs.util-linux pkgs.tmux pkgs.pulseaudio pkgs.power-profiles-daemon pkgs.cliphist pkgs.wl-clipboard pkgs.libnotify pkgs.xdg-utils pkgs.quickshell]}
  '';

  # Standalone Screenshot tool with OCR and Translation. Reuses the `bar`
  # derivation rather than copying the tree a second time — the copy used to
  # double a 2.5 GiB closure for one QML entry point.
  mujo-screenshot = pkgs.runCommand "mujo-screenshot" {nativeBuildInputs = [pkgs.makeWrapper];} ''
    install -Dm755 ${./mujo-screenshot.sh} $out/libexec/mujo-screenshot.sh
    makeWrapper $out/libexec/mujo-screenshot.sh $out/bin/mujo-screenshot \
      --prefix PATH : ${pkgs.lib.makeBinPath ([pkgs.quickshell pkgs.jq pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.procps pkgs.findutils pkgs.curl pkgs.wtype] ++ screenshotTools)} \
      --set QML2_IMPORT_PATH "${qmlImportPath}" \
      --set MUJO_SCREENSHOT_QML "${bar}/screenshot.qml"
  '';

  # Keyring CRUD over the Secret Service (gnome-keyring) for the Settings
  # Keyring panel. Python + secretstorage (D-Bus), the native credential store.
  mujo-keyring = pkgs.runCommand "mujo-keyring" {nativeBuildInputs = [pkgs.makeWrapper];} ''
    install -Dm755 ${./keyring/mujo-keyring.py} $out/libexec/mujo-keyring.py
    makeWrapper ${pkgs.python3.withPackages (ps: [ps.secretstorage])}/bin/python3 \
      $out/bin/mujo-keyring --add-flags "$out/libexec/mujo-keyring.py"
  '';

  # Wallpaper Engine backend helper for Steam Workshop search, details,
  # local project scanning, and process management.
  mujo-wallpaper-engine = pkgs.runCommand "mujo-wallpaper-engine" {nativeBuildInputs = [pkgs.makeWrapper];} ''
    install -Dm755 ${./wallpaper-engine/mujo-wallpaper-engine.py} $out/libexec/mujo-wallpaper-engine.py
    makeWrapper ${pkgs.python3}/bin/python3 \
      $out/bin/mujo-wallpaper-engine --add-flags "$out/libexec/mujo-wallpaper-engine.py"
  '';

  # Small C helper that reads raw mouse input events from /dev/input and
  # outputs normalised cursor positions as JSON.  Used by Wallpaper.qml's
  # zoom/pan effect when effects.motion is enabled.
  cursor-tracker = pkgs.stdenv.mkDerivation {
    pname = "cursor-tracker";
    version = "0.1.0";
    src = ./cursor-tracker;
    buildPhase = ''
      $CC -O2 -o cursor-tracker cursor-tracker.c
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp cursor-tracker $out/bin/
    '';
  };

  # PAM auth helper for the lock screen (WP-14). Reads a password on stdin,
  # authenticates the current user via the `qsshell-lock` PAM service, exits 0/1.
  # Not setuid — pam_unix uses the setuid unix_chkpwd for the shadow check.
  unlock = pkgs.stdenv.mkDerivation {
    pname = "qsshell-unlock";
    version = "0.1.0";
    src = ./unlock;
    buildInputs = [pkgs.pam];
    buildPhase = ''
      $CC -O2 -o qsshell-unlock unlock.c -lpam
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp qsshell-unlock $out/bin/
    '';
  };
}
