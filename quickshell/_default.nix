{self, pkgs}: let
  shell = ./Shell.qml;
  wallpaper = ./Wallpaper.qml;
in {
  inherit shell wallpaper;


  mujo = pkgs.writeShellScriptBin "mujo" (builtins.readFile ./mujo.sh);

  combined = pkgs.runCommand "quickshell-combined" {} ''
    mkdir -p "$out"
    cp ${shell}  "$out/Shell.qml"
    cp ${wallpaper} "$out/Wallpaper.qml"
  '';
}
