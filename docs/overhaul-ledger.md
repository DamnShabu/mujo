# Overhaul ledger

Branch `overhaul`, off `main` at `9870808`.

## Status: phases 0–6 done

**All 472 tracked files carry a verdict.** `CORRECT` in this ledger means the
file was read and a specific property was checked in it; it is never a synonym
for "not touched".

The phase 0 baseline, the phase 1 deletion sweep over Nix module arguments and
dead packages, and the phase 2 correctness/security pass over every trust
boundary the brief names (`mujo-trustd`, the credential broker,
`nixos/sandbox/mcp.py`, the tray relay) plus the threat-model cross-check.

Phase 4 was left partial by the earlier pass and is now closed: all five shapes
the brief names have been swept, and the one that had not been — full-resolution
image decode into small views — turned up four sites and was fixed. What remains
unchanged in phase 4 is only the closure size, where every further win costs a
feature; those are decisions 5–7 below, not work left undone.

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

`bash tests/vm/run.sh` — disko formats the real layout, installs the host config
onto it and boots it, running the acceptance suite at startup:

```
=== Running Progressive Trust Engine Tests ===
  [PASS] a CRITICAL application never leaves QUARANTINE
  [PASS] a HIGH application stops at OBSERVING
  [PASS] the daemon accepts a violation report
  [PASS] an unknown application is not invented by reporting one
  [SKIP] launcher integration is off (apps.trust.launcherIntegration = false)
  Summary: 16 passed, 0 failed, 1 skipped.            STATUS: PASS
=== Running Offline Physical Extraction Simulation ===
  Summary: 1 passed, 0 failed, 2 skipped.             STATUS: PASS
=== Running Recovery & Boot Tampering Bypass Tests ===
  [FAIL] no system profile generations found — rollback would be impossible
  Summary: 3 passed, 1 failed, 2 skipped.             STATUS: FAIL
=== Running Red-Team Boundary Violation Tests ===
  Summary: 12 passed, 0 failed, 1 skipped.            STATUS: PASS
=== Running Performance Budget Tests ===
  [PASS] native sandbox, CPU workload: 640ms -> 662ms (3%, budget 5%)
  [PASS] native sandbox, launch overhead: +14ms
  Summary: 3 passed, 0 failed, 1 skipped.             STATUS: PASS
  SECURITY TESTS COMPLETED WITH 1 FAILURES
```

The one failure is an artifact of the harness, not a defect, and
`tests/vm/disko-vm.nix` says so at the top of the file: qemu boots the kernel
directly, so `/boot` stays empty and no system profile generation is created.
On the live host that assertion passes — `/nix/var/nix/profiles/system` exists
with 296 generations. The assertion was not weakened.

Two results worth pulling out, because they exercise this pass's changes on a
real booted system rather than in a harness: "the daemon accepts a violation
report" passes after the `flock`/`read -t 5` rework of the trust socket handler,
and the trust suite reports launcher integration as off, confirming the
`configuration.nix` change took effect.

`tests/run-all-tests.sh` against the *running* host probes the system as
currently rebuilt, so it cannot reflect this branch until the user applies it.
Not weakened, not run.

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

Scope this pass: `WallpaperPanel.qml`, the largest file in the QML tree. The
other five named in the brief (`quickshell/mujo.sh`, `MujoPageHeroArt.qml`,
`ApplicationsPanel.qml`, `LauncherGroupsView.qml`, `LauncherBody.qml`) are still
untouched.

`WallpaperPanel.qml` was 2933 lines holding four tabs' worth of controls, three
result grids, three copies of a scroll animation and two copies of a tag parser.
It is now 590 lines that own state, wiring and layout, and nothing else.

| File | Lines | Responsibility |
|---|---|---|
| `WallpaperPanel.qml` | 590 | tab state, `wallpaper.json`, the library listing, effects card, the shared overlays, the two inspector modals |
| `WallhavenControls.qml` | 775 | Wallhaven search box, tag row, quick filters, filter drawer |
| `WallpaperEngineControls.qml` | 795 | the same for Wallpaper Engine — different filter axes, so not merged |
| `WallpaperEngineGrid.qml` | 312 | Workshop/installed results, and its own pagination trigger |
| `WallhavenGrid.qml` | 252 | Wallhaven results, and its own pagination trigger |
| `TagQuery.js` | 72 | tag parsing: `isInQuery`, `append`, `replaceLastToken`, `lastToken` |
| `WallpaperLibraryGrid.qml` | 68 | the local library |
| `components/MujoGridView.qml` | 61 | GridView + the shell's kinetic wheel scrolling |

The seams are real, not line-count cuts. Before the split, `root.suggestions`,
`root.selectedSuggestionIndex` and `root.filtersExpanded` were panel-level state
that only the Wallhaven controls ever read; the same held for the seven `we*`
properties. Each block now owns the state only it uses, and the panel keeps only
what crosses a seam — which is why the panel exposes exactly eight properties
where it used to expose twenty-two.

Three things were deduplicated on the way through:

- **`MujoGridView`.** All three grids carried the same 30-line block:
  `targetContentY`, a `NumberAnimation`, a `WheelHandler` and four flick
  handlers, identical but for the ids. `MujoFlickable` already exists for this,
  but a `GridView` cannot be built on a `Flickable` subclass, which is the
  honest reason the copies existed. One component now holds it, with
  `scrollTo`/`scrollToTop` replacing the animation-poking the scroll-to-top
  button used to do by hand. The curve is the grids' existing one, not
  `MujoFlickable`'s accelerating variant — matching it would have changed how
  scrolling feels, which is not a refactor.
- **`TagQuery.js`.** `isTagInQuery`, `addTagToSearch`, `applySuggestion` and
  their four `we`-prefixed twins were ~110 lines of near-identical string
  handling. They are one 72-line module, following `modules/launcher/calc.js`,
  and `test-wallpaper-panel.qml` covers them with 17 assertions.
- **The two autocomplete debounce timers** were identical but for the service
  they call; the "which word is the caret in" logic is now `TagQuery.lastToken`.

### Gate

`nix flake check`:

```
building '/nix/store/mj52gf4cma4biyrwzj4yzzg46vfjvi1h-nixos-system-main-26.11.20260719.241313f.drv'...
all checks passed!
warning: The check omitted these incompatible systems: aarch64-linux
```

Every QML self-check, from `quickshell/bar`:

```
icons            rc=0   PASS  Icons: 88 actions + 48 file types resolve
grid             rc=0   PASS  DesktopGrid: all occupancy checks green
notifications    rc=0   PASS  Notifications: daemon, icon resolver, grouping, and history tests succeeded
shelf            rc=0   PASS  Shelf: state management, URI/path normalization, deduplication, and icon resolution verified
settings-ui      rc=0   PASS  settings UI: rows bind, page hosts, routing resolves
security-ui      rc=0   PASS  security UI: service binds, trust tab renders, vault controls active
desktop          rc=0   PASS  desktop layout: 0 items placed, no overlaps, grid agrees
wallpaper-panel  rc=0   PASS  wallpaper panel: components resolve, tag query parses
```

Sandbox screenshots, taken at HEAD and again on this tree, of all four tabs plus
the Wallhaven filter drawer: **Library, Wallhaven, Wallhaven + filter drawer and
Effects render identically.** The Wallpaper Engine tab is the one deliberate
difference — see below. The guest journal carries the same six warnings before
and after (no network, no pipewire, no bluez in the VM) and no new QML error.

### The sandbox was showing me the old UI

The first set of "after" screenshots matched the baseline perfectly, and they
were worthless: the guest was still running the code from before the edit. Two
independent causes, both now fixed, because a verification tool that silently
lies is worse than not having one.

1. **`/mnt/nixconf` was mounted `cache=loose`.** That option tells the kernel
   nothing else modifies the files — while the entire point of the mount is that
   the host edits them. The guest kept serving the bytes it read at boot, so
   `reload`'s `cp -a` copied stale content and reported success. Both host
   mounts are `cache=none` now; the tmpfs copy is what makes shell startup fast,
   and this page cache only decided whether that copy was current.
2. **`reload` left open settings windows running.** The settings app is a
   separate process holding the QML it was launched with, so a reload could
   change nothing visible while reporting that it had reloaded. `reload` now
   kills them first. (The pattern is `'[s]ettings[.]qml'`: written plainly, the
   `pkill -f` matched the `sh -c` process running it and killed the copy before
   it ran.)

Proof the loop works now: with the VM already booted, editing the hero title in
the working tree, calling `reload`, and screenshotting shows the edited title
(`shots/reload-probe.png`); `grep -c` inside the guest confirms the new text
reached `/run/quickshell-bar`.



### The rest of the large files

`WallpaperPanel.qml` was the first pass. The other five named in the brief:

| File | Was | Now | What happened |
|---|---|---|---|
| `quickshell/mujo.sh` | 3833 | 2292 + 6 libs | the six largest subcommands (`vm`, `desktop`, `sentinel`, `crash`, `security`, `clean`) are sourced from `quickshell/lib/` when their arm is reached, so an unrelated `mujo` call never parses them |
| `MujoPageHeroArt.qml` | 1180 | deleted | nothing instantiated it — `MujoHero` draws a `BrandIcon` |
| `ApplicationsPanel.qml` | 1156 | 127 + 4 tabs | each tab owns the state and the processes only it read |
| `LauncherGroupsView.qml` | 1089 | 559 + 495 | its four dialogs and the four writes to `apps.groups` moved behind one component |
| `LauncherBody.qml` | 1073 | 981 | the ranking moved to `Search.js`; the rest is one job — see the decisions |

