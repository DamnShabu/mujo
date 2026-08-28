# mujō — agent instructions

**This file is the source of truth for the repo.** `quickshell/bar/AGENTS.md` covers the desktop shell in depth.

Personal NixOS flake (flake-parts), one host `main`: AMD CPU + AMD GPU (`amdgpu`), dual monitor, Niri/Wayland, btrfs impermanence. No test suite — correctness is `nix flake check` plus a live `qs -p` instance for QML.

## COMMANDS

```bash
nh os switch ~/nixconf/                                        # apply (everyday)
pkexec nixos-rebuild switch --flake /home/yurii/nixconf#main   # apply (raw; user accepts the polkit prompt)
nix flake check                                                # evaluate
nix flake show                                                 # inspect outputs
trunk check | trunk fmt                                        # lint / format
qs -p ./quickshell/bar/shell.qml                               # working-tree test instance; qs kill -i <id> to stop
nix run .#sandbox                                              # disposable VM + MCP server (see SANDBOX)
```

## CORE CONSTRAINTS

- **`--flake` takes an absolute path.** pkexec runs as root from `/root`, so `.#main` resolves there and fails.
- **`git add` new files before rebuilding.** The flake source is git; untracked files are invisible to the build.
- **Route formatters through trunk** (nixpkgs-fmt, shellcheck, ruff, markdownlint).
- **Never hardcode `"yurii"`.** Use `config.preferences.user.name` (resolves from gitignored `secrets/username`, fallback in `nixos/core/user.nix`).
- **Persist state explicitly.** The btrfs root is wiped on boot; only `/persist` survives. Each module declares its own `persistence.data.directories`, `persistence.cache.directories`, `persistence.directories`, or `persistence.files` entries.
- **Read colors from `self.theme.base00..base0F`** (`modules/flake/theme.nix`), never literals.
- **Home config is hjem** (`hjem.users."${user}".files/...`), not home-manager.
- **Check `modules/flake/perSystem.nix` before assuming a package is upstream** — `preload`, `skeuos-gtk` and `quicksnip` are vendored there.

## LAYOUT

```
nixos/
├── hosts/main/   configuration.nix -> nixosConfigurations.main + nixosModules.hostMain;
│                 _boot.nix, _networking.nix, _hardware-and-services.nix, disko.nix
├── core/         base options, user, persistence, impermanence, nix daemon, hjem, ui-overrides
├── desktop/      session, GTK, plymouth, notifications, keyring prompter, quickshell packaging
├── security/     vaultwarden secrets
├── services/     system daemons (pipewire, mullvad, preload)
├── apps/         per-app integrations (zen, claude-code, opencode, antigravity, herdr, steam, …)
└── overrides/    machine-local drop-ins — see nixos/overrides/README.md

modules/
├── flake/        theme.nix (palette), perSystem.nix (vendored packages + wrapper-modules)
└── wrappers/     nix-wrapper-modules: fish, kitty, niri, environment (login shell + CLI toolset)

quickshell/       _default.nix derivations (bar, mujo, mujo-keyring, cursor-tracker, unlock),
                  mujo.sh CLI, C/Python helpers, bar/ (the shell)

docs/agents/      issue-tracker + domain-doc conventions consumed by skills
tools/graphify/   graphify install & upgrade scripts
```

## MODULE DISCOVERY

1. `flake.nix` auto-imports every `.nix` under `./nixos/` and `./modules/wrappers/` **without** a leading `_`, via `importTree`.
2. Auto-import only **evaluates** a file. To run on the host, the module must define `flake.nixosModules.<name>` **and** be listed as `self.nixosModules.<name>` in `nixos/hosts/main/configuration.nix`. Missing that line = the file does nothing.
3. `_`-prefixed files are fragments — import them explicitly.
4. `modules/flake/theme.nix` and `modules/flake/perSystem.nix` are wired directly in `flake.nix`, outside `importTree`.

## SECRETS

Vaultwarden-backed (SecretSpec + `bw` CLI) in `nixos/security/vaultwarden.nix`. Enable with `secrets.vaultwarden.enable = true`:

```nix
secrets.vaultwarden.files.myservice = { item = "item"; field = "field"; type = "login"; };
```

Also `secrets.vaultwarden.sshKeys.*` and `secrets.vaultwarden.gpgKeys.*`.

## QUICKSHELL

- `shell.qml` runs as the `qs-bar` systemd user service from the Nix store copy — **working-tree edits reach it only after a rebuild**. Iterate with `qs -p` instead.
- The `bar` derivation copies the **whole** `bar/` tree, so sibling scripts and relative QML imports resolve inside the store path. Keep that when touching `quickshell/_default.nix`.
- Standalone settings app: `settings.qml` (`mujo settings` / `Mod+,`).
- **Register every new QML component in its domain's `qmldir`** (`components/`, `services/`, `modules/<domain>/`), or it will not resolve.
- Full detail: `quickshell/bar/AGENTS.md`.

