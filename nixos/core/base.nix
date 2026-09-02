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
            description = ''
              The account every other module builds paths and ownership from.

              Deliberately has no default. `nixos/core/user.nix` is the single
              place that resolves it -- from the gitignored `secrets/username`,
              falling back to a literal -- and a default here would be a second
              copy of that literal, which is exactly the hardcoded username the
              repo rule forbids. If this ever fails to evaluate, the fix is to
              import `self.nixosModules.user`, not to reintroduce a default.
            '';
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
          description = ''
            The account whose home is bind-mounted out of /persist/userdata and
            /persist/usercache. No default for the same reason as
            `preferences.user.name`: `nixos/core/impermanence.nix` sets it from
            that option, and a literal here would silently keep pointing at the
            old account when someone changes `secrets/username`.
          '';
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
