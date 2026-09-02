---
name: overhaul
description: Full-repo production pass on the mujō flake — delete, harden, restructure, optimize, and finish every file, with a per-file verdict ledger and verification gates. Trigger: /overhaul
argument-hint: "optional scope or phase, e.g. 'quickshell only' or 'phase 3'"
disable-model-invocation: true
---

# Overhaul

You are the **maintainer** of mujō, not a consultant reviewing someone else's
work. The repo is yours. Nothing in it is off-limits because a previous author
wrote it that way.

Read `AGENTS.md` and `quickshell/bar/AGENTS.md` before your first edit. They are
the source of truth for commands, module discovery, and the invariants below.

## Definition of done

A stranger opens any file in this repo and says *"this is production
software"*. Concretely: no dead code, no duplicated logic, no unexplained
constant, no file that needs a verbal footnote to justify its shape, no feature
that is half-wired, no doc that describes something the code no longer does.

## Non-negotiables

Violating any of these fails the task regardless of how good the rest is.

1. **Never apply.** No `nh os switch`, no `nixos-rebuild switch`, no
   `nixos-rebuild boot`. You verify by evaluation and in VMs. The user applies.
2. **Never touch credentials.** `/persist/passwd`, `hashedPasswordFile`,
   anything under `secrets/`, any vault or Vaultwarden item. Read-only. If a
   change would require rotating a credential, stop and say so instead.
3. **Boot-risk switches ship off.** `security.mujo.boot.secureBoot`,
   `security.mujo.devices.dmaProtection`, `systemd.enableEmergencyMode = false`,
   `SYSTEMD_SULOGIN_FORCE`, and any new early-boot kernel parameter
   (`amd_iommu=*`, `efi=disable_early_pci_dma`, initrd/device-init changes).
   Implement fully, document the runbook, default to `false`, say so in the
   report. `main` is the user's only machine — a failed boot costs them the
   machine, not a test.
4. **`git add` new files before any `nix` command.** The flake source is git;
   untracked files do not exist to the build.
5. **`--flake` takes an absolute path.** `.#main` resolves against `/root`
   under pkexec and fails.
6. **Never hardcode the username.** `config.preferences.user.name`.
7. **Never hardcode a color.** `self.theme.base00..base0F` in Nix,
   `Theme.*` in QML.
8. **The trust registry stays root-owned.** `/var/lib/mujo-trust/registry.json`
   decides where every app runs. Never "fix" a permission error by loosening it.
9. **New state must be persisted explicitly.** The btrfs root is wiped on boot.
   Any module that writes state declares its own `persistence.*` entry, or the
   feature silently dies on the next reboot.

## The rule against deference

These outputs are **banned**. If you write one, delete it and do the work:

- "this matches the existing repo style"
- "I would do this differently, but I'll keep it consistent"
- "left as-is for consistency with the rest of the codebase"
- "out of scope for this pass"
- "the original author probably intended…"
- "consider refactoring X" / "you may want to Y" — *you* are the one who does X

Existing style is evidence, not authority. Where the repo is consistently good,
match it because it is good and say which property makes it good. Where it is
consistently bad, fix it everywhere in one pass and update `AGENTS.md` to make
the new shape the rule.

**Every tracked file gets exactly one of three verdicts. There is no fourth.**

| Verdict | Requires |
|---|---|
| `CHANGED` | the diff, and one line on what it buys |
| `CORRECT` | one line naming the property that makes it correct — a claim about the code, never about the style |
| `DELETED` | what absorbed its responsibility |

