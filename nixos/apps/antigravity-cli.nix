{self, ...}: {
  flake.nixosModules.antigravity-cli = {
    pkgs,
    config,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
    sharedMcp = import ./_ai-mcp.nix {inherit user;};
    # Format taken from what `agy mcp add` itself writes: a `mcpServers` map of
    # {command, args, disabled}, with `command` a bare string.
    mcpConfig = pkgs.writeText "mcp_config.json" (builtins.toJSON {
      mcpServers =
        lib.mapAttrs (_: server: {
          inherit (server) command args;
          disabled = false;
        })
        sharedMcp;
    });
  in {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli];

    # All of antigravity-cli's state lives under ~/.gemini, persisted in
    # general.nix. It writes no ~/.config/antigravity-cli or
    # ~/.cache/antigravity-cli, so neither is persisted here.

    # Nix owns the MCP server list from here on: this replaces the file
    # `agy mcp add/remove` used to manage, so servers are added by editing
    # _ai-mcp.nix and rebuilding, not from the CLI.
    hjem.users."${user}".files = {
      ".gemini/config/mcp_config.json".source = mcpConfig;
    };
  };
}
