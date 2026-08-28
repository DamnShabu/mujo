# Local overrides

Drop-in NixOS modules for machine-specific tweaks, kept out of the main module tree. Each override is an ordinary NixOS module — start from `template.nix.example`.

## How it works

- `nixos/core/ui-overrides.nix` imports every `*.nix` here at rebuild time (except `template.nix` / `default.nix`).
- Disabling renames `*.nix` → `*.disabled`, so the loader stops matching it.
- A file that fails to **parse** is skipped and reported in `config.preferences.overrides.report` instead of breaking the build. A file that parses but sets a bad option **still fails the rebuild** — disable it to recover.
- **A flake only sees git-tracked files**, so `mujo overrides` stages what it creates (intent-to-add). Content stays uncommitted until you `git commit`.

## Manage

```bash
mujo overrides list                 # JSON: name + enabled
mujo overrides add my-tweak         # copy template.nix.example -> my-tweak.nix
mujo overrides show my-tweak
mujo overrides disable my-tweak     # my-tweak.nix -> my-tweak.disabled
mujo overrides enable my-tweak
mujo overrides remove my-tweak
```

Or **System panel → Overrides** in the shell. Changes apply on the next rebuild.
