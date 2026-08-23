# nixos/hosts/main/

The single host this flake builds: `main`, an AMD desktop with an Nvidia GPU
(VR-capable) and dual monitors. `configuration.nix` is the entrypoint;
`_boot.nix`, `_networking.nix`, `_hardware-and-services.nix` are underscore
fragments it imports explicitly (underscore files are excluded from
`importTree` auto-discovery — see root `AGENTS.md`). `disko.nix` defines the
disk layout separately and is imported via `inputs.disko.nixosModules.disko`.

## Files

- **`configuration.nix`** — defines both `flake.nixosConfigurations.main`
  (the buildable system) and `flake.nixosModules.hostMain` (its module set).
  **This is the single place that turns an auto-discovered feature module
  into something that actually runs on the host** — a module under
  `nixos/features/` that isn't in this file's `imports` list evaluates but
  does nothing. Current `imports`: the three fragments above, `base`,
  `general`, `desktop`, `impermanence`, `preload`, `flatpak`, `opencode`,
  `claude-code`, `discord`, `obsidian`, `steam`, `gaming`, `user-config`,
  `user`, `mullvad`, `notifications`, `quickshell`, `vaultwarden`,
  `extra_plymouth`, plus `disko` and `nix-flatpak`. Also sets
  `nixpkgs.hostPlatform = "x86_64-linux"`, enables
  `secrets.vaultwarden.enable`, wires the vendored `preload` package/service,
  enables AppImage support, and pins `system.stateVersion = "25.11"`.
- **`_boot.nix`** — GRUB (EFI, `efiInstallAsRemovable`, 5-generation limit),
  NTFS support, fixed video mode kernel params for the two monitors
  (`DP-1:1920x1080@165`, `HDMI-A-1:1920x1080@60`), `coretemp`/`cpuid`/
  `v4l2loopback` kernel modules, and `aarch64-linux` binfmt emulation.
- **`_networking.nix`** — hostname `main` (`lib.mkDefault`, overridable),
  NetworkManager, firewall enabled with TCP port 11434 open (Ollama).
- **`_hardware-and-services.nix`** — the catch-all hardware/services grab
  bag: AMD microcode updates, `flatpak`/`udisks2`/`printing`/`upower`/
  `power-profiles-daemon`, Docker, zram swap (50% of RAM, layered in front
  of the disk swap partition — see in-file comment on the zram/disk
  swap-priority relationship), misc system packages (`zerotierone`,
  `android-tools`, `rtk`), XDG portal config split
  by session (niri vs. generic gnome/gtk backends, with per-portal
  overrides for file chooser / open-URI / screencast / screenshot), the
  `niri` compositor program (packaged via `self.packages`), and the
  `amdgpu` video driver (both Xorg and initrd).
- **`disko.nix`** — `flake.diskoConfigurations.hostMain`, consumed by
  `configuration.nix`. Layout on the NVMe SSD (device pinned by
  `/dev/disk/by-id/...`, so swapping drives requires updating this path):
  1MB BIOS-boot partition, 2G FAT ESP mounted at `/boot`, 16G swap
  (`resumeDevice = true`, for hibernation), and the remainder as an LVM PV
  in `btrfs_vg`. That volume group holds a single LV (`root`, 100% free)
  formatted btrfs with subvolumes `/root` (unmounted directly — see
  impermanence's root-wipe logic in `nixos/extra/impermanence.nix`),
  `/persist` (`noatime`), and `/nix` (`relatime` — deliberately *not*
  `noatime`, because the vendored `preload` daemon learns prefetch
  candidates from atime and all store paths live under `/nix`).
