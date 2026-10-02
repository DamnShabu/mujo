{inputs, ...}: {
  flake.nixosModules.impermanence = {
    lib,
    config,
    ...
  }: let
    cfg = config.persistence;
  in {
    imports = [
      inputs.impermanence.nixosModules.impermanence
    ];

    config = lib.mkMerge [
      {
        persistence.enable = lib.mkDefault true;
        persistence.user = lib.mkDefault config.preferences.user.name;
      }
      (lib.mkIf cfg.enable {
        fileSystems."/persist".neededForBoot = true;

        programs.fuse.userAllowOther = true;

        boot.tmp.cleanOnBoot = lib.mkDefault true;

        environment.persistence = {
          "/persist/userdata".users."${cfg.user}" = {
            directories = cfg.data.directories;
            files =
              cfg.data.files
              ++ [
                {
                  file = ".face.icon";
                  method = "symlink";
                }
                {
                  file = ".face";
                  method = "symlink";
                }
              ];
          };

          "/persist/usercache".users."${cfg.user}" = {
            directories = cfg.cache.directories;
            files = cfg.cache.files;
          };

          "/persist/system" = {
            hideMounts = true;
            directories =
              [
                "/etc/nixos"
                "/var/log"
                "/var/lib/nixos"

                "/var/lib/zerotier-one"
              ]
              ++ cfg.directories;
            files =
              [
                "/etc/machine-id"
                "/etc/lact/config.yaml"
                {
                  file = "/var/keys/secret_file";
                  parentDirectory = {mode = "u=rwx,g=,o=";};
                }
              ]
              ++ cfg.files;
          };
        };

        # There is no root-wipe script: / is a tmpfs (disko.nix nodev "/"), so
        # it is empty on every boot by construction. The old nukeRoot
        # postDeviceCommands could not even be enabled -- systemd stage 1 fails
        # the build on postDeviceCommands.
      })
    ];
  };
}
