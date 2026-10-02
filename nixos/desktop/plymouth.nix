{self, ...}: {
  flake.nixosModules.plymouth = {pkgs, ...}: let
    themeDir = "${self}/nixos/desktop/plymouth";
    themeName = "nixos-mac-style";

    theme = pkgs.runCommand "${themeName}-theme" {} ''
      mkdir -p $out/share/plymouth/themes/${themeName}
      cp ${themeDir}/nixos-mac-style.plymouth $out/share/plymouth/themes/${themeName}/${themeName}.plymouth
      cp ${themeDir}/images/* $out/share/plymouth/themes/${themeName}/
      substituteInPlace $out/share/plymouth/themes/${themeName}/${themeName}.plymouth \
        --replace-fail '/usr/share/plymouth/themes/nixos-mac-style' \
                       "$out/share/plymouth/themes/${themeName}"
    '';
  in {
    boot.plymouth = {
      enable = true;
      theme = themeName;
      themePackages = [theme];
      # The initrd carries exactly this one font file.
      font = "${self.packages.${pkgs.stdenv.hostPlatform.system}.monocraft-nerd}/share/fonts/truetype/Monocraft-nerd-fonts-patched.ttc";
    };
  };
}
