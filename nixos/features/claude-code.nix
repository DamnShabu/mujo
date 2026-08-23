{self, ...}: {
  flake.nixosModules.claude-code = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [claude-code];

    # ~/.claude holds credentials, projects, todos, skills, history;
    # ~/.claude.json is the top-level config (accounts, MCP servers,
    # onboarding state, per-project history) and lives at the home root
    # as a file, so it must be persisted separately.
    # ~/.agents is where `npx skills add` installs shared agent skills;
    # ~/.claude/skills symlinks into it, so losing it dangles the links.
    persistence.data.directories = [
      ".agents"
      ".claude"
      ".config/claude"
    ];

    persistence.data.files = [
      ".claude.json"
    ];

    persistence.cache.directories = [
      ".cache/claude"
    ];
  };
}