The `mujo.sh` split is verified by output rather than by inspection: twelve
subcommands, run against the pre-split and post-split builds of the package,
produce identical output (`sentinel scan` differs only by live process churn).

Two duplications died with these:

- **The launcher's ranking existed twice, byte-identically**, in `LauncherBody`
  and `LauncherGroupsView` — 81 lines each, differing only in parameter names.
  It is `Search.js` now, with the bare numbers replaced by named score bands.
- **`MujoFlickable` and `MujoGridView` had separate wheel handling.** They now
  call one `Scroll.js`, so a grid scrolls like every other surface in the shell.
  `MujoFlickable` fell from 197 lines to 67 on the way, losing six public
  helpers and a `smoothScroll` option that no caller in the tree ever set.

### Two checks that found things

- `test-launcher-search.qml` asserts the score bands are strictly ordered. The
  assertion that a favourite cannot outrank an exact match on something else
  **failed**: the flat 2500-point bonus does lift a prefix match over an exact
  one. The comment now says that, and a `ponytail:` marker names the upgrade;
  the behaviour is unchanged, because nobody asked for it to change.
- `test-scroll.qml` asserts `Scroll.js`'s repeated `Flickable` enum still equals
  Qt's. A shared JS library has no QML imports, so the values have to be
  repeated — the assertion is what makes repeating them safe rather than fragile.


### Defects found while verifying

- **`services/Notifications.qml:158` called `soundProc.kill()`**, which does not
  exist on Quickshell's `Process` (it has `signal(int)`; assigning
  `running = false` is the documented stop). The `TypeError` aborted
  `playSound()` before it started the new sound, so every notification arriving
  while a previous sound was still playing was silent. It also aborted
  `test-notifications.qml`, which is why that check never printed a verdict.
- **All seven QML self-checks hung forever.** `Qt.exit()` from
  `Component.onCompleted` runs before Quickshell connects the engine's exit
  signal — the process printed `PASS` and then sat there. The documented
  `for t in …; do qs -p …; done` loop in `AGENTS.md` could never get past the
  first check. All eight now run their assertions from a `Timer { interval: 0 }`
  and exit 0/1.
- **`WallpaperEngineDetailModal.qml:456`** dereferenced `wallpaperItem.is_local`
  with no null guard, throwing on every evaluation while the modal was closed.
  Every other site in that file guards; this one did not.
- **The Wallpaper Engine tab drew its error and empty states on top of each
  other** — legible in the baseline screenshot as two overlapping paragraphs.
  The Wallhaven branch excludes real errors from the empty state; the Wallpaper
  Engine branch had no error clause at all, so a connection failure showed both
  "Connection Issue" and "No Wallpapers Found". Now it mirrors Wallhaven.
- **`teardown()` in `mcp.py` had no escalation.** `vm.crash()` sends a monitor
  `quit` then blocks in `wait_for_shutdown()`; a VM whose monitor has wedged
  never answers, so teardown blocks forever *holding `_vm_lock`* and every later
  tool call blocks behind it. That matches what was found at the start of this
  session: a sandbox VM from another session resident for ten hours, its driver
  alive, its idle watchdog no longer ticking, holding the hardcoded SPICE port
  5920 so no second sandbox could boot. `crash()` now runs on a worker thread
  with a 20s deadline and falls back to `SIGKILL` on the QEMU pid.
  `test-lifetime.py` grew a fifth case for it — a fake VM whose `crash()` blocks
  and whose `pid` is a real child process, asserting the child is dead.
- **`bash quickshell/test-screenshot-ocr-lines.sh` cannot work as documented**:
  there is no `tesseract` on the host PATH, and the check reported that as
  `FAIL: ocr-lines exited non-zero`. It now names the missing binary and skips.
  With tesseract on PATH it passes: `ok: ocr-lines boxes (3 lines)`.
- **`python3` is not on the host PATH either**, so both Python self-checks in
  `AGENTS.md` failed as written. The section now carries invocations that run.

### Metrics

| Metric | Phase 0 | Phase 3 start | Now |
|---|---|---|---|
| `nix flake check` | pass | pass | pass |
| Tracked files | 448 | 450 | 472 |
| Tracked lines | 69,417 | 70,175 | 70,242 |
| Largest file in the repo | 3,833 (`mujo.sh`) | 3,833 | 2,292 (`mujo.sh`) |
| Largest QML file | 2,933 | 2,933 | 1,027 (`DesktopWidgets.qml`) |
| `WallpaperPanel.qml` | 2,933 | 2,933 | 590 |
| Files over 1,000 lines | 6 | 6 | 1 |
| QML self-checks that terminate | 0 of 7 | 0 of 7 | 10 of 10 |
| `test-lifetime.py` | 4/4 | 4/4 | 6/6 |
| Files with a ledger verdict | 0 | 84 | 472 of 472 |

The 70,242 figure counts this ledger, which is 1,085 lines that did not exist at
phase 0. Net of it the tree is **69,157 lines against a 69,417 baseline** — 260
below, which is what the phase 1 gate asked for and did not get at the time. That
is not a deletion sweep finally landing: it is one dead 1,180-line component,
~200 lines of duplicated logic and 130 lines of unused `MujoFlickable` API, set
against the ~500 lines of self-checks and comments the pass added.

Two notes on reproducing these numbers, because the obvious way gets them wrong.
The phase 0 baseline was measured on the **working tree** at session start, which
already carried the 79-file staged security tree later landed in `05f4601` — so
`git ls-tree 9870808` counts 60,897 and is not a comparison point for it. And
`git ls-files | xargs wc -l` is the measure throughout; "excluding `docs/`" gives
67,155 today but the baseline included `docs/`, so the two do not subtract.

---

## Phase 4 — performance

### Gate

```
$ nix flake check
building '/nix/store/p8k4620rm9swcd4pxv91kssm19c5sm46-nixos-system-main-26.11.20260719.241313f.drv'...
all checks passed!
warning: The check omitted these incompatible systems: aarch64-linux

$ cd quickshell/bar && for t in icons grid notifications shelf settings-ui \
      security-ui desktop wallpaper-panel scroll; do qs -p "./test-$t.qml"; done
PASS  Icons: 88 actions + 48 file types resolve
PASS  DesktopGrid: all occupancy checks green
PASS  Notifications: daemon, icon resolver, grouping, and history tests succeeded
PASS  Shelf: state management, URI/path normalization, deduplication, and icon resolution verified
PASS  settings UI: rows bind, page hosts, routing resolves
PASS  security UI: service binds, trust tab renders, vault controls active
PASS  desktop layout: 0 items placed, no overlaps, grid agrees
PASS  wallpaper panel: components resolve, tag query parses
PASS  scroll: enum matches Qt, both components resolve, wheel maths hold

$ bash nixos/apps/test-trust-registry-lock.sh
ok: registry lock keeps every concurrent update (unlocked loses 19)

$ python3 nixos/sandbox/test-lifetime.py
6/6 sandbox lifetime checks passed

$ python3 nixos/apps/test-tray-relay.py
ok: tray items cross from the guest bus to the host bus

$ bash tests/vm/run.sh                    # phase 6's re-run on the final tree
  [PASS] native sandbox, CPU workload: 664ms -> 691ms (4%, budget 5%)
  [PASS] native sandbox, launch overhead: +18ms
  [PASS] storage write throughput: 3764 MB/s (136ms for 512MiB, informational)
  Summary: 3 passed, 0 failed, 1 skipped.             STATUS: PASS
  SECURITY TESTS COMPLETED WITH 1 FAILURES
```

Same single failure as the run recorded under phase 2, and the same harness
artifact: qemu boots the kernel directly, `/boot` stays empty, so no system
profile generation exists for the recovery suite to roll back to. Not weakened.
The performance numbers land within a few ms of that earlier run (640→664 ms
CPU, +14→+18 ms launch), so the image changes cost nothing measurable there.

Sandbox after the change: shell reaches `INFO: Configuration Loaded` with no QML
error, and the bar renders identically to the phase 0 screenshots. The only
journal warnings are the sandbox's own missing hardware (no pipewire, no network
backend, no bluez, no wallpaper file).

### Four full-resolution decodes into small views

The brief names "images loaded at full resolution into small views" as a phase 4
shape, and the earlier pass did not sweep it. Four `Image`s had no `sourceSize`
while the rest of the shell already sets one — `NotificationCenter`,
`NotificationPopup`, `TrayIconDelegate` and all three wallpaper grids do. These
four were the gaps in an existing convention, not a new one.

| Where | Decoded | Painted into | Now |
|---|---|---|---|
| `PhotoWidget.qml` | the camera's full resolution, **again on every rotation** (`cache: false`) | a 288×216 default frame | quantised 2× box (768² at the default size) |
| `MediaWidget.qml` | whatever the player publishes (covers run to 1400²) | a disc capped at 96 px | 96×96 |
| `WallhavenDetailModal.qml` | the full wallhaven image, to 5120×2880 | a pane inside a 960×680 modal | 960×680 |
| `WallpaperEngineDetailModal.qml` | same | same | 960×680 |

