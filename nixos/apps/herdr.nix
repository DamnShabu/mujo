{self, ...}: {
  flake.nixosModules.herdr = {pkgs, ...}: let
    herdrPkg = self.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
    herdrDesktopItem = pkgs.makeDesktopItem {
      name = "herdr";
      desktopName = "Herdr";
      genericName = "Terminal Workspace Manager";
      comment = "Agent-native terminal workspace runtime";
      icon = "utilities-terminal";
      exec = "kitty --app-id herdr -e herdr";
      terminal = false;
      categories = [
        "Development"
        "Utility"
        "ConsoleOnly"
      ];
      keywords = [
        "terminal"
        "agent"
        "workspace"
        "multiplexer"
        "herdr"
      ];
    };
  in {
    environment.systemPackages = [
      herdrPkg
      herdrDesktopItem
    ];

    # ~/.config/herdr holds config.toml, logs, and plugin configs
    # ~/.local/share/herdr holds plugin installations and runtime state
    # ~/.herdr holds default Git worktrees and session state
    persistence.data.directories = [
      ".config/herdr"
      ".local/share/herdr"
      ".herdr"
    ];

    persistence.cache.directories = [
      ".cache/herdr"
    ];
  };
}
