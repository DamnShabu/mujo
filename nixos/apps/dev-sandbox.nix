{...}: {
  flake.nixosModules.app-dev-sandbox = {
    config,
    lib,
    pkgs,
    ...
  }: let
    user = config.preferences.user.name;

    # mujo-dev-sandbox CLI: Developer Sandbox with isolated workspace access
    mujoDevSandbox = pkgs.writeShellApplication {
      name = "mujo-dev-sandbox";
      runtimeInputs = with pkgs; [bubblewrap coreutils util-linux git];
      text = ''
        set -euo pipefail

        if [ "$#" -lt 1 ]; then
          echo "Usage: mujo-dev-sandbox <workspace-dir> [command...]"
          echo "Launches a development environment with workspace access while isolating personal vault and sensitive keys."
          exit 1
        fi

        WORKSPACE_DIR="$(realpath "$1")"
        shift
        CMD=("''${@:-bash}")

        USER_HOME="/home/${user}"
        SCRATCH_HOME="/tmp/mujo-dev-home-$$-$(date +%s)"
        mkdir -p "$SCRATCH_HOME"
        # Unset under a bare `sudo -u` or a systemd unit; `set -u` would abort.
        RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        # niri's socket is wayland-1, so find the one that exists rather than
        # guessing wayland-0 (same as nixos/apps/native-sandbox.nix).
        WAYLAND="''${WAYLAND_DISPLAY:-}"
        if [ -z "$WAYLAND" ]; then
          for s in "$RUNTIME_DIR"/wayland-[0-9]*; do
            if [ -S "$s" ]; then WAYLAND=''${s##*/}; break; fi
          done
          WAYLAND="''${WAYLAND:-wayland-0}"
        fi

        echo "Entering Mujo Developer Sandbox for workspace: $WORKSPACE_DIR"

        # bwrap mounts in argument order, so each tmpfs must come before what is
        # bound underneath it. --tmpfs /run used to follow the
        # /run/current-system bind and cover it back up, leaving no system
        # profile inside -- `mujo-dev-sandbox <dir>` could not even find bash.
        # Same fix nixos/apps/native-sandbox.nix carries.
        exec bwrap \
          --proc /proc \
          --dev /dev \
          --tmpfs /tmp \
          --tmpfs /run \
          --ro-bind /usr /usr \
          --ro-bind /nix/store /nix/store \
          --ro-bind /bin /bin \
          --ro-bind-try /run/current-system /run/current-system \
          --ro-bind-try /run/opengl-driver /run/opengl-driver \
          --ro-bind-try /etc /etc \
          --bind "$SCRATCH_HOME" "$USER_HOME" \
          --bind "$WORKSPACE_DIR" "$WORKSPACE_DIR" \
          --ro-bind-try "$USER_HOME/.gitconfig" "$USER_HOME/.gitconfig" \
          --ro-bind-try "$RUNTIME_DIR/$WAYLAND" "$RUNTIME_DIR/$WAYLAND" \
          --setenv XDG_RUNTIME_DIR "$RUNTIME_DIR" \
          --setenv WAYLAND_DISPLAY "$WAYLAND" \
          --setenv PATH /run/current-system/sw/bin:/usr/bin:/bin \
          --unshare-all \
          --share-net \
          --chdir "$WORKSPACE_DIR" \
          --die-with-parent \
          "''${CMD[@]}"
      '';
    };
  in {
    options.apps.devSandbox = {
      enable = lib.mkEnableOption "Mujo developer workspace sandbox" // {default = true;};
    };

    config = lib.mkIf config.apps.devSandbox.enable {
      environment.systemPackages = [
        mujoDevSandbox
      ];
    };
  };
}
