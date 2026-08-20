{inputs, ...}: {
  flake.nixosModules.extra_impermanence = {
    lib,
    config,
    ...
  }: let
    cfg = config.persistence;
  in {
    imports = [
      inputs.impermanence.nixosModules.impermanence
    ];

    config = lib.mkIf cfg.enable {
      fileSystems."/persist".neededForBoot = true;

      programs.fuse.userAllowOther = true;

      boot.tmp.cleanOnBoot = lib.mkDefault true;

      environment.persistence = {
        "/persist/userdata".users."${cfg.user}" = {
          directories = cfg.data.directories;
          files = cfg.data.files ++ [
            { file = ".face.icon"; method = "symlink"; }
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
              "/var/lib/bluetooth"
              "/var/lib/nixos"
              "/var/lib/private/ollama"
              "/var/lib/systemd/coredump"
              "/etc/NetworkManager/system-connections"
              "/tmp"

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

      # ponytail: one-time transition cleanup of persisted state and leftover
      # bind mounts of the removed searxng/sops features and the old mullvad
      # cache/data dirs. Runs inside the activation script, i.e. AFTER
      # switch-to-configuration-ng's stop phase, so it cannot prevent
      # stop-phase errors — it only detaches leftover busy mounts and
      # removes their persisted data. (switch-to-configuration-ng does stop
      # units active in the previous generation but absent in the new one, so
      # the old "Failed to stop etc-mullvad-vpn.mount" could still fire on a
      # host migrating from an older generation; it is only no longer expected
      # here because the old mount is already gone on this host, and the
      # marker prevents re-running.)
      # Self-disables via the marker; delete this whole block once migration
      # is confirmed.
      system.activationScripts."cleanup-removed-features" = {
        deps = [ "createPersistentStorageDirs" ];
        text = ''
          if [ ! -e /persist/.cleanup-removed-features.done ]; then
            for m in \
              /var/cache/mullvad-vpn \
              /home/${cfg.user}/Documents/.data/mullvad-vpn \
              /home/${cfg.user}/searxng \
              /home/${cfg.user}/sops-age
            do
              umount -l "$m" 2>/dev/null || true
            done

            rm -rf /persist/system/var/cache/mullvad-vpn
            rm -rf /persist/searxng
            rm -rf /persist/userdata/home/${cfg.user}/searxng
            rm -rf /persist/userdata/home/${cfg.user}/sops-age
            rm -rf /persist/userdata/home/${cfg.user}/Documents/.data/mullvad-vpn

            touch /persist/.cleanup-removed-features.done || true
          fi
        '';
      };

      boot.initrd.postDeviceCommands =
        lib.mkIf cfg.nukeRoot.enable
        (lib.mkAfter ''
          mkdir /btrfs_tmp
          mount /dev/${cfg.volumeGroup}/root /btrfs_tmp
          if [[ -e /btrfs_tmp/root ]]; then
              mkdir -p /btrfs_tmp/old_roots
              timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
              mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
          fi

          delete_subvolume_recursively() {
              IFS=$'\n'
              for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                  delete_subvolume_recursively "/btrfs_tmp/$i"
              done
              btrfs subvolume delete "$1"
          }

          for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
              delete_subvolume_recursively "$i"
          done

          btrfs subvolume create /btrfs_tmp/root
          umount /btrfs_tmp
        '');
    };
  };
}
