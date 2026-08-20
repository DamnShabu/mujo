{self, pkgs}: let
  shell = ./Shell.qml;
  wallpaper = ./Wallpaper.qml;
in {
  inherit shell wallpaper;

  # Full bar shell (workspaces, launcher, tray, settings, weather).
  # Whole tree is copied so super-monitor.pl finds shell.qml next to it
  # and QML relative imports (./modules/bar/modules) resolve.
  bar = pkgs.runCommand "quickshell-bar" {} ''
    mkdir -p "$out"
    cp -r ${./bar}/. "$out/"
    chmod +x "$out/super-monitor.pl"
  '';

  mujo = pkgs.writeShellScriptBin "mujo" (builtins.readFile ./mujo.sh);

  combined = pkgs.runCommand "quickshell-combined" {} ''
    mkdir -p "$out"
    cp ${shell}  "$out/Shell.qml"
    cp ${wallpaper} "$out/Wallpaper.qml"
  '';
}
