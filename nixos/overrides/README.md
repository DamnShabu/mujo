# Local overrides

Drop-in NixOS modules for quick, machine-specific host tweaks kept out of the
main feature tree. A flake only sees git-tracked files, so `mujo overrides`
stages each file it creates (intent-to-add) — the loader picks it up on the
next rebuild while the content stays uncommitted until you `git commit` it.

## How it works

- Every `*.nix` in this directory is imported by `nixos/features/_overrides.nix`
  (the `ui-overrides` module) at rebuild time.
- Disabling one renames it `*.nix` → `*.disabled` so the loader skips it.
- A file that fails to *parse* is skipped and reported in
  `config.preferences.overrides.report` instead of breaking the build. A file
  that parses but produces a bad NixOS option still fails the rebuild — disable
  it to recover.

## Manage them

```bash
mujo overrides list                 # JSON: name + enabled
mujo overrides add my-tweak         # copy template.nix.example -> my-tweak.nix
mujo overrides disable my-tweak     # my-tweak.nix -> my-tweak.disabled
mujo overrides enable my-tweak
mujo overrides show my-tweak
mujo overrides remove my-tweak
```

Or from the shell: **System panel → Overrides**. Changes apply on the next
rebuild.

Each override is an ordinary NixOS module — see `template.nix.example`.
