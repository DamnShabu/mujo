# mujō

Personal NixOS flake and Quickshell desktop for a single host, `main`: Intel CPU + AMD GPU, dual monitor, Niri on Wayland, btrfs with impermanence.

## Apply

```bash
nh os switch ~/nixconf/
# or
pkexec nixos-rebuild switch --flake /home/yurii/nixconf#main
```

**`--flake` must be an absolute path** — pkexec runs as root from `/root`. **`git add` new files first**; the flake only sees git-tracked source.

## Fresh install

> Run from a **NixOS live USB**, not from the system being replaced.

From a checkout of this repo on the live system (`git clone … nixconf && cd nixconf`):

```bash
# 1. Partition + format. disko.nix is a flake-parts module, so it is addressed
#    through the flake (diskoConfigurations.hostMain), not as a file. It targets
#    the NVMe by-id path in nixos/hosts/main/disko.nix -- check it matches.
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko -- --mode disko --flake .#hostMain

# 2. Your login password. The account reads its hash from /persist/passwd
#    (users.users.<name>.hashedPasswordFile); without it the account has no
#    password and sudo cannot be used.
nix-shell -p mkpasswd --run 'mkpasswd -m yescrypt' | sudo tee /mnt/persist/passwd >/dev/null
sudo chmod 600 /mnt/persist/passwd

# 3. Put the repo where the system expects it (~/nixconf is persisted).
sudo mkdir -p /mnt/persist/userdata/home/yurii
sudo cp -a . /mnt/persist/userdata/home/yurii/nixconf
sudo chown -R 1000:100 /mnt/persist/userdata/home/yurii

# 4. Install and reboot.
sudo nixos-install --flake .#main --root /mnt
reboot
```

Replace `yurii` if `secrets/username` names a different account.

> Reinstalling over an existing system: use `nixos-rebuild switch`, **not** `nixos-install`, to keep `/persist`.

## Map

| Path | What |
|---|---|
| **`AGENTS.md`** | **Source of truth** — commands, constraints, layout, module discovery, secrets |
| `quickshell/bar/AGENTS.md` | Desktop shell architecture and QML conventions |
| `nixos/overrides/README.md` | Machine-local drop-in modules |
| `flake.nix` | Entrypoint and module auto-discovery |