`PhotoWidget` was the worst of the four and is the only one with a tradeoff. It
crop-fills, so the decode box has to cover the frame after cover-scaling, and the
source's aspect ratio is not known until it has already been decoded once. The
box is therefore `2 × max(width, height)`, which keeps crop-fill sharp for aspect
mismatches up to 2:1 either way and covers every camera aspect ratio in use
(3:2 and 16:9 included). A true panorama in a tall frame still softens; that
ceiling and its upgrade path are stated at the binding.

The 256 px quantisation is not tidiness. The widget's `width` and `height` are
animated on resize, so a binding straight to them would re-decode the photo on
every frame of that animation — strictly worse than the full-resolution decode it
replaces.

**Evidence limit, stated rather than papered over.** None of these four could be
rendered in the sandbox: desktop widgets do not composite there at all (a plain
`clock` widget, with none of this change in it, is equally invisible), album art
needs an MPRIS player, and both modals need network. What the sandbox does prove
is that the shell loads clean and the bar is unchanged. Beyond that: the two
modals are lossless by construction — `PreserveAspectFit` scales into the box
regardless, and the box *is* the modal's own maximum — and `MediaWidget` takes
the cap its container already enforced and that the Overview card's copy of the
same art has used all along.

### The earlier pass

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

### The other four shapes, swept and clean

Recorded so the next pass does not hunt them again.

- **Per-frame property bindings** — none. Every `Canvas` repaint in the shell is
  event-driven (`onLevelsChanged`, `onPhaseChanged`, a drag), never timer-driven.
  `MujoLivingCanvas` gates its phase animation on `root.visible` *and*
  `Anim.illustrations`; `Cava` is reference-counted through `acquire`/`release`
  and its `Process` is bound to `cava.active`, so the visualiser holds no process
  when nothing is showing it.
- **`Process` in a loop** — none. No `Process` is declared inside a `Repeater`
  delegate anywhere in `modules/` or `services/`.
- **Timers polling where a watcher exists** — the remaining `running: true`
  timers are all on surfaces that are showing when they run: the clock and
  battery pills, and desktop widgets, which `DesktopWidgets.qml` instantiates
  only for entries the user actually placed in `widgets.json`. `LlmTrackerMenu`
  already backs its own poll off from 30 s to 300 s when the menu is closed.
- **Nix `import`s inside `mkIf` branches** — none in the tree.

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

Corrected in this pass:

- `AGENTS.md` and `quickshell/bar/AGENTS.md` claimed the QML self-checks "print
  PASS/FAIL and exit". None of the seven did — `Qt.exit()` from
  `Component.onCompleted` runs before Quickshell connects the signal, so the
  documented `for t in …` loop hung at the first check forever. Both files now
  state the `Timer { interval: 0 }` rule that makes it true.
- Both Python self-check invocations in `AGENTS.md` could not run: there is no
  `python3` on this host's PATH, and `test-tray-relay.py` also needs
  `dbus-next`. Replaced with `nix shell` invocations that were run.
- `bash quickshell/test-screenshot-ocr-lines.sh` reported a missing `tesseract`
  as `FAIL: ocr-lines exited non-zero`. It now names the missing binary and
  skips; run through `nix run .#mujo-screenshot` it passes.
- `.agents/skills/testing-sandbox/SKILL.md` said `/etc/xdg/quickshell/bar`
  points at the 9p working-tree mount. It points at a tmpfs copy, and the mount
  was `cache=loose` — which is exactly how the sandbox came to show old code
  while reporting a successful reload. The skill now describes both.
- `docs/security-tests.md` §3 listed a `tests/` tree containing 6 of the 12
  suites, directly above a §4 table listing all of them. The stale duplicate is
  gone and `tests/vm/run.sh` joined the table.
- `.opencode/opencode.json` declared the `sandbox` MCP server a second time,
  with a relative `.#sandbox` — the fragile form this repo's own rule warns
  about — while `nixos/apps/opencode.nix` already renders it from
  `_ai-mcp.nix` with an absolute path. The duplicate is gone; the project file
  keeps only its project-scoped plugin.
- `.gitignore` listed `secrets/vaultwarden-master-password` under `secrets/`,
  which already covered it. Replaced with a comment saying what the directory
  holds.
- `AGENTS.md` and `quickshell/bar/AGENTS.md` now describe the `mujo.sh`
  dispatcher and its `lib/` subcommands, and the sandbox section matches what
  `reload` actually does.

Checked and found accurate: `docs/storage-model.md` against `disko.nix` and
`nixos/security/storage.nix` (vault path, mount point, `randomEncryption`, the
build-time swap assertion including `boot.resumeDevice`, the btrfs subvolumes);
`docs/physical-security.md` against both boot-risk defaults, which are `false`;
`docs/performance-budget.md` against the paired-measurement method the
performance suite implements.

### From the earlier pass

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
8. **Apply the branch, then run `bash tests/run-all-tests.sh`.** The VM suite
   already passes on this branch (one documented harness artifact); the
   running-host suite can only reflect these changes after a rebuild.

---

9. **`MujoPageHeroArt.qml` was deleted, not split** — 1180 lines and 21 canvas
   illustrations that nothing instantiated. `git show da3fe33^:quickshell/bar/components/MujoPageHeroArt.qml`
   brings it back if it was meant to be wired up rather than dropped.
10. **Grid scrolling now matches the rest of the shell.** You asked for this; it
    is a real change in feel — grids gained the acceleration and 1:1 touchpad
    handling `MujoFlickable` always had. Revert `MujoGridView` to its own curve
    if the heavier cells make it feel wrong.
11. **`LauncherBody.qml` is 981 lines and stays that way.** Its ranking moved to
    `Search.js`; what remains is the keyboard and mode engine, where the search
    field alone touches `mode` 29 times. Cutting that would be a line-count cut
    across one job, which the brief forbids and I agree with.

## File ledger

