# mujō

A personal NixOS desktop that treats every application as untrusted until it has earned otherwise, and decides where each one runs from that record.

## Progressive trust

**Application**:
One exact build of a program, identified by its store path or Flatpak commit. An update is a different application and starts its evaluation over.
_Avoid_: app version, package

**Application name**:
The key an application is known by everywhere: its Flatpak application id, or the name of the program on PATH. Derived by launch resolution, never configured, so the registry record, the broker's credential grants and the sandbox home always agree.
_Avoid_: binary, app id (for native programs)

**Launch resolution**:
Working out an application's name, kind and identity from the command a person ran, and the exact command each runtime starts it with. One module (`mujo-trust-launch`) owns it.
_Avoid_: dispatch, wrapper

**Trust registry**:
The root-owned record of every application's trust state, tier and history; the single source for where an application runs.
_Avoid_: trust database, trust DB

**Trust state**:
Where an application stands: QUARANTINE (runs in the quarantine VM), OBSERVING (still quarantined, nearly eligible), GRADUATED (runs natively in a sandbox) or REVOKED (refuses to run).
_Avoid_: trust level, status

**Tier**:
An application's risk class (low, medium, high, critical), which caps how far it may graduate without a person: critical never leaves quarantine, high never leaves observation.
_Avoid_: risk level, priority

**Graduation**:
An application moving to GRADUATED, either by the evaluator after enough clean observed runtime or by an administrator.
_Avoid_: promotion, approval

**Violation**:
A reported attempt by an application to cross its sandbox, such as a denied credential request. Any violation revokes.
_Avoid_: incident, breach

**Rollback**:
Returning a revoked or updated application to its previous known-good build, restored to GRADUATED.
_Avoid_: downgrade, restore

**Seeding**:
Declaring an application's initial tier and trust state from configuration, reapplied on every boot without overriding a revocation.
_Avoid_: pre-trust, whitelisting
