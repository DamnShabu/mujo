{self, ...}: {
  flake.nixosModules.log-daemon = {pkgs, lib, config, ...}: let
    cfg = config.services.log-daemon;
    user = config.preferences.user.name;
    # ponytail: single python derivation with watchdog baked in, avoids a
    # separate wrapper script.
    python = pkgs.python3.withPackages (ps: [ps.watchdog]);
  in {
    options.services.log-daemon = {
      enable = lib.mkEnableOption "Log-to-Obsidian conversion daemon";

      watchDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${user}/Documents/obsidianVaults/Logs/inbox";
        description = "Directory to watch for new log files";
      };

      outputDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${user}/Documents/obsidianVaults/Logs/processed";
        description = "Directory to write Obsidian notes";
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${user}/.local/state/log-daemon";
        description = "Directory for daemon state files (processed file ledger)";
      };

      ollamaUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:11434/api/generate";
        description = "Ollama API endpoint URL";
      };

      ollamaModel = lib.mkOption {
        type = lib.types.str;
        default = "llama3.2";
        description = "Ollama model name for log summarisation";
      };

      ollamaTimeout = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Timeout in seconds for Ollama requests";
      };

      extraTags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["system"];
        description = "Extra tags to add to every note's frontmatter";
      };

      maxNoteLength = lib.mkOption {
        type = lib.types.int;
        default = 10000;
        description = "Maximum note body length before truncation with <!-- TRUNCATED --> marker";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.user.services.log-daemon = {
        after = [];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = "${python}/bin/python ${../../modules/log-daemon/log-daemon.py}";
          Restart = "always";
          RestartSec = 2;
          Type = "simple";
        };
        environment = {
          LOG_DAEMON_WATCH_DIR = cfg.watchDir;
          LOG_DAEMON_OUTPUT_DIR = cfg.outputDir;
          LOG_DAEMON_STATE_DIR = cfg.stateDir;
          LOG_DAEMON_OLLAMA_URL = cfg.ollamaUrl;
          LOG_DAEMON_OLLAMA_MODEL = cfg.ollamaModel;
          LOG_DAEMON_OLLAMA_TIMEOUT = toString cfg.ollamaTimeout;
          LOG_DAEMON_EXTRA_TAGS = lib.concatStringsSep "," cfg.extraTags;
          LOG_DAEMON_MAX_NOTE_LENGTH = toString cfg.maxNoteLength;
        };
      };

      persistence.data.directories = [
        ".local/state/log-daemon"
        "Documents/obsidianVaults/Logs"
      ];
    };
  };
}
