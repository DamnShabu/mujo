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

        # Mujo manages root as an ephemeral tmpfs, /persist via btrfs subvolumes,
        # and persistence via impermanence bind mounts. Disable nix-mineral's Kicksecure-style
        # synthetic filesystem remounts so they do not conflict with impermanence.
        filesystems.enable = false;

        kernel-modules.enable = false; # Mujo manages driver and kernel module loading
        settings.misc.nix-wheel = false; # Allow normal nix operation
        # Mujo sets kernel.sysrq = 16 (emergency sync only) in kernel.nix; mineral
        # mkForce'd it to 0 over that, silently, and the kernel test failed on it.
        settings.kernel.sysrq = "none";
        settings.network.random-mac = false; # per-boot random MACs break DHCP reservations; see privacy.nix
      };
    };
  };
}
