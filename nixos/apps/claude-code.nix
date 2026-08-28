{self, ...}: {
  flake.nixosModules.claude-code = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code];

    # ~/.claude holds credentials, projects, todos, skills, history;
    # ~/.claude.json is the top-level config (accounts, MCP servers,
    # onboarding state, per-project history) and lives at the home root
    # as a file, so it must be persisted separately.
    # Note: ~/.agents is persisted in general.nix.
    #
    # Claude Code writes neither ~/.config/claude nor ~/.cache/claude — both
    # were persisted here and both stayed empty, so they are not listed.
    persistence.data.directories = [
      ".claude"
    ];

    persistence.data.files = [
      ".claude.json"
    ];
  };
}
