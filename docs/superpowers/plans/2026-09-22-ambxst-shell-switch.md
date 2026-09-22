# Ambxst Shell Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn off the Quickshell desktop shell daemon (`qs-bar`) and configure the Ambxst desktop shell as the active shell on Niri.

**Architecture:** Add `ambxst` flake input; add a `services.qs-bar.enable` option to `nixos/desktop/quickshell.nix` and set it to `false`; create `nixos/desktop/ambxst.nix` to declare `flake.nixosModules.ambxst` with persistence, systemd user service `ambxst.service`, and an activation script creating `~/.local/share/ambxst/niri.kdl` stub; wire `niri.kdl` include and Ambxst shortcuts in `modules/wrappers/niri.nix`.

**Tech Stack:** NixOS, Nix Flakes, Quickshell, Ambxst, Niri Wayland compositor.

**Spec:** `docs/superpowers/specs/2026-09-22-ambxst-shell-switch-design.md`

## Global Constraints
- Prefix shell commands with `rtk` when running supported CLI tools.
- Do not remove supporting utilities from `quickshell.nix` (`mujo`, `mujo-screenshot`, PAM lock service).
- Follow impermanence rules: persist `.config/ambxst` and `.local/share/ambxst`.
- Never hardcode the username: use `config.preferences.user.name`.
- Untracked files must be added to git with `git add` before evaluating flake.

---

### Task 1: Add Ambxst Flake Input

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add input to flake.nix**
Add `ambxst` to `inputs` in `flake.nix`:
```nix
    ambxst = {
      url = "github:Axenide/Ambxst";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Verify flake lock and eval**
Run `nix flake lock` and check that `ambxst` is locked.
Run: `nix flake check --no-build`

- [ ] **Step 3: Commit**
Run: `git add flake.nix flake.lock && git commit -m "feat(flake): add ambxst input"`

---

### Task 2: Make Quickshell Bar Daemon Toggleable

**Files:**
- Modify: `nixos/desktop/quickshell.nix`

- [ ] **Step 1: Add `services.qs-bar.enable` option**
In `nixos/desktop/quickshell.nix`:
```nix
    options.services.qs-bar.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the quickshell bar daemon";
    };
```

- [ ] **Step 2: Guard `qs-bar` service with the option**
Wrap the `qs-bar` service in `systemd.user.services` with `lib.mkIf config.services.qs-bar.enable`:
```nix
    systemd.user.services = {
      qs-bar = lib.mkIf config.services.qs-bar.enable (mkDaemon {
        command = "${pkgs.quickshell}/bin/quickshell -p ${barConfig}";
        path = with pkgs; ["/run/wrappers"] ++ [bash coreutils findutils gnugrep gnused jq curl sqlite libsecret wl-clipboard cliphist xdg-utils systemd swayidle brightnessctl cava quickshell qs.unlock qs.mujo-screenshot] ++ ["/run/current-system/sw"];
        environment = {
          QS_ICON_THEME = "Colloid-Dark";
          XDG_DATA_DIRS = appDataDirs;
        };
      });
      wl-cliphist = { ... };
    };
```
And in `upholds`:
```nix
    systemd.user.targets.graphical-session.upholds =
      (lib.optional config.services.qs-bar.enable "qs-bar.service");
```

- [ ] **Step 3: Commit**
Run: `git add nixos/desktop/quickshell.nix && git commit -m "feat(quickshell): add services.qs-bar.enable toggle"`

---

### Task 3: Create Ambxst Desktop Module

**Files:**
- Create: `nixos/desktop/ambxst.nix`

- [ ] **Step 1: Create `nixos/desktop/ambxst.nix`**
```nix
{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.ambxst = {
    pkgs,
    config,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
    generationTrigger = self.rev or self.dirtyRev or "unknown";
  in {
    imports = [
      inputs.ambxst.nixosModules.default
    ];

    persistence.data.directories = [
      ".config/ambxst"
      ".local/share/ambxst"
    ];

    # Safeguard: ensure ~/.local/share/ambxst/niri.kdl stub exists before Niri starts
    system.activationScripts.ambxstInit = lib.stringAfter ["users"] ''
      mkdir -p /home/${user}/.local/share/ambxst
      touch /home/${user}/.local/share/ambxst/niri.kdl
      chown -R ${user}:users /home/${user}/.local/share/ambxst
    '';

    systemd.user.services.ambxst = {
      description = "Ambxst Shell Daemon";
      after = ["niri.service" "graphical-session.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      path = with pkgs; [
        "/run/wrappers"
        "/run/current-system/sw"
      ];
      serviceConfig = {
        ExecStart = "${pkgs.ambxst}/bin/ambxst";
        Restart = "always";
        RestartSec = 2;
      };
      restartTriggers = [generationTrigger];
    };

    systemd.user.targets.graphical-session.upholds = ["ambxst.service"];
  };
}
```

- [ ] **Step 2: Commit**
Run: `git add nixos/desktop/ambxst.nix && git commit -m "feat(desktop): add ambxst module"`

---

### Task 4: Enable Ambxst and Disable `qs-bar` in Host Config

**Files:**
- Modify: `nixos/hosts/main/configuration.nix`

- [ ] **Step 1: Add `self.nixosModules.ambxst` to imports**
Add `self.nixosModules.ambxst` right after `self.nixosModules.quickshell`.

- [ ] **Step 2: Set `services.qs-bar.enable = false`**
Add:
```nix
    services.qs-bar.enable = false;
```

- [ ] **Step 3: Commit**
Run: `git add nixos/hosts/main/configuration.nix && git commit -m "feat(main): enable ambxst and disable qs-bar"`

---

### Task 5: Configure Niri Keybindings & Include in Wrapper

**Files:**
- Modify: `modules/wrappers/niri.nix`

- [ ] **Step 1: Add include and update keybinds**
In `modules/wrappers/niri.nix`:
Add `include = "~/.local/share/ambxst/niri.kdl";` (or list) to `settings`.
Update binds:
- `"Mod+Space".spawn = ["ambxst" "toggle" "launcher"];`
- `"Mod+Comma"."spawn-sh" = "ambxst run config";`
- `"Mod+Ctrl+L"."spawn-sh" = "ambxst lock";`

- [ ] **Step 2: Test Niri evaluation and generated KDL**
Run: `nix eval .#packages.x86_64-linux.niri.meta.description`
Verify KDL syntax with `niri validate`.

- [ ] **Step 3: Commit**
Run: `git add modules/wrappers/niri.nix && git commit -m "feat(niri): integrate ambxst binds and niri.kdl include"`

---

### Task 6: Full System Evaluation & Verification

**Files:** None (testing)

- [ ] **Step 1: Evaluate flake**
Run: `nix flake check`
Expected: Evaluates hostMain toplevel cleanly.

- [ ] **Step 2: Run dry-build**
Run: `nixos-rebuild dry-build --flake /home/yurii/nixconf#main`
Expected: Success.
