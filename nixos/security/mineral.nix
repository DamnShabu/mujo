{inputs, ...}: {
  flake.nixosModules.security-mineral = {
    config,
    lib,
    ...
  }: let
    cfg = config.security.mujo.mineral;
  in {
    imports = [
      inputs.nix-mineral.nixosModules.nix-mineral
    ];

    options.security.mujo.mineral = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.security.mujo.enable;
        description = "Enable nix-mineral kernel, sysctl, and attack surface hardening with desktop compatibility";
      };
    };

    config = lib.mkIf cfg.enable {
      nix-mineral = {
        enable = true;
        preset = ["compatibility"];

        # Guarantee desktop & virtualization compatibility overrides
        filesystems = {
          special = {
            "/proc".options.hidepid = false;
          };
          normal = {
            "/home".options.noexec = false;
            "/tmp".options.noexec = false;
          };
        };

        kernel-modules.enable = false; # Mujo manages driver and kernel module loading
        settings.misc.nix-wheel = false; # Allow normal nix operation
        settings.network.random-mac = false; # Mujo privacy.nix manages stable MAC addresses
      };

      fileSystems."/etc".neededForBoot = true;
      fileSystems."/var".neededForBoot = true;
      fileSystems."/home".neededForBoot = true;
      fileSystems."/var/lib".neededForBoot = true;
    };
  };
}
