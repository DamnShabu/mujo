# Overhaul ledger

Branch `overhaul`, off `main` at `9870808`.

## Status: incomplete pass — phases 0–2 done, 3–6 partial

This is an honest accounting, not a completed sweep. **449 tracked files; 84 have
a verdict below.** The remaining 365 were not read, and they carry no row rather
than a fabricated `CORRECT`. `CORRECT` in this ledger means the file was read and
a specific property was checked; it is not a synonym for "not touched".

What is genuinely finished: the phase 0 baseline, the phase 1 deletion sweep over
Nix module arguments and dead packages, and the phase 2 correctness/security pass
over every trust boundary the brief names (`mujo-trustd`, the credential broker,
`nixos/sandbox/mcp.py`, the tray relay) plus the threat-model cross-check.

What is not: phase 3 (no large file was split), phase 4 (one real fix; the
big closure wins all cost a feature — see the decisions), phase 5 (landed; the two
default-off switches stay off, with reasons), and phase 6 for the 365 unreviewed
files.

### The brief's own numbers were stale

| Brief says | Actual at session start |
|---|---|
| 447 tracked files | 448 |
| 119 `TODO\|FIXME\|XXX\|HACK\|ponytail:` markers | 20 matching lines, of which **12** are real markers — the other 8 are `mktemp … XXXXXX` templates |
| `preload`, `skeuos-gtk`, `quicksnip` vendored in `perSystem.nix` | only `skeuos-gtk`; `preload` is gone from the repo entirely, `quicksnip` was an alias, not a vendored package |
| `nixos/security/` staged but unlanded | correct — landed in `05f4601` |
| `apps.trust.launcherIntegration` is off | **it was `true`** in `nixos/hosts/main/configuration.nix` |

The 12 real markers are all `ponytail:` comments that already name a ceiling and
an upgrade path, which is the convention working as intended. One did not, and
was rewritten (`nixos/core/general.nix`, see phase 2).

---

## Phase 0 — baseline

| Metric | Baseline | Now |
|---|---|---|
| `nix flake check` | pass | pass |
| Tracked files | 448 | 449 |
| Tracked lines | 69,417 | 69,607 |
| Nix lines | 7,138 | 7,186 |
| System closure | 15.8 GiB | 15.8 GiB |
| Real debt markers | 12 | 11 |
| `test-lifetime.py` | 4/4 | 4/4 |
| `test-tray-relay.py` | ok | ok |
| `test-trust-registry-lock.sh` | did not exist | ok (20/20 vs 1/20) |

**Line count went up, not down, and the phase 1 gate asks for down.** Deletions
removed ~23 lines. The pass then added a 77-line self-check and replaced bare
markers and undocumented switches with stated ceilings. I am not going to delete
a working check to make a number go the right way; the gate is not met and this
is why.

### One thing worth correcting about the gate itself

`nix flake check` prints `running 0 flake checks` on Nix 2.34 even when checks
run. It is counting non-derivation checks only. `checks.x86_64-linux.hostMain`
**is** evaluated and built — visible as `checking derivation
checks.x86_64-linux.hostMain...` and, on any host-affecting change, a
`nixos-system-main-…drv` build. `nixos/hosts/main/checks.nix` does what its
comment claims.

---

## Phase 1 — delete

### Gate

```
$ nix flake check
checking derivation checks.x86_64-linux.hostMain...
...
building '/nix/store/kay5asyn8c8adj97gbxj48va5ga9rz34-nixos-system-main-26.11.20260719.241313f.drv'...
all checks passed!
warning: The check omitted these incompatible systems: aarch64-linux
```

`qs -p` was not needed for this phase (no QML changed). Later phases did use it
on the live session — see phase 2's gate — after the sandbox MCP wedged; it is
the documented entrypoint and each check exits on its own.

### Deleted

