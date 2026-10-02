# AMD Radeon RX 9070 XT — Navi 48, RDNA4 (gfx1201), PCI id 1002:7550.
#
# Everything this card needs from the system, in one place:
#
#   kernel    amdgpu learned RDNA4 over 6.13-6.14. The default
#             linuxPackages (the LTS series) is newer than that; the assertion
#             below keeps a future kernel pin from silently dropping under it.
#   firmware  linux-firmware, via hardware.enableRedistributableFirmware in
#             nixos/desktop/desktop.nix. Because amdgpu loads in stage 1, the
#             initrd builder copies every blob the module declares — Navi 48's
#             gc_12_0_1, psp_14_0_3, smu_14_0_3, dcn_4_0_1, sdma_7_0_1 and
#             vcn_5_0_0 — into the initrd with it, so no firmware has to come
#             from the root filesystem.
#   userspace Mesa (radeonsi for GL, RADV for Vulkan, both 32- and 64-bit) via
#             hardware.graphics in desktop.nix. gfx12 needs Mesa 25.0+.
#             Flatpak apps — Steam and every Proton game included — do not use
#             this Mesa: they render with their runtime's GL extension, which is
#             why nixos/apps/flatpak.nix keeps Flathub updated on a timer.
{
  config,
  lib,
  ...
}: {
  # Early KMS: amdgpu binds in the initrd, so Plymouth and the console come up
  # at the panel's native mode instead of on the firmware framebuffer.
  hardware.amdgpu.initrd.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];

  # LACT: clocks, temperatures, fan curve, power cap and VRAM use, with a GUI
  # (`lact gui`) on top of a small root daemon. Without overdrive (no
  # amdgpu.ppfeaturemask) it can read everything and set fan and power limits,
  # but not under/overclock, which is what keeps the kernel untainted.
  services.lact.enable = true;
  # The daemon rewrites /etc/lact/config.yaml when settings change in the GUI.
  # Persist the directory, not the file: a bind-mounted single file breaks the
  # moment the writer replaces it instead of editing it in place.
  persistence.directories = ["/etc/lact"];

  # A GPU driver oops on brand-new silicon is the textbook case of a "harmless
  # oops from a bad driver". With panic_on_oops, it panics the whole machine —
  # before journald can flush the trace that would explain it — instead of
  # leaving a GPU reset or a dead display to recover from. Kernel-hardening
  # guides recommend turning it on (oops=panic); this host keeps it off, at a
  # priority above mkForce, so no hardening module can win by accident.
  boot.kernel.sysctl."kernel.panic_on_oops" = lib.mkOverride 40 0;

  assertions = [
    {
      assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.14";
      message = ''
        The RX 9070 XT (RDNA4) needs Linux 6.14 or newer, but
        boot.kernelPackages is ${config.boot.kernelPackages.kernel.version}.
        Older amdgpu either does not bind the card or hangs it under load.
      '';
    }
    {
      assertion = lib.versionAtLeast config.hardware.graphics.package.version "25.0";
      message = ''
        The RX 9070 XT (RDNA4) needs Mesa 25.0 or newer for radeonsi and RADV,
        but hardware.graphics.package is ${config.hardware.graphics.package.version}.
        Anything older falls back to llvmpipe software rendering.
      '';
    }
  ];
}
