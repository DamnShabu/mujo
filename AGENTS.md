# mujō — agent instructions

**This file is the source of truth for the repo.** `quickshell/bar/AGENTS.md` covers the desktop shell in depth.

Personal NixOS flake (flake-parts), one host `main`: Intel CPU (i9-14900K, `hardware.cpu.intel.updateMicrocode`) + AMD GPU (`amdgpu`), dual monitor, Niri/Wayland, btrfs impermanence.

Correctness has three layers, and they check different things. `nix flake check`
evaluates the flake *and* builds the host toplevel (via `checks.hostMain`), so an
option conflict or a failed assertion goes red there. The self-checks under
**SELF-CHECKS** below run offline against no running system and are the ones to
reach for while editing. `tests/run-all-tests.sh` probes the **running** host, so
it fails until you rebuild — that is deliberate, a check that cannot fail is not
a check. QML has no evaluator: use a live `qs -p` instance.

## COMMANDS

```bash
nh os switch ~/nixconf/                                        # apply (everyday)
pkexec nixos-rebuild switch --flake /home/yurii/nixconf#main   # apply (raw; user accepts the polkit prompt)
nix flake check                                                # evaluate
nix flake show                                                 # inspect outputs
bash tests/run-all-tests.sh                                    # security acceptance tests (checks the RUNNING system)
bash tests/vm/run.sh                                           # boot the host config as a real installed system in a throwaway VM
qs -p ./quickshell/bar/shell.qml                               # working-tree test instance; qs kill -i <id> to stop
nix run .#sandbox                                              # disposable VM + MCP server (see SANDBOX)
```

## SELF-CHECKS

Offline, no running system, no framework — each is a plain script that prints
PASS/FAIL and exits non-zero on failure. Non-trivial logic in this repo leaves
one of these behind rather than a test suite.

```bash
# There is no python3 on the host PATH -- these two bring their own.
nix shell --impure --expr 'with import <nixpkgs> {}; python3.withPackages (p: [p.dbus-next])' \
  -c python3 nixos/apps/test-tray-relay.py       # tray relay: two private buses, no VM
nix shell nixpkgs#python3 -c python3 nixos/sandbox/test-lifetime.py   # sandbox VM lifetime: mcp.py vs a fake Machine
bash nixos/apps/test-trust-registry-lock.sh      # trust registry survives concurrent writers

# mujo-vault's non-interactive passphrase path, on a throwaway container (never
# touches the real vault). Needs root for device-mapper, and e2fsprogs, which is
# not in systemPackages -- the vault CLI gets it via runtimeInputs:
E2FS=$(nix build nixpkgs#e2fsprogs.bin --no-link --print-out-paths)
pkexec env "PATH=$E2FS/bin:/run/current-system/sw/bin" \
  bash nixos/security/test-vault-passphrase.sh
bash quickshell/test-screenshot-crop.sh          # screenshot crop bounds guard (ImageMagick only)
bash quickshell/test-screenshot-ocr-lines.sh     # OCR line boxes; SKIPs unless run under nix run .#mujo-screenshot

nix shell nixpkgs#shellcheck -c shellcheck -S warning -e SC1090 -P quickshell \
  $(git ls-files '*.sh')                         # every tracked script; must stay silent
```

`-P quickshell` lets shellcheck follow `mujo.sh`'s six sourced libraries, so the
CLI is checked as one program rather than seven fragments. `SC1090` is the only
exclusion: `MUJO_LIB` resolves at runtime, and the `# shellcheck source=`
directives at each `.` already say where the library lives.

The shell's own checks each print PASS/FAIL and exit 0 or 1, so they can be run
in a row. Full list in `quickshell/bar/AGENTS.md` → RUNNING:

```bash
cd quickshell/bar
for t in icons grid notifications shelf settings-ui security-ui desktop wallpaper-panel scroll vm-service reorder-list greeter bar-modular; do
  qs -p "./test-$t.qml"
done
```

A new one runs its assertions from a `Timer { interval: 0 }`, never from
`Component.onCompleted`: Quickshell connects `Qt.exit()` only after the config
finishes loading, so a check that exits from `onCompleted` prints its verdict
and then hangs forever.

## CORE CONSTRAINTS