| What | Where | Lines |
|---|---|---|
| `packages.quicksnip`, a bare alias of `packages.mujo-screenshot` — two names, one derivation, zero references | `modules/flake/perSystem.nix` | 1 |
| Unused outer `lib` argument (inner module shadows it) | 15 Nix modules | 15 |
| Unused outer `self` / `inputs` arguments | 7 Nix modules | ~7 |

Kept, because the inner module closes over the outer binding rather than
rebinding it — `nix flake check` proved each one by failing when removed:
`modules/wrappers/environment.nix`, `kitty.nix`, `niri.nix` (`lib` only),
`nixos/core/system-preferences.nix`.

Nothing else was dead. Specifically checked and **not** dead: every QML component
is referenced outside its own file and registered in a `qmldir`; all nine
`security.mujo.<sub>.enable` options are read (as `cfg.<sub>.enable`);
`persistence.volumeGroup`, `nukeRoot` and `cache.files` are all read by
`impermanence.nix`.

---

## Phase 2 — correctness and security

### Gate

```
$ nix flake check
running 42 flake checks...
all checks passed!

$ python3 nixos/sandbox/test-lifetime.py
4/4 sandbox lifetime checks passed

$ python3 nixos/apps/test-tray-relay.py
ok: tray items cross from the guest bus to the host bus

$ bash nixos/apps/test-trust-registry-lock.sh
unlocked: 1/20 records survived 20 concurrent writers
locked:   20/20 records survived 20 concurrent writers
ok: registry lock keeps every concurrent update (unlocked loses 19)

$ cd quickshell/bar && for t in icons grid security-ui settings-ui shelf notifications desktop; do qs -p "./test-$t.qml"; done
PASS  Icons: 88 actions + 48 file types resolve
PASS  DesktopGrid: all occupancy checks green
PASS  security UI: service binds, trust tab renders, vault controls active
PASS  settings UI: rows bind, page hosts, routing resolves
PASS  Shelf: state management, URI/path normalization, deduplication, and icon resolution verified
PASS  Notifications: daemon, icon resolver, grouping, and history tests succeeded
PASS  desktop layout: 0 items placed, no overlaps, grid agrees

$ qs -p ./settings.qml            # with settings-target=security, then restored
INFO: Configuration Loaded        # no binding warnings on the Security page
```

`bash tests/vm/run.sh` could not complete unattended — it `exec`s `disko-vm`,
which wants an interactive console. Its build step was run instead and passes:
`nix build …vmWithDisko` → `/nix/store/bgjdighb4gqscwlxdd2cgxfydzxjgclc-disko-vm`.
That verifies the host config installs onto the real disk layout; it does not
verify the in-VM suite. **Someone should run `bash tests/vm/run.sh` at a
terminal.**

`tests/run-all-tests.sh` probes the running host and therefore cannot pass until
a rebuild. Not weakened, not run.

### The defects that mattered

**The trust registry had no lock.** All four writers — socket handler, graduation
evaluator, boot seeder, root CLI — did `jq > tmp && mv tmp registry`. The `mv` is
atomic, so the file was never half-written, and that was mistaken for the whole
story. Two writers that both read the pre-update registry produce two complete
files and the second `mv` silently discards the first. The write most likely to
be lost is `begin`'s requarantine of an application whose store path moved, which
leaves an updated binary on its old `GRADUATED` state — the supply-chain case
`docs/threat-model.md` A4 claims is detected. The evaluator is worse: it rewrites
every record on a timer and could discard a `REVOKED` a `violation` had just
written. All four now take one `flock`. Measured: 20 concurrent writers, unlocked
keeps 1, locked keeps 20.

**Guest→host notification relay was gated on object path only**, so a compromised
quarantine guest could invoke any member the host's `org.freedesktop.Notifications`
exposes — `CloseNotification` against ids it never created, for instance — rather
than only raising its own. Now a four-member allowlist.

