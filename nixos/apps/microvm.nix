{self, ...}: {
  flake.nixosModules.app-microvm = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.apps.microvm;

    guestName = "mujo-quarantine";

    # AF_VSOCK addresses. 0, 1 and 2 are reserved by the protocol
    # (hypervisor, loopback, host), so the guest gets an arbitrary id above
    # those. Two ports cross the boundary and no others:
    #
    #   host -> guest, port 1024 : "run this command line"
    #   guest -> host, port 6000 : the Wayland stream, via waypipe
    #
    # Nothing else is shared. There is no tap device, no host directory beyond
    # the read-only Nix store, and no host D-Bus.
    agentPort = 1024;
    waypipePort = 6000;
    dbusPort = 6001;

    caps = cfg.capabilities;

    # The one host directory a quarantined application can write to, when the
    # downloads capability is on. Files a user wants to keep have to leave the
    # domain somehow; this is that somewhere, and it is the only one.
    #
    # Host uid 1000 and guest uid 1000 are both the intended owner, so virtiofs
    # needs no id translation.
    user = config.preferences.user.name;
    downloadsHost = "/home/${user}/Quarantine";
    downloadsGuest = "/home/quarantine/Downloads";

    # PulseAudio over qemu's user-mode network. 10.0.2.2 is the SLIRP gateway,
    # which maps to the host's loopback, so the guest reaches a service bound to
    # 127.0.0.1 without the host opening a port to the outside world.
    pulseTcpPort = 4713;

    # One definition of the environment a quarantined application runs under.
    # It used to be spelled out four times -- the session script, the guest's
    # own sessionVariables, and both `flatpak run` argument lists -- which is
    # how the GPU switch below would have been forgotten in one of them.
    waylandEnv = {
      QT_QPA_PLATFORM = "wayland";
      GDK_BACKEND = "wayland";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      XDG_SESSION_TYPE = "wayland";
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      MOZ_ENABLE_WAYLAND = "1";
      MOZ_WEBRENDER = "1";
    };

    # Unless the guest is on llvmpipe, nothing here may force software
    # rendering: mesa picks virgl or the native context off the virtio-gpu's
    # capset by itself, and this forcing is what used to cap every window at
    # llvmpipe regardless. When llvmpipe *is* all there is, it gets every vCPU
    # and the widest vector unit it can use.
    graphicsEnv =
      {
        MESA_NO_ERROR = "1";
        vblank_mode = "0";
      }
      // lib.optionalAttrs (cfg.gpu == "none") {
        GALLIUM_DRIVER = "llvmpipe";
        LIBGL_ALWAYS_SOFTWARE = "1";
        LP_NUM_THREADS = toString cfg.cores;
        LP_NATIVE_VECTOR_WIDTH = "256";
      };

    # blob resources put guest buffers in a host memory window instead of
    # copying them through the command stream; both modes below need it, and
    # the native context is useless without it.
    gpuArgs = {
      none = [];
      virgl = [
        "-device"
        "virtio-gpu-gl-pci,blob=true,hostmem=4G,max_hostmem=8G"
        "-display"
        "egl-headless"
      ];
      native = [
        "-device"
        "virtio-gpu-gl-pci,drm_native_context=on,blob=true,hostmem=4G,max_hostmem=8G"
        "-display"
        "egl-headless"
      ];
    };

    themeEnv = {
      GTK_THEME = "Skeuos-Grey-Dark";
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";
      QS_ICON_THEME = "Colloid-Dark";
    };

    appEnv = waylandEnv // graphicsEnv;
    sessionEnv = appEnv // themeEnv;

    sessionExports =
      lib.concatStringsSep "\n"
      (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") sessionEnv);

    flatpakEnvArgs =
      lib.concatStringsSep " "
      (lib.mapAttrsToList (k: v: ''"--env=${k}=${v}"'') appEnv);

    # ── guest side ────────────────────────────────────────────────────────

    # Carries a Flatpak's tray icon and notifications out of the domain. See
    # nixos/apps/tray-relay.py for why a Flatpak cannot simply use the host bus
    # the way a native application does.
    trayRelay = pkgs.writeScriptBin "mujo-tray-relay" ''
      #!${pkgs.python3.withPackages (ps: [ps.dbus-next])}/bin/python3
      ${builtins.readFile ./tray-relay.py}
    '';

    # One instance runs per accepted connection (systemd socket Accept=yes),
    # so stdin/stdout *are* the vsock connection: the host writes one line of
    # shell, and whatever the process prints comes back the same way.
    guestAgent = pkgs.writeShellApplication {
      name = "mujo-quarantine-agent";
      runtimeInputs = with pkgs; [waypipe coreutils];
      text = ''
        IFS= read -r request || request=""

        # An empty line is the liveness probe mujo-quarantine-run uses while
        # the guest is still booting. Answer it and say nothing.
        if [ -z "$request" ]; then
          exit 0
        fi

        # Wire format is one line: MODE<TAB>COMMAND. The host decides the mode,
        # because only the host knows whether a compositor and a waypipe client
        # are actually there to receive a window.
        mode=''${request%%	*}
        cmdline=''${request#*	}

        export XDG_RUNTIME_DIR=/run/mujo-agent

        # A systemd service inherits a bare PATH. The host resolves the launched
        # binary to an absolute store path before sending it, so an application
        # starts either way -- but anything it shells out to by name would not,
        # which made the guest look like it had no network when it does.
        export PATH=/run/wrappers/bin:/run/current-system/sw/bin:$PATH

        ${lib.optionalString caps.audio ''
          # PulseAudio's protocol carries both playback and capture, so this
          # single setting is also what grants microphone access. That is why
          # apps.microvm.capabilities.audio defaults to off.
          export PULSE_SERVER=tcp:10.0.2.2:${toString pulseTcpPort}
        ''}

        if [ "$mode" = "gui" ]; then
          # waypipe server connects out to the host's waypipe client (CID 2) and
          # sets WAYLAND_DISPLAY for the child, so the application believes it
          # is talking to a local compositor. mujo-quarantine-session starts the
          # in-guest desktop services that need to share that display.
          # Use --compress none because AF_VSOCK is in-memory IPC: compressing frames
          # with lz4 wastes guest CPU, increases latency, and caps refresh rate.
          exec waypipe --compress none --vsock -s 2:${toString waypipePort} server -- \
            ${lib.getExe guestSession} "$cmdline"
        fi

        exec /bin/sh -c "$cmdline"
      '';
    };

    # Runs inside the waypipe session, so everything it starts shares the
    # forwarded display and appears on the host desktop as ordinary windows.
    guestSession = pkgs.writeShellApplication {
      name = "mujo-quarantine-session";
      runtimeInputs = with pkgs; [coreutils dbus socat];
      text = ''
        ${sessionExports}
        ${lib.optionalString caps.audio ''
          export PULSE_SERVER=tcp:10.0.2.2:${toString pulseTcpPort}
        ''}

        # Ensure per-application isolated persistent state across quarantine & host tiers
        app_id=""
        is_flatpak=0
        for arg in $1; do
          case "$arg" in
            flatpak|run) is_flatpak=1 ;;
            -*) ;;
            *)
              app_id=$(basename "$arg")
              break
              ;;
          esac
        done
        [ -n "$app_id" ] || app_id="general"

        if [ "$is_flatpak" -eq 1 ] || [ -d "/var/lib/flatpak/app/$app_id" ]; then
          # Flatpak app: dedicated persistent storage directly in /home/quarantine/.var/app
          is_flatpak=1
          mkdir -p "/home/quarantine/.var/app/$app_id" 2>/dev/null || true
          chmod 700 "/home/quarantine/.var/app/$app_id" 2>/dev/null || true
          export HOME="/home/quarantine"
        else
          # Native app: point HOME to its dedicated persistent sandbox directory from host
          mkdir -p "/mnt/host-sandboxes/$app_id" 2>/dev/null || true
          chmod 700 "/mnt/host-sandboxes/$app_id" 2>/dev/null || true
          export HOME="/mnt/host-sandboxes/$app_id"
        fi

        # The host's session bus, filtered by xdg-dbus-proxy on the far side of
        # the vsock. This is what puts a quarantined application's tray icon in
        # the host's tray: StatusNotifierItem only works when the application
        # and the watcher share one bus, because the watcher calls back into the
        # application to read its icon, title and menu. A per-interface bridge
        # -- which is what notifications used to have -- can forward a one-way
        # Notify but has no way to answer those calls.
        #
        # ponytail: the guest's own xdg-desktop-portal is unreachable from this
        # bus, and the host's is deliberately not in the filter (it would hand
        # out host file dialogs), so file choosers fall back to the toolkit's
        # own. Add a portal only if something actually needs it.
        # Per launch: XDG_RUNTIME_DIR is shared by every mujo-agent@ instance,
        # so a fixed name would have the second launch unlink the first's socket.
        bus="$XDG_RUNTIME_DIR/host-bus-$$"
        rm -f "$bus"
        socat "UNIX-LISTEN:$bus,fork,unlink-early" \
          VSOCK-CONNECT:2:${toString dbusPort} &
        for _ in $(seq 1 100); do
          [ -S "$bus" ] && break
          sleep 0.05
        done

        # No trap needed anywhere below: this is the main process of the
        # mujo-agent@ unit, and systemd tears the whole cgroup down -- socat and
        # the relay included -- when it exits.

        # A Flatpak cannot use that bus directly. Two reasons, either one fatal:
        #
        #   * `flatpak run` interposes its own xdg-dbus-proxy, and two of those
        #     in a row do not compose. flatpak-proxy reserves the top 65536
        #     serials for messages it originates, and the bridge's proxy on the
        #     far side rejects those as "Invalid client serial" and drops the
        #     connection, so the application never finishes connecting.
        #   * zypak -- the Chromium sandbox shim every Electron Flatpak runs
        #     under -- spawns its renderers through org.freedesktop.portal.Flatpak.
        #     That name is necessarily guest-local: forwarding it would have the
        #     *host's* portal spawning processes on the host, which is the one
        #     thing this domain exists to prevent. Without it every renderer
        #     exits immediately and the window stays blank.
        #
        # So a Flatpak gets a private guest bus, and mujo-tray-relay carries the
        # two things that have to leave the domain across to the host bus: the
        # StatusNotifierItem, and notifications. Without it, closing Vesktop or
        # Steam "to tray" simply lost the window -- the application went on
        # running against a tray that existed only inside the VM.
        if [ "$is_flatpak" -eq 1 ]; then
          export MUJO_HOST_BUS="unix:path=$bus"
          ${lib.optionalString caps.notifications "export MUJO_RELAY_NOTIFICATIONS=1"}
          # shellcheck disable=SC2016 # $1 is the inner shell's, not this one's
          exec dbus-run-session -- /bin/sh -c \
            '${trayRelay}/bin/mujo-tray-relay & exec /bin/sh -c "$1"' sh "$1"
        fi

        export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
        exec /bin/sh -c "$1"
      '';
    };

    quarantineGuest = {
      lib,
      pkgs,
      ...
    }: {
      imports = [
        self.nixosModules.gtk
      ];

      boot.kernelParams = [
        "clocksource=tsc"
        "tsc=reliable"
        "nohpet"
        "nomce"
        "elevator=none"
        "quiet"
        "rd.udev.log_level=3"
        "systemd.show_status=auto"
        # microvm's own optimize module normally supplies this; it is off below.
        "8250.nr_uarts=1"
        "nowatchdog"
        "random.trust_cpu=on"
        # Guest-internal speculative-execution mitigations only. The boundary
        # that matters here is KVM's, which the *host* kernel enforces and this
        # cannot touch; what it buys back is the syscall overhead a disposable
        # single-purpose guest has no reason to pay.
        "mitigations=off"
      ];

      microvm = {
        hypervisor = "qemu";
        mem = cfg.memoryMb;
        vcpu = cfg.cores;
        vsock.cid = cfg.cid;

        virtiofsd.threadPoolSize = 16;

        # microvm's optimize module force-overrides qemu to the stripped
        # nixosTestRunner build, which has no EGL and so cannot drive
        # virtio-gpu-gl. Its supported alternative -- microvm.graphics.enable --
        # instead rebuilds qemu from source for USB input devices this domain
        # has no use for, and that rebuild returns on every nixpkgs bump. So:
        # turn optimize off, keep the three things it actually did (below and in
        # kernelParams), and use the cached pkgs.qemu.
        optimize.enable = false;
        qemu = {
          package = pkgs.qemu;
          extraArgs = gpuArgs.${cfg.gpu};
        };

        # qemu's user-mode network stack: the guest gets NATed internet with no
        # tap device on the host and no interface it shares with the host LAN.
        # Caveat worth knowing: SLIRP routes through the host, so the guest can
        # still reach whatever the host can route to. Blocking the LAN range
        # belongs in the guest firewall below, not in the interface type.
        interfaces = [
          {
            type = "user";
            id = "qvm-net";
            mac = "02:00:00:6d:75:6a";
          }
        ];

        # The only host paths the guest can see: read-only Nix store and Flatpaks,
        # plus host-persisted per-app data shares (/home/${user}/.var/app and /home/${user}/.local/share/mujo-sandboxes).
        # /persist, real host /home and /run/mujo/vault are absent because they are never bound in.
        shares =
          [
            {
              proto = "virtiofs";
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              cache = "always";
            }
            {
              proto = "virtiofs";
              tag = "ro-flatpak";
              source = "/var/lib/flatpak";
              mountPoint = "/var/lib/flatpak";
              cache = "always";
            }
            {
              proto = "virtiofs";
              tag = "flatpak-data";
              source = "/home/${user}/.var/app";
              mountPoint = "/home/quarantine/.var/app";
            }
            {
              proto = "virtiofs";
              tag = "sandbox-data";
              source = "/home/${user}/.local/share/mujo-sandboxes";
              mountPoint = "/mnt/host-sandboxes";
            }
          ]
          ++ lib.optional caps.downloads {
            proto = "virtiofs";
            tag = "downloads";
            source = downloadsHost;
            mountPoint = downloadsGuest;
          };
      };

      # No microvm.volumes are declared, so / is a tmpfs. The guest is rebuilt
      # from the Nix store on every start and keeps nothing across a shutdown,
      # which is what makes "destroy and recreate" the only recovery path.
      # What microvm.optimize.enable used to set for us. Everything else it did
      # is either already spelled out here or does not apply to this guest.
      documentation.enable = false;
      boot.initrd.systemd.enable = true;
      system.switch.enable = false;
      systemd.network.wait-online.enable = false;

      networking = {
        hostName = guestName;
        useNetworkd = true;
        firewall = {
          enable = true;
          # Nothing listens on the network. The agent is on vsock, which the
          # firewall does not cover, and that is the point: the control channel
          # is not reachable over IP at all.
          allowedTCPPorts = [];
        };
      };
      systemd.network.networks."10-quarantine" = {
        matchConfig.Type = "ether";
        networkConfig.DHCP = "yes";
      };
      services.resolved.enable = true;

      users.users.quarantine = {
        isNormalUser = true;
        uid = 1000;
        group = "quarantine";
        home = "/home/quarantine";
        createHome = true;
      };
      users.groups.quarantine = {};

      # llvmpipe. The guest has no GPU: waypipe ships finished buffers to the
      # host compositor, so nothing here needs a passthrough device.
      hardware.graphics.enable = true;
      fonts = {
        enableDefaultPackages = true;
        packages = with pkgs; [
          ubuntu-sans
          fira-code
          nerd-fonts.jetbrains-mono
          material-symbols
        ];
      };

      services.dbus.enable = true;
      services.flatpak.enable = true;
      programs.fuse.userAllowOther = true;
      boot.kernelModules = ["fuse"] ++ lib.optional (cfg.gpu != "none") "virtio_gpu";
      security.unprivilegedUsernsClone = true;
      boot.kernel.sysctl = {
        "kernel.unprivileged_userns_clone" = 1;
        "user.max_user_namespaces" = 65536;
      };
      xdg.portal = {
        enable = true;
        extraPortals = [pkgs.xdg-desktop-portal-gtk];
        config.common.default = "*";
      };

      environment.sessionVariables =
        sessionEnv
        // lib.optionalAttrs caps.audio {
          PULSE_SERVER = "tcp:10.0.2.2:${toString pulseTcpPort}";
        };

      systemd.sockets.mujo-agent = {
        wantedBy = ["sockets.target"];
        socketConfig = {
          ListenStream = "vsock::${toString agentPort}";
          Accept = "yes";
        };
      };
      systemd.services."mujo-agent@" = {
        description = "Mujo quarantine exec agent";
        serviceConfig = {
          ExecStart = lib.getExe guestAgent;
          StandardInput = "socket";
          StandardOutput = "socket";
          # Back to the caller, not the guest journal: a quarantined program
          # that fails should say why on the terminal that launched it, rather
          # than exiting in silence.
          StandardError = "socket";
          User = "quarantine";
          Group = "quarantine";
          RuntimeDirectory = "mujo-agent";
          RuntimeDirectoryPreserve = "yes";
        };
      };

      environment.systemPackages = with pkgs;
        [
          waypipe
          xdg-utils
          flatpak
          socat
        ]
        ++ lib.optionals caps.audio [libpulseaudio pulseaudio alsa-utils];
      system.stateVersion = config.system.stateVersion;
    };

    # ── host side ─────────────────────────────────────────────────────────
    mujoQuarantineRun = pkgs.writeShellApplication {
      name = "mujo-quarantine-run";
      runtimeInputs = with pkgs; [coreutils socat systemd];
      text = ''
        if [ "$#" -lt 1 ]; then
          cat >&2 <<'USAGE'
        Usage: mujo-quarantine-run <command> [args...]

        Runs <command> inside the Mujo quarantine MicroVM: ephemeral tmpfs root,
        read-only Nix store and Flatpaks, no host home, no /persist, no vault.
        Graphical output is forwarded to this session over waypipe.

        Boundary: a KVM virtual machine. See docs/application-trust.md.
        USAGE
          exit 64
        fi

        cmdline=""
        if [ "$1" = "flatpak" ]; then
          shift
          if [ "''${1:-}" = "run" ]; then
            shift
          fi
          # shellcheck disable=SC2059
          cmdline=$(printf '%q ' "flatpak" "run" \
            ${lib.optionalString caps.audio ''"--socket=pulseaudio" "--env=PULSE_SERVER=tcp:10.0.2.2:${toString pulseTcpPort}"''} \
            ${flatpakEnvArgs} \
            "$@")
        elif [ -d "/var/lib/flatpak/app/$1" ]; then
          # Flatpak app passed by ID (e.g. dev.vencord.Vesktop, app.zen_browser.zen)
          # shellcheck disable=SC2059
          cmdline=$(printf '%q ' "flatpak" "run" \
            ${lib.optionalString caps.audio ''"--socket=pulseaudio" "--env=PULSE_SERVER=tcp:10.0.2.2:${toString pulseTcpPort}"''} \
            ${flatpakEnvArgs} \
            "$@")
        else
          # Resolve to a store path before crossing the boundary. /run/current-system
          # inside the guest is the *guest's* system, so a host PATH entry such as
          # /run/current-system/sw/bin/firefox would resolve to the wrong thing --
          # or to nothing -- once it gets there.
          if ! target=$(type -P "$1") || [ -z "$target" ]; then
            echo "mujo-quarantine-run: $1: not found" >&2
            exit 127
          fi

          # Resolve the *directory* into the store and keep the original file
          # name. Fully resolving the path would follow uname -> coreutils, and a
          # multicall binary dispatches on argv[0]: the guest would silently run
          # `coreutils -a` instead of `uname -a`. Resolving only the directory
          # yields a store path the guest can see, still ending in the name the
          # program expects to be called by.
          target="$(readlink -f "$(dirname "$target")")/$(basename "$target")"
          case "$target" in
            /nix/store/*) ;;
            *)
              echo "mujo-quarantine-run: $1 does not resolve into the Nix store; the guest could not see it." >&2
              exit 127
              ;;
          esac
          shift
          # shellcheck disable=SC2059 # %q is the point: this is quoted for the guest shell
          cmdline=$(printf '%q ' "$target" "$@")
        fi

        if ! systemctl is-active --quiet "microvm@${guestName}.service"; then
          echo "mujo-quarantine-run: starting quarantine domain..." >&2
          systemctl start "microvm@${guestName}.service"
        fi

        # The host end of the Wayland bridge runs in the user session because
        # that is where WAYLAND_DISPLAY lives; systemd's user manager does not
        # inherit it on its own. Without a compositor there is nothing to
        # forward to, and the guest is told so rather than being left to hang
        # against a vsock port nobody is listening on.
        mode=nogui
        if [ -n "''${WAYLAND_DISPLAY:-}" ] &&
           systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR 2>/dev/null &&
           systemctl --user start mujo-waypipe-client.service mujo-quarantine-dbus-bridge.service 2>/dev/null; then
          mode=gui
        fi

        # Wait for the guest agent. An empty line is the probe the agent
        # answers silently, so this does not leave failed units behind.
        ready=""
        for _ in $(seq 1 120); do
          if : | socat -T2 - "VSOCK-CONNECT:${toString cfg.cid}:${toString agentPort}" >/dev/null 2>&1; then
            ready=yes
            break
          fi
          sleep 1
        done
        if [ -z "$ready" ]; then
          echo "mujo-quarantine-run: quarantine domain did not come up (see journalctl -u microvm@${guestName})" >&2
          exit 69
        fi

        printf '%s\t%s\n' "$mode" "$cmdline" |
          socat - "VSOCK-CONNECT:${toString cfg.cid}:${toString agentPort}"
      '';
    };
  in {
    options.apps.microvm = {
      enable =
        lib.mkEnableOption "Mujo quarantine MicroVM for untrusted applications"
        // {default = true;};

      memoryMb = lib.mkOption {
        type = lib.types.int;
        default = 8192;
        description = ''
          Memory ceiling for the quarantine domain. A ceiling, not a
          reservation: qemu's memfd backing is not preallocated, so an idle
          domain does not hold this.
        '';
      };

      cores = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = ''
          vCPU count for the quarantine domain. Worth more than it looks when
          `gpu = "none"`, because llvmpipe rasterises across every vCPU it is
          given -- that is the whole of the software-rendering fallback's
          throughput.
        '';
      };

      gpu = lib.mkOption {
        type = lib.types.enum ["none" "virgl" "native"];
        default = "native";
        description = ''
          How the quarantine domain reaches the GPU.

          `none`
            : llvmpipe. Every frame is rasterised on the guest's vCPUs, which
              is why `cores` matters most in this mode.

          `virgl`
            : virtio-gpu with virglrenderer. The guest's GL command stream is
              translated by qemu and replayed against the host driver. Real
              acceleration, and virglrenderer parses everything the guest
              sends, so it is the narrower of the two accelerated modes.

          `native`
            : virtio-gpu with `drm_native_context=on`. The guest's mesa
              (radeonsi and RADV both, via its `amdvgpu` winsys) speaks the
              *native amdgpu UAPI*, which virglrenderer's amdgpu renderer
              hands to the host's real driver. This is as close to passthrough
              as a single-GPU machine gets: no VFIO, no IOMMU, and the host
              keeps its display, because the card is shared rather than
              assigned.

          **True VFIO passthrough is not available on this machine and this
          option cannot provide it.** There is one GPU (`1002:7590` at
          `0000:03:00.0`) and it drives both monitors; assigning it to the
          guest would take the desktop with it. `/sys/kernel/iommu_groups` is
          also empty — the IOMMU is off, and turning it on is an early-boot
          kernel parameter, which this repo does not enable by default.

          The tradeoff for `native`, stated plainly: an untrusted guest is
          issuing amdgpu ioctls that reach the host kernel's GPU driver, with
          virglrenderer's `amdgpu-experimental` renderer in between. That is a
          far wider hole than `virgl`, and wider still than the "no device
          passthrough at all" docs/application-trust.md §6 used to claim. Drop
          to `virgl` for a narrower surface at some cost in speed, or `none` to
          give the domain no GPU path at all.
        '';
      };

      cid = lib.mkOption {
        type = lib.types.int;
        default = 42;
        description = ''
          AF_VSOCK context id of the quarantine guest. Must not be 0, 1 or 2,
          which the protocol reserves for the hypervisor, loopback and host.
        '';
      };

      # The capability profile of docs/application-trust.md §4, as the subset
      # that is actually enforced. Screen, keyboard, clipboard and drag-and-drop
      # are not listed because waypipe carries them as part of the Wayland
      # protocol itself; camera and direct GPU are not listed because the domain
      # has no device passthrough at all, so there is nothing to switch off.
      capabilities = {
        downloads =
          lib.mkEnableOption "host Downloads directory sharing (read-write)"
          // {default = false;};
        audio =
          lib.mkEnableOption "host PulseAudio sharing (playback and capture)"
          // {default = true;};
        notifications =
          lib.mkEnableOption "desktop notifications from the quarantine domain"
          // {default = true;};
      };
    };

    config = lib.mkIf cfg.enable {
      microvm.vms.${guestName} = {
        # Not started at boot: an idle domain would hold cfg.memoryMb for
        # nothing. mujo-quarantine-run brings it up on first use. Pre-warming a
        # pool is Phase 37 and is not needed to make the boundary real.
        autostart = false;
        config = quarantineGuest;
      };

      boot.kernelModules = ["vhost_vsock"];

      # Created before the microvm host module's own tmpfiles rule runs
      # (00-nixos.conf sorts ahead of 10-microvm.conf), so the exchange
      # directory ends up owned by the user rather than by the VM runner.
      systemd.tmpfiles.rules =
        [
          "d /home/${config.preferences.user.name}/.var/app 0755 ${config.preferences.user.name} users -"
          "d /home/${config.preferences.user.name}/.local/share/mujo-sandboxes 0755 ${config.preferences.user.name} users -"
        ]
        ++ lib.optional caps.downloads "d ${downloadsHost} 0700 ${config.preferences.user.name} users -";

      # qemu runs as the unprivileged `microvm` user (group kvm, created by the
      # microvm host module), so it needs the vsock device to be group-readable.
      services.udev.extraRules = ''
        KERNEL=="vhost-vsock", GROUP="kvm", MODE="0660"
      '';

      # egl-headless renders through the host's DRM render node. It is 0666 on
      # this machine already, but qemu runs as `microvm` and a mode change
      # upstream should not silently turn GL back into llvmpipe.
      users.users.microvm.extraGroups = lib.mkIf (cfg.gpu != "none") ["render" "video"];

      # Bringing the domain up is a privileged operation, but requiring a
      # password to launch an application would push people straight back to
      # running it unquarantined. Scoped to this one unit.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "microvm@${guestName}.service" &&
              subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';

      systemd.user.services.mujo-waypipe-client = {
        description = "Host end of the Mujo quarantine Wayland bridge";
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.waypipe} --compress none --vsock -s ${toString waypipePort} client";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      # The guest's whole session bus, filtered. xdg-dbus-proxy is what keeps
      # this from being "the quarantine domain gets the host bus": everything is
      # denied unless named below, so a quarantined application can raise a
      # notification and own a tray item, and can see nothing else on the bus.
      #
      # StatusNotifierItem is a two-way protocol -- the watcher calls back into
      # the application for its icon, title and menu -- which is why the tray
      # needs a bus and not the one-way vsock bridge notifications used to have.
      # `--own=org.kde.*` is what covers the item name, because it is
      # org.kde.StatusNotifierItem-<pid>-<n>, with a dash the proxy's `name.*`
      # wildcard does not match.
      systemd.user.services.mujo-quarantine-dbus-bridge = {
        description = "Host end of the Mujo quarantine D-Bus bridge (notifications, system tray)";
        serviceConfig = {
          ExecStart = lib.getExe (pkgs.writeShellApplication {
            name = "mujo-quarantine-dbus-bridge";
            runtimeInputs = with pkgs; [coreutils socat xdg-dbus-proxy];
            text = ''
              sock="$XDG_RUNTIME_DIR/mujo-quarantine-bus"
              rm -f "$sock"
              xdg-dbus-proxy "unix:path=$XDG_RUNTIME_DIR/bus" "$sock" --filter \
                ${lib.concatStringsSep " " (
                lib.optional caps.notifications
                ''--call='org.freedesktop.Notifications=org.freedesktop.Notifications.*@/org/freedesktop/Notifications' ''
                ++ [
                  "--talk=org.kde.StatusNotifierWatcher"
                  "'--own=org.kde.*'"
                  "--talk=org.freedesktop.DBus"
                ]
              )} &
              for _ in $(seq 1 100); do
                [ -S "$sock" ] && break
                sleep 0.05
              done
              exec socat VSOCK-LISTEN:${toString dbusPort},fork,reuseaddr \
                "UNIX-CONNECT:$sock"
            '';
          });
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      environment.systemPackages = [mujoQuarantineRun];
    };
  };
}
