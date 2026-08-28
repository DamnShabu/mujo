{self, ...}: {
  flake.nixosModules.antigravity-ide = {pkgs, ...}: {
    # The desktop build of Antigravity. Shares ~/.gemini (persisted in
    # general.nix) and the MCP config written by antigravity-cli.nix with the
    # CLI, so it needs no state of its own — it lives here rather than inline in
    # the host file only so every app is reachable as a module.
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-ide];
  };
}
