# Disposable graphical NixOS VM + an MCP server that can see into it.
#
#   nix run .#sandbox     # speaks MCP over stdio; boots the VM on first tool call
#
# The VM layer is nixpkgs' own NixOS test driver (QEMU + HMP monitor + QMP +
# a root backdoor shell). It already does screenshots, key injection and guest
# command execution, so the only new code here is the JSON-RPC shim in ./mcp.py.
#
# The working tree is 9p-mounted read-only at /mnt/nixconf and qs-bar is
# repointed at it, so the loop is: edit QML -> `reload` -> `screenshot`. No
# rebuild, and nothing the guest does can reach the host session or home.
{self, ...}: {
  flake.nixosModules.sandbox = {
    pkgs,
    config,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
    niri = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  in {
    imports = [
      self.nixosModules.base
      self.nixosModules.user
      self.nixosModules.quickshell
    ];

    boot.kernelParams = [
      "quiet"
      "mitigations=off"
      "nowatchdog"
      "audit=0"
      "nohpet"
      "tsc=reliable"
      "nomce"
      "elevator=none"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"
    ];

    virtualisation = {
      memorySize = 8192;
      cores = 16;
      vlans = [];
      # Root is a tmpfs that dies with the QEMU process — nothing to clean up.
      diskImage = null;
      qemu = {
        # The stripped QEMU used for VM tests has neither virgl nor
        # egl-headless, and niri refuses to run on a software EGL renderer
        # ("software EGL renderers are skipped"), so it needs the full build.
        package = lib.mkForce pkgs.qemu;
        options = [
          # Hardware CPU passthrough with invariant TSC and fast string features
          "-cpu host,migratable=off,+invtsc,+tsc-deadline,+clflushopt,+fsrm"
          "-machine q35,accel=kvm,kernel-irqchip=on"
          "-no-hpet"
          "-global kvm-pit.lost_tick_policy=discard"
          # virgl over a host render node: real GLES in the guest
          "-vga none"
          "-device virtio-gpu-gl-pci,xres=1280,yres=800"
          "-display egl-headless"
        ];
      };
      sharedDirectories.nixconf = {
        source = ''''${MUJO_SANDBOX_REPO:-/home/${user}/nixconf}'';
        target = "/mnt/nixconf";
        securityModel = "none";
      };
      # The sandbox may read the working tree, never write to it.
      fileSystems."/mnt/nixconf".options = [
        "ro"
        "trans=virtio"
        "version=9p2000.L"
        "msize=1048576"
        "cache=loose"
        "posixacl=0"
      ];
    };

    environment.sessionVariables = {
      QML_DISK_CACHE_PATH = "/tmp/qml_cache";
      MESA_LOADER_DRIVER_OVERRIDE = "virgl";
    };

    services.pipewire = {
      enable = true;
      pulse.enable = true;
      extraConfig.pipewire."99-no-rt"."context.properties"."module.rt" = false;
      extraConfig.pipewire-pulse."99-no-rt"."context.properties"."module.rt" = false;
    };
    security.rtkit.enable = lib.mkForce false;
    services.upower.enable = lib.mkForce false;
    services.udisks2.enable = lib.mkForce false;
    services.power-profiles-daemon.enable = lib.mkForce false;
    services.flatpak.enable = lib.mkForce false;
    services.printing.enable = lib.mkForce false;

    # Ensure the shared exchange directory is world-writable so screenshots write directly
    systemd.tmpfiles.rules = [
      "d /tmp/shared 1777 root root -"
    ];

    users.users.${user} = {
      isNormalUser = true;
      uid = 1000;
      password = "";
      extraGroups = ["wheel" "video" "input"];
    };
    services.getty.autologinUser = user;
    security.sudo.wheelNeedsPassword = false;
    security.polkit.enable = true;
    hardware.graphics.enable = true;

    # Wires the units, graphical-session.target and session packages.
    programs.niri = {
      enable = true;
      package = niri;
      useNautilus = false;
    };
    # Fast boot: disable network daemons and settle services in sandbox
    networking = {
      useDHCP = false;
      dhcpcd.enable = false;
      networkmanager.enable = false;
    };
    systemd.services = {
      dhcpcd.enable = false;
      systemd-udev-settle.enable = false;
      NetworkManager-wait-online.enable = false;
    };

    # Portals pull in the whole GNOME portal stack for no benefit here.
    xdg.portal.enable = lib.mkForce false;

    # Start the compositor on autologin. Deliberately not `niri-session`: that
    # script re-execs $SHELL as a login shell, which re-enters this hook and
    # forkbombs. niri.service's own `niri --session` does the systemd/D-Bus
    # environment import anyway.
    programs.bash.loginShellInit = ''
      if [ "$(tty)" = /dev/tty1 ]; then
        chmod 1777 /tmp/shared 2>/dev/null || true
        # Seed ~/.config/{quickshell,qsshell}. The shell reads its settings from
        # there via SettingsBus, and an unseeded guest renders against missing
        # files instead of the defaults `mujo` writes. Any invocation seeds;
        # `help` is the one that only reads, and it exits 1 by design.
        mujo help >/dev/null 2>&1 || true
        systemctl --user start niri.service
      fi
    '';

    # grim is how the MCP server takes screenshots: QEMU's own screendump only
    # has a surface while a VNC client is attached to the display above, and
    # wlr-screencopy from inside the session works whether one is or not.
    # quickshell itself is needed on PATH because niri's keybinds shell out
    # to `qs -p … ipc call …` to drive the running instance.
    environment.systemPackages = [pkgs.grim pkgs.quickshell];

    # Enough to render the bar without tofu.
    fonts.packages = with pkgs; [
      ubuntu-sans
      fira-code
      material-symbols
      nerd-fonts.jetbrains-mono
    ];

    # Point the stable /etc path at the 9p working tree instead of the store
    # copy, so an edit is live after a qs-bar restart with no rebuild. Doing it
    # here rather than by overriding qs-bar's ExecStart keeps the niri keybinds
    # working: they address the running instance as
    # `qs -p /etc/xdg/quickshell/bar/shell.qml ipc call …`, which only matches
    # if the service was started from that same path.
    environment.etc."xdg/quickshell/bar".source =
      lib.mkForce "/mnt/nixconf/quickshell/bar";

    system.stateVersion = "25.11";
  };

  perSystem = {pkgs, ...}: let
    sandbox = pkgs.testers.runNixOSTest {
      name = "mujo-sandbox";
      # The "test" never ends on its own: it serves MCP until stdin closes.
      globalTimeout = 86400;
      skipLint = true;
      skipTypeCheck = true;
      nodes.machine = self.nixosModules.sandbox;
      testScript = builtins.readFile ./mcp.py;
    };
  in {
    packages.sandbox = sandbox.driver;
    apps.sandbox = {
      type = "app";
      program = "${sandbox.driver}/bin/nixos-test-driver";
      meta.description = "Disposable VM + MCP server for testing desktop UI";
    };
  };
}