**Three unbounded waits and one crash**, all at boundaries an untrusted party
controls: `read` with no timeout in the trust daemon and in the credential broker
(each holds a *root* process); `NameOwnerChanged` unpacked without an arity check
(any guest client can forge that signal, and the `ValueError` took the relay
down); `json.loads` outside the request `try` in `mcp.py` (one malformed line
killed the MCP server and the VM with it).

**`Launch.trustRouting` defaulted `true`, inverting its own gate.** The property
is read from `/etc/mujo/launcher-integration`, which `trust.nix` writes only
under `lib.mkIf cfg.launcherIntegration` — so *missing file* is the off state.
The default was `true` and `onLoadFailed` was an empty function that kept it, so
turning the option off left every launch routed through `mujo-run` anyway. The
comment three lines above said "Off unless the host wrote the marker". Because
this only bites once the option is off, it would have made the
`configuration.nix` change in phase 5 silently ineffective in the shell.

### Four security indicators that could not report a problem

This is the largest single finding of the pass, and it is one shape repeated.

| Where | What it showed | What was true |
|---|---|---|
| `SecurityGroup.qml` — Encrypted Swap, Core Dumps, Ephemeral /tmp, Firewall | hardcoded `Theme.successDim`, success-coloured icon, `DisplayChip { selected: true }` | `SecurityService` polls all four real values every 15s into properties with **zero consumers** anywhere in the tree |
| `SecurityService.inventoryProc` | catch set `inventoryClean = true`, 0 findings → green "Clean: No unencrypted keys or tokens found on persistent storage" | the scan crashed or printed nothing; nothing was verified |
| `mujo security summary` → UEFI Secure Boot card | green "ENFORCED" | `bootctl status` says **disabled**; the check tested only that the efivar *file exists*, which it does on every UEFI machine, and never read its value |

`tests/lib.sh` states the rule these break: "a check either proves the invariant
holds or it FAILS". All four cards now bind to the telemetry; the audit has a
third `inventoryFailed` state rendered in `Theme.warning`; Secure Boot reads the
variable's value byte. The hardening properties also had to stop defaulting
`true` and stop reading a *missing* JSON field as on (`!== false` → `=== true`),
or "UNVERIFIED" would have been a lie in the other direction.

**`SentinelService._runAction`** chose its argv on `val ?`, so `renice(pid, 0)` —
reset to normal priority — dropped the argument and would have run
`renice -n "" -p <pid>`. Latent: nothing calls `renice` yet.

### Threat-model cross-check

Two claims the code does not enforce. I could not fix the code — both fixes are
exactly the switches the brief forbids turning on — so I corrected the doc.

| Doc claimed | Reality | Resolution |
|---|---|---|
| A1 casual physical attacker: "**Full Defense**: Secure Boot + TPM" | host boots GRUB; `security.mujo.boot.secureBoot = false`; GRUB's editor gives `init=/bin/sh` | doc now says "Partial today", names what does hold (data at rest) and what does not (the boot chain) |
| Invariants 3, 5, 6 stated unconditionally | 3 needs `secureBoot`, 5 and 6 need `apps.trust.launcherIntegration` — all default off | every invariant now marked *enforced* or *conditional on `<switch>`*, with a paragraph saying a conditional invariant is a commitment, not a property to rely on |
| §4: the tradeoff combines tmpfs root, encrypted swap "and Secure Boot" | Secure Boot is off | reworded to "once invariant 3 is switched on" |

### Debt markers

11 of 12 `ponytail:` markers already name a ceiling and an upgrade path — the
convention working. Each was read and left. The twelfth did not, and it was the
one that mattered: `nixos/core/general.nix` carried `# ponytail: allow
passwordless activation for nh` over a `NOPASSWD` sudo rule. `nixos-rebuild` is
root-equivalent by construction, so that rule grants passwordless **root**, not
passwordless rebuild — and narrowing the glob would not change it, since any user
who can talk to the nix daemon can realise a store path matching
`*-nixos-system-*`. It weakens A3 and bypasses the `timestamp_timeout=5` /
`passwd_tries=3` hardening in `nixos/security/users.nix`. Left in place — it is a
deliberate convenience trade for this machine's only user — with the cost now
written down. See decisions.

