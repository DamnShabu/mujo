# modules/wrappers/

Program wrapper modules built with the `nix-wrapper-modules` flake input
(`inputs.wrapper-modules`, imported by `modules/perSystem.nix`). Each file
defines a `flake.wrappers.<name>` that wraps a specific program's config +
binary into a single derivation. Auto-discovered by `importTree` (per root
`AGENTS.md`), so a new `.nix` file here is picked up automatically — but
still needs to be referenced (e.g. via `self.wrapperModules.<name>` /
`self.wrappers.<name>`) somewhere to actually be used.

## Files

- **`fish.nix`** — `flake.wrappers.fish`: fish shell config as a wrapper.
  Sets a colored prompt, disables the greeting, adds `~/.local/bin` to
  `PATH`, enables vi key bindings, initializes `zoxide`, defines an `lf`
  function that `cd`s to the last directory on exit, and hooks `direnv` if
  present.
- **`kitty.nix`** — `flake.wrappers.kitty`: kitty terminal config. Exposes a
  `shell` option (which program kitty launches). Notably forces
  `KITTY_CONFIG_DIRECTORY` via env var instead of the `--config` flag to
  avoid a kitten-launch bug (see in-file comment, kitty issues #1519/#4885).
  Disables the audio bell; sets `JetBrainsMono Nerd Font` at size 15.
- **`niri.nix`** — `flake.wrappers.niri`: the Niri (Wayland compositor)
  config, ~300 lines — window rules, keybinds, layout. Exposes a `terminal`
  option for which terminal to bind. This is the largest wrapper file.
- **`environment.nix`** — defines the two "meta" wrappers that tie
  everything together:
  - `flake.wrappers.environment` — wraps `fish` and adds the full CLI
    toolset used at the shell (`nil`/`nixd`/`statix`/`alejandra`, `fzf`,
    `htop`/`btop`, `eza`/`fd`/`zoxide`/`dust`/`ripgrep`, `lazygit`, `just`,
    `mprocs`, `nh`, `lf`, plus vendored packages like `nix-check-bin`,
    `jprocsall`/`jprocs`, and the `mujo` CLI from `quickshell/_default.nix`).
    This is the `binName = "fish"` the user actually logs into.
  - `flake.wrappers.terminal` — wraps `kitty`, launching it with
    `environment`'s wrapped fish as its shell.
  - Also defines `perSystem.packages.jprocs` / `jprocsall` (mprocs wrapped
    with `--just`, different `--on-init`) and `nix-check-bin` (opens
    `$EDITOR` on a built package's `bin/` dir — handy for inspecting what a
    derivation produces).
