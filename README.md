# mujō

Personal NixOS flake and Quickshell desktop for a single host, `main`: AMD CPU + AMD GPU, dual monitor, Niri on Wayland, btrfs with impermanence.

## Apply

```bash
nh os switch ~/nixconf/
# or
pkexec nixos-rebuild switch --flake /home/yurii/nixconf#main
```

**`--flake` must be an absolute path** — pkexec runs as root from `/root`. **`git add` new files first**; the flake only sees git-tracked source.

## Fresh install

> Run from a **NixOS live USB**, not from the system being replaced.

```bash
sudo nix run github:nix-community/disko -- --mode disko ./nixos/hosts/main/disko.nix
sudo nixos-install --flake .#main --root /mnt
reboot
nh os switch ~/nixconf/
```

> Reinstalling over an existing system: use `nixos-rebuild switch`, **not** `nixos-install`, to keep `/persist`.

## Map

| Path | What |
|---|---|
| **`AGENTS.md`** | **Source of truth** — commands, constraints, layout, module discovery, secrets |
| `quickshell/bar/AGENTS.md` | Desktop shell architecture and QML conventions |
| `nixos/overrides/README.md` | Machine-local drop-in modules |
| `flake.nix` | Entrypoint and module auto-discovery |
