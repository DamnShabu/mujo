# Mujo Progressive Trust & Application Sandboxing

This document specifies application identity, progressive trust lifecycle states, capability profiles, and behavioral sandboxing in Mujo.

---

## 1. Application Identity Model

In Mujo, application identity is tied directly to Nix's cryptographic store derivations. Every application managed by the system has a cryptographically verifiable identity record:

```
Application Identity Record
├── id:                "org.mozilla.firefox"
├── name:              "Firefox"
├── version:           "135.0"
├── derivation:        "/nix/store/a1b2c3...-firefox-135.0.drv"
├── store_path:        "/nix/store/x9y8z7...-firefox-135.0"
├── content_hash:      "sha256-..."
├── install_timestamp: 1772390400
├── trust_state:       "QUARANTINE" | "OBSERVING" | "GRADUATED" | "REVOKED"
├── observation_time:  "0/72h"
├── risk_tier:         "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
└── capability_profile: {
      network: "ALLOW_INTERNET",
      gpu: "ACCELERATED",
      audio: "PULSE_PIPEWIRE",
      camera: "USER_PROMPT",
      microphone: "USER_PROMPT",
      filesystem: "ISOLATED_TMPFS",
      vault_access: "DENY",
      host_ipc: "DENY"
    }
```

---

## 2. Progressive Trust Lifecycle

Applications progress through distinct security stages governed by `mujo-trustd`:

```
   [ Application Installed or Updated ]
                     │
                     ▼
         ┌───────────────────────┐
         │      QUARANTINE       │  (MicroVM Domain: Ephemeral root, no host access)
         └───────────┬───────────┘
                     │
              72h Active Use
                     │
                     ▼
         ┌───────────────────────┐
         │       OBSERVING       │  (Behavioral audit: 0 anomalous security events)
         └───────────┬───────────┘
                     │
              Audit Approved
                     │
                     ▼
         ┌───────────────────────┐
         │       GRADUATED       │  (Native Sandbox: systemd cgroup, seccomp, Landlock)
         └───────────┬───────────┘
                     │
      [ Security Violation Detected ]
                     │
                     ▼
         ┌───────────────────────┐
         │    REVOKED / ROLLBACK │  (VM destroyed; revert to previous known-good hash)
         └───────────────────────┘
```

### Trust States Explained

1. **QUARANTINE**:
   - Initial state for all newly installed packages and major updates.
   - Executes inside a lightweight MicroVM (`microvm.nix` / KVM).
   - Zero access to host user files, persistent data, or vault.
   - Wayland and pipewire forwarding provide native window and audio integration.

2. **OBSERVING**:
   - Application has accumulated active runtime hours.
   - Monitored for boundary violations (unexpected IPC, unauthorized network calls, sensitive path traversal attempts).

3. **GRADUATED**:
   - Application earned promotion to run as a native host process for lower resource overhead.
   - Remains strictly constrained by Linux namespaces, systemd sandboxing (`ProtectSystem=strict`, `ProtectHome=tmpfs`), and seccomp filters.

4. **REVOKED / ROLLBACK**:
   - Triggered upon detection of malicious or anomalous activity.
   - Application instance is terminated, cache discarded, and previous known-good Nix generation restored.

---

## 3. Application Classification Tiers

| Tier | Example Applications | Graduation Policy |
|---|---|---|
| **LOW** | VLC, Evince, Calculator, Offline Viewers | Eligible for automatic graduation after 72h clean run. |
| **MEDIUM** | Firefox, Chromium, Discord, Slack, Spotify | Eligible for graduation to native sandboxing with strict network/portal restrictions. |
| **HIGH** | Compilers, IDEs (Antigravity, VSCode), Build Tools | Requires developer workspace sandbox; restricted vault access. |
| **CRITICAL** | Password Manager, Keyring Prompter, Disk/Firmware Tools | **NEVER** auto-graduates; runs with strict dedicated security profiles. |

---

## 4. Capability Profile Matrix

| Capability | Quarantine MicroVM | Graduated Native Sandbox | Critical Tool Domain |
|---|---|---|---|
| **Host Filesystem** | Denied (Ephemeral tmpfs) | Restricted Allowlist (`~/Downloads`) | Restricted Allowlist |
| **Encrypted Vault** | Strict Deny | Strict Deny (Mediated via Broker) | Mediated via SecretSpec |
| **Direct Hardware** | Emulated VirtIO | Filtered Host Devices | Minimal Host Devices |
| **Network Access** | Filtered Outbound | Filtered Outbound | Strict Deny / Local Only |
| **Camera / Mic** | Portal Consent Prompt | Portal Consent Prompt | Denied by default |
| **Host IPC / D-Bus** | Denied | Screened Portal Proxy | Minimal System D-Bus |

