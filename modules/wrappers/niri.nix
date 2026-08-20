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

    config.settings = {
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
            layout = "us";
            options = "grp:alt_shift_toggle,caps:escape";
          };
          repeat-rate = 40;
          repeat-delay = 250;
        };

        workspace-auto-back-and-forth = _: {};

        touchpad = {
          natural-scroll = _: {};
          tap = _: {};
        };

        mouse = {
          accel-profile = "flat";
        };
      };

      binds = {
        "Mod+Tab".toggle-overview = _: {};

        "Mod+Return".spawn = config.terminal;

        "Mod+Q".close-window = _: {};
        "Mod+Space"."spawn-sh" = "vicinae toggle";
        # "Mod+Space"."spawn-sh" = "pibble toggle";

        "Mod+F".maximize-column = _: {};
        "Mod+G".fullscreen-window = _: {};
        "Mod+Shift+F".toggle-window-floating = _: {};
        "Mod+Shift+G".toggle-windowed-fullscreen = _: {};
        "Mod+C".center-column = _: {};
        "Mod+W".toggle-column-tabbed-display = _: {};
        "Mod+E".spawn = "nautilus";

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
          background-effect = { blur = true; };
        }
        {
          matches = [ { app-id = "^kitty$"; } ];
          open-maximized = true;
        }
        {
          matches = [ { app-id = "zen"; } ];
          open-maximized = true;
        }
        {
          matches = [ { app-id = "(?i)nautilus"; } ];
          open-maximized = true;
        }
        {
          matches = [ { app-id = "(?i)steam"; } ];
          open-maximized = true;
        }
        {
          matches = [ { app-id = "(?i)vesktop"; } ];
          open-maximized = true;
        }
      ];

      layer-rules = [
        {
          matches = [
            { namespace = "^noctalia-overview-"; }
          ];
          place-within-backdrop = true;
          background-effect = {
            blur = true;
          };
        }
        {
          matches = [
            { namespace = "^qs-wallpaper-bg"; }
          ];
          place-within-backdrop = true;
        }
        {
          matches = [
            { namespace = "^psst-"; }
          ];
          background-effect = {
            blur = true;
            xray = true;
          };
        }
      ];

      workspaces = let
        settings = {layout.gaps = 5;};
      in {
        "w0" = settings;
        "w1" = settings;
        "w2" = settings;
      };

      outputs = {
        "DP-1" = {
          mode = "1920x1080@165.003";
          position = _: {
            props = {
              x = 0;
              y = 1080;
            };
          };
          scale = 1.0;
        };
        "HDMI-A-1" = {
          mode = "1920x1080@60";
          position = _: {
            props = {
              x = 0;
              y = 0;
            };
          };
          scale = 1.0;
        };
      };

      xwayland-satellite.path =
        lib.getExe pkgs.xwayland-satellite;

      spawn-sh-at-startup = [
        "sleep 1 && ${pkgs.mpv}/bin/mpv --no-video --no-terminal --volume=50 --ao=pipewire ${self}/sounds/startup-sound1.mp3"
      ];
    };
  };
}
