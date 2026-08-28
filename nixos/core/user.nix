{
  flake.nixosModules.user = {lib, ...}: let
    usernameFile = ../../secrets/username;
    usernameOverride =
      if builtins.pathExists usernameFile
      then lib.trim (builtins.readFile usernameFile)
      else "";
    finalName =
      if usernameOverride != ""
      then usernameOverride
      else "yurii";
  in {
    preferences.user.name = lib.mkDefault finalName;
    preferences.locale.timeZone = lib.mkDefault "Europe/Berlin";
  };
}
