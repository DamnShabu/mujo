# AMD Radeon RX 9070 XT — Navi 48, RDNA4 (gfx1201), PCI id 1002:7550.
#
# Everything this card needs from the system, in one place:
#
#   kernel    6.12 is the first kernel whose amdgpu has Navi 48's IP blocks
#             (GFX 12.0.1, PSP/SMU 14.0.3, DCN 4.0.1); 6.6 and older fail to
#             initialise the card. The default linuxPackages (the 6.18 LTS
#             series here) is well past that; the assertion below catches a
#             kernel pin that is not.
#   firmware  linux-firmware, via hardware.enableRedistributableFirmware in
#             nixos/desktop/desktop.nix. Because amdgpu loads in stage 1, the
#             initrd builder copies every blob the module declares — Navi 48's
#             gc_12_0_1, psp_14_0_3, smu_14_0_3, dcn_4_0_1, sdma_7_0_1 and
#             vcn_5_0_0 — into the initrd with it, so no firmware has to come
#             from the root filesystem.
#   userspace Mesa (radeonsi for GL, RADV for Vulkan, both 32- and 64-bit) via
#             hardware.graphics in desktop.nix. Mesa 25.0 is the first release
#             with complete gfx12 support in both drivers.
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

  # LACT: clocks, temperatures, fan speed, power draw and VRAM use, with a GUI
  # (`lact gui`) on top of a small root daemon -- the first place to look when
  # a game stutters or the card throttles. Without overdrive it reads all of
  # that and can set the power cap, but on this card that is all it can set:
  # amdgpu only creates gpu_od/ (custom fan curves, clocks, voltage offsets)
  # when the overdrive bit is in amdgpu.ppfeaturemask, and that bit taints the
  # kernel ("Overdrive is enabled, please disable it before reporting any
  # bugs"). Until then the card's own firmware fan curve runs. The switch is
  # hardware.amdgpu.overdrive.enable; LACT's GUI button for it refuses on
  # NixOS and says so.
  #
  # Who can drive it: the daemon's socket is /run/lactd.sock, mode 0660, group
  # wheel -- so any unsandboxed process running as the user can change fan and
  # power limits. Sandboxed ones cannot: native-sandbox mounts a fresh tmpfs on
  # /run and Flatpak never shows it. That is no new privilege for this user,
  # who can already rebuild the system without a password (general.nix).
  services.lact.enable = true;
  # The daemon rewrites /etc/lact/config.yaml when settings change in the GUI.
  # Persist the directory, not the file: a bind-mounted single file breaks the
  # moment the writer replaces it instead of editing it in place.
  persistence.directories = ["/etc/lact"];

  # A GPU driver oops is the textbook case of a "harmless oops from a bad
  # driver". With panic_on_oops, it panics the whole machine —
  # before journald can flush the trace that would explain it — instead of
  # leaving a GPU reset or a dead display to recover from. Kernel-hardening
  # guides recommend turning it on (oops=panic); this host keeps it off, at a
  # priority above mkForce, so no hardening module can win by accident.
  boot.kernel.sysctl."kernel.panic_on_oops" = lib.mkOverride 40 0;

  assertions = [
    {
      assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.12";
      message = ''
        The RX 9070 XT (RDNA4) needs Linux 6.12 or newer, but
        boot.kernelPackages is ${config.boot.kernelPackages.kernel.version}.
        Older amdgpu has no GFX 12 support and fails to initialise the card,
        leaving the desktop without GPU acceleration.
      '';
    }
    {
      assertion = lib.versionAtLeast config.hardware.graphics.package.version "25.0";
      message = ''
        The RX 9070 XT (RDNA4) needs Mesa 25.0 or newer for radeonsi and RADV,
        but hardware.graphics.package is ${config.hardware.graphics.package.version}.
        Older Mesa lacks complete gfx12 support.
      '';
    }
  ];
}
