# Quiet mode: the PC keeps running (downloads, servers, a render) with every
# display off, every RGB LED off and the fans at their floor. The first key
# press, click or mouse movement brings everything back.
#
#   mujo-quiet on | off | toggle | status      (Mod+Ctrl+P runs `on`)
#
# How the pieces fit, and why each is where it is (the script is
# ./mujo-quiet.sh, its self-check ./test-mujo-quiet.sh):
#
#   displays  niri's power-off-monitors (DPMS on every output it drives,
#             DisplayLink/evdi included), from the mujo-quiet-session user
#             unit -- the compositor is the session's. Outputs DPMS leaves lit
#             can be switched off outright (displays.niriOutputs), and USB
#             screens niri never sees -- a sensor panel, an AIO's LCD -- are
#             de-authorised on the bus (displays.usbDevices).
#   RGB       OpenRGB's server, which this enables. Everything goes through
#             its SDK port, so only one process ever drives the SMBus.
#   fans      hwmon pwm channels, set to manual at fans.pwm. They are watched,
#             not just stopped: past fans.hotCelsius on any sensor they go back
#             to the board's own curve, and come down again under
#             fans.coolCelsius. The GPU is left alone by default -- RDNA4 has
#             no writable hwmon fan control without overdrive, and its
#             firmware already stops the fans at idle (zero-RPM).
#   wake      libinput, as root, in mujo-quiet.service. The same input wakes
#             niri's monitors on its own, so both come back together. While
#             quiet mode is on, a logind inhibitor keeps the machine from
#             sleeping: "keeps running" is the point.
#
# Restoring is ExecStopPost, so a crash, `mujo-quiet off` or `systemctl stop`
# puts the fans, LEDs, USB screens and power profile back as surely as a key
# press does.
{...}: {
  # The root half (fan save/quiet/restore, thermal watchdog, RGB, USB screens,
  # power profile, input wake) against a fake /sys, by `nix flake check`.
  perSystem = {pkgs, ...}: {
    checks.quiet =
      pkgs.runCommand "mujo-quiet-check" {
        nativeBuildInputs = with pkgs; [bash coreutils findutils gnugrep gnused];
      } ''
        cp ${./mujo-quiet.sh} mujo-quiet.sh
        cp ${./test-mujo-quiet.sh} test-mujo-quiet.sh
        bash test-mujo-quiet.sh
        touch $out
      '';
  };

  flake.nixosModules.quiet = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.mujo-quiet;
    inherit (lib) mkOption types;

    words = lib.concatStringsSep " ";
    flag = b:
      if b
      then "1"
      else "0";

    quietEnv = pkgs.writeText "mujo-quiet.env" ''
      FANS=${flag cfg.fans.enable}
      FAN_PWM=${toString cfg.fans.pwm}
      FAN_EXCLUDE_CHIPS=${lib.escapeShellArg (words cfg.fans.excludeChips)}
      FAN_EXCLUDE=${lib.escapeShellArg (words cfg.fans.exclude)}
      SENSOR_CHIPS=${lib.escapeShellArg (words cfg.fans.sensorChips)}
      HOT=${toString cfg.fans.hotCelsius}
      COOL=${toString cfg.fans.coolCelsius}
      RGB=${flag cfg.rgb.enable}
      RGB_PORT=${toString config.services.hardware.openrgb.server.port}
      USB_DISPLAYS=${lib.escapeShellArg (words cfg.displays.usbDevices)}
      NIRI_OUTPUTS=${lib.escapeShellArg (words cfg.displays.niriOutputs)}
      POWER_SAVER=${flag cfg.powerSaver}
    '';

    mujoQuiet = pkgs.writeShellApplication {
      name = "mujo-quiet";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        systemd
        (lib.getBin libinput)
        config.services.hardware.openrgb.package
        config.services.power-profiles-daemon.package
        config.programs.niri.package
      ];
      text = builtins.readFile ./mujo-quiet.sh;
    };
  in {
    options.services.mujo-quiet = {
      enable = lib.mkEnableOption "quiet mode (`mujo-quiet`): displays, RGB and fans off until the next input";

      fans = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Take the fans down while quiet mode is on.";
        };
        pwm = mkOption {
          type = types.ints.between 0 255;
          default = 0;
          description = ''
            Duty cycle (0-255) the fans are held at. 0 is off: most fans stop,
            some 4-pin fans keep their own minimum. A pump on a fan header must
            be listed in `exclude`, or it stops too (the thermal watchdog would
            catch the heat, but late).
          '';
        };
        exclude = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["nct6798/pwm2"];
          description = ''
            Channels never touched, as `<hwmon name>/pwmN` (`cat
            /sys/class/hwmon/hwmon*/name`). Put an AIO pump header here.
          '';
        };
        excludeChips = mkOption {
          type = types.listOf types.str;
          default = ["amdgpu"];
          description = "hwmon chips whose fans are never touched; the GPU's firmware already parks its fans at idle.";
        };
        sensorChips = mkOption {
          type = types.listOf types.str;
          default = ["coretemp" "amdgpu" "nvme"];
          description = ''
            hwmon chips whose temperatures the watchdog reads. Not the Super
            I/O chip: its unconnected inputs report nonsense. With none of
            these readable, the fans are left alone.
          '';
        };
        hotCelsius = mkOption {
          type = types.ints.positive;
          default = 70;
          description = "Above this, on any watched sensor, the fans go back to firmware control.";
        };
        coolCelsius = mkOption {
          type = types.ints.positive;
          default = 55;
          description = "Below this, on every watched sensor, they come back down.";
        };
        kernelModules = mkOption {
          type = types.listOf types.str;
          default = ["nct6775"];
          description = ''
            Super I/O driver that exposes the board's fan headers as hwmon pwm
            channels. nct6775 covers Nuvoton chips (most ASUS and ASRock
            boards). Gigabyte's ITE chips need it87 and MSI's NCT6687D needs
            nct6687, both out of tree (add them to boot.extraModulePackages).
            Without one there is nothing to drive and the fans are left alone.
          '';
        };
      };

      rgb.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Turn every OpenRGB-supported LED off (enables the OpenRGB server).";
      };

      displays = {
        niriOutputs = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["DVI-I-1"];
          description = ''
            Outputs to switch off entirely (`niri msg output <name> off`), for
            screens that stay lit under DPMS -- some DisplayLink adapters do.
            Everything else is powered off through DPMS.
          '';
        };
        usbDevices = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["1d6b:0106"];
          description = ''
            USB screens niri does not drive (a sensor panel, an AIO's LCD), as
            `vendor:product` from `lsusb`. They are de-authorised while quiet
            mode is on. Hubs and anything with an input interface are refused.
          '';
        };
      };

      powerSaver = mkOption {
        type = types.bool;
        default = true;
        description = "Switch power-profiles-daemon to power-saver while quiet, so less heat needs moving.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.fans.coolCelsius < cfg.fans.hotCelsius;
          message = "services.mujo-quiet.fans.coolCelsius must be below hotCelsius, or the fans flap.";
        }
      ];

      environment.systemPackages = [mujoQuiet];
      environment.etc."mujo/quiet.env".source = quietEnv;

      boot.kernelModules = lib.mkIf cfg.fans.enable cfg.fans.kernelModules;

      services.hardware.openrgb.enable = lib.mkIf cfg.rgb.enable true;
      # Device settings and profiles made in the OpenRGB GUI.
      persistence.directories = lib.mkIf cfg.rgb.enable ["/var/lib/OpenRGB"];

      # 0755 so the session side can see when the daemon is armed.
      systemd.tmpfiles.rules = ["d /run/mujo-quiet 0755 root root -"];

      systemd.services.mujo-quiet = {
        description = "Quiet mode: displays, RGB and fans off until the next input";
        wants = lib.optional cfg.rgb.enable "openrgb.service";
        after = lib.optional cfg.rgb.enable "openrgb.service";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle --who=mujo-quiet --why='Quiet mode keeps the PC running' --mode=block ${lib.getExe mujoQuiet} daemon";
          ExecStopPost = "${lib.getExe mujoQuiet} restore";
        };
      };

      # Starting and stopping this one unit is what `mujo-quiet on/off` needs
      # from root. The worst it can do is quiet the fans, under the watchdog.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "mujo-quiet.service" &&
              subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';
    };
  };
}