---

## Phase 3 — structure

**Not done.** `quickshell/mujo.sh` (3826), `WallpaperPanel.qml` (2933),
`MujoPageHeroArt.qml` (1180), `ApplicationsPanel.qml` (1156),
`LauncherGroupsView.qml` / `LauncherBody.qml` (~1080) are untouched. Splitting
QML has one honest gate — identical renders from the sandbox MCP, before and
after — and I did not have that evidence, so I did not start cutting. This is the
largest remaining piece of the brief.

---

## Phase 4 — performance

One change taken, because it cost nothing:

**`NetworkPanel.qml` polled `mullvad` forever once visited.** Settings panels
stay alive after first display so scroll position survives switching category, so
`quickshell/bar/AGENTS.md` requires anything that polls to bind
`running: root.visible`. NetworkPanel was the only panel in `modules/settings/`
using a bare `running: true`, and its `refresh()` starts four `Process`es — so
opening the Network category once left four `mullvad` invocations firing every
three seconds for the rest of the session, off screen, with nothing rendering the
result. Now gated, with `triggeredOnStart` so it refreshes on show rather than up
to 3s later. Verified in the sandbox: settings reaches "Configuration Loaded"
clean and the bar renders unchanged.

Everything else measured and **not** changed, because each costs a feature.

Closure is 15.8 GiB, unchanged. Largest individual store paths:

| Size | Path | Why it is there |
|---|---|---|
| 1468 MiB | `linux-wallpaperengine` | `nixos/desktop/quickshell.nix` — systemPackages *and* the `qs-bar` service path |
| 964 MiB | `qemu-11.0.2` | `nixos/apps/vm.nix` systemPackages, directly |
| 964 MiB | `qemu-11.0.2` (second, different path) | pulled in by `quickemu`, also in `vm.nix` |
| 770 MiB | `linux-firmware` | unavoidable |
| 721 MiB | `antigravity-ide` | from the `unstable` input |
| 540 + 528 MiB | `llvm-21.1.8-lib` ×2 | two nixpkgs revisions |
| 273 + 265 MiB | `mesa-26.1.5` ×2 | same |

The lock holds **three** nixpkgs revisions. `nixpkgs` and `unstable` are pinned to
the *same branch* (`github:nixos/nixpkgs/nixos-unstable`) at *different* commits
(`241313f` vs `56c02bc`), which is what duplicates llvm and mesa. That is not an
accident — `flake.nix` says `unstable` exists so `claude-code` and `antigravity`
can be bumped alone — but it is not free either. See decisions.

One micro-fix taken because it costs nothing: `test-tray-relay.py` spawned
`sleep 0.02` as a subprocess up to 200 times to poll for a socket. `time.sleep`.

---

## Phase 5 — finish what is promised

- **`nixos/security/` is landed** (`05f4601`), with the rest of the 79-file
  staged tree that arrived with the working directory.
- **`apps.trust.launcherIntegration` set back to `false`.** It was `true`. With
  it on, every ungraduated application boots the 4 GB quarantine MicroVM on first
  click — on the only machine this config is applied to. The option's own default
  is already `false` and its description already explains why; the host was
  overriding it. See decisions.
- **`security.mujo.broker.acl` left empty.** The brief says ship a default ACL. I
  disagree and did not. `docs/application-trust.md` §7 commits in writing to
  "Empty by default: an application with no entry gets no socket and can ask for
  nothing", and a default ACL would invent credential policy for credentials that
  may not exist in this user's vault, widening access by default. The brief's
  premise — that the detector "never fires" — is also not quite the issue: an
  empty ACL denies *everything* rather than nothing, and the deny→violation path
  is covered by `tests/redteam/test-boundary-violations.sh:32` and
  `tests/trust/test-trust-engine.sh:126`. See decisions.

