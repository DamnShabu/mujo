{...}: {
  # GUI-managed persistence list. The Settings app's Persistence panel edits
  # nixos/user-persistence.json (via `mujo persist`); this module folds that list
  # into the existing impermanence configuration — the SAME persistence system,
  # with one extra declarative input, not a second source of truth. A rebuild
  # applies it; the bind mount then survives the impermanence root wipe.
  #
  #   { "user":   ["Documents/vault", …],   # relative to $HOME → persistence.data.directories
  #     "system": ["/var/lib/foo", …] }     # absolute paths     → persistence.directories
  flake.nixosModules.user-persistence = {...}: let
    file = ./user-persistence.json;
    data =
      if builtins.pathExists file
      then builtins.fromJSON (builtins.readFile file)
      else {
        user = [];
        system = [];
      };
  in {
    persistence.data.directories = data.user or [];
    persistence.directories = data.system or [];
  };
}
