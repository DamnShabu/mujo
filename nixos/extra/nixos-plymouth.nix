{
  self,
  ...
}: {
  flake.nixosModules.extra_plymouth = {
    pkgs,
    lib,
    ...
  }: let
    themeDir = "${self}/nixos/extra/nixos-plymouth";
    themeName = "nixos-mac-style";

    theme = pkgs.runCommand "${themeName}-theme" {} ''
      mkdir -p $out/share/plymouth/themes/${themeName}/images
      cp ${themeDir}/nixos-mac-style.plymouth $out/share/plymouth/themes/${themeName}/${themeName}.plymouth
      cp ${themeDir}/images/* $out/share/plymouth/themes/${themeName}/images/
      substituteInPlace $out/share/plymouth/themes/${themeName}/${themeName}.plymouth \
        --replace '/usr/share/plymouth/themes/nixos-mac-style/images' \
                    "$out/share/plymouth/themes/${themeName}/images"
    '';
  in {
    boot.plymouth = {
      enable = true;
      theme = themeName;
      themePackages = [theme];
    };
  };
}