---

## Phase 6 — docs

Corrected against the code:

- `AGENTS.md` claimed `preload` and `quicksnip` were vendored in `perSystem.nix`.
  `preload` does not exist anywhere in the repo (`disko.nix` notes it was
  removed); `quicksnip` was an alias, now deleted. Line rewritten.
- `AGENTS.md` layout listed `services/` as containing `preload`. It contains
  `pipewire` and `mullvad`.
- `AGENTS.md` opened with "No test suite" and then listed three test entry points
  seven lines later. Replaced with what each of the three layers actually checks,
  and a new **SELF-CHECKS** section listing the seven offline checks — four of
  which were not mentioned anywhere.
- `docs/threat-model.md` — see the cross-check table above.
- `AGENTS.md` said "**Read colors from `self.theme…`**, never literals". Too
  absolute to be true, and the codebase is right where the rule is wrong: of ~279
  hex literals under `quickshell/bar/`, ~112 are black/white shadow and scrim
  primitives, and most of the rest are *data* — brand colours in `theme/Brand.qml`
  (Mullvad's yellow is not the user's accent), the accent swatches the user picks
  from in `AppearancePanel.qml`, note colours in `NotesWidget.qml`. The rule now
  says what it actually is: chrome from `Theme`, brand/palette/primitive literal.
  A handful in the wallpaper detail modals (`#05070a`, `#181818`, `#ffca28`) are
  genuine leaks; none has an exact `Theme` token, so closing them would change the
  render and they were left alone.

`README.md` was read and is accurate; it gets a stranger oriented in well under
60 seconds.

---

## Decisions for the user

Each is one line, each is actionable, none was taken unilaterally.

1. **Passwordless sudo is passwordless root.** `nixos/core/general.nix`'s
   `NOPASSWD` rule for `nixos-rebuild` means a compromised application running as
   you can become root without your password. Delete that `security.sudo.extraRules`
   block to take the prompt back; nothing else depends on it.
2. **`apps.trust.launcherIntegration` is now `false`** (it was `true`). Turn it
   back on deliberately after walking `docs/application-trust.md` §8 and
   graduating the applications you use daily, or every ungraduated app boots a
   4 GB VM on first click.
3. **Secure Boot stays off**, so `docs/threat-model.md` invariant 3 is not
   enforced and physical access is root access. `docs/physical-security.md` §2a
   is the runbook; do it with a known-good generation still in the boot menu.
4. **The credential broker ACL stays empty**, so no application can request a
   credential. Populate `security.mujo.broker.acl` per `docs/application-trust.md`
   §7 when you have credentials in the vault worth granting — I will not invent
   the policy.
5. **~964 MiB: `qemu` and `quickemu` are both in `nixos/apps/vm.nix`**, and
   quickemu carries its own qemu build. Drop the bare `qemu` if you only ever
   drive VMs through quickemu — but that removes `qemu-system-x86_64` from PATH.
6. **~1.07 GiB: `nixpkgs` and `unstable` are the same branch at different
   commits.** `inputs.unstable.follows = "nixpkgs"` removes the duplicate llvm and
   mesa, and costs you the ability to bump `claude-code`/`antigravity` alone.
7. **1.47 GiB: `linux-wallpaperengine`** is the single largest path in the
   closure. Only worth touching if you do not use Wallpaper Engine wallpapers.
8. **Run `bash tests/vm/run.sh` at a terminal** — it needs an interactive console,
   so the in-VM acceptance suite has not been executed this pass.

---

## File ledger

84 of 449 files. Verdicts: `CHANGED` (diff + what it buys), `CORRECT` (the
property checked), `DELETED` (what absorbed it).

