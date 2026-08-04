{self, pkgs}: let
  shell = ./Shell.qml;
  wallpaper = ./Wallpaper.qml;
  wizardEntry = ./wizard/Wizard.qml;
in {
  inherit shell wallpaper;


  mujo = pkgs.writeShellScriptBin "mujo" (builtins.readFile ./mujo.sh);

  combined = pkgs.runCommand "quickshell-combined" {} ''
    mkdir -p "$out"
    cp ${shell}  "$out/Shell.qml"
    cp ${wallpaper} "$out/Wallpaper.qml"
  '';

  wizard = pkgs.runCommand "quickshell-wizard" {} ''
    mkdir -p "$out/Wizard"
    cp ${wizardEntry} "$out/Wizard.qml"
    cp ${./wizard/qmldir} "$out/Wizard/qmldir"
    cp ${./wizard/WizardTheme.qml} "$out/Wizard/WizardTheme.qml"
    cp ${./wizard/WizardState.qml} "$out/Wizard/WizardState.qml"
    cp ${./wizard/WizField.qml} "$out/Wizard/WizField.qml"
    cp ${./wizard/PageIdentity.qml} "$out/Wizard/PageIdentity.qml"
    cp ${./wizard/PageMachine.qml} "$out/Wizard/PageMachine.qml"
    cp ${./wizard/PageSeal.qml} "$out/Wizard/PageSeal.qml"
  '';
}
