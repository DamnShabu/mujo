{...}: {
  flake.nixosModules.security-baseline = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
  in {
    options.security.mujo = {
      enable = lib.mkEnableOption "Mujo 2.0 Security Architecture" // {default = true;};

      kernel.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable host kernel hardening sysctl tunables and mitigations";
      };

      boot.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable boot chain integrity and recovery protections";
      };

      storage.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable storage leak prevention (coredump controls, swap protections)";
      };

      network.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable network stack sysctl hardening and firewall rules";
      };

      users.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable user account hardening and sudo restrictions";
      };

      devices.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable hardware security (IOMMU, Thunderbolt DMA protection)";
      };

      audit.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable security audit event logging and journal bounded storage";
      };

      privacy.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable minimal entropy privacy enhancements";
      };

      vault.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable LUKS2 container vault subsystem";
      };
    };

    config = lib.mkIf cfg.enable {
      security = {
        protectKernelImage = lib.mkDefault true;
        lockKernelModules = lib.mkDefault false; # Keep false to permit runtime driver modules while hardening loading
        polkit.enable = lib.mkDefault true;
      };
    };
  };
}