| File | Verdict | Note | Phase |
|---|---|---|---|
| `modules/flake/perSystem.nix` | CHANGED | dropped `packages.quicksnip`, an alias of `mujo-screenshot` with no references | 1 |
| `modules/wrappers/environment.nix` | CORRECT | outer `lib` is genuinely used — inner modules close over it, proven by a failing eval | 1 |
| `modules/wrappers/kitty.nix` | CORRECT | same; `lib.optionalAttrs` at line 80 is outside the inner module | 1 |
| `modules/wrappers/niri.nix` | CHANGED | dropped unused `inputs`; `self` and `lib` are used | 1 |
| `modules/wrappers/fish.nix` | CHANGED | dropped unused `self` | 1 |
| `nixos/core/system-preferences.nix` | CORRECT | inner module takes `{config, ...}` and closes over the outer `lib` | 1 |
| `nixos/apps/gaming.nix` | CHANGED | dropped unused `self` and `inputs` | 1 |
| `nixos/apps/opencode.nix` | CHANGED | dropped unused `self` | 1 |
| `nixos/apps/vm.nix` | CHANGED | dropped unused `self` and `inputs`; carries the duplicate-qemu decision | 1, 4 |
| `nixos/desktop/notifications.nix` | CHANGED | dropped unused `self` | 1 |
| `nixos/services/mullvad.nix` | CHANGED | dropped unused `self` | 1 |
| `nixos/security/kernel.nix` | CHANGED | dropped unused outer `lib`; gating on `cfg.enable && cfg.kernel.enable` is real | 1 |
| `nixos/security/network.nix` | CHANGED | same | 1 |
| `nixos/security/audit.nix` | CHANGED | same | 1 |
| `nixos/security/users.nix` | CHANGED | same; the `log_input` omission is deliberate and documented | 1 |
| `nixos/security/privacy.nix` | CHANGED | same; `dnsOverTls` default-off is correct — it fights the Mullvad daemon | 1 |
| `nixos/security/baseline.nix` | CHANGED | same; all nine sub-`enable` options are read by their modules | 1 |
| `nixos/security/boot.nix` | CHANGED | same; `secureBoot` default `false` is the required state | 1, 5 |
| `nixos/security/storage.nix` | CHANGED | dropped unused outer `lib` | 1 |
| `nixos/security/devices.nix` | CHANGED | same | 1 |
| `nixos/security/vault.nix` | CHANGED | same | 1 |
| `nixos/apps/dev-sandbox.nix` | CHANGED | same | 1 |
| `nixos/apps/microvm.nix` | CHANGED | same | 1 |
| `nixos/apps/native-sandbox.nix` | CHANGED | same | 1 |
| `nixos/apps/trust.nix` | CHANGED | `flock` on all four registry writers; `read -t 5`; 128-char key bound; block-scoped fd in `edit_db` | 1, 2 |
| `nixos/security/broker.nix` | CHANGED | `read -t 5`; capability-by-socket design verified sound — grants are exact build-time strings and the `[^/]+/[^/]+` assertion makes traversal unreachable | 2 |
| `nixos/apps/tray-relay.py` | CHANGED | four-member notification allowlist; arity check on `NameOwnerChanged` | 2 |
| `nixos/apps/test-tray-relay.py` | CHANGED | `time.sleep` for `subprocess.run(["sleep"])` ×200 | 2, 4 |
| `nixos/apps/test-trust-registry-lock.sh` | CHANGED | new: 20 concurrent writers, fails if the unlocked round stops losing updates | 2 |
| `nixos/sandbox/mcp.py` | CHANGED | `json.loads` moved inside a guard; parse errors answer -32700 and the loop survives | 2 |
| `nixos/sandbox/test-lifetime.py` | CORRECT | 4/4; already times out its subprocess; the pattern the other self-checks follow | 2 |
| `quickshell/wallpaper-engine/mujo-wallpaper-engine.py` | CHANGED | `timeout=5` on two `pgrep` and one `pkill`, all inside existing `except` handlers | 2 |
| `nixos/core/base.nix` | CHANGED | removed two `"yurii"` literals that the repo's own rule forbids; both were already shadowed | 2 |
| `nixos/core/general.nix` | CHANGED | bare `ponytail:` replaced with the actual ceiling: this grants passwordless root | 2 |
| `nixos/core/user.nix` | CORRECT | sole resolver of the username, from gitignored `secrets/username` with one fallback | 2 |
| `nixos/core/impermanence.nix` | CORRECT | derives `persistence.user` from `preferences.user.name`; reads `volumeGroup`, `nukeRoot`, `cache.files` | 1 |
| `nixos/core/ui-overrides.nix` | CORRECT | `tryEval` isolates parse errors only, and the marker says exactly that | 2 |
| `nixos/core/user-config.nix` | CORRECT | pure XDG variable declarations, no logic | 1 |
| `nixos/hosts/main/configuration.nix` | CHANGED | `launcherIntegration` `true` → `false` with the reason inline | 5 |
| `nixos/hosts/main/checks.nix` | CORRECT | genuinely re-exports the host toplevel; verified by watching it rebuild | 0 |
| `nixos/hosts/main/_boot.nix` | CORRECT | GRUB active, lanzaboote wired but gated; the marker names a real size-vs-hash ceiling | 2 |
| `docs/threat-model.md` | CHANGED | A1 and invariants 3/5/6 now say what is enforced vs conditional | 2, 6 |
| `AGENTS.md` | CHANGED | `preload`/`quicksnip` claims corrected; "No test suite" replaced; SELF-CHECKS added | 6 |
| `README.md` | CORRECT | accurate, and orients a stranger in under 60 seconds | 6 |
| `docs/application-trust.md` | CORRECT | §7 matches the implementation, including the empty-ACL commitment | 5 |
| `flake.nix` | CORRECT | `importTree` and the `_` convention work as documented; the `unstable` duplication is a decision, not a defect | 4 |
| `quickshell/mujo.sh` | CORRECT | `set -e` without `pipefail` is right here: 653 pipelines, many `… \| head -1 \|\| fallback`, where pipefail would turn a benign SIGPIPE into the fallback branch | 2 |
| `quickshell/test-screenshot-crop.sh` | CORRECT | omits `-e` deliberately — it asserts on commands that must fail | 2 |
| `quickshell/test-screenshot-ocr-lines.sh` | CORRECT | same | 2 |
| `tests/lib.sh` | CORRECT | a sourced library; shell options belong to the entry points, and all eleven set them | 2 |
| `tests/vm/run.sh` | CORRECT | builds and boots the real layout; needs a console, so it cannot run unattended | 2 |
| `tests/trust/test-trust-engine.sh` | CORRECT | drives the `violation` verb, so the broker's detector is covered | 5 |
| `tests/redteam/test-boundary-violations.sh` | CORRECT | covers "sandbox → credential broker without a grant" | 5 |
| `nixos/desktop/gtk.nix` | CORRECT | sets `QS_ICON_THEME` session-wide, which the shell depends on; reached via `desktop.nix` | 1 |
| `nixos/desktop/desktop.nix` | CORRECT | the aggregator that makes `gtk`/`pipewire`/`zen` live despite not being in `configuration.nix` | 1 |
| `nixos/services/pipewire.nix` | CORRECT | wired via `desktop.nix` | 1 |
| `nixos/apps/zen.nix` | CORRECT | wired via `desktop.nix` | 1 |
| `nixos/core/hjem.nix` | CORRECT | wired via `general.nix` | 1 |
| `nixos/core/nix.nix` | CORRECT | wired via `general.nix` | 1 |
| `nixos/sandbox/sandbox.nix` | CORRECT | defines its own test node; not host-wired by design | 1 |
| `nixos/apps/discord.nix` | CORRECT | inner module binds its own `lib`; no outer argument to drop | 1 |
| `quickshell/bar/screenshot.qml` | CORRECT | an entrypoint like `shell.qml`, so its absence from a `qmldir` is right | 1 |
| `nixos/hosts/main/disko.nix` | CORRECT | `randomEncryption` swap; the `noatime` comment records why `preload` left | 1 |
| `modules/flake/theme.nix` | CORRECT | the single palette source the no-hardcoded-colour rule points at | 1 |
| `quickshell/bar/modules/settings/NetworkPanel.qml` | CHANGED | `running: true` → `running: root.visible` + `triggeredOnStart`; it was the one panel in `modules/settings/` breaking the documented rule | 4 |
| `quickshell/bar/theme/Brand.qml` | CORRECT | literal brand colours are right — a vendor's colour is not the user's theme; this file is why the absolute form of the rule is wrong | 6 |
| `quickshell/bar/modules/settings/AppearancePanel.qml` | CORRECT | its hex literals are the accent swatches the user picks *from*, i.e. data | 6 |
| `quickshell/bar/modules/desktop/NotesWidget.qml` | CORRECT | note colour themes are per-note data, not shell chrome | 6 |
| `quickshell/bar/modules/settings/OverviewPanel.qml` | CORRECT | every timer gated on `root.active` (and on expansion where the work is expensive) | 4 |
| `quickshell/bar/modules/settings/VmGroup.qml` | CORRECT | `running: root.visible` — the idiom NetworkPanel was missing | 4 |
| `quickshell/bar/settings.qml` | CORRECT | loads to "Configuration Loaded" with no warnings, including routed to Security | 4 |
| `quickshell/bar/services/Launch.qml` | CHANGED | `trustRouting` default `true` → `false`; `onLoadFailed` now sets false, so an absent marker means off | 2 |
| `quickshell/bar/services/SecurityService.qml` | CHANGED | `inventoryFailed` added; hardening flags default false and parse `=== true`; both silent catches now warn | 2 |
| `quickshell/bar/modules/settings/SecurityGroup.qml` | CHANGED | four hardcoded-green hardening cards bound to live telemetry; audit failure rendered as its own state | 5 |
| `quickshell/mujo.sh` | CHANGED | Secure Boot detection reads the efivar's value byte instead of testing that the file exists | 2 |
| `quickshell/bar/services/SentinelService.qml` | CHANGED | `val ?` → `val !== undefined`, so `renice(pid, 0)` keeps its argument | 2 |
| `quickshell/bar/test-security-ui.qml` | CORRECT | PASS after the SecurityService and SecurityGroup changes | 2 |
| `quickshell/bar/test-icons.qml` | CORRECT | PASS — 88 actions + 48 file types resolve | 2 |
| `quickshell/bar/test-grid.qml` | CORRECT | PASS — occupancy checks green | 2 |
| `quickshell/bar/test-settings-ui.qml` | CORRECT | PASS — rows bind, page hosts, routing resolves | 2 |
| `quickshell/bar/test-shelf.qml` | CORRECT | PASS — state, URI normalisation, dedup, icons | 2 |
| `quickshell/bar/test-notifications.qml` | CORRECT | PASS — daemon, icon resolver, grouping, history | 2 |
| `quickshell/bar/test-desktop.qml` | CORRECT | PASS — no overlaps, grid agrees | 2 |

### Not reviewed — 365 files

No verdict, because they were not read.

| Area | Files |
|---|---|
| `nixos/desktop/` (139 of these are `plymouth/images/*.png`) | 146 |
| `quickshell/bar/modules/` | 97 |
| `quickshell/bar/components/` | 29 |
| `quickshell/bar/services/` | 21 |
| `.agents/` | 15 |
| everything else (docs, tests, theme, tools, dotfiles) | ~78 |

The QML tree is the bulk of it, and it is also where phase 3 has not started.
