{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.vm = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      quickemu
      virt-viewer # remote-viewer for SPICE and VNC visual display
      spice-gtk   # spicy / spice-client tools
      swtpm       # TPM 2.0 emulator for Windows 11
      OVMF.fd     # UEFI firmware
      qemu
    ];

    persistence.data.directories = [
      "VMs"
    ];
  };
}