---

## 5. Updates & Atomic Rollback Protocol

When an application is updated (e.g. `nix flake update` or package update):
1. **Identity Calculation**: The new Nix store path hash is calculated.
2. **Re-Quarantine**: The updated package is immediately placed into `QUARANTINE` in a fresh MicroVM.
3. **Historic Fallback**: The prior graduated version remains cached in the Nix store.
4. **Behavioral Anomaly Response**: If the updated package triggers a security violation in quarantine:
   - Quarantine VM is killed.
   - Update is tagged `REVOKED`.
   - The user receives a notification: *"Application update isolated due to unexpected behavior. Previous stable version remains active."*

---

## 6. Quarantine Domain — As Implemented

Sections 1–5 describe the target. This section describes what
`nixos/apps/microvm.nix` actually builds today, so the gap between the two is
visible rather than assumed.

### Shape

```
        HOST (Niri session)                    GUEST (mujo-quarantine)
                                     
   mujo-quarantine-run <app>                   tmpfs /              ← nothing survives
            │                                  read-only /nix/store ← virtiofs, host's
            │  vsock 42:1024                   unprivileged user
            ├──────────── command line ──────▶ systemd socket → exec agent
            │                                            │
   waypipe client                                        │
   (user service) ◀───── vsock 2:6000 ─────────── waypipe server
            │                                            │
      Niri compositor                              the application
            │                                            │
   xdg-dbus-proxy ◀───── vsock 2:6001 ─────────── socat → $DBUS_SESSION_BUS_ADDRESS
   (user service)
            │
   host session bus
```

Three vsock ports cross the boundary and nothing else. There is no tap device,
no shared home, no `/persist`, and no vault path — not because they are
filtered, but because they are never handed to the guest.

The session bus is the exception, and it is filtered rather than absent. The
guest has no private bus of its own: its `DBUS_SESSION_BUS_ADDRESS` is a socat
listener forwarding to an `xdg-dbus-proxy` on the host, which denies everything
that is not named in its policy. What is named:

| Allowed | Why |
|---|---|
| `--call` on `org.freedesktop.Notifications` | Notifications, when `capabilities.notifications` is on. Replaces the one-way JSON bridge this used to have, so a quarantined application's notifications now carry its own name, icon and actions. |
| `--talk=org.kde.StatusNotifierWatcher`, `--own=org.kde.*` | System tray. `StatusNotifierItem` is two-way — the watcher calls back into the application for its icon, title and menu — so a per-interface bridge cannot carry it; the item and the watcher have to share one bus. The item name is `org.kde.StatusNotifierItem-<pid>-<n>`, which the proxy's `name.*` wildcard does not match because of the dash, hence the broader `org.kde.*`. |
| `--talk=org.freedesktop.DBus` | Name registration and ownership signals. |

Everything else — the portals, the secret service, the compositor's own
interfaces, and every other name on the host bus — is denied. One consequence
worth naming: the guest's own `xdg-desktop-portal` is no longer reachable
either, and the host's is deliberately not in the policy, so file choosers in
quarantined applications fall back to the toolkit's built-in dialog.

### Verified properties

Confirmed against a booted guest, not read off the module:

| Property | Result |
|---|---|
| `systemd-detect-virt` inside the domain | `kvm` — a hypervisor boundary, not a namespace |
| Process identity | unprivileged `quarantine` user, uid 1000 |
| `/persist`, `/run/mujo/vault`, host `$HOME` | absent |
| Shared `/nix/store` | read-only; write attempt fails |
| Root filesystem | `tmpfs` — destroyed on shutdown |
| Outbound network | DHCP via qemu user-mode NAT, DNS and HTTPS egress both work |

`tests/microvm/test-quarantine-boundary.sh` (SEC-005) asserts all of these
against the running system, including an explicit check that
`systemd-detect-virt` does not report `none` — the regression that would mean
quarantine had quietly degraded to a namespace again.

### Honest limits

- **qemu user-mode networking routes through the host.** The guest cannot see
  the host LAN as an interface, but SLIRP will forward to anything the host can
  route to. The per-domain network policy in Phase 26 is not built; restricting
  egress belongs in the guest firewall.
- **The whole host Nix store is visible read-only.** It is world-readable on the
  host already, so this grants a quarantined process nothing a local process did
  not have — but a secret checked into the store would be readable from
  quarantine.