## SANDBOX

`nixos/sandbox/` is a throwaway graphical VM an agent can see into, so shell work can be checked visually instead of guessed at. `nix run .#sandbox` is **both** the launcher and an MCP stdio server (registered for this repo in `.mcp.json` as `sandbox`); the VM boots on the first tool call and dies when the client disconnects.

- Tools: `screenshot`, `click`, `type`, `key`, `logs`, `reload`, `exec`.
- The VM is nixpkgs' NixOS test driver (QEMU); root is a tmpfs, so no state survives.
- The working tree is 9p-mounted read-only at `/mnt/nixconf` and `/etc/xdg/quickshell/bar` points at it, so the loop is **edit → `reload` → `screenshot`, no rebuild**. `reload` waits for quickshell to actually finish loading (~20s) and reports the journal instead if it crash-loops on a QML error.
- Values behind `SettingsBus.get(…)` come from the guest's `~/.config/qsshell/settings.json`, so editing their *defaults* in `Theme.qml` will not change the render — edit plain literals, or set the value with `mujo settings`.
- It needs the host's render node (`/dev/dri/renderD128`): niri refuses software EGL, so the guest gets virgl via `-device virtio-gpu-gl-pci -display egl-headless`. Nothing is drawn on the real session.
- **The first tool call costs ~45s** (VM boot + the ~20s quickshell load); later ones are fast.
- **`MCP_TIMEOUT` must be raised** (`.claude/settings.json` sets it to 180000). A warm `nix run .#sandbox` answers `initialize` in ~0.5s, but a cold flake eval — which is what happens right after any source edit — exceeds the client's 30s default and the server never connects.

## AI ASSISTANTS

Three agents run against this repo — Claude Code, Antigravity (`agy` + the IDE build) and
opencode — and they are configured to see the same things:

- **Rules**: `.agents/rules/*.md` is read by all three (`~/.agents` is persisted in
  `nixos/core/general.nix`). `rtk.md` there mandates prefixing shell commands with `rtk`, a
  proxy that compresses command output before it reaches the model.
- **MCP**: host-wide servers (`nixos`, `sandbox`) are declared once in
  `nixos/apps/_ai-mcp.nix` and rendered into each tool's own format by
  `nixos/apps/opencode.nix` and `nixos/apps/antigravity-cli.nix`. Checked-in
  `.mcp.json` (Claude) and `.opencode/opencode.json` (opencode) provide
  repo-scoped fallbacks.
- **Nix owns the generated configs.** `~/.config/opencode/opencode.json` and
  `~/.gemini/config/mcp_config.json` are hjem symlinks into the store, so `agy mcp add` and
  hand edits will not stick — change `_ai-mcp.nix` and rebuild instead. Everything else
  (`~/.claude.json`, `~/.claude/settings.json`) stays mutable, because the tools write to it.
- **Usage tracking**: the bar's LLM widget scans each tool's local state — see
  `quickshell/bar/llm-usage.sh`, which is the only data source and documents each provider's
  files at the top.
- **The agent CLIs are also the desktop's AI backend.** With `ai.provider = "agent"`,
  everything behind "Ask AI" (the launcher `/` palette, the crash assistant, the Overview
  card) is answered by an installed agent CLI instead of an OpenAI-compatible endpoint.
  `mujo ai agents` is the single detection source (claude, opencode, agy, codex, gemini, pi,
  plus a custom argv from `ai.agentCommand`); `mujo ai chat` runs the selected one in its
  read-only mode from an empty scratch dir at `~/.cache/qsshell/ai-scratch`. The launcher
  also offers "Open <agent>: <query>", which opens the same agent interactively in kitty.
- **One selection, desktop-wide.** `~/.config/qsshell/llm-default.json` names the active
  agent. `mujo ai use <id>` is its only writer, called both from the bar's LLM widget tabs
  and from Settings → AI, so switching in either place switches the other and the Ask-AI
  backend with it. Agent ids match `llm-usage.sh`'s provider ids for exactly this reason.

## GRAPHIFY

- Codebase questions: `graphify query "<question>"` first, then `graphify path "<A>" "<B>"` or `graphify explain "<concept>"`.
- After changing code: `graphify update .` (AST-only, no API cost).
- After a uv upgrade: `nix-shell -p uv --run ~/nixconf/tools/graphify/apply.sh`.

## FURTHER READING

| Topic | Document |
|---|---|
| Desktop shell architecture | `quickshell/bar/AGENTS.md` |
| Machine-local overrides | `nixos/overrides/README.md` |
| Issues & specs (`gh` in `DamnShabu/mujo`) | `docs/agents/issue-tracker.md` |
| Domain docs (`CONTEXT.md`, `docs/adr/`) | `docs/agents/domain.md` |
