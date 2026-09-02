{...}: {
  flake.nixosModules.app-native-sandbox = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.apps.nativeSandbox;
    user = config.preferences.user.name;

    # The runtime a GRADUATED application gets: cheaper than a VM, still not the
    # host. Everything a capability would grant is absent unless the caller asks
    # for it by name, so the default launch is the most restricted one.
    mujoSandboxRun = pkgs.writeShellApplication {
      name = "mujo-sandbox-run";
      runtimeInputs = with pkgs; [bubblewrap coreutils util-linux flatpak xdg-dbus-proxy procps];
      text = ''
        USER_HOME="/home/${user}"
        # The suite and any non-graphical caller run without a session
        # environment, and an unset variable under `set -u` would abort the
        # launch rather than simply forwarding no Wayland socket.
        RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

        usage() {
          cat >&2 <<'USAGE'
        Usage: mujo-sandbox-run [capability...] <command> [args...]

        Runs <command> in the graduated native sandbox: its own mount, PID, IPC
        and UTS namespaces, an ephemeral home, and no access to /persist, the
        vault, or the user's keys.

        Capabilities, each off unless named (docs/application-trust.md §4):
          --app <name>     Attach this application's credential broker socket
          --dir <path>     Bind one host directory read-write
          --ro-dir <path>  Bind one host directory read-only
          --camera         Allow /dev/video* (denied by default)
          --no-net         Remove network access
        USAGE
          exit 64
        }

        binds=()
        app=""
        share_net=--share-net
        camera=0

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --app)    [ "$#" -ge 2 ] || usage; app="$2"; shift 2 ;;
            --dir)    [ "$#" -ge 2 ] || usage; binds+=(--bind "$(realpath "$2")" "$(realpath "$2")"); shift 2 ;;
            --ro-dir) [ "$#" -ge 2 ] || usage; binds+=(--ro-bind "$(realpath "$2")" "$(realpath "$2")"); shift 2 ;;
            --camera) camera=1; shift ;;
            --no-net) share_net=--unshare-net; shift ;;
            --)       shift; break ;;
            -*)       usage ;;
            *)        break ;;
          esac
        done

        [ "$#" -ge 1 ] || usage

        # Flatpak applications manage their own Bubblewrap sandbox and
        # cannot be nested inside an unprivileged Bubblewrap namespace.
        if [ -d "/var/lib/flatpak/app/$1" ]; then
          exec flatpak run "$@"
        fi
        if [ "$1" = "flatpak" ]; then
          exec "$@"
        fi

        # Determine application identifier for isolated persistent state
        app_name="$app"
        if [ -z "$app_name" ]; then
          app_name=$(basename "$1")
        fi

        # Isolated per-application persistent storage.
        # Each sandboxed application gets its own dedicated directory under
        # ~/.local/share/mujo-sandboxes/<app_name> with strict 0700 permissions.
        # Only this application's Bubblewrap namespace mounts this directory as HOME.
        # Other applications cannot see or access it, and the real host HOME/vault/persist
        # remain completely hidden.
        SANDBOX_HOME="$USER_HOME/.local/share/mujo-sandboxes/$app_name"
        mkdir -p "$SANDBOX_HOME"
        chmod 700 "$SANDBOX_HOME"

        # One credential socket, bound to a fixed path inside. This is what
        # makes the broker's ACL enforceable: the application cannot reach a
        # socket that was never bound into its mount namespace, whatever name it
        # claims over the wire.
        if [ -n "$app" ]; then
          host_sock="/run/mujo/secrets/$app.sock"
          if [ -S "$host_sock" ]; then
            binds+=(--ro-bind "$host_sock" /run/mujo/secret.sock)
          else
            echo "mujo-sandbox-run: no broker socket for '$app'; it was granted no credentials." >&2
          fi
        fi

        if [ "$camera" -eq 1 ]; then
          for dev in /dev/video*; do
            [ -e "$dev" ] && binds+=(--dev-bind "$dev" "$dev")
          done
        fi

        # Filtered D-Bus proxy: grants one-way notification sending and StatusNotifierItem tray support
        # while denying eavesdropping, signal listening, and access to host private services.
        dbus_proxy_dir=""
        if [ -S "$RUNTIME_DIR/bus" ]; then
          dbus_proxy_dir=$(mktemp -d "$RUNTIME_DIR/mujo-dbus-XXXXXX" 2>/dev/null || mktemp -d "/tmp/mujo-dbus-XXXXXX")
          dbus_sock="$dbus_proxy_dir/bus"
          xdg-dbus-proxy "unix:path=$RUNTIME_DIR/bus" "$dbus_sock" \
            --filter \
            --call="org.freedesktop.Notifications=org.freedesktop.Notifications.Notify@/org/freedesktop/Notifications" \
            --call="org.freedesktop.Notifications=org.freedesktop.Notifications.CloseNotification@/org/freedesktop/Notifications" \
            --call="org.freedesktop.Notifications=org.freedesktop.Notifications.GetCapabilities@/org/freedesktop/Notifications" \
            --call="org.freedesktop.Notifications=org.freedesktop.Notifications.GetServerInformation@/org/freedesktop/Notifications" \
            --talk="org.kde.StatusNotifierWatcher" \
            --own="org.kde.StatusNotifierItem.*" \
            --own="org.freedesktop.StatusNotifierItem.*" \
            --own="org.kde.*" \
            --talk="org.freedesktop.DBus" \
            --talk="org.freedesktop.portal.Desktop" \
            --talk="org.freedesktop.portal.Documents" \
            --talk="org.freedesktop.portal.Flatpak" &
          proxy_pid=$!
          for _ in $(seq 1 50); do
            [ -S "$dbus_sock" ] && break
            sleep 0.01
          done
          if [ -S "$dbus_sock" ]; then
            binds+=(--ro-bind "$dbus_sock" "$RUNTIME_DIR/bus")
          fi
          # shellcheck disable=SC2064
          trap "kill $proxy_pid 2>/dev/null || true; rm -rf '$dbus_proxy_dir'" EXIT INT TERM
        fi

        # Every bwrap PID namespace starts the payload at PID 2, and both Qt and
        # libappindicator derive their tray bus name from getpid():
        # org.kde.StatusNotifierItem-<pid>-1. So two sandboxed tray applications
        # asked the host bus for the same name, the second one lost it, and an
        # application that cannot own its name never reaches the host's tray.
        # Burning a launcher-dependent number of PIDs first, then starting the
        # payload as a child rather than exec'ing it (exec would keep the
        # shell's own PID 2), gives each one a different pid and so a different
        # name. The shell stays as a one-line supervisor that forwards the exit
        # status; bwrap's PID 1 still reaps everything.
        #
        # ponytail: host pid modulo 97, so two concurrent launches can still
        # land on the same offset about 1% of the time. A shared counter under
        # the sandbox state directory would make it exact if that ever bites.
        # shellcheck disable=SC2016 # $1/$@ are the inner shell's, not this one's
        pid_burn='n=$1; shift; while [ "$n" -gt 0 ]; do : & n=$((n-1)); done; wait; "$@" & app=$!; wait "$app"'
        set -- "$(( $$ % 97 ))" "$@"

        # PATH is set explicitly below rather than inherited. This wrapper's own
        # runtimeInputs sit at the front of its PATH, and a bwrap child inherits
        # the environment -- so without this the sandbox silently resolved
        # coreutils to the wrapper's plain build instead of the system's
        # coreutils-full, which is a different binary with different
        # performance. A sandbox should present the system's environment, not
        # the launcher's.
        #
        # /dev/snd is not bound: audio goes through the PipeWire socket below,
        # which the compositor session already mediates. Binding the raw device
        # would hand over every capture stream on the machine.
        # bwrap applies these in order, so every tmpfs has to come *before*
        # anything mounted underneath it. /run/current-system is what puts the
        # system profile on PATH; with --tmpfs /run listed after it, it was
        # covered back up and nothing inside the sandbox could resolve even sh.
        bwrap \
          --proc /proc \
          --dev /dev \
          --dev-bind-try /dev/dri /dev/dri \
          --dev-bind-try /dev/kfd /dev/kfd \
          --tmpfs /tmp \
          --tmpfs /run \
          --ro-bind /nix/store /nix/store \
          --ro-bind-try /run/current-system /run/current-system \
          --ro-bind-try /run/opengl-driver /run/opengl-driver \
          --ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32 \
          --ro-bind-try /etc /etc \
          --ro-bind-try /bin /bin \
          --ro-bind-try /usr /usr \
          --bind "$SANDBOX_HOME" "$USER_HOME" \
          --ro-bind-try "$RUNTIME_DIR/''${WAYLAND_DISPLAY:-wayland-0}" "$RUNTIME_DIR/''${WAYLAND_DISPLAY:-wayland-0}" \
          --ro-bind-try "$RUNTIME_DIR/pipewire-0" "$RUNTIME_DIR/pipewire-0" \
          --ro-bind-try "$RUNTIME_DIR/pulse" "$RUNTIME_DIR/pulse" \
          "''${binds[@]}" \
          --setenv HOME "$USER_HOME" \
          --setenv XDG_RUNTIME_DIR "$RUNTIME_DIR" \
          --setenv WAYLAND_DISPLAY "''${WAYLAND_DISPLAY:-wayland-0}" \
          --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$RUNTIME_DIR/bus" \
          --setenv MUJO_SECRET_SOCKET /run/mujo/secret.sock \
          --setenv PATH /run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin \
          --chdir "$USER_HOME" \
          --unshare-all \
          $share_net \
          --new-session \
          --die-with-parent \
          -- /bin/sh -c "$pid_burn" mujo-sandbox-run "$@"
      '';
    };
  in {
    options.apps.nativeSandbox = {
      enable =
        lib.mkEnableOption "Mujo graduated native process sandboxing"
        // {default = true;};
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [mujoSandboxRun pkgs.bubblewrap];
      persistence.data.directories = [
        ".local/share/mujo-sandboxes"
      ];
    };
  };
}
