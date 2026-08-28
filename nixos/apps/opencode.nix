{self, ...}: {
  flake.nixosModules.opencode = {
    pkgs,
    config,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
    sharedMcp = import ./_ai-mcp.nix {inherit user;};
    opencodeConfig = pkgs.writeText "opencode.json" (builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      lsp = true;
      plugin = ["@dietrichgebert/ponytail"];
      # opencode takes the executable and its arguments as one list.
      mcp =
        lib.mapAttrs (_: server: {
          type = "local";
          command = [server.command] ++ server.args;
          enabled = true;
        })
        sharedMcp;
    });
  in {
    environment.systemPackages = with pkgs; [opencode];

    persistence.data.directories = [
      ".config/opencode"
      ".local/share/opencode"
    ];

    persistence.cache.directories = [
      ".cache/opencode"
    ];

    hjem.users."${user}".files = {
      ".config/opencode/opencode.json".source = opencodeConfig;
    };
  };
}
