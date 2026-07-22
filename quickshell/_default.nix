{self, pkgs}: let
  t = self.theme;
  cavaConf = pkgs.writeText "cava-config" ''
    [general]
    framerate = 60
    bars = 40

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    bar_delimiter = 32
    frame_delimiter = 10
    ascii_max_range = 1000
  '';
in {
  desktop = pkgs.replaceVars ./desktop.qml {
    base02 = t.base02; base03 = t.base03; base05 = t.base05;
    base0D = t.base0D; ffmpeg = pkgs.ffmpeg; "wl-clipboard" = pkgs.wl-clipboard;
  };
  notifd = pkgs.replaceVars ./notifd.qml {
    base00 = t.base00; base02 = t.base02; base03 = t.base03;
    base04 = t.base04; base05 = t.base05; base08 = t.base08;
    base09 = t.base09; base0A = t.base0A; base0B = t.base0B;
    base0C = t.base0C; base0D = t.base0D; base0E = t.base0E; base0F = t.base0F;
  };
  visualizer = pkgs.replaceVars ./visualizer.qml {
    base02 = t.base02; base05 = t.base05;
    cavaConf = cavaConf;
  };
  wallpaper = ./wallpaper.qml;
  wallpaperBg = ./wallpaper-bg.qml;
  swayosdCSS = pkgs.replaceVars ./swayosd.css {
    base01 = t.base01; base02 = t.base02; base05 = t.base05;
    base0D = t.base0D; base0E = t.base0E;
  };
  mujo = pkgs.writeShellScriptBin "mujo" (builtins.readFile ./mujo.sh);
}
