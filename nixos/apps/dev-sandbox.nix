{pkgs, ...}: {
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

        echo "Entering Mujo Developer Sandbox for workspace: $WORKSPACE_DIR"

        exec bwrap \
          --ro-bind /usr /usr \
          --ro-bind /nix/store /nix/store \
          --ro-bind /bin /bin \
          --ro-bind-try /run/current-system /run/current-system \
          --ro-bind-try /etc /etc \
          --proc /proc \
          --dev /dev \
          --tmpfs /tmp \
          --tmpfs /run \
          --bind "$SCRATCH_HOME" "$USER_HOME" \
          --bind "$WORKSPACE_DIR" "$WORKSPACE_DIR" \
          --ro-bind-try "$USER_HOME/.gitconfig" "$USER_HOME/.gitconfig" \
          --ro-bind-try "$XDG_RUNTIME_DIR/wayland-0" "$XDG_RUNTIME_DIR/wayland-0" \
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