`CORRECT` is a real verdict, not an escape hatch. "Pure function, total over its
input domain, single caller, covered by tests/trust/*" is a verdict. "Looks
fine" and "consistent with the rest" are not.

## The ledger

Maintain `docs/overhaul-ledger.md`: one row per tracked file — path, verdict,
one-line note, phase. It is the completion criterion; the pass is done when
every tracked file has a row and no row is blank.

Group-row exceptions (one row for the set, not per file):
`nixos/desktop/plymouth/images/*` (139 PNGs), `**/package-lock.json`,
`.agents/skills/graphify/references/*`.

Run `git ls-files | wc -l` at the start and put the number at the top of the
ledger. It is currently 447.

## Phases

Each phase ends at a **green gate**. Do not start phase N+1 until phase N's gate
is green. Commit at every gate — one commit per phase, message naming the phase.
Work on a branch, never on `main`'s working tree without saying so.

**Phase 0 — Baseline.** Record the starting state: `nix flake check` result,
`git ls-files | wc -l`, the 119 `TODO|FIXME|XXX|HACK|ponytail:` markers with
locations, `nix path-info -Sh .#nixosConfigurations.main.config.system.build.toplevel`
for closure size, and quickshell startup time. Every later claim of
"improved" is measured against these numbers. Write them into the ledger header.

Gate: `nix flake check` passes, or its failures are recorded as phase-2 work.

**Phase 1 — Delete.** The highest-value phase. Dead modules, options declared
and never read, `_`-prefixed fragments nobody imports, vendored packages now
upstream (check `modules/flake/perSystem.nix` against nixpkgs — `preload`,
`skeuos-gtk`, `quicksnip`), QML components not in any `qmldir`, duplicated
helpers, commented-out blocks, docs describing removed behaviour. Also: every
option with exactly one possible value in practice, and every abstraction with
one implementation.

Gate: `nix flake check` green, `qs -p ./quickshell/bar/shell.qml` starts clean,
line count strictly lower than phase 0.

**Phase 2 — Correctness and security.** Now the code that survives must be
right. Unhandled errors, missing input validation at trust boundaries (the
`mujo-trustd` socket, the credential broker, `nixos/sandbox/mcp.py`, the tray
relay), TOCTOU in anything touching `/persist`, shell scripts without `set
-euo pipefail`, unquoted expansions, Python without timeouts on subprocess,
QML bindings that can throw on undefined. Resolve every one of the 119 debt
markers: fix it, or delete it, or convert it into a tracked issue with a real
plan — never leave the bare marker.

Cross-check the code against `docs/threat-model.md`. Where the doc claims a
property the code does not enforce, one of the two is wrong; fix the code and
say so, or correct the doc and say so.

Gate: `nix flake check` green, `bash tests/vm/run.sh` passes,
`python3 nixos/apps/test-tray-relay.py` and
`python3 nixos/sandbox/test-lifetime.py` pass.

**Phase 3 — Structure.** Split what is too large to hold in one head:
`quickshell/mujo.sh` (3826 lines), `WallpaperPanel.qml` (2933),
`MujoPageHeroArt.qml` (1180), `ApplicationsPanel.qml` (1156),
`LauncherGroupsView.qml` / `LauncherBody.qml` (~1080 each). Split along
responsibility seams, not line counts — a 900-line file with one job stays.
Every new QML component goes in its domain's `qmldir` or it will not resolve.
Every new Nix module defines `flake.nixosModules.<name>` **and** is listed in
`nixos/hosts/main/configuration.nix`, or it evaluates and does nothing.

Remember QML cannot import across `..`; shared components live in one directory.

Gate: `nix flake check` green, `qs -p` clean, and the sandbox MCP
(`screenshot` after `reload`) shows the bar, launcher, and settings rendering
identically to phase 0 screenshots.

**Phase 4 — Performance.** Measure, change, measure. Closure size, evaluation
time (`nix flake check` wall clock), quickshell startup and idle CPU,
`tests/performance`. Target the known shapes: QML property bindings that
recompute on every frame, `Process` calls in a loop where one call would do,
images loaded at full resolution into small views, timers that poll where a
watcher exists, Nix `import`s inside `mkIf` branches.

**Never trade a feature or a visual for a number.** If an optimization costs
either, do not take it — record it in the report as a choice for the user.

Gate: every phase-0 metric equal or better, with the numbers in the report. No
visual diff in sandbox screenshots.

**Phase 5 — Finish what is promised.** Not new invention: the repo currently
ships features that are wired but inert, and that gap is the biggest thing
between it and "production".

- `apps.trust.launcherIntegration` is off; with it on, anything ungraduated
  boots a VM on first click. Make the graduation path good enough that turning
  it on is reasonable, then document the runbook — leave the default off.
- `security.mujo.broker.acl` is empty, so the credential broker denies nothing
  and the Phase-21 violation detector never fires. Ship a real default ACL.
- The `nixos/security/` tree is staged but unlanded. Land it, or delete it.
- Anything `docs/*.md` promises that the code does not do: build it, or cut the
  promise.

Net-new features only where a doc in `docs/` already commits to them. If you
believe something else is missing, put it in the report, do not build it.

Gate: everything from phase 2's gate, plus `bash tests/run-all-tests.sh`
reviewed — note which assertions require a rebuild to pass and say so, rather
than weakening the assertion. A check that cannot fail is not a check.

**Phase 6 — Docs and close.** `AGENTS.md` and `quickshell/bar/AGENTS.md` must
describe the repo as it now is, including any rule you changed in phase 1.
Every `docs/*.md` claim traceable to code. `README` that lets a stranger
understand the project in 60 seconds. Ledger complete.

Gate: every gate above, re-run once on the final tree.

## Standards by domain

**Nix.** Options get `type`, `default`, and a `description` that says why, not
what. Assertions for invariants that a wrong config would otherwise discover at
runtime (`security.mujo.storage.encryptedSwap` is the model). `lib.mkIf` over
conditional imports. No `with lib;`. Prefer an existing declared option over a
new toggle.

**QML.** Declarative bindings over imperative `on*Changed` assignment.
`required property` on component inputs. No magic numbers — spacing, radii, and
durations come from `Theme`. Colors from `Theme` only. Every component in its
`qmldir`.

**Shell.** `set -euo pipefail`, quoted expansions, `local` in functions,
`trap` for cleanup of anything created in `/tmp`. Long scripts get functions
with single responsibilities.

**Python.** Type hints on public functions, `subprocess` always with a timeout,
`pathlib` over string paths, explicit exception types. The existing self-check
scripts (`test-tray-relay.py`, `test-lifetime.py`) are the pattern — non-trivial
new logic leaves one runnable check behind, no framework.

**Tests.** `tests/lib.sh` holds the shared assertions; use them. Tests probe the
running system and therefore fail until the user rebuilds — that is intended,
do not "fix" it by weakening an assertion.

## Verification you are allowed to run

```bash
git add -A                                       # before any nix command
nix flake check                                  # evaluates, incl. checks.hostMain
nix flake show
bash tests/vm/run.sh                             # host config in a throwaway VM
bash tests/run-all-tests.sh                      # probes the RUNNING system
python3 nixos/apps/test-tray-relay.py
python3 nixos/sandbox/test-lifetime.py
qs -p ./quickshell/bar/shell.qml                 # then: qs kill -i <id>
nix run .#sandbox                                # MCP: reload -> screenshot
nix path-info -Sh .#nixosConfigurations.main.config.system.build.toplevel
```

Never `nh os switch` or `nixos-rebuild switch`.

Screenshots via the sandbox MCP are the only acceptable evidence for a visual
claim. "Should look the same" is not evidence.

## Reporting

Per phase, in the ledger, in this order and nothing else:

1. Gate output — the actual command output, pasted, not summarized.
2. Metrics table — phase-0 baseline vs now.
3. What was deleted, with line counts.
4. Decisions the user must make: boot-risk toggles left off, optimizations
   refused because they cost a feature, features not built because no doc
   promises them. Each one line, each actionable.

No design essays. No feature tours. If the explanation is longer than the diff,
the diff is wrong or the explanation is padding.

## Scope argument

If invoked with an argument, treat it as a scope restriction (`quickshell only`,
`phase 3`, `nixos/security`) — every rule above still applies, to the subset.
The ledger then covers only that subset and says so at the top.
