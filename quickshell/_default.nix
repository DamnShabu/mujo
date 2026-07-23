{self, pkgs}: let
  desktop = pkgs.replaceVars ./Desktop.qml {
    base02 = self.theme.base02; base03 = self.theme.base03; base05 = self.theme.base05;
    base0D = self.theme.base0D; ffmpeg = pkgs.ffmpeg; "wl-clipboard" = pkgs.wl-clipboard;
  };
  shell = pkgs.replaceVars ./Shell.qml {
    base00 = self.theme.base00; base02 = self.theme.base02; base03 = self.theme.base03;
    base04 = self.theme.base04; base05 = self.theme.base05; base08 = self.theme.base08;
    base09 = self.theme.base09; base0A = self.theme.base0A; base0B = self.theme.base0B;
    base0C = self.theme.base0C; base0D = self.theme.base0D; base0E = self.theme.base0E; base0F = self.theme.base0F;
  };
  wallpaper = ./Wallpaper.qml;
in {
  inherit desktop shell wallpaper;

  swayosdCSS = pkgs.replaceVars ./swayosd.css {
    base01 = self.theme.base01; base02 = self.theme.base02; base05 = self.theme.base05;
    base0D = self.theme.base0D; base0E = self.theme.base0E;
  };
  mujo = pkgs.writeShellScriptBin "mujo" (builtins.readFile ./mujo.sh);

  combined = pkgs.runCommand "quickshell-combined" {} ''
    mkdir -p "$out"
    cp ${shell}  "$out/Shell.qml"
    cp ${desktop} "$out/Desktop.qml"
    cp ${wallpaper} "$out/Wallpaper.qml"
  '';
}
