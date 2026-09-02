{...}: {
  flake.nixosModules.security-devices = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
  in {
    options.security.mujo.devices = {
      dmaProtection = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Force the IOMMU on and block DMA from devices the firmware brought up
          before the kernel. Off by default because both parameters act during
          early boot, where a bad interaction with firmware or GPU initialisation
          shows up as a machine that does not reach a display. Enable it once you
          have confirmed the machine boots with it, and keep a previous generation
          selectable while you do.
        '';
      };

      iommuPassthrough = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Add `iommu=pt`, which maps devices directly instead of translating
          their DMA.

          This is a performance setting, not a protection one — it is the
          cheaper of the two IOMMU modes, and exists to stay inside the I/O
          budget in docs/performance-budget.md. It buys no security, so it is
          not worth spending boot risk on by default: like the parameters behind
          `dmaProtection`, it acts during early device initialisation, and this
          host has an AMD GPU whose initialisation is the sensitive part.

          Turn it on by itself, with a known-good generation still selectable in
          the boot menu, and only if I/O measurements show you need it.
        '';
      };
    };

    config = lib.mkIf (cfg.enable && cfg.devices.enable) {
      boot.kernelParams =
        lib.optionals cfg.devices.iommuPassthrough [
          # Passthrough mode. A performance setting, not a protection one: it
          # maps devices directly rather than translating their DMA. Gated
          # because it still acts during early device initialisation, which on
          # this machine is where a bad interaction costs a display.
          "iommu=pt"
        ]
        ++ lib.optionals cfg.devices.dmaProtection [
          # Force the IOMMU on rather than relying on firmware defaults.
          "amd_iommu=on"

          # Refuse DMA from devices the firmware left enabled before the kernel
          # took over -- the window an evil-maid Thunderbolt/PCIe device uses.
          # Both parameters are off by default: they change device
          # initialisation early in boot, and on some firmware/GPU combinations
          # that is the difference between a display and a black screen.
          "efi=disable_early_pci_dma"
        ];

      # Thunderbolt device manager to guard against unauthorized PCIe direct memory access
      services.hardware.bolt.enable = lib.mkDefault true;
    };
  };
}
