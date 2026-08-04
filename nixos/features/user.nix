{
  flake.nixosModules.user = {lib, ...}: let
    wizardFile = ../../user-config/_user.nix;
    usernameFile = ../../secrets/username;
    wizardUser = if builtins.pathExists wizardFile then (import wizardFile).name or "yurii" else "yurii";
    wizardTz = if builtins.pathExists wizardFile then (import wizardFile).timezone or "Europe/Berlin" else "Europe/Berlin";
    usernameOverride = if builtins.pathExists usernameFile then lib.trim (builtins.readFile usernameFile) else "";
    finalName = if usernameOverride != "" then usernameOverride else wizardUser;
  in {
    # ponytail: wizard-written plaintext username overrides wizard username, which overrides default "yurii"
    preferences.user.name = lib.mkDefault finalName;
    preferences.locale.timeZone = lib.mkDefault wizardTz;
  };
}
