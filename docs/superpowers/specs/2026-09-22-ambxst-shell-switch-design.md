# Ambxst Shell Switch Design

## Overview
This design covers disabling the custom Quickshell shell (`qs-bar`) and switching to the Ambxst Wayland desktop shell (https://axeni.de/ambxst / https://github.com/Axenide/Ambxst) on Niri.

Supporting utilities from the Quickshell module (`mujo` CLI, `mujo-screenshot`, and PAM lock service) are preserved, while the desktop UI daemon (`qs-bar`) is disabled. Ambxst is run as a systemd user service under `graphical-session.target`.

## Components & Changes

### 1. Flake Input (`flake.nix`)
Add Ambxst input following nixpkgs:
```nix
ambxst = {
  url = "github:Axenide/Ambxst";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### 2. Quickshell Daemon Toggle (`nixos/desktop/quickshell.nix`)
Add a boolean option to cleanly disable `qs-bar` while retaining other tools:
```nix
options.services.qs-bar.enable = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = "Whether to run the quickshell bar daemon";
};
```
Wrap `systemd.user.services.qs-bar` and its entry in `systemd.user.targets.graphical-session.upholds` with `lib.mkIf config.services.qs-bar.enable`.

### 3. Ambxst Desktop Module (`nixos/desktop/ambxst.nix`)
Create `nixos/desktop/ambxst.nix` providing `flake.nixosModules.ambxst`:
* Imports `inputs.ambxst.nixosModules.default` (which manages `programs.ambxst`, required fonts like Phosphor icons, and recommended power/media services).
* Configures persistence under `persistence.data.directories`:
  * `.config/ambxst`
  * `.local/share/ambxst`
* Ensures `~/.local/share/ambxst/niri.kdl` exists on boot via system activation script so that Niri never fails to start on cold boots or post-wipe boots.
* Declares `systemd.user.services.ambxst`:
  * `after = ["niri.service" "graphical-session.target"]`
  * `partOf = ["graphical-session.target"]`
  * `wantedBy = ["graphical-session.target"]`
  * `ExecStart = "${pkgs.ambxst}/bin/ambxst"`
  * `Restart = "always"`
  * `RestartSec = 2`
* Declares `systemd.user.targets.graphical-session.upholds = ["ambxst.service"]`.

### 4. Host Configuration (`nixos/hosts/main/configuration.nix`)
* Add `self.nixosModules.ambxst` to `imports`.
* Set `services.qs-bar.enable = false;`.

### 5. Niri Wrappers Configuration (`modules/wrappers/niri.nix`)
* Add `include = "~/.local/share/ambxst/niri.kdl";` to Niri `settings`.
* Update shell-related keybindings:
  * `"Mod+Space".spawn = ["ambxst" "run" "launcher"];`
  * `"Mod+Comma"."spawn-sh" = "ambxst run config";`
  * `"Mod+Ctrl+L"."spawn-sh" = "ambxst lock";`

## Verification & Safety
1. `nix flake check` evaluates the flake and builds the host toplevel (`checks.hostMain`).
2. Verify that `/nix/store/...-niri-config.kdl` contains `include "~/.local/share/ambxst/niri.kdl"` and passes `niri validate`.
3. Check that the activation script creates the fallback stub `~/.local/share/ambxst/niri.kdl`.
4. Apply using `nh os switch ~/nixconf/` or `pkexec nixos-rebuild switch --flake /home/yurii/nixconf#main`.
