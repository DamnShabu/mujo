{inputs, self, ...}: {
  flake.nixosModules.desktop = {pkgs, config, lib, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [
      self.nixosModules.gtk
      self.nixosModules.vicinae

      self.nixosModules.pipewire
      self.nixosModules.zen

      inputs.silentSDDM.nixosModules.default
    ];

    services.xserver.enable = true;

    environment.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";
    };

    services.xserver.xrandrHeads = [
      {
        output = "DP-1";
        primary = true;
        monitorConfig = ''
          Option "PreferredMode" "1920x1080_165.00"
          Option "Position" "0x1080"
        '';
      }
      {
        output = "HDMI-A-1";
        monitorConfig = ''
          Option "PreferredMode" "1920x1080_60.00"
          Option "Position" "0x0"
        '';
      }
    ];

    services.xserver.inputClassSections = [
      ''
        Identifier "Set cursor theme"
        MatchIsPointer "on"
        Option "XcursorTheme" "Bibata-Modern-Classic"
        Option "XcursorSize" "24"
      ''
    ];

    programs.silentSDDM = {
      enable = true;
      theme = "nord";
    };

    services.displayManager.sddm.settings = {
      General.GreeterEnvironment = lib.mkForce
        "QML2_IMPORT_PATH=${config.programs.silentSDDM.package'}/share/sddm/themes/silent/components/:${pkgs.kdePackages.qtvirtualkeyboard}/lib/qt-6/qml,QT_IM_MODULE=qtvirtualkeyboard,XCURSOR_THEME=Bibata-Modern-Classic,XCURSOR_SIZE=24,XCURSOR_PATH=${pkgs.bibata-cursors}/share/icons";
      Input.XCursorTheme = "Bibata-Modern-Classic";
      Users.DefaultFace = "/home/${config.preferences.user.name}/.face.icon";
    };

    services.displayManager.sddm.setupScript = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --auto --output HDMI-A-1 --off
      ${pkgs.mpv}/bin/mpv --no-video --no-terminal --audio-device=alsa/hw:0,0 ${self}/sounds/startup-sound1.mp3 &
    '';

    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
      pkgs.wl-clipboard
      pkgs.xdg-utils
      pkgs.age
      pkgs.sops
      pkgs.cava
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };

    time.timeZone = config.preferences.locale.timeZone;
    i18n.defaultLocale = config.preferences.locale.default;
    i18n.extraLocaleSettings = config.preferences.locale.extra;

    xdg.mime = {
      enable = true;
      defaultApplications = {
        "text/html" = ["app.zen_browser.zen.desktop"];
        "x-scheme-handler/http" = ["app.zen_browser.zen.desktop"];
        "x-scheme-handler/https" = ["app.zen_browser.zen.desktop"];
        "application/pdf" = ["app.zen_browser.zen.desktop"];
        "image/png" = ["org.gimp.GIMP.desktop"];
        "image/jpeg" = ["org.gimp.GIMP.desktop"];
        "image/gif" = ["org.gimp.GIMP.desktop"];
        "image/webp" = ["org.gimp.GIMP.desktop"];
        "image/bmp" = ["org.gimp.GIMP.desktop"];
        "image/svg+xml" = ["org.gimp.GIMP.desktop"];
        "text/markdown" = ["md.obsidian.Obsidian.desktop"];
        "text/plain" = ["org.gnome.TextEditor.desktop" "kitty.desktop"];
        "inode/directory" = ["pcmanfm.desktop"];
        "x-scheme-handler/file" = ["pcmanfm.desktop"];
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop"];
        "x-scheme-handler/spotify" = ["spotify.desktop"];
      };
    };

    security.polkit.enable = true;

    hardware = {
      enableAllFirmware = true;

      bluetooth.enable = true;

      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
