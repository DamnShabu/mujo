{
  flake.nixosModules.base = {
    lib,
    pkgs,
    ...
  }: {
    options = {
      preferences = {
        user = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "yurii";
          };
        };

        locale = {
          timeZone = lib.mkOption {
            type = lib.types.str;
            default = "Europe/Berlin";
          };
          default = lib.mkOption {
            type = lib.types.str;
            default = "en_US.UTF-8";
          };
        };

        overrides.report = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Local override drop-ins that failed to load, name -> reason.";
        };
      };

      persistence = {
        enable = lib.mkEnableOption "enable persistence";

        nukeRoot.enable = lib.mkEnableOption "Destroy /root on every boot";

        volumeGroup = lib.mkOption {
          default = "btrfs_vg";
        };

        user = lib.mkOption {
          default = "yurii";
        };

        directories = lib.mkOption {
          default = [];
        };

        files = lib.mkOption {
          default = [];
        };

        data.directories = lib.mkOption {
          default = [];
        };

        data.files = lib.mkOption {
          default = [];
        };

        cache.directories = lib.mkOption {
          default = [];
        };

        cache.files = lib.mkOption {
          default = [];
        };
      };
    };
  };
}
