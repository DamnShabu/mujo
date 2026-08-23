# nixos/features/

One NixOS module per concern, each defining `flake.nixosModules.<name>`.
Auto-discovered by `importTree`, but **evaluation ≠ activation** — a module
only applies to the host if it's listed in `nixos/hosts/main/configuration.nix`'s
`imports` (as `self.nixosModules.<name>`). Check that file to see which of
these are actually live. Most modules add their own `persistence.*` entries
for whatever state they create under `$HOME` or `/var`/`/etc` — see
`nixos/extra/README.md` for how those are consumed.

## Core / platform

- **`nix.nix`** — Nix daemon settings: flakes + nix-command, weekly GC
  (14-day retention), `nix-index`, `direnv`/`nix-direnv`, `nix-ld`,
  `allowUnfree`, and the Nix-adjacent CLI toolset (`nil`, `nixd`, `statix`,
  `alejandra`, `mcp-nixos`, ...).
- **`general.nix`** — creates the primary user account (groups: `wheel`,
  `networkmanager`, `input`, `disk`, `docker`; shell = the wrapped
  `environment` package from `modules/wrappers/environment.nix`), a
  passwordless-`nixos-rebuild` sudo rule (for `nh os switch`), a permissive
  wheel polkit rule, and the bulk of the per-user `persistence.data`/`cache`
  directory list (Pictures/Documents/Projects/.ssh/quickshell/etc).
- **`user.nix`** — resolves `preferences.user.name` from the gitignored
  `secrets/username` file, falling back to `"yurii"`; sets
  `preferences.locale.timeZone = "Europe/Berlin"`. Never hardcode the
  username elsewhere — read `config.preferences.user.name` instead (see root
  `AGENTS.md`).
- **`user-config.nix`** — sets the standard XDG user-dirs environment
  variables (`XDG_DESKTOP_DIR`, `XDG_DOCUMENTS_DIR`, etc.) to `$HOME/...`.
- **`impermanence.nix`** — thin activation shim: imports
  `nixos/extra/impermanence.nix`'s module and flips
  `persistence.enable = true` for `config.preferences.user.name`. The actual
  bind-mount logic lives in `nixos/extra/`.
- **`preload.nix`** — a `services.preload` option module (packaged
  separately since upstream `preload` was dropped from nixpkgs — see
  `modules/perSystem.nix`). Patched via `modules/preload/`.

## Desktop environment

- **`desktop.nix`** — the desktop-session umbrella: imports `gtk`,
  `pipewire`, `zen`, and the `thyx` SDDM theme input. Enables
  SDDM + `services.displayManager`, sets Wayland session env vars
  (`NIXOS_OZONE_WL`, `QT_QPA_PLATFORM`, `XDG_CURRENT_DESKTOP = "niri:GNOME"`),
  installs fonts (Fira Code, JetBrainsMono Nerd Font, Ubuntu Sans, Material
  Symbols), sets XDG MIME default apps (Zen for web/PDF, GIMP for images,
  Obsidian for markdown, kitty for files/text), and works around Nix store
  binaries losing setuid bits by shipping a `pkexec` wrapper unit for
  polkit. Enables bluetooth and 32-bit graphics.
- **`gtk.nix`** — GTK 3/4 theming: `Skeuos-Grey-Dark` GTK theme (vendored,
  see `modules/perSystem.nix`), `Colloid-Dark` icons, `Bibata-Modern-Classic`
  cursor. Writes `/etc/xdg/gtk-{3,4}.0/settings.ini` and a matching `dconf`
  profile so GTK and GNOME-settings-reading apps agree.
- **`pipewire.nix`** — audio stack: PipeWire with ALSA/Pulse/JACK
  compatibility, 96kHz/256-quantum clock defaults, and a DeepFilterNet
  LADSPA noise-cancelling source (`99-input-denoising` filter-chain module)
  for mic input.
- **`quickshell.nix`** — builds and wires the quickshell bar shell
  (`quickshell/_default.nix`) as the `qs-bar` systemd user service, with the
  Qt/QML plugin search paths (`qtmultimedia`, `qtwayland`, `qml-niri`, ...)
  assembled from `inputs.qml-niri` and `pkgs.quickshell`. See
  `quickshell/README.md` for the shell itself.
- **`notifications.nix`** — notification stack: sets `QML2_IMPORT_PATH` for
  Qt multimedia, installs `quickshell`, `swayosd` (OSD popups), and
  `libnotify`.

## Apps (mostly Flatpak-packaged)

- **`flatpak.nix`** — enables `services.flatpak` and adds the Flathub
  remote; the substrate the app modules below declare packages into.
- **`discord.nix`** — Flatpak `dev.vencord.Vesktop` (Vencord-patched
  Discord client).
- **`telegram.nix`** — Flatpak `org.telegram.desktop`.
- **`obsidian.nix`** — Flatpak `md.obsidian.Obsidian`.
- **`zen.nix`** — Flatpak `app.zen_browser.zen` (default browser, per
  `desktop.nix`'s MIME associations).
- **`steam.nix`** — Flatpak `com.valvesoftware.Steam` +
  `hardware.steam-hardware.enable`.
- **`gaming.nix`** — general gaming support: `gamescope`, `dxvk`,
  `mangohud`, `zerotierone` (for LAN-over-VPN play), and the
  `nix-gaming` cachix substituter.

## Dev tools

- **`claude-code.nix`** — installs `pkgs.claude-code`;
  persists `~/.claude`, `~/.config/claude` (data) and `~/.cache/claude`
  (cache).
- **`opencode.nix`** — installs `pkgs.opencode`; writes a static
  `~/.config/opencode/opencode.json` (via `hjem`) enabling LSP, the
  `ponytail` plugin, and an `mcp-nixos` local MCP server; persists
  `~/.config/opencode` and `~/.local/share/opencode`.

## Networking / security

- **`mullvad.nix`** — installs `mullvad-vpn` (daemon+CLI+GUI pinned to one
  package so gRPC versions match), redirects `MULLVAD_SETTINGS_DIR` to
  `/var/lib/mullvad-vpn` (persisted), and re-asserts a declarative DNS
  blocklist + custom relay-location lists into `settings.json` via a jq
  merge script run as `ExecStartPre` before every daemon start (the daemon
  only reads settings at startup, so GUI-side edits to these fields are
  silently overwritten by design — see in-file comments before changing
  behavior here).
- **`vaultwarden.nix`** — the custom `secrets.vaultwarden.*` option module:
  builds `secretspec` from source (rustPlatform), backs it with the `bw`
  (Bitwarden/Vaultwarden) CLI to materialize secret files, SSH keys, and GPG
  keys declared as `secrets.vaultwarden.files.<name>` /
  `sshKeys.<name>` / `gpgKeys.<name>` = `{ item; field; type; }`. See root
  `AGENTS.md` for the enable/usage shape.
