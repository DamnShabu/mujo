{self, ...}: {
  # A greeting card centred on the focused output at login, and again when the
  # lock screen goes away after a while (every wake from sleep passes through
  # it: ambxst locks before suspend). The headline is computed locally and shows
  # at once; a small local model (Ollama) writes the line under it from facts
  # ranked by `importance`. Script: mujo-greeting.sh. Self-check:
  # test-mujo-greeting.sh.
  flake.nixosModules.greeting = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.desktop.greeting;
    user = config.preferences.user.name;
    t = self.theme;

    popup = pkgs.replaceVars ./mujo-greeting.qml {
      bg = "#F2${lib.removePrefix "#" t.base00}";
      border = t.base02;
      fg = t.base07;
      text = t.base05;
      muted = t.base04;
      accent = t.base0D;
    };

    greeting = pkgs.writeShellApplication {
      name = "mujo-greeting";
      runtimeInputs = with pkgs; [coreutils curl gnused jq quickshell systemd util-linux];
      runtimeEnv = {
        MUJO_GREETING_QML = popup;
        MUJO_GREETING_MODEL = cfg.model;
        MUJO_GREETING_NAME = cfg.displayName;
        MUJO_GREETING_FACTORS = lib.concatStringsSep " " cfg.importance;
        MUJO_GREETING_MIN_AWAY = toString (cfg.minAwayMinutes * 60);
        OLLAMA_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
      };
      text = builtins.readFile ./mujo-greeting.sh;
    };
  in {
    options.desktop.greeting = {
      enable = lib.mkEnableOption "the greeting popup at login and after unlock" // {default = true;};

      model = lib.mkOption {
        type = lib.types.str;
        default = "qwen3:4b-instruct";
        description = ''
          Ollama model that writes the line. Measured on the RX 9060 XT:
          qwen3:4b-instruct ~0.6 s warm, ~2.2 s from cold, and stays on the
          facts; gemma3:1b is ~0.7 s either way but muddles them; gemma3:4b
          parrots the prompt's examples.
        '';
      };

      displayName = lib.mkOption {
        type = lib.types.str;
        default = lib.toUpper (lib.substring 0 1 user) + lib.substring 1 (-1) user;
        defaultText = lib.literalMD "the login name, capitalised";
        description = "Name used in the headline.";
      };

      importance = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["failed-units" "return" "time" "disk" "rebuild-age" "streak"]);
        default = ["failed-units" "return" "time" "disk" "rebuild-age" "streak"];
        description = ''
          Facts handed to the model, most important first. Each is only sent
          when it is notable (e.g. `disk` from 85% full, `rebuild-age` from 14
          days); the model picks one or two worth mentioning.
        '';
      };

      minAwayMinutes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 15;
        description = "Shortest lock (or sleep) that earns a welcome-back greeting on unlock.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        internal = true;
        default = greeting;
      };
    };

    config = lib.mkIf cfg.enable {
      services.ollama = {
        enable = true;
        # Vulkan reaches the AMD GPU without the multi-GB ROCm closure.
        package = pkgs.ollama-vulkan;
        loadModels = [cfg.model];
      };

      # DynamicUser keeps the state under /var/lib/private, and systemd refuses
      # to start the unit unless that parent is 0700. Impermanence creates the
      # parent of the bind mount at 0755, so tighten it back.
      persistence.directories = ["/var/lib/private/ollama"];
      systemd.tmpfiles.rules = ["d /var/lib/private 0700 root root -"];
      persistence.data.directories = [".local/state/mujo-greeting"];

      environment.systemPackages = [greeting];

      systemd.user.services.mujo-greeting = {
        description = "Greeting popup at login";
        wantedBy = ["graphical-session.target"];
        after = ["graphical-session.target" "niri.service"];
        # For `niri msg`, which picks the output the card appears on.
        path = ["/run/current-system/sw"];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${greeting}/bin/mujo-greeting boot";
        };
      };
    };
  };
}