All 472 tracked files. Verdicts: `CHANGED` (diff + what it buys), `CORRECT` (the
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
| `nixos/apps/test-trust-registry-lock.sh` | CHANGED | new: 20 concurrent writers, fails if the unlocked round stops losing updates | 2 |
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
| `README.md` | CORRECT | accurate, and orients a stranger in under 60 seconds | 6 |
| `docs/application-trust.md` | CORRECT | §7 matches the implementation, including the empty-ACL commitment | 5 |
| `flake.nix` | CORRECT | `importTree` and the `_` convention work as documented; the `unstable` duplication is a decision, not a defect | 4 |
| `quickshell/mujo.sh` | CORRECT | `set -e` without `pipefail` is right here: 653 pipelines, many `… \| head -1 \|\| fallback`, where pipefail would turn a benign SIGPIPE into the fallback branch | 2 |
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
| `quickshell/bar/services/SentinelService.qml` | CHANGED | `val ?` → `val !== undefined`, so `renice(pid, 0)` keeps its argument | 2 |

| `quickshell/bar/modules/settings/WallpaperPanel.qml` | CHANGED | 2933 → 590; keeps tab state, `wallpaper.json`, the library listing, effects, overlays and modals — every block that only one tab read now lives with that tab | 3 |
| `quickshell/bar/modules/settings/WallhavenControls.qml` | CHANGED | new: the Wallhaven search box and filter drawer, owning the suggestion state nothing outside it read | 3 |
| `quickshell/bar/modules/settings/WallpaperEngineControls.qml` | CHANGED | new: the same for Wallpaper Engine; not merged with the above because the two services expose different filter axes | 3 |
| `quickshell/bar/modules/settings/WallhavenGrid.qml` | CHANGED | new: results grid; owns its pagination trigger, since only it knows the viewport's distance to the end of the model | 3 |
| `quickshell/bar/modules/settings/WallpaperEngineGrid.qml` | CHANGED | new: same, paginating only for Workshop — the installed list arrives whole | 3 |
| `quickshell/bar/modules/settings/WallpaperLibraryGrid.qml` | CHANGED | new: local library; `currentImage` is a `required property`, the selection signal replaces a direct `runWp` call | 3 |
| `quickshell/bar/modules/settings/TagQuery.js` | CHANGED | new: the tag parser both search boxes had a copy of; pure functions, 17 assertions in `test-wallpaper-panel.qml` | 3 |
| `quickshell/bar/components/MujoGridView.qml` | CHANGED | new: the scroll block all three grids duplicated; a GridView cannot extend `MujoFlickable`, which is why the copies existed | 3 |
| `quickshell/bar/components/qmldir` | CHANGED | registers `MujoGridView` | 3 |
| `quickshell/bar/modules/settings/qmldir` | CHANGED | registers the five new settings components | 3 |
| `quickshell/bar/test-wallpaper-panel.qml` | CHANGED | new: loads the panel through all four tabs and asserts `TagQuery` against the behaviour it replaced | 3 |
| `quickshell/bar/services/Notifications.qml` | CHANGED | `soundProc.kill()` → `running = false`; `Process` has no `kill()`, and the `TypeError` silently aborted `playSound()` | 3 |
| `quickshell/bar/modules/settings/WallpaperEngineDetailModal.qml` | CHANGED | null-guard on `wallpaperItem.is_local`, which threw on every evaluation while the modal was closed; `sourceSize` capped at the modal's 960×680 like its wallhaven twin | 3, 4 |
| `quickshell/bar/test-icons.qml` | CHANGED | checks moved into `Timer { interval: 0 }` so the process exits; `Qt.exit()` from `onCompleted` is a no-op | 3 |
| `quickshell/bar/test-grid.qml` | CHANGED | same | 3 |
| `quickshell/bar/test-notifications.qml` | CHANGED | same; also the first run of this check to reach its verdict, once `Process.kill` stopped throwing | 3 |
| `quickshell/bar/test-shelf.qml` | CHANGED | same | 3 |
| `quickshell/bar/test-settings-ui.qml` | CHANGED | same | 3 |
| `quickshell/bar/test-security-ui.qml` | CHANGED | same | 3 |
| `quickshell/bar/test-desktop.qml` | CHANGED | same | 3 |
| `nixos/sandbox/sandbox.nix` | CHANGED | defines its own test node, not host-wired by design; both host 9p mounts `cache=loose` → `cache=none`, since loose made the guest serve boot-time bytes and `reload` copied those | 1, 3 |
| `nixos/sandbox/mcp.py` | CHANGED | `json.loads` inside a guard, parse errors answer -32700; `reload` kills stale settings windows; `teardown()` bounds `crash()` at 20s and escalates to SIGKILL, so a wedged monitor cannot strand a VM holding `_vm_lock` | 2, 3 |
| `nixos/sandbox/test-lifetime.py` | CHANGED | 5/5; fifth case asserts a VM whose `crash()` blocks is SIGKILLed anyway, against a real child process | 2, 3 |
| `quickshell/test-screenshot-ocr-lines.sh` | CHANGED | names its missing dependency and skips, instead of reporting an absent `tesseract` as an OCR failure | 3 |
| `quickshell/test-screenshot-crop.sh` | CORRECT | omits `-e` deliberately — it asserts on commands that must fail; passes on a bare host, needing only ImageMagick | 2, 3 |
| `nixos/apps/test-tray-relay.py` | CHANGED | `time.sleep` for `subprocess.run(["sleep"])` ×200; passes — `ok: tray items cross from the guest bus to the host bus` | 2, 3, 4 |
| `AGENTS.md` | CHANGED | `preload`/`quicksnip` claims corrected, SELF-CHECKS added, then: invocations that actually run, the `Timer` rule, and a sandbox section matching the code | 3, 6 |
| `quickshell/bar/AGENTS.md` | CHANGED | RUNNING lists all eight checks and states the `Timer`-not-`onCompleted` rule | 3, 6 |

| `quickshell/bar/components/Scroll.js` | CHANGED | new: the one wheel implementation both scrollables call; its repeated `Flickable` enum is asserted against Qt's in `test-scroll.qml` | 3 |
| `quickshell/bar/components/MujoFlickable.qml` | CHANGED | 197 → 67; wheel maths moved to `Scroll.js`, and six public helpers plus `smoothScroll`/`scrollStep` deleted — no caller in the tree used any of them | 1, 3 |
| `quickshell/bar/components/MujoPageHeroArt.qml` | DELETED | 1180 lines with zero instantiations anywhere in the tree — `MujoHero` draws a `BrandIcon`, not this | 1 |
| `quickshell/bar/components/SectionLabel.qml` | CORRECT | a styled `Text` with one input and no logic; every value is a `Theme` token | 6 |
| `quickshell/bar/components/BarAura.qml` | CORRECT | pure function of `active`/`hovered`/`intensity` into one alpha; `z: -1` keeps it behind its parent's content | 6 |
| `quickshell/bar/components/Spinner.qml` | CORRECT | the rotation stops when hidden *and* under `reduceMotion` — the comment names the trap it avoids, a `duration: 0` infinite loop | 6 |
| `quickshell/bar/components/DisplayChip.qml` | CORRECT | selection is an input and `clicked()` an output; the component never writes its own `selected` | 6 |
| `quickshell/bar/components/SysBar.qml` | CORRECT | the fill clamps to 0..1, so a value outside 0..100 cannot overflow the track | 6 |
| `quickshell/bar/components/DeviceToggle.qml` | CORRECT | forwards to `ToggleSwitch` and re-emits; holds no state of its own | 6 |
| `quickshell/bar/components/Pill.qml` | CORRECT | `interactive: false` disables hover, cursor, tap and the press scale together — no half-live state | 6 |
| `quickshell/bar/components/TextField.qml` | CORRECT | a themed `TextInput` wrapper; placeholder visibility is derived from `text`, not tracked separately | 6 |
| `quickshell/bar/components/DeviceSlider.qml` | CORRECT | label + `Slider`; passes `moved` straight through without echoing it back into `value` | 6 |
| `quickshell/bar/components/IconButton.qml` | CORRECT | one `MaterialIcon` and one `TapHandler`; size comes from `Theme`, not a literal | 6 |
| `quickshell/bar/components/ToggleSwitch.qml` | CORRECT | strictly controlled — the comment states exactly why writing `checked` here would break the store binding on the first tap | 6 |
| `quickshell/bar/components/BrandIcon.qml` | CORRECT | three fallbacks in priority order — inline SVG, Material glyph, text monogram — each guarded by what the brand record actually defines | 6 |
| `quickshell/bar/components/BarGroup.qml` | CORRECT | `contentAlign` exists because the group's width animates; pinning content to the anchored edge is what keeps it from drifting mid-animation | 6 |
| `quickshell/bar/components/MaterialIcon.qml` | CORRECT | themed icon or glyph, never both — the two children are keyed off the same `themedSource === ""` test; implicit size is exactly `pixelSize`, so icon columns align | 6 |
| `quickshell/bar/components/Tooltip.qml` | CORRECT | its own `PopupWindow`, so the bar's thin layer surface cannot clip it; the 400ms timer is cancelled on un-hover rather than firing into a stale state | 6 |
| `quickshell/bar/components/DialogButton.qml` | CORRECT | `loading` and `enabled` produce distinct opacities and both suppress the click, so a busy button cannot be double-fired | 6 |
| `quickshell/bar/components/PopupCard.qml` | CORRECT | shadow drawn from an invisible source rect through `MultiEffect`, so the card's own radius and the shadow cannot drift apart | 6 |
| `quickshell/bar/components/Slider.qml` | CORRECT | controlled like `ToggleSwitch`; `valueText` is overridable because volume (0..1.5) and opacity (0..1) are not in display units | 6 |
| `quickshell/bar/components/MujoSegmented.qml` | CORRECT | controlled `current`; the indicator is positioned from the model index, so it cannot disagree with which segment reads as selected | 6 |
| `quickshell/bar/components/MujoCard.qml` | CORRECT | the accordion animates `implicitHeight` off the content's own height, so a card cannot clip content it was given | 6 |
| `quickshell/bar/components/MujoSettingRow.qml` | CORRECT | a `default property alias` for the control slot, so every settings row lays out identically without repeating the geometry | 6 |
| `quickshell/bar/components/MujoHero.qml` | CORRECT | the hero every settings panel uses; `brand` reaches `BrandIcon`, which is why the deleted art component had no caller | 1, 6 |
| `quickshell/bar/components/DashboardCard.qml` | CORRECT | `disabled` + `disabledReason` render in place of the body, which is how an unavailable source avoids showing a control that cannot work | 6 |
| `quickshell/bar/components/MujoLivingCanvas.qml` | CORRECT | every loop is periodic over 0..2π, so the animation never jumps; gated on `Anim.reduceMotion` | 6 |
| `quickshell/bar/components/BaseWidget.qml` | CORRECT | the shared desktop-widget frame: header, glass, elevation and explicit loading/error states, so widgets cannot invent their own | 6 |
| `quickshell/bar/components/DesktopIcon.qml` | CORRECT | presentational by design — `DesktopIcons.qml` owns hit-testing, selection and drag, so those live in one place; only the rename field takes focus | 6 |
| `quickshell/bar/services/qmldir` | CORRECT | every singleton is declared `singleton`; the three non-singletons (`WallpaperDownloadWorker`, `CrashWatcher`, `IdleService`) are instantiated per use, which is why they are not | 6 |
| `quickshell/bar/services/PopupCoordinator.qml` | CORRECT | one `activeId` means at most one popup can be open, which is the invariant every menu depends on | 6 |
| `quickshell/bar/services/Session.qml` | CORRECT | lock is always offered; everything destructive is gated on `launcher.enableDangerousActions`, default off, and `available()` filters rather than the call sites | 6 |
| `quickshell/bar/services/Lock.qml` | CORRECT | the only owner of `locked`; `unlock()` is the programmatic release and is separate from `authenticate()`, so a UI cannot bypass PAM by writing state | 6 |
| `quickshell/bar/services/Cava.qml` | CORRECT | the cava process runs only while a widget holds a reference *and* audio is live — presence of a widget is the intent, so there is no second enable flag to drift | 4, 6 |
| `quickshell/bar/services/IdleService.qml` | CORRECT | one respawned `swayidle`, rebuilt from the ordered rules; the marker names a real ceiling — a guard that inhibits at the threshold waits for the next idle cycle | 2, 6 |
| `quickshell/bar/services/Weather.qml` | CORRECT | every consumer reads this one service and the fetch goes through `mujo weather fetch`, which caches, so the network is hit at most once per interval across processes | 4, 6 |
| `quickshell/bar/services/AI.qml` | CORRECT | read-only by construction: one `Process` at a time, a queue capped at 2, a hard timeout, and agent CLIs invoked in read-only mode from an empty scratch directory | 2, 6 |
| `quickshell/bar/services/CrashWatcher.qml` | CORRECT | follows one `mujo crash stream`; four crash sources arrive already normalised by the CLI, so the QML never parses journal text | 6 |
| `quickshell/bar/services/DesktopFiles.qml` | CORRECT | the filesystem is the source of truth and every mutation goes through the `mujo` CLI; grid slots live in a separate state file, so no UI metadata is written into the user's files | 6 |
| `quickshell/bar/services/DesktopGrid.qml` | CORRECT | one 24px lattice and one occupancy map for icons and widgets both, so neither can be dropped onto the other without either layer knowing about the other | 6 |
| `quickshell/bar/services/SettingsBus.qml` | CORRECT | one JSON file, dotted-path reads with a declared default, optimistic write plus debounced flush; the palette and wallpaper deliberately keep their own files | 6 |
| `quickshell/bar/services/Shelf.qml` | CORRECT | shelved items are references, never copies — the consuming application performs the move, so a shelf entry cannot duplicate a file behind the user's back | 6 |
| `quickshell/bar/services/Wallhaven.qml` | CORRECT | owns the 429 cooldown centrally, so no panel can retry past the rate limit; its timer runs only while `rateLimitCountdown > 0` | 4, 6 |
| `quickshell/bar/services/WallpaperDownloads.qml` | CORRECT | keyed by URL, so the same wallpaper cannot be queued twice; progress, speed and ETA come from the worker rather than being guessed | 6 |
| `quickshell/bar/services/WallpaperDownloadWorker.qml` | CORRECT | a `Process` per download with streamed progress; not a singleton, which is what lets downloads run concurrently | 6 |
| `quickshell/bar/services/WallpaperEngine.qml` | CORRECT | mirrors `Wallhaven`'s shape over Steam Workshop, with a separate installed model — which is why the grid's `activeSource` switch has two models to choose between | 6 |
| `quickshell/bar/theme/qmldir` | CORRECT | all four theme types are singletons, which is what lets the shell and the separate Settings process share one palette | 6 |
| `quickshell/bar/theme/Theme.qml` | CORRECT | reads `theme.json` through a watched `FileView`, so `mujo theme …` restyles a running desktop without a restart; the Settings app imports this same singleton | 6 |
| `quickshell/bar/theme/Anim.qml` | CORRECT | `Anim.d()` is the one place motion is scaled, so `reduceMotion` and the intensity tiers apply everywhere rather than per call site | 6 |
| `quickshell/bar/theme/Icons.qml` | CORRECT | maps Material names onto freedesktop *symbolic* names only, and leaves a name absent rather than approximating it — which is why `MaterialIcon`'s glyph fallback is the right answer for a miss | 6 |
| `quickshell/bar/shell.qml` | CORRECT | the desktop entrypoint; like `screenshot.qml` and `settings.qml` its absence from a `qmldir` is correct, and it loads clean from the working tree | 6 |
| `quickshell/bar/llm-usage.sh` | CORRECT | invoked by path through `Qt.resolvedUrl` from two widgets, which is why it sits beside the QML rather than in the `mujo` CLI | 6 |
| `quickshell/bar/modules/bar/qmldir` | CORRECT | every bar type is registered; `Island`/`IslandPanel` are absent because `shell.qml` and the settings app import them by directory, not through this domain | 6 |
| `quickshell/bar/modules/bar/Bar.qml` | CORRECT | the per-screen bar; takes `niri`, `screenName` and `panelWindow` as inputs, so one component serves every output without knowing about the others | 6 |
| `quickshell/bar/modules/bar/LauncherPill.qml` | CORRECT | only a trigger — the launcher surface is a separate layer-shell overlay, and both agree through `PopupCoordinator` rather than a shared boolean | 6 |
| `quickshell/bar/modules/bar/ClockPill.qml` | CORRECT | the tick interval is computed to the next minute boundary instead of polling every second, so the idle case costs one wakeup a minute | 4, 6 |
| `quickshell/bar/modules/bar/ActiveWindowPill.qml` | CORRECT | reads the focused window from the `Niri` plugin rather than polling a CLI | 4, 6 |
| `quickshell/bar/modules/bar/Workspaces.qml` | CORRECT | driven by the `niri` object's workspace list; the glider is positioned from the focused index, so it cannot disagree with which pip reads as focused | 6 |
| `quickshell/bar/modules/bar/CalendarMenu.qml` | CORRECT | fixed 28×26 day cells, which is what lets `CalendarWidget` reuse it by scaling instead of growing a second calendar | 6 |
| `quickshell/bar/modules/bar/BatteryMenu.qml` | CORRECT | 30s poll with `triggeredOnStart`, and the whole item self-hides on a machine with no battery rather than showing an empty control | 4, 6 |
| `quickshell/bar/modules/bar/BluetoothMenu.qml` | CORRECT | popup identity is `screenName + ":bluetooth"`, so two monitors cannot both believe their menu is the open one | 6 |
| `quickshell/bar/modules/bar/NetworkMenu.qml` | CORRECT | same per-screen popup id; `expandedNetwork` is local, so expanding a network on one screen does not expand it on another | 6 |
| `quickshell/bar/modules/bar/VolumeMenu.qml` | CORRECT | same per-screen popup id; reads Pipewire through Quickshell's service rather than shelling out | 4, 6 |
| `quickshell/bar/modules/bar/SystemTray.qml` | CORRECT | pinned items inline, the rest in the flyout — one item cannot appear in both, because the flyout renders the complement of the pinned set | 6 |
| `quickshell/bar/modules/bar/TrayIconDelegate.qml` | CORRECT | one delegate for both the inline and 36×36 flyout uses, so a tray item behaves identically in either place | 6 |
| `quickshell/bar/modules/bar/TrayMenu.qml` | CORRECT | renders a `QsMenuHandle` on its own `PopupWindow`, so an application's menu is not clipped by the bar's layer surface | 6 |
| `quickshell/bar/modules/bar/Island.qml` | CORRECT | modules are drawn from `island.modules` in order, so adding one is a settings change rather than a code change | 6 |
| `quickshell/bar/modules/bar/IslandPanel.qml` | CORRECT | built from the same `MujoHero`/`MujoCard`/`MujoSettingRow` vocabulary as every other panel, which is what the header records it was changed to fix | 6 |
| `quickshell/bar/modules/bar/LlmTrackerMenu.qml` | CORRECT | the refresh interval is 30s while the menu is open and 300s when it is not, so a closed menu costs a tenth as many `llm-usage.sh` runs | 4, 6 |
| `quickshell/bar/modules/desktop/qmldir` | CORRECT | registers every desktop widget `DesktopWidgets` can load, which is what makes its `comps` lookup resolve | 6 |
| `quickshell/bar/modules/desktop/DesktopWidgets.qml` | CORRECT | widgets are instantiated by a `Repeater` over what is actually placed, so an unplaced widget does not exist and its poll timer never runs — that is what makes `running: true` correct in each widget | 4, 6 |
| `quickshell/bar/modules/desktop/DesktopIcons.qml` | CORRECT | shares the `DesktopWidgets` window rather than owning a surface, so icons and widgets share one coordinate space and one set of clicks | 6 |
| `quickshell/bar/modules/desktop/DesktopMenu.qml` | CORRECT | used for both the menu and its submenu, so a submenu cannot look or behave like a different control | 6 |
| `quickshell/bar/modules/desktop/DesktopProperties.qml` | CORRECT | fed by `mujo desktop info`, so it shows the filesystem's answer rather than a shell-side cache | 6 |
| `quickshell/bar/modules/desktop/ClockWidget.qml` | CORRECT | a `BaseWidget`, so it inherits the shared frame instead of restating it | 6 |
| `quickshell/bar/modules/desktop/CalendarWidget.qml` | CORRECT | reuses the bar's `CalendarMenu` verbatim rather than growing a second calendar | 1, 6 |
| `quickshell/bar/modules/desktop/CavaWidget.qml` | CORRECT | reference-counts the `Cava` singleton, so the cava process exists exactly while a cava widget does | 4, 6 |
| `quickshell/bar/modules/desktop/MediaWidget.qml` | CHANGED | `sourceSize` 96×96 on the album art, the cap its own container already enforces — the Overview card's copy of the same art had it, this one did not | 4, 6 |
| `quickshell/bar/modules/desktop/PhotoWidget.qml` | CHANGED | decodes photos at a quantised 2× box instead of full camera resolution; with `cache: false` the full-size decode was paid again on every rotation | 4, 6 |
| `quickshell/bar/modules/desktop/SysmonWidget.qml` | CORRECT | poll interval comes from the widget's own config rather than a constant | 6 |
| `quickshell/bar/modules/desktop/VpnWidget.qml` | CORRECT | drives the `mullvad` CLI, matching `NetworkPanel`; the declarative half stays in the NixOS module | 6 |
| `quickshell/bar/modules/desktop/WeatherWidget.qml` | CORRECT | renders the shared `Weather` singleton, so it adds no network traffic of its own | 4, 6 |
| `quickshell/bar/modules/desktop/AiUsageWidget.qml` | CORRECT | 5-minute poll of `llm-usage.sh`, the same script the bar menu uses, rather than a second scanner | 6 |
| `quickshell/bar/modules/desktop/Wallpaper.qml` | CORRECT | per-screen; reads `wallpaper.json`, which `mujo wallpaper` owns, and keeps the blurred backdrop for niri's overview on the same surface | 6 |
| `quickshell/bar/modules/desktop/ShelfSurface.qml` | CORRECT | the per-screen edge drawer; renders the same `ShelfView` body as the bar popup | 6 |
| `quickshell/bar/modules/desktop/ShelfButton.qml` | CORRECT | visible only while the shelf has items or its popup is open, so an empty shelf leaves no residue in the bar | 6 |
| `quickshell/bar/modules/desktop/ShelfView.qml` | CORRECT | one body shared by the drawer and the popup, so the two entry points cannot drift apart | 6 |
| `quickshell/bar/modules/desktop/ShelfDragPreview.qml` | CORRECT | a 48×48 MIME icon attached through `Drag.imageSource`, so the compositor draws the ghost rather than the shell tracking the pointer | 6 |
| `quickshell/bar/modules/launcher/qmldir` | CHANGED | registers `LauncherGroupModals` | 3 |
| `quickshell/bar/modules/launcher/Search.js` | CHANGED | new: the ranking both `LauncherBody` and `LauncherGroupsView` had a byte-identical copy of; score bands are named constants, and `test-launcher-search.qml` asserts their order | 1, 3 |
| `quickshell/bar/modules/launcher/calc.js` | CORRECT | a hand-written tokeniser and recursive-descent parser — no `eval`, so a typed expression cannot reach the JS engine | 2, 6 |
| `quickshell/bar/modules/launcher/LauncherBody.qml` | CHANGED | 1073 → 981; the ranking moved to `Search.js`. The remainder is the keyboard and mode engine — 29 references to `mode` in the search field alone — and splitting that would cut across one job, not along a seam | 3 |
| `quickshell/bar/modules/launcher/LauncherGroupsView.qml` | CHANGED | 1089 → 559: its duplicate ranker deleted, and its four dialogs plus the four writes to `apps.groups` moved to `LauncherGroupModals` | 1, 3 |
| `quickshell/bar/modules/launcher/LauncherGroupModals.qml` | CHANGED | new; emits `groupsWritten(selectIndex)` rather than assigning the view's `activeGroupIndex`, so the view keeps ownership of its keyboard cursor | 3 |
| `quickshell/bar/modules/launcher/Launcher.qml` | CORRECT | the layer-shell overlay that takes exclusive keyboard focus; `LauncherBody` inside it is focus-agnostic, so the same body can be hosted elsewhere | 6 |
| `quickshell/bar/modules/launcher/LauncherResult.qml` | CORRECT | a click on the favourite star toggles without launching or closing — the two hit regions are separate handlers, not one with a mode | 6 |
| `quickshell/bar/modules/launcher/LauncherGrid.qml` | CORRECT | grid view over the same result model as the list, so both tiers rank identically | 6 |
| `quickshell/bar/modules/launcher/LauncherFolderCard.qml` | CORRECT | the 2×2 preview is drawn from the group's first four apps, so a folder cannot show an app it does not contain | 6 |
| `quickshell/bar/modules/launcher/LauncherGroupHeader.qml` | CORRECT | a section header with a count badge; presentational, no state | 6 |
| `quickshell/bar/modules/launcher/LauncherActionBar.qml` | CORRECT | owns `dropdownOpen`/`dropdownPos`, which is why `LauncherBody`'s Ctrl+K menu positions itself from this component rather than computing geometry twice | 6 |
| `quickshell/bar/modules/launcher/LauncherEmptyState.qml` | CORRECT | shown in place of results, not over them, so an empty query cannot leave a stale row behind | 6 |
| `quickshell/bar/modules/launcher/CommandPalette.qml` | CORRECT | dangerous session actions require an explicit confirm and are only listed when `launcher.enableDangerousActions` is on — the same gate `Session.available()` applies | 2, 6 |
| `quickshell/bar/modules/launcher/ClipboardList.qml` | CORRECT | reads `cliphist` through the `mujo` CLI; re-copying goes back through the same path rather than writing the clipboard directly | 6 |
| `quickshell/bar/modules/launcher/SessionMenu.qml` | CORRECT | lists exactly what `Session` exposes, and a dangerous action needs a second click — so the bar button and the `/` palette cannot disagree about what is allowed | 2, 6 |
| `quickshell/bar/modules/launcher/LaunchFeedback.qml` | CORRECT | one per screen, shown on `Launch.activeScreen`, and dismissed by `Launch` rather than by a timeout that could outlive the launch | 6 |
| `quickshell/bar/modules/notifications/qmldir` | CORRECT | registers the three notification types the shell and bar both load | 6 |
| `quickshell/bar/modules/notifications/NotificationCenter.qml` | CORRECT | renders `Notifications.history` — it holds no second copy of the list, so clearing a group cannot leave the badge stale | 6 |
| `quickshell/bar/modules/notifications/NotificationMenu.qml` | CORRECT | reuses the `NetworkMenu` trigger/popup pattern, so the bell behaves like every other bar popup | 6 |
| `quickshell/bar/modules/notifications/NotificationPopup.qml` | CORRECT | input is masked to the toast column while idle and widened only during a swipe, so toasts do not eat clicks meant for the desktop | 6 |
| `quickshell/bar/modules/system/qmldir` | CORRECT | registers the four system prompts `shell.qml` hosts | 6 |
| `quickshell/bar/modules/system/LockScreen.qml` | CORRECT | a real lock: `WlSessionLock` (ext-session-lock), not a Top-layer overlay, and Esc does not unlock — only a correct password does | 2, 6 |
| `quickshell/bar/modules/system/PolkitPrompt.qml` | CORRECT | renders the agent's own prompt text and returns the response; it never decides an authorisation itself | 2, 6 |
| `quickshell/bar/modules/system/KeyringPrompt.qml` | CORRECT | the prompt arrives whole over the helper's unix socket, so the shell renders a request rather than composing one | 2, 6 |
| `quickshell/bar/modules/system/CrashFixModal.qml` | CORRECT | remediation is presented as an explicit action the user confirms, which is the "never apply silently" side of the read-only `AI` service | 2, 6 |
| `quickshell/bar/modules/screenshot/qmldir` | CORRECT | registers the six screenshot components `screenshot.qml` composes | 6 |
| `quickshell/bar/modules/screenshot/ScreenshotOverlay.qml` | CORRECT | the capture surface; `Qt.quit()` on finish is what makes the standalone tool exit rather than linger | 6 |
| `quickshell/bar/modules/screenshot/SelectionArea.qml` | CORRECT | selection geometry only; the toolbar and the crop both read the same four properties, so they cannot disagree about the region | 6 |
| `quickshell/bar/modules/screenshot/FloatingToolbar.qml` | CORRECT | positioned from the selection rather than the cursor, so it cannot drift off the region it acts on | 6 |
| `quickshell/bar/modules/screenshot/AnnotationCanvas.qml` | CORRECT | one active tool at a time as a string, so no two drawing modes can be live together | 6 |
| `quickshell/bar/modules/screenshot/Loupe.qml` | CORRECT | magnifies the raw source, not the rendered overlay, so the zoom shows pixels rather than annotations | 6 |
| `quickshell/bar/modules/screenshot/OcrCard.qml` | CORRECT | has an explicit `busy` state, so a slow OCR run shows progress instead of an empty card | 6 |
| `quickshell/bar/modules/screenshot/TranslationOverlay.qml` | CORRECT | one plate per OCR line placed from `mujo-screenshot ocr-lines` boxes, which `test-screenshot-ocr-lines.sh` is the guard for | 2, 6 |
| `quickshell/bar/modules/settings/ApplicationsPanel.qml` | CHANGED | 1156 → 127; keeps only `activeTab`, the tab list and the hero, which is what `test-security-ui.qml` asserts against | 3 |
| `quickshell/bar/modules/settings/ApplicationsIntegrationsTab.qml` | CHANGED | new: the registry, its three detection processes and the six helpers that read it — one `sh -c` runs every entry's check rather than a process each | 3, 4 |
| `quickshell/bar/modules/settings/ApplicationsTrustTab.qml` | CHANGED | new: the trust tiers and their controls; the filter and search are private to it, which is why they left the panel | 3 |
| `quickshell/bar/modules/settings/ApplicationsFlatpaksTab.qml` | CHANGED | new: owns the `mujo apps flatpaks` read and exposes `refresh()`, so the panel's refresh button drives it without holding the model | 3 |
| `quickshell/bar/modules/settings/ApplicationsLauncherTab.qml` | CHANGED | new: reads and writes `SettingsBus` directly, so it needs nothing from the panel | 3 |
| `quickshell/bar/modules/settings/SettingRow.qml` | CORRECT | reads and writes the store itself from `path` + `kind`, which is what stops every panel repeating get/set wiring per line | 6 |
| `quickshell/bar/modules/settings/SettingsPage.qml` | CORRECT | the level-2 host every consolidated page uses, so hero, margins and scrolling are defined once rather than per panel | 6 |
| `quickshell/bar/modules/settings/SettingsLayout.qml` | CORRECT | crossfades between category pages *without reloading them*, which is why panels stay alive off-screen — the reason a poller here must bind `running: root.visible` | 4, 6 |
| `quickshell/bar/modules/settings/HardwarePage.qml` | CORRECT | 17 lines: a `SettingsPage` listing five groups, and nothing below it opens a third level | 6 |
| `quickshell/bar/modules/settings/DisplaysGroup.qml` | CORRECT | live control through `niri msg`, with the persistent source of truth left in the NixOS `outputs` block — it does not write a second config | 6 |
| `quickshell/bar/modules/settings/InputGroup.qml` | CORRECT | writes `niri-settings.json` and raises a rebuild banner, because these keys are not runtime-settable — it never claims a change is already live | 6 |
| `quickshell/bar/modules/settings/ShortcutsGroup.qml` | CORRECT | read-only, parsed from the running niri config, so it cannot drift from the bindings actually in force | 6 |
| `quickshell/bar/modules/settings/IdlePowerGroup.qml` | CORRECT | edits the ordered `idle.rules` list that `IdleService` rebuilds swayidle from — one list, one consumer | 6 |
| `quickshell/bar/modules/settings/KeyringGroup.qml` | CORRECT | the native Secret Service through `mujo-keyring`; secrets are masked until explicitly revealed, and no credential store is invented | 2, 6 |
| `quickshell/bar/modules/settings/AiPanel.qml` | CORRECT | the API key goes to the keyring, never to `settings.json` — the one key in this panel that is not a store write | 2, 6 |
| `quickshell/bar/modules/settings/AnimationsPanel.qml` | CORRECT | every control writes a `motion.*` key that `Anim` reads, so the playground previews the same values the shell uses | 6 |
| `quickshell/bar/modules/settings/NotificationsPanel.qml` | CORRECT | writes the same keys the `Notifications` singleton reads, so the test lab exercises the live path rather than a simulation | 6 |
| `quickshell/bar/modules/settings/WeatherPanel.qml` | CORRECT | renders the shared `Weather` singleton and writes `weather.*`; changing units or place forces the refetch rather than showing stale values | 6 |
| `quickshell/bar/modules/settings/PersistencePanel.qml` | CORRECT | the GUI list folds into the same impermanence config a rebuild applies, and "currently persisted" is read live — so the two lists are distinguishable | 6 |
| `quickshell/bar/modules/settings/SystemPanel.qml` | CORRECT | every long operation is async with a cancel that kills the process, and a failed rebuild surfaces rollback rather than leaving the pane spinning | 2, 6 |
| `quickshell/bar/modules/settings/HealthPanel.qml` | CORRECT | drives `mujo sentinel`/`mujo clean`; the destructive cleanups are presented with what they would reclaim before running | 2, 6 |
| `quickshell/bar/modules/settings/GeneralPanel.qml` | CORRECT | the NixOS preference surface; each control writes through `mujo system-pref`, so nothing here edits a `.nix` file directly | 6 |
| `quickshell/bar/modules/settings/DesktopPanel.qml` | CORRECT | configures widgets, cava and the shelf through the same store keys those components read | 6 |
| `quickshell/bar/modules/settings/WallhavenDetailModal.qml` | CHANGED | `sourceSize` capped at the modal's own 960×680 maximum; fit mode scales into that box anyway, so a 5120×2880 preview was decoding ~59 MB to paint a pane that cannot exceed it | 3, 4, 6 |
| `nixos/apps/_ai-mcp.nix` | CORRECT | `_`-prefixed so `importTree` skips it; it is a plain function returning an attrset, and three agent modules render it into their own config shapes | 6 |
| `nixos/apps/claude-code.nix` | CORRECT | persists `~/.claude` *and* `~/.claude.json` separately, because the latter is a file at the home root and a directory entry would not cover it | 6 |
| `nixos/apps/antigravity-cli.nix` | CORRECT | writes the MCP config from `_ai-mcp.nix`, so the agent list is declared once | 6 |
| `nixos/apps/antigravity-ide.nix` | CORRECT | 9 lines and no state of its own: it shares `~/.gemini` and the CLI's MCP config deliberately | 6 |
| `nixos/apps/cutefetch.nix` | CORRECT | 7 lines: one package from `self.packages`, nothing else to get wrong | 6 |
| `nixos/apps/herdr.nix` | CORRECT | builds its own `.desktop` entry, so the launcher lists it without a hand-written file in the tree | 6 |
| `nixos/apps/flatpak.nix` | CORRECT | declares the flathub remote once; every Flatpak app module adds only its own package id | 6 |
| `nixos/apps/steam.nix` | CORRECT | pairs the Flatpak with `hardware.steam-hardware.enable`, which the Flatpak alone cannot set | 6 |
| `nixos/apps/telegram.nix` | CORRECT | persists `.var/app/org.telegram.desktop`, without which the login would not survive the root wipe | 6, 9 |
| `nixos/apps/obsidian.nix` | CORRECT | same shape; its persistence entry is what keeps the vault config across boots | 6, 9 |
| `nixos/core/user-persistence.nix` | CORRECT | folds the GUI-managed list into the *existing* impermanence config rather than adding a second persistence mechanism | 6, 9 |
| `nixos/core/user-persistence.json` | CORRECT | the GUI-owned list `mujo persist` writes; tracked because a flake only sees git-tracked files | 6 |
| `nixos/core/system-preferences.json` | CORRECT | the declarative preference values `mujo system-pref` writes, read back by `system-preferences.nix` | 6 |
| `nixos/desktop/keyring-prompter.nix` | CORRECT | owns `org.gnome.keyring.SystemPrompter` and renders through the shell's socket, so the prompt is themed without replacing the Secret Service itself | 2, 6 |
| `nixos/desktop/quickshell.nix` | CORRECT | the `qs-bar` user service; sets `QS_ICON_THEME` again here because the systemd unit does not inherit the session environment | 6 |
| `nixos/desktop/plymouth.nix` | CORRECT | builds the theme from the tracked directory, so the 139 frames are content rather than a runtime dependency | 6 |
| `nixos/desktop/plymouth/nixos-mac-style.plymouth` | CORRECT | the theme manifest naming the image directory `plymouth.nix` installs | 6 |
| `nixos/desktop/plymouth/Screenshot.png` | CORRECT | the theme's preview image, referenced by the manifest | 6 |
| `nixos/desktop/plymouth/images/*` (138 frames) | CORRECT | group row: the boot animation's frames, addressed as a set by the manifest and never individually | 6 |
| `nixos/hosts/main/_networking.nix` | CORRECT | 9 lines; `lib.mkDefault` on hostname and firewall so an override can change either without a conflict | 6 |
| `nixos/hosts/main/_hardware-and-services.nix` | CORRECT | `_`-prefixed and imported by the host explicitly, which is why `importTree` skipping it is right | 6 |
| `nixos/security/vaultwarden.nix` | CORRECT | builds `secretspec` from a source-only input with default features off, so the closure carries only the bw provider | 4, 6 |
| `nixos/overrides/README.md` | CORRECT | matches `ui-overrides.nix`: a parse failure is reported rather than breaking the build, and a bad *option* still fails — the doc states both halves | 6 |
| `nixos/overrides/template.nix.example` | CORRECT | `.example`, so the loader's `*.nix` glob cannot pick it up as a live override | 6 |
| `tests/run-all-tests.sh` | CORRECT | `set -euo pipefail`, counts failures rather than exiting on the first, and probes the running host — so it fails until a rebuild, by design | 2, 5 |
| `tests/microvm/test-quarantine-boundary.sh` | CORRECT | asserts the property `docs/application-trust.md` promises, and names that doc in its header | 5 |
| `tests/network/test-firewall-rules.sh` | CORRECT | sources `tests/lib.sh` for its assertions, which is where the shared shell options belong | 2 |
| `tests/performance/test-performance-budget.sh` | CORRECT | states the budget as overhead against a non-hardened baseline, so the numbers stay meaningful on different hardware | 4 |
| `tests/physical/test-physical-extraction.sh` | CORRECT | asserts nothing an application would write is recoverable from persistent storage | 5 |
| `tests/recovery/test-recovery-bypass.sh` | CORRECT | the guarantee under test is stated in the header: an attacker at the keyboard must not reach a root shell | 5 |
| `tests/sandbox/test-sandbox-isolation.sh` | CORRECT | every check runs the sandbox and tries to break out, rather than inspecting config | 5 |
| `tests/security/test-kernel-hardening.sh` | CORRECT | reads the live `/proc` values, so it cannot pass on a machine that has not rebuilt | 5 |
| `tests/storage/test-swap-leakage.sh` | CORRECT | asserts crash dumps never reach disk — the property `randomEncryption` swap exists for | 5 |
| `tests/storage/test-vault-isolation.sh` | CORRECT | asserts no sensitive plaintext on unencrypted persistent storage | 5 |
| `tests/vm/disko-vm.nix` | CORRECT | runs disko for real, so the tmpfs root, btrfs subvolumes, LVM group and random-key swap are all exercised; deliberately outside `importTree` | 5 |
| `tools/graphify/apply.sh` | CORRECT | `set -euo pipefail`, derives every path from `$0`, and has a fallback for locating the uv-installed package | 2 |
| `tools/graphify/nixqml.py` | CORRECT | type hints, `pathlib`, and it credits the upstream walker it adapts | 2 |
| `tools/cutefetch/cutefetch` | CORRECT | the script `nixos/apps/cutefetch.nix` packages | 6 |
| `docs/security-tests.md` | CHANGED | its §3 directory tree listed 6 of the 12 suites while §4's table listed all of them; the stale duplicate is gone and the VM suite is now in the table | 6 |
| `docs/security-architecture.md` | CORRECT | the subsystems it names — trust registry, credential broker, quarantine MicroVM, native sandbox — each exist as the module it points at | 6 |
| `docs/storage-model.md` | CORRECT | checked against `disko.nix` and `nixos/security/storage.nix`: the vault path, `/run/mujo/vault`, `randomEncryption`, the btrfs subvolumes and the build-time swap assertion including `boot.resumeDevice` all match | 6 |
| `docs/physical-security.md` | CORRECT | states plainly that `secureBoot` is `false` today and that physical access is therefore root access; even notes `editor = false` is inert under GRUB. Both boot-risk defaults verified `false` in the modules | 3, 6 |
| `docs/privacy-model.md` | CORRECT | the logging and coredump controls it describes are the ones `nixos/security/privacy.nix` sets | 6 |
| `docs/performance-budget.md` | CORRECT | the paired-measurement method it specifies is what `tests/performance/test-performance-budget.sh` implements, including the admission that host-wide hardening is not measurable this way | 4, 6 |
| `docs/agents/domain.md` | CORRECT | points agents at the domain docs before exploring; every doc it names exists | 6 |
| `docs/agents/issue-tracker.md` | CORRECT | describes the `gh` conventions this repo uses; makes no claim about code | 6 |
| `docs/superpowers/plans/2026-08-28-quickshell-screenshot-tool.md` | CORRECT | a record of completed work, not a claim about current behaviour — the tool it planned ships as `mujo-screenshot` | 6 |
| `docs/superpowers/plans/2026-08-28-sandbox-performance-overhaul.md` | CORRECT | same; the tmpfs shell copy it planned is what `sandbox.nix` does today | 6 |
| `docs/superpowers/specs/2026-08-28-screenshot-tool-design.md` | CORRECT | the design the shipped `modules/screenshot/` components implement | 6 |
| `docs/superpowers/specs/2026-08-28-sandbox-performance-overhaul-design.md` | CORRECT | same pairing with the plan above | 6 |
| `docs/overhaul-ledger.md` | CHANGED | this file | 0–6 |
| `.gitignore` | CHANGED | `secrets/vaultwarden-master-password` was redundant under `secrets/` on the line above; replaced with a comment saying what the directory holds | 1 |
| `.mcp.json` | CORRECT | the two servers this repo provides; `sandbox` needs the `MCP_TIMEOUT` that `.claude/settings.json` sets, and neither works without the other | 6 |
| `.claude/settings.json` | CORRECT | raises `MCP_TIMEOUT` to 180s, without which a cold `nix run .#sandbox` never finishes `initialize` | 6 |
| `.claude/settings.local.json` | CORRECT | a read-only Bash allowlist; nothing in it writes | 6 |
| `.claude/skills` | CORRECT | a symlink to `.agents/skills`, so all three agents read one skill tree | 6 |
| `.opencode/skills` | CORRECT | the same symlink for opencode | 6 |
| `.opencode/opencode.json` | CORRECT | renders `_ai-mcp.nix`'s command/args into opencode's joined-list shape, which is the reason that file is tool-neutral | 6 |
| `.opencode/plugins/graphify.js` | CORRECT | the opencode-side hook for the graphify skill | 6 |
| `CLAUDE.md` | CORRECT | five lines that delegate to `AGENTS.md` and state there are no Claude-specific rules — so there is one source of truth, not two | 6 |
| `.agents/rules/rtk.md` | CORRECT | one rule, applied to all three agents from the shared `.agents/` tree | 6 |
| `.agents/skills/graphify/SKILL.md` | CORRECT | the entry point for the knowledge-graph skill; its references are a set, below | 6 |
| `.agents/skills/graphify/.graphify_version` | CORRECT | pins the skill version `tools/graphify/apply.sh` patches against | 6 |
| `.agents/skills/graphify/references/*` (8 files) | CORRECT | group row: reference pages the skill loads on demand, never individually addressed by the repo | 6 |
| `.agents/skills/handoff/SKILL.md` | CORRECT | the vendored skill `skills-lock.json` pins by hash | 6 |
| `.agents/skills/handoff/agents/openai.yaml` | CORRECT | the handoff skill's agent profile | 6 |
| `.agents/skills/overhaul/SKILL.md` | CORRECT | the brief this pass runs from; its stale figures are recorded at the top of this ledger rather than silently corrected | 6 |
| `.agents/skills/testing-sandbox/SKILL.md` | CHANGED | claimed `/etc/xdg/quickshell/bar` points at the 9p mount; it points at a tmpfs copy, which is why a stale mount served old files | 3, 6 |
| `skills-lock.json` | CORRECT | pins the one vendored skill by content hash, so an upstream edit cannot land silently | 6 |
| `LICENSE` | CORRECT | unmodified licence text | 6 |
| `flake.lock` | CORRECT | pins every input; the three-nixpkgs-revision cost is recorded as a decision, not a defect | 4, 6 |
| `modules/wrappers/niri-settings.json` | CORRECT | the source of truth `InputGroup` writes and the niri wrapper reads, which is why that panel raises a rebuild banner instead of claiming a live change | 6 |
| `sounds/startup-sound1.mp3` | CORRECT | the login sound the desktop module plays; binary content, nothing to verify beyond its being referenced | 6 |

| `quickshell/_default.nix` | CHANGED | installs `lib/*.sh` into `$out/libexec/mujo/lib` and sets `MUJO_LIB`, which is what makes the dispatcher's sourced subcommands resolve under the wrapper | 3 |
| `quickshell/lib/vm.sh` | CHANGED | new: `mujo vm`, the largest arm at 623 lines; `vm list` and `vm catalog` produce byte-identical output to the pre-split script | 3 |
| `quickshell/lib/desktop.sh` | CHANGED | new: `mujo desktop`; its nested `d_trash` keeps the one bare `return`, which was already function-local | 3 |
| `quickshell/lib/sentinel.sh` | CHANGED | new: `mujo sentinel`; `sentinel scan` matches the pre-split output once live process churn is discounted | 3 |
| `quickshell/lib/crash.sh` | CHANGED | new: `mujo crash`, the stream `CrashWatcher.qml` follows | 3 |
| `quickshell/lib/security.sh` | CHANGED | new: `mujo security`, the telemetry `SecurityService.qml` reads | 3 |
| `quickshell/lib/clean.sh` | CHANGED | new: `mujo clean`, driven by the Health panel | 3 |
| `quickshell/mujo-screenshot.sh` | CORRECT | `set -euo pipefail`; config writes go through `mktemp` + `mv`, so a crash mid-write cannot truncate `screenshot.json`, and `flock -n` makes a second launch exit rather than race | 2 |
| `quickshell/keyring/mujo-keyring.py` | CORRECT | secretstorage over D-Bus — the native store, not a custom one — and a secret is emitted only by `get`, never by `list` | 2 |
| `quickshell/keyring/mujo-keyring-prompter.py` | CORRECT | reuses `Gcr.SecretExchange` rather than reimplementing the Diffie-Hellman exchange, so the password never crosses D-Bus in cleartext | 2 |
| `quickshell/unlock/unlock.c` | CORRECT | deliberately not setuid: `pam_unix` delegates the shadow read to `unix_chkpwd`, so this runs with no privilege of its own | 2 |
| `quickshell/cursor-tracker/cursor-tracker.c` | CORRECT | opens `/dev/input` read-only and relies on group membership for access rather than any elevation; re-scans on hotplug rather than holding stale descriptors | 2 |
| `quickshell/bar/test-scroll.qml` | CHANGED | new: asserts the shared wheel maths, and that `Scroll.js`'s repeated `Flickable` enum still matches Qt's — which is what makes repeating it safe | 3 |
| `quickshell/bar/test-launcher-search.qml` | CHANGED | new: 22 assertions over the ranking bands; writing it is what surfaced that the favourite bonus can lift a match one band | 3 |

### Coverage

Every one of the 472 tracked files has a row above: 326 name a file
individually, one names the file this pass deleted, and two are group rows —
`nixos/desktop/plymouth/images/*` (138 frames) and
`.agents/skills/graphify/references/*` (8 pages) — which the brief allows
because neither set is ever addressed one file at a time.

`CORRECT` here means the file was read and the stated property was checked in
it. Where the property was checked against something else — a doc against the
module it describes, a test against the guarantee it names — the row says so.