- **`--flake` takes an absolute path.** pkexec runs as root from `/root`, so `.#main` resolves there and fails.
- **`git add` new files before rebuilding.** The flake source is git; untracked files are invisible to the build.
- **The host still boots via GRUB.** lanzaboote/Secure Boot is wired up but off: `security.mujo.boot.secureBoot = false`. It is the only switch here that replaces the bootloader, so it stays off until someone walks the runbook in `docs/physical-security.md` §2a. Consequence to keep in mind: with GRUB, physical access is root access (press `e`, append `init=/bin/sh`).
- **No hibernation.** Swap is re-keyed with a random key every boot (`randomEncryption` in `disko.nix`), so there is no stable key to resume under; NixOS adds `nohibernate` to the kernel params for the same reason. `security.mujo.storage.encryptedSwap` asserts this at build time.
- **Two hardening switches are deliberately off** because they act during early boot or replace the bootloader: `security.mujo.boot.secureBoot` and `security.mujo.devices.dmaProtection`. Turn them on one at a time, with a known-good generation still selectable in the boot menu.
- **Quarantine is a real VM, and it is started on demand.** `mujo-quarantine-run <app>` brings up `microvm@mujo-quarantine.service` (not autostarted — an idle domain would hold 4 GB) and forwards the window over waypipe on vsock. Three vsock ports are the entire guest→host surface (agent, waypipe, filtered session bus). Every payload runs on a private guest session bus (`dbus-run-session`), and `nixos/apps/tray-relay.py` re-exports its tray item and notifications to the host bus; the bridged host bus is reachable only behind the xdg-dbus-proxy policy. Handing the payload that bridged bus directly is what killed every GTK application: the proxy's ownership policy is `--own=org.kde.*` alone, so `RequestName` on an app id came back `ServiceUnknown` and each GApplication exited with `Failed to register` before drawing a window. `apps.microvm.gpu` defaults to `"native"` (virtio-gpu `drm_native_context`, i.e. the guest issues amdgpu ioctls that reach the host driver) — the one setting here that trades real security surface for speed; `"virgl"` and `"none"` narrow it. True VFIO passthrough is impossible on this box: one GPU, it drives both monitors, IOMMU off. Limits and verified properties: `docs/application-trust.md` §6.
- **The boot greeter is a session-lock surface, not a display manager.** SDDM still autologins; the greeter (`quickshell/bar/modules/system/GreeterScreen.qml`, state in `services/Greeter.qml`) comes up with the shell and takes the `ext-session-lock` surface to unlock the vault — or, when no container exists, to create one. It is deliberately **dismissible** (Esc / Skip): the vault is optional, and a greeter that could not be waved past would be a way to lose the machine to a QML error. Only one session lock may exist at a time, which is why `LockScreen.locked` is `Lock.locked && !Greeter.active`. Turn it off with `greeter.enable = false` (Settings store), which the setup pane's "Don't ask again" sets.
- **`/persist/secure` is 0700 root, so the user cannot stat the vault container.** `mujo-vault marker` stamps `/run/mujo/vault-present` (0444, in 0755 `/run/mujo`) at boot via `mujo-vault-marker.service`, carrying the container size. That marker — not a `test -f` on the container — is how the greeter picks its pane and how `mujo security summary` reports `vault.containerPresent`; the direct stat is kept as the root-side path. Widening `/persist/secure` instead would fail `tests/storage/test-vault-isolation.sh` and contradict SEC-004.
- **`mujo-vault init`/`open` read the passphrase from stdin when stdin is not a tty**, which is what lets the greeter drive them without a terminal. `luksFormat` additionally needs `--batch-mode` — without a tty there is nobody to type the "YES" confirmation, and it hangs. Self-check: `nixos/security/test-vault-passphrase.sh`.
- **The trust registry is root-owned on purpose.** `/var/lib/mujo-trust/registry.json` decides where every application runs, so the user cannot write it. Applications self-report over `mujo-trustd` on a unix socket (`begin`/`end`/`violation` only); `graduate`, `revoke`, `tier` and `rollback` are root CLI verbs. Never "fix" a permission error there by loosening the file.
- **`mujo-trust run <app>` is the entry point** that picks the runtime from the trust state. A graduated *Flatpak* cannot be nested in the native sandbox, so the engine narrows it instead: `apps.trust.flatpakNarrowing` maps its risk tier to subtractive `flatpak run` overrides (`low` gets none — Steam needs `devices=all`; everything else loses raw devices, `devel` and smartcard access), with `apps.trust.flatpakNarrowingOverrides` per application id. `apps.trust.launcherIntegration` puts the shell's launcher behind it (`Launch.app()` prefixes `mujo-trust run`, gated on `/etc/mujo/launcher-integration`), but it is **off**: with it on, anything not yet graduated boots a VM on first click. Runbook in `docs/application-trust.md` §8. Off, launching from a menu bypasses the engine.
- **A denied credential request revokes the application.** `nixos/security/broker.nix` reports every DENY to `mujo-trustd` as a violation — that is the Phase 21 detector. Inert until `security.mujo.broker.acl` is non-empty (no ACL entry, no socket, nothing to deny). Recovery is `sudo mujo-trust rollback <app>` or `sudo mujo-trust graduate <app>`.
- **Never hardcode `"yurii"`.** Use `config.preferences.user.name` (resolves from gitignored `secrets/username`, fallback in `nixos/core/user.nix`).
- **Persist state explicitly.** The btrfs root is wiped on boot; only `/persist` survives. Each module declares its own `persistence.data.directories`, `persistence.cache.directories`, `persistence.directories`, or `persistence.files` entries.
- **Read colors from `self.theme.base00..base0F`** in Nix (`modules/flake/theme.nix`) and `Theme.*` in QML — for anything that is *shell chrome*: backgrounds, surfaces, borders, text, accents, state colours. Four things are deliberately literal, because they are data rather than theming: **brand colours** (`quickshell/bar/theme/Brand.qml` — Mullvad's yellow is Mullvad's, not the user's), **user-selectable palettes** (accent swatches in `ThemeGroup.qml`, note colours in `NotesWidget.qml`, background swatches in `WallpaperEffectsGroup.qml` and `IslandGroup.qml`, file-type colours in `ShelfView.qml`), **media chrome** (`Theme.mediaBackdrop`/`mediaDim`/`mediaScrim`/`mediaPanel`/`mediaShield`/`ratingStar` — the wallpaper browsers show other people's images, so their surround must not carry the user's accent), and **black/white primitives** for shadows, scrims and low-alpha overlays. Those four groups plus `Theme.qml`'s own presets account for every one of the ~618 hex literals in `quickshell/bar/`; a new one outside them is a bug.
- **Home config is hjem** (`hjem.users."${user}".files/...`), not home-manager.
- **Check `modules/flake/perSystem.nix` before assuming a package is upstream** — `skeuos-gtk` is vendored there, and `cutefetch` is built from `tools/cutefetch/`.

## LAYOUT

```
nixos/
├── hosts/main/   configuration.nix -> nixosConfigurations.main + nixosModules.hostMain;
│                 _boot.nix, _networking.nix, _hardware-and-services.nix, disko.nix
├── core/         base options, user, persistence, impermanence, nix daemon, hjem, ui-overrides
├── desktop/      session, GTK, plymouth, notifications, keyring prompter, quickshell packaging
├── security/     modular security architecture (baseline, kernel, boot, storage, network, users, devices, audit, privacy, vault, broker, vaultwarden)
├── services/     system daemons (pipewire, mullvad)
├── apps/         per-app integrations + progressive trust & sandboxing (trust, native-sandbox, microvm, zen, claude-code, opencode, antigravity, herdr, steam, …)
└── overrides/    machine-local drop-ins — see nixos/overrides/README.md

modules/
├── flake/        theme.nix (palette), perSystem.nix (vendored packages + wrapper-modules)
└── wrappers/     nix-wrapper-modules: fish, kitty, niri, environment (login shell + CLI toolset)

quickshell/       _default.nix derivations (bar, mujo, mujo-screenshot, mujo-keyring,
                  mujo-wallpaper-engine, cursor-tracker, unlock),
                  mujo.sh CLI + lib/ (its six largest subcommands), C/Python helpers, bar/ (the shell)

tests/            security acceptance test suite (kernel, storage, vault, network, sandbox, microvm, trust, physical, recovery, redteam, performance);
                  lib.sh holds the shared assertions. These probe the running
                  system, not the flake, so they fail until you rebuild — that is
                  the point, a check that cannot fail is not a check.
tests/vm/         throwaway VM harness: disko formats the real layout, installs
                  the host config onto it and boots it, running the suite at
                  startup. Outside importTree, so it only evaluates on request.
docs/             security specifications (threat-model, security-architecture, storage-model, application-trust, physical-security, privacy-model, performance-budget, security-tests)
docs/agents/      issue-tracker + domain-doc conventions consumed by skills
tools/graphify/   graphify install & upgrade scripts
```

## MODULE DISCOVERY

1. `flake.nix` auto-imports every `.nix` under `./nixos/` and `./modules/wrappers/` **without** a leading `_`, via `importTree`.
2. Auto-import only **evaluates** a file. To run on the host, the module must define `flake.nixosModules.<name>` **and** be listed as `self.nixosModules.<name>` in `nixos/hosts/main/configuration.nix`. Missing that line = the file does nothing.
3. `_`-prefixed files are fragments — import them explicitly.
4. `modules/flake/theme.nix` and `modules/flake/perSystem.nix` are wired directly in `flake.nix`, outside `importTree`.
5. **`nix flake check` does not evaluate `nixosConfigurations` on its own.** `nixos/hosts/main/checks.nix` re-exports the host toplevel as `checks.hostMain` so it does. Without that the host config can stop evaluating entirely and every check still reports green.

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
- The working tree is 9p-mounted read-only at `/mnt/nixconf`, and `reload` copies it into the tmpfs `/run/quickshell-bar` that `/etc/xdg/quickshell/bar` points at, so the loop is **edit → `reload` → `screenshot`, no rebuild**. `reload` waits for quickshell to actually finish loading (~20s) and reports the journal instead if it crash-loops on a QML error. It also kills any open settings window, because that is a separate process still running the QML it was launched with — leaving it up makes a reload look like it changed nothing. The 9p mounts are `cache=none` for the same reason: with `cache=loose` the guest kept serving the bytes it read at boot and `reload` copied those, reporting success while showing the old UI.
- Values behind `SettingsBus.get(…)` come from the guest's `~/.config/qsshell/settings.json`, so editing their *defaults* in `Theme.qml` will not change the render — edit plain literals, or set the value with `mujo settings`.
- It needs the host's render node (`/dev/dri/renderD128`): niri refuses software EGL, so the guest gets virgl via `-device virtio-gpu-gl-pci -display egl-headless`. Nothing is drawn on the real session.
- **The first tool call costs ~45s** (VM boot + the ~20s quickshell load); later ones are fast.
- **The VM powers itself off after 10 minutes idle** and boots again on the next tool call, so an agent session left open in another terminal cannot pin its 4 GiB indefinitely (one was found resident for 1h41m holding 1.4 GB). Tune with `MUJO_SANDBOX_IDLE_SEC`; the only cost of a teardown is that the next call pays the ~45s cold start again. `nix shell nixpkgs#python3 -c python3 nixos/sandbox/test-lifetime.py` is the self-check — it runs mcp.py against a fake Machine, needs no QEMU, and covers three directions: the VM comes down when idle or disconnected, never while a client is still calling, and comes down by SIGKILL when its monitor stops answering `crash()` (which is how one stayed resident for ten hours).
- **`MCP_TIMEOUT` must be raised** (`.claude/settings.json` sets it to 180000). A warm `nix run .#sandbox` answers `initialize` in ~0.5s, but a cold flake eval — which is what happens right after any source edit — exceeds the client's 30s default and the server never connects.

## AI ASSISTANTS

Three agents run against this repo — Claude Code, Antigravity (`agy` + the IDE build) and
opencode — and they are configured to see the same things:

- **`.agents/` is the single agent tree.** `.agents/rules/*.md` is read by all three
  (`~/.agents` is persisted in `nixos/core/general.nix`); `rtk.md` there mandates prefixing
  shell commands with `rtk`, a proxy that compresses command output before it reaches the
  model. `.agents/skills/*` holds every repo skill (`graphify`, `handoff`,
  `testing-sandbox`) — `.claude/skills` and `.opencode/skills` are symlinks to it, so a
  skill is added once. `.claude/` and `.opencode/` keep nothing but their own tool config
  (`settings*.json`, `opencode.json`, `plugins/`).
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
| Security architecture | `docs/security-architecture.md` |
| Threat model & invariants | `docs/threat-model.md` |
| Storage model & vault | `docs/storage-model.md` |
| Progressive trust engine | `docs/application-trust.md` |
| Physical & boot security | `docs/physical-security.md` |
| Privacy & metadata model | `docs/privacy-model.md` |
| Credential broker & capability profiles | `docs/application-trust.md` §7 |
| Security test suite layout | `docs/security-tests.md` §4 |
| Performance budget | `docs/performance-budget.md` |
| Security tests specification | `docs/security-tests.md` |
| Overhaul ledger (per-file verdicts, open decisions) | `docs/overhaul-ledger.md` |
| Machine-local overrides | `nixos/overrides/README.md` |
| Issues & specs (`gh` in `DamnShabu/mujo`) | `docs/agents/issue-tracker.md` |
| Domain docs (`CONTEXT.md`, `docs/adr/`) | `docs/agents/domain.md` |
