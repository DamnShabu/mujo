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

        git = {
          userName = lib.mkOption {
            type = lib.types.str;
            default = "DamnShabu";
            description = "Default Git author name";
          };
          userEmail = lib.mkOption {
            type = lib.types.str;
            default = "DamnShabu@porkbuns.xyz";
            description = "Default Git author email";
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
          type = lib.types.str;
          default = "btrfs_vg";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "yurii";
        };

        directories = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.anything);
          default = [];
        };

        files = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.anything);
          default = [];
        };

        data.directories = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.anything);
          default = [];
        };

        data.files = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.anything);
          default = [];
        };

        cache.directories = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.anything);
          default = [];
        };

        cache.files = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.anything);
          default = [];
        };
      };
    };
  };
}