- **The domain is shared, not per-application.** One `mujo-quarantine` guest
  serves every quarantined launch, so two quarantined applications can see each
  other. Per-application domains and the pre-warmed pool of Phase 37 are not
  built.
- **`--own=org.kde.*` is broader than the tray needs.** A quarantined
  application can own any name under `org.kde.`, not only its own
  `StatusNotifierItem-<pid>-<n>`. It can therefore squat a KDE service name a
  host application expects. Narrowing this needs a proxy that understands the
  dash-separated form, which `xdg-dbus-proxy` does not.
- **The GPU is shared, not passed through — and `apps.microvm.gpu = "native"`
  is the widest hole in this domain.** VFIO passthrough is not available on this
  machine at all: there is one GPU (`1002:7590` at `0000:03:00.0`) and it drives
  both monitors, so assigning it to the guest would take the desktop with it,
  and `/sys/kernel/iommu_groups` is empty because the IOMMU is off. What is
  available is `virtio-gpu-gl` with `drm_native_context=on`, where the guest's
  mesa — radeonsi and RADV alike, through its `amdvgpu` winsys — issues the
  *native amdgpu UAPI*, and virglrenderer's `amdgpu-experimental` renderer hands
  those calls to the host's real driver. Near-native speed, host keeps its
  display, and an untrusted guest is now driving the host kernel's GPU driver
  more or less directly. `"virgl"` narrows that to a parsed GL command stream at
  some cost in speed; `"none"` removes the path entirely and returns to
  llvmpipe. Either way no host device node is bound into the guest — the guest
  sees a virtio device — but this is a long way from §6's original "no device
  passthrough at all".
- **A Flatpak's tray and notifications are relayed, not native.** Flatpak
  applications run on a private guest bus (see the shape above for why), so
  `mujo-tray-relay` re-exports their `StatusNotifierItem` onto the host bus over
  a second connection and forwards `Notify` calls the same way. What does *not*
  cross is the return path for notification actions: the host proxy's policy is
  `--call`, not `--broadcast`, so clicking a notification button does nothing.
  Tray menus and clicks are unaffected — those ride the item connection, which
  is bidirectional.
- **The trust engine does not drive this yet.** `mujo-trust` records states and
  `mujo-quarantine-run` enforces the boundary, but nothing automatically routes
  a QUARANTINE-state application into the domain, counts observation hours, or
  re-quarantines on a store-path change. That wiring is Milestone 7.

---

## 7. Trust Engine — As Implemented

`nixos/apps/trust.nix` builds the lifecycle of §2 as a state machine over a
root-owned registry at `/var/lib/mujo-trust/registry.json`.

### Why the registry is not writable by the user

The registry decides where every application runs. If a process running as the
user could edit it, a compromised application would simply set its own state to
`GRADUATED` and every check downstream would believe it — the control would be a
suggestion. So:

- **Administration** (`register`, `graduate`, `revoke`, `tier`, `rollback`,
  `evaluate`) is a root CLI that writes the file directly.
- **Self-reporting** (`begin`, `end`, `violation`, `get`) goes through
  `mujo-trustd` on a unix socket, which exposes only the verbs an application is
  safe to let speak about itself. There is no verb that promotes anything.

### One entry point

```
mujo-trust run <app>
        │
        ├─ resolve <app> to its /nix/store path        ← the identity
        │
        ├─ ask mujo-trustd which runtime that state maps to
        │
        ├── QUARANTINE / OBSERVING → mujo-quarantine-run   (MicroVM)
        ├── GRADUATED              → mujo-sandbox-run      (native sandbox)
        └── REVOKED                → refuse, and point at `rollback`
        │
        └─ report the session's runtime back when the process exits
```

### Policy

| From | To | Requires |
|---|---|---|
| *(unregistered)* | QUARANTINE | first launch — nothing is trusted by default |
| QUARANTINE | OBSERVING | `observationPeriodHours` (72h) of accumulated runtime, zero violations, tier ≠ critical |
| OBSERVING | GRADUATED | a further `observingPeriodHours` (24h) clean, tier ∈ {low, medium} |
| *any* | QUARANTINE | the store path changed — an update is a different application |
| *any* | REVOKED | a reported violation; no amount of runtime undoes it |

Time is never sufficient on its own (plan Phase 20): a clean violation record and
the tier gate both apply. **CRITICAL never leaves quarantine**, and **HIGH stops
at OBSERVING** until a person runs `sudo mujo-trust graduate`.

Observation counts *runtime*, not wall-clock since installation, and only one
accumulator is open per application — so launching an application ten times over
does not bank ten hours per hour.

