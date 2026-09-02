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
      self.nixosModules.gtk
    ];

    boot.kernelParams = lib.mkAfter [
      "clocksource=tsc"
      "tsc=reliable"
      "nohpet"
      "mitigations=off"
      "nowatchdog"
      "audit=0"
      "nomce"
      "elevator=none"
      "quiet"
      "rd.udev.log_level=3"
      "systemd.show_status=auto"
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
          "-machine hpet=off"
          "-global kvm-pit.lost_tick_policy=discard"
          # virgl over a host render node: real GLES in the guest with zero-copy blob memory
          "-vga none"
          "-device virtio-gpu-gl-pci,xres=1280,yres=800,blob=true,hostmem=1G,max_hostmem=2G"
          "-display egl-headless"
          "-spice port=5920,disable-ticketing=on"
        ];
      };
      sharedDirectories.nixconf = {
        source = ''''${MUJO_SANDBOX_REPO:-/home/${user}/nixconf}'';
        target = "/mnt/nixconf";
        securityModel = "none";
      };
      sharedDirectories.hostConfig = {
        source = ''''${MUJO_SANDBOX_CONFIG:-/home/${user}/.config}'';
        target = "/mnt/host-config";
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
      fileSystems."/mnt/host-config".options = [
        "ro"
        "trans=virtio"
        "version=9p2000.L"
        "msize=1048576"
        "cache=loose"
        "posixacl=0"
      ];
      fileSystems."/nix/.ro-store".options = [
        "ro"
        "trans=virtio"
        "version=9p2000.L"
        "msize=1048576"
        "cache=loose"
        "posixacl=0"
      ];
      fileSystems."/tmp/shared".options = [
        "trans=virtio"
        "version=9p2000.L"
        "msize=1048576"
        "cache=none"
        "posixacl=0"
      ];
    };

    environment.sessionVariables = {
      QML_DISK_CACHE_PATH = "/run/qmlcache";
      QSG_RHI_BACKEND = "opengl";
      VK_DRIVER_FILES = "";
      VK_ICD_FILENAMES = "";
    };

    services.pipewire.enable = lib.mkForce false;
    security.rtkit.enable = lib.mkForce false;
    services.upower.enable = lib.mkForce false;
    services.udisks2.enable = lib.mkForce false;
    services.power-profiles-daemon.enable = lib.mkForce false;
    services.flatpak.enable = lib.mkForce false;
    services.printing.enable = lib.mkForce false;

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
    # Fast boot: disable network daemons in sandbox
    networking = {
      useDHCP = false;
      dhcpcd.enable = false;
      networkmanager.enable = false;
    };
    systemd.services = {
      dhcpcd.enable = false;
      NetworkManager-wait-online.enable = false;
      bluetooth.serviceConfig.ExecStart = "${pkgs.coreutils}/bin/false";
      ModemManager.serviceConfig.ExecStart = "${pkgs.coreutils}/bin/false";
      wpa_supplicant.serviceConfig.ExecStart = "${pkgs.coreutils}/bin/false";
    };

    # Portals pull in the whole GNOME portal stack for no benefit here.
    xdg.portal.enable = lib.mkForce false;

    # Start the compositor on autologin. Deliberately not `niri-session`: that
    # script re-execs $SHELL as a login shell, which re-enters this hook and
    # forkbombs. niri.service's own `niri --session` does the systemd/D-Bus
    # environment import anyway.
    programs.bash.loginShellInit = ''
      if [ "$(tty)" = /dev/tty1 ]; then
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

    # Point the stable /etc path at an in-memory tmpfs copy synced from the
    # 9p working tree. Reading 140 QML files and resolving thousands of type
    # lookups over 9p VirtFS introduces massive IOPS latency; running from
    # RAM tmpfs drops shell load times from ~18s to under 1s.
    systemd.tmpfiles.rules = [
      "d /tmp/shared 1777 root root -"
      "d /run/qmlcache 1777 root root -"
      "d /run/quickshell-bar 0755 ${user} users -"
    ];

    systemd.services.sync-quickshell-bar = {
      description = "Sync quickshell bar into RAM tmpfs and seed state";
      wantedBy = ["multi-user.target"];
      before = ["graphical.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "sync-sandbox-state" ''
          mkdir -p /run/quickshell-bar /run/qmlcache /tmp/shared
          chmod 1777 /tmp/shared /run/qmlcache
          ${pkgs.coreutils}/bin/cp -a /mnt/nixconf/quickshell/bar/. /run/quickshell-bar/
          mkdir -p /home/${user}/.cache/qsshell /home/${user}/.local/state/qsshell /home/${user}/.config/quickshell /home/${user}/.config/qsshell

          # Sync host quickshell & qsshell theme/settings if mounted
          if [ -d /mnt/host-config/quickshell ]; then
            ${pkgs.coreutils}/bin/cp -a /mnt/host-config/quickshell/. /home/${user}/.config/quickshell/ 2>/dev/null || true
          fi
          if [ -d /mnt/host-config/qsshell ]; then
            ${pkgs.coreutils}/bin/cp -a /mnt/host-config/qsshell/. /home/${user}/.config/qsshell/ 2>/dev/null || true
          fi

          # Ensure fallback defaults if files don't exist
          [ -f /home/${user}/.cache/qsshell/weather.json ] || echo '{"temp":20,"code":0,"city":"Sandbox","humidity":50,"wind":5,"updated":'$(date +%s)',"units":"metric"}' > /home/${user}/.cache/qsshell/weather.json
          [ -f /home/${user}/.local/state/qsshell/desktop.json ] || echo '{"items":[],"positions":{}}' > /home/${user}/.local/state/qsshell/desktop.json
          [ -f /home/${user}/.local/state/qsshell/notifications.json ] || echo '[]' > /home/${user}/.local/state/qsshell/notifications.json
          [ -f /home/${user}/.local/state/qsshell/shelf.json ] || echo '{"items":[]}' > /home/${user}/.local/state/qsshell/shelf.json
          chown -R ${user}:users /home/${user} /run/quickshell-bar
        '';
        RemainAfterExit = true;
      };
    };

    environment.etc."xdg/quickshell/bar".source =
      lib.mkForce "/run/quickshell-bar";

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
