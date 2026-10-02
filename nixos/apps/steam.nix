{
  flake.nixosModules.steam = {
    config,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
  in {
    services.flatpak.packages = ["com.valvesoftware.Steam"];

    hardware.steam-hardware.enable = true;

    # Flatpak isolates Steam into ~/.var/app/com.valvesoftware.Steam/.steam.
    # Host tools using the Steamworks SDK (such as skwd-deck-steamworks / skwd-steam)
    # locate the running client via ~/.steam/sdk64/steamclient.so and ~/.steam/steam.pipe.
    system.activationScripts.steamFlatpakCompat = lib.stringAfter ["users"] ''
      USER_HOME="/home/${user}"
      STEAM_FLATPAK="$USER_HOME/.var/app/com.valvesoftware.Steam/.steam"
      mkdir -p "$STEAM_FLATPAK"
      # Only the directories mkdir may just have created. This was `chown -R`
      # over all of ~/.var/app, i.e. every Flatpak's data including the Steam
      # library, walked on every boot and every rebuild.
      chown ${user}:users "$USER_HOME/.var" "$USER_HOME/.var/app" \
        "$USER_HOME/.var/app/com.valvesoftware.Steam" "$STEAM_FLATPAK"
      if [ -L "$USER_HOME/.steam" ]; then
        if [ ! -e "$USER_HOME/.steam" ]; then
          ln -sfn "$STEAM_FLATPAK" "$USER_HOME/.steam"
          chown -h ${user}:users "$USER_HOME/.steam"
        fi
      elif [ ! -e "$USER_HOME/.steam" ]; then
        ln -s "$STEAM_FLATPAK" "$USER_HOME/.steam"
        chown -h ${user}:users "$USER_HOME/.steam"
      fi
    '';
  };
}