`tests/trust/test-trust-engine.sh` (SEC-009) drives all fourteen of these
transitions against the policy the running system actually carries.

### Capability profiles

Enforced, not advisory — each is the absence of something rather than a filter
over it:

| | Quarantine (MicroVM) | Graduated (native sandbox) |
|---|---|---|
| Host filesystem | none, except the Downloads exchange | none, except `--dir` / `--ro-dir` |
| Vault | no path exists in the domain | no path; only a broker socket, if granted |
| Camera | no device passthrough at all | denied unless `--camera` |
| Microphone | only if `capabilities.audio` (see §6) | via the session's PipeWire socket |
| Network | qemu user-mode NAT | on, unless `--no-net` |
| Host process table | separate kernel | separate PID namespace |

### Credential broker (`nixos/security/broker.nix`)

An application asks for one credential and receives one credential; it never
learns where the vault is mounted and cannot enumerate what it was not granted.

The hard part is knowing *which* application is asking, since a name sent over a
socket is worthless. Identity is a filesystem capability instead: every entry in
`security.mujo.broker.acl` gets its own socket, and `mujo-sandbox-run --app
<name>` binds exactly one of them into the sandbox's mount namespace. An
application can only reach the socket it was handed.

```nix
security.mujo.broker.acl = {
  git = ["github/token"];
};
```

Grants are fixed at build time. Every request is journalled — granted or denied,
by credential *name* only, never value. Empty by default: an application with no
entry gets no socket and can ask for nothing.

A denial is not only logged. The handler reports it to `mujo-trustd` as a
`violation`, which revokes the application — an application reaching for a
credential it was never granted is a boundary probe, not a typo, since the socket
it is talking to is the only one it can see and its grants were fixed at build
time. This is the detector behind Phase 21's "attempted credential access", and
Phase 40's remediation follows from it: the application stops launching until
someone runs `sudo mujo-trust rollback <app>` or re-graduates it. Only the
credential's *name* crosses to the trust daemon, never its value, and a trust
daemon that is down cannot turn a denial into a hang.

**Ceiling:** the sockets live in a traversable directory, so the user's own shell
can connect to any of them outside a sandbox. That is not a regression — the user
already has direct vault access. The boundary the ACL enforces is the sandbox's.
It does mean a stray hand-typed `mujo-credential` request can revoke an
application; the recovery is one root command.

## 8. Launcher integration

`mujo-trust run <app>` is the entry point, and `apps.trust.launcherIntegration`
puts the desktop launcher behind it. With it on, `Launch.app()` in
`quickshell/bar/services/Launch.qml` spawns `mujo-trust run <argv…>` instead of
`<argv…>`, so the trust state — not the `.desktop` file — decides whether the
application comes up in the quarantine MicroVM or the native sandbox. The user
clicks the same icon and sees the same window; only the runtime moves.

The shell decides by stat'ing `/etc/mujo/launcher-integration`, which the module
writes only when the option is on. A marker file rather than a build-time value
because the shell runs from the working tree as often as from the store, and a
file is the one channel that is true in both.

**It ships off.** With it on, an application nobody has graduated yet boots a
4 GB VM the first time it is clicked — that is the intended end state, but it
changes every launch on the machine at once. Turn it on deliberately:

1. `sudo mujo-trust register <app> <tier>` and `sudo mujo-trust graduate <app>`
   for the handful of applications you use constantly, so the first day is not
   spent waiting on VM boots.
2. Set `apps.trust.launcherIntegration = true;` and rebuild.
3. Launch something. If nothing appears, `journalctl --user -u qs-bar` and
   `mujo-trust list` say which state it resolved to.
4. To back out, set it to `false` and rebuild; the registry is untouched.

**Limitation:** an entry whose `Exec` runs a launcher — Flatpak's `flatpak run
app.zen_browser.zen` — is identified as *the launcher*, so every Flatpak
application shares one trust record and one runtime. Keep those out of the engine
until the entry resolves to the application's own store path. The `entry.execute()`
fallback in `Launch.app()`, taken only when quickshell cannot parse the `Exec`
line, also bypasses routing.

### Not implemented

- **No behavioural monitoring beyond the credential boundary.** The broker's
  deny path is a real detector, but the other Phase 21 events — unexpected
  device access, unexpected persistence, unexpected executable creation — are
  not observed automatically and are still reported by hand.
- **`rollback` re-points the registry**, and the previous closure is still in the
  Nix store — but nix will re-select the newer version on the next rebuild
  unless it is pinned.
