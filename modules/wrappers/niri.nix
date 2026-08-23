{
  self,
  lib,
  inputs,
  ...
}: {
  flake.wrappers.niri = {
    wlib,
    pkgs,
    config,
    ...
  }: {
    imports = [wlib.wrapperModules.niri];

    options.terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
    };

    config = let
      # GUI-managed display + input settings — the single source of truth for
      # these, edited by the Settings app (Display/Devices panels via
      # `mujo niri`) and folded in below. Seeded to the current values so a
      # rebuild is a no-op until something is changed. See niri-settings.json.
      ns =
        if builtins.pathExists ./niri-settings.json
        then builtins.fromJSON (builtins.readFile ./niri-settings.json)
        else {
          outputs = {};
          input = {};
        };
      nin = ns.input or {};
    in {
    settings = {
      prefer-no-csd = _: {};

      hotkey-overlay = {
        skip-at-startup = _: {};
      };

      cursor = {
        xcursor-theme = "Bibata-Modern-Classic";
        xcursor-size = 24;
      };

      input = {
        focus-follows-mouse = _: {};

        keyboard = {
          xkb = {
            layout = nin.keyboard_layout or "us";
            options = "grp:alt_shift_toggle,caps:escape";
          };
          repeat-rate = nin.repeat_rate or 40;
          repeat-delay = nin.repeat_delay or 250;
        };

        workspace-auto-back-and-forth = _: {};

        touchpad =
          {}
          // (lib.optionalAttrs (nin.touchpad_natural_scroll or true) {natural-scroll = _: {};})
          // (lib.optionalAttrs (nin.touchpad_tap or true) {tap = _: {};})
          // (lib.optionalAttrs (nin.touchpad_dwt or false) {dwt = _: {};});

        mouse =
          {
            accel-profile = nin.mouse_accel_profile or "flat";
            accel-speed = nin.mouse_accel_speed or 0.0;
          }
          // (lib.optionalAttrs (nin.mouse_natural_scroll or false) {natural-scroll = _: {};})
          // (lib.optionalAttrs (nin.mouse_middle_emulation or false) {middle-emulation = _: {};});
      };

      binds = {
        "Mod+Tab".toggle-overview = _: {};

        "Mod+Return".spawn = config.terminal;

        "Mod+Q".close-window = _: {};
        # Path must match the qs-bar daemon's launch path (quickshell.nix
        # barConfig); a bare `qs ipc` can't pick between multiple running
        # quickshell instances and silently no-ops.
        "Mod+Space"."spawn-sh" = "qs -p /etc/xdg/quickshell/bar/shell.qml ipc call launcher toggle";
        # Standalone Settings app (separate quickshell instance, floated by the
        # window-rule matching its title below).
        "Mod+Comma"."spawn-sh" = "qs -p /etc/xdg/quickshell/bar/settings.qml";
        # Lock screen (WP-14). Mod+Shift+L is taken (move-column-right); path must
        # match the qs-bar daemon so the IPC targets the running instance.
        "Mod+Ctrl+L"."spawn-sh" = "qs -p /etc/xdg/quickshell/bar/shell.qml ipc call lock lock";

        "Mod+F".maximize-column = _: {};
        "Mod+G".fullscreen-window = _: {};
        "Mod+Shift+F".toggle-window-floating = _: {};
        "Mod+Shift+G".toggle-windowed-fullscreen = _: {};
        "Mod+C".center-column = _: {};
        "Mod+W".toggle-column-tabbed-display = _: {};
        "Mod+E".spawn = "nautilus";
        # Flatpak exports binaries under the full app ID, not a short name
        # (e.g. /var/lib/flatpak/exports/bin/app.zen_browser.zen), so these
        # go through `flatpak run` rather than a bare spawn.
        "Mod+B".spawn = ["flatpak" "run" "app.zen_browser.zen"];
        "Mod+M".spawn = ["flatpak" "run" "org.jeffvli.feishin"];
        "Mod+T".spawn = ["flatpak" "run" "com.visualstudio.code"];
        "Mod+P".spawn = ["flatpak" "run" "com.super_productivity.SuperProductivity"];

        # cross-boundary navigation (wraps across monitors/workspaces)
        "Mod+H"."focus-column-or-monitor-left" = _: {};
        "Mod+L"."focus-column-or-monitor-right" = _: {};
        "Mod+K"."focus-window-or-workspace-up" = _: {};
        "Mod+J"."focus-window-or-workspace-down" = _: {};

        "Mod+Left".focus-column-left = _: {};
        "Mod+Right".focus-column-right = _: {};
        "Mod+Up"."focus-window-up-or-bottom" = _: {};
        "Mod+Down"."focus-window-down-or-top" = _: {};

        "Mod+Home"."focus-column-first" = _: {};
        "Mod+End"."focus-column-last" = _: {};
        "Mod+BackSpace".focus-window-previous = _: {};

        # move windows/columns across boundaries
        "Mod+Shift+H"."move-column-left-or-to-monitor-left" = _: {};
        "Mod+Shift+L"."move-column-right-or-to-monitor-right" = _: {};
        "Mod+Shift+K"."move-window-up-or-to-workspace-up" = _: {};
        "Mod+Shift+J"."move-window-down-or-to-workspace-down" = _: {};

        "Mod+Shift+Home"."move-column-to-first" = _: {};
        "Mod+Shift+End"."move-column-to-last" = _: {};

        # swap windows within a column
        "Mod+Ctrl+K".swap-window-left = _: {};
        "Mod+Ctrl+J".swap-window-right = _: {};

        # consume/expel windows between columns
        "Mod+BraceLeft"."consume-or-expel-window-left" = _: {};
        "Mod+BraceRight"."consume-or-expel-window-right" = _: {};

        # opacity toggle
        "Mod+O".toggle-window-rule-opacity = _: {};

        # resize with brackets (replaces Ctrl+HJKL)
        "Mod+Ctrl+BraceLeft".set-column-width = "-5%";
        "Mod+Ctrl+BraceRight".set-column-width = "+5%";
        "Mod+Ctrl+Minus".set-window-height = "-5%";
        "Mod+Ctrl+Equal".set-window-height = "+5%";

        "Mod+1".focus-workspace = "w0";
        "Mod+2".focus-workspace = "w1";
        "Mod+3".focus-workspace = "w2";
        "Mod+4".focus-workspace = "w3";
        "Mod+5".focus-workspace = "w4";
        "Mod+6".focus-workspace = "w5";
        "Mod+7".focus-workspace = "w6";
        "Mod+8".focus-workspace = "w7";
        "Mod+9".focus-workspace = "w8";
        "Mod+0".focus-workspace = "w9";

        "Mod+Shift+1".move-column-to-workspace = "w0";
        "Mod+Shift+2".move-column-to-workspace = "w1";
        "Mod+Shift+3".move-column-to-workspace = "w2";
        "Mod+Shift+4".move-column-to-workspace = "w3";
        "Mod+Shift+5".move-column-to-workspace = "w4";
        "Mod+Shift+6".move-column-to-workspace = "w5";
        "Mod+Shift+7".move-column-to-workspace = "w6";
        "Mod+Shift+8".move-column-to-workspace = "w7";
        "Mod+Shift+9".move-column-to-workspace = "w8";
        "Mod+Shift+0".move-column-to-workspace = "w9";

        # mouse/touchpad
        "Mod+WheelScrollDown".focus-column-left = _: {};
        "Mod+WheelScrollUp".focus-column-right = _: {};
        "Mod+Ctrl+WheelScrollDown".focus-workspace-down = _: {};
        "Mod+Ctrl+WheelScrollUp".focus-workspace-up = _: {};

        # audio
        "Mod+V".spawn-sh = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86AudioRaiseVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";

        # brightness
        "XF86MonBrightnessUp".spawn-sh = "${pkgs.brightnessctl}/bin/brightnessctl s 5%+";
        "XF86MonBrightnessDown".spawn-sh = "${pkgs.brightnessctl}/bin/brightnessctl s 5%-";

        # screenshots: region/OCR via QuickSnip
        "Mod+Shift+S".spawn-sh = "quicksnip";
        "Mod+Ctrl+S".screenshot-window = _: {};
        "Mod+Ctrl+Shift+S".screenshot-screen = _: {};

        # display / session
        "Mod+Shift+P"."power-off-monitors" = _: {};
        "Mod+Shift+R".spawn-sh = "${lib.getExe pkgs.niri} msg action reload-config";
        "Mod+Shift+Slash"."show-hotkey-overlay" = _: {};
      };

      layout = {
        gaps = 10;
        background-color = "transparent";

        struts = {
          left = 10;
          right = 10;
          top = 10;
          bottom = 10;
        };

        focus-ring = {
          off = _: {};
        };

        shadow = {
          softness = 1;
          spread = 0;
          offset = _: {
            props = {
              x = 0;
              y = 0;
            };
          };
          color = "#E6E1CFAA";
          inactive-color = "#E6E1CF55";
        };
      };

      blur = {
        passes = 3;
        offset = 3.0;
        noise = 0.02;
        saturation = 1.5;
      };

      window-rules = [
        {
          geometry-corner-radius = 4;
          clip-to-geometry = true;
          opacity = 0.9;
          background-effect = {blur = true;};
        }
        {
          # mujō Settings — maximized like a regular window, just rounded.
          matches = [{title = "^mujō Settings";}];
          open-maximized = true;
          geometry-corner-radius = 14;
          clip-to-geometry = true;
        }
        {
          matches = [{app-id = "^kitty$";}];
          open-maximized = true;
        }
        {
          matches = [{app-id = "zen";}];
          open-maximized = true;
        }
        {
          matches = [{app-id = "(?i)nautilus";}];
          open-maximized = true;
        }
        {
          matches = [{app-id = "(?i)steam";}];
          open-maximized = true;
        }
        {
          matches = [{app-id = "(?i)vesktop";}];
          open-maximized = true;
        }
        {
          matches = [
            {
              app-id = "(?i)steam";
              title = "^notificationtoasts_\\d+_desktop$";
            }
          ];
          default-floating-position = _: {
            props = {
              x = 10;
              y = 10;
              relative-to = "bottom-right";
            };
          };
          open-floating = true;
          open-focused = false;
        }
      ];

      layer-rules = [
        {
          matches = [
            {namespace = "^noctalia-overview-";}
          ];
          place-within-backdrop = true;
          background-effect = {
            blur = true;
          };
        }
        {
          matches = [
            {namespace = "^qs-wallpaper-bg";}
          ];
          place-within-backdrop = true;
        }
      ];

      workspaces = let
        settings = {layout.gaps = 5;};
      in
        lib.genAttrs (map (i: "w${toString i}") (lib.range 0 9)) (_: settings);

      # Built from niri-settings.json (the single source of truth). Each output:
      #   { mode; x; y; scale; transform?; enabled? }
      outputs =
        lib.mapAttrs (
          _name: o:
            {
              mode = o.mode;
              position = _: {
                props = {
                  x = o.x;
                  y = o.y;
                };
              };
              scale = o.scale;
            }
            // (lib.optionalAttrs ((o.transform or "normal") != "normal") {transform = o.transform;})
            // (lib.optionalAttrs (! (o.enabled or true)) {off = _: {};})
        ) (ns.outputs or {});

      xwayland-satellite.path =
        lib.getExe pkgs.xwayland-satellite;

      spawn-sh-at-startup = [
        "sleep 1 && ${pkgs.mpv}/bin/mpv --no-video --no-terminal --volume=50 --ao=pipewire ${self}/sounds/startup-sound1.mp3"
      ];
    };
    };
  };
}
