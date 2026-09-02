# Mujo Privacy & Metadata Minimization Model

This document outlines the privacy posture, fingerprinting reduction philosophy, logging controls, and memory crash protection in Mujo.

---

## 1. Philosophy: Minimal Unique Entropy

Mujo adheres to the principle of **minimal unique entropy**:
- Rather than applying aggressive or unusual fingerprint spoofing (which ironically makes a system uniquely identifiable in browser telemetry), Mujo blends in with standard modern Linux configurations while stripping unnecessary diagnostic leaks.
- Unnecessary hardware serial numbers, diagnostic probes, and ambient telemetry are disabled.

---

## 2. Privacy Controls & Defaults

### 2.1 Networking & Identifiers
- **Stable Private IPv6 Addresses**: Uses RFC 7217 privacy extensions to generate interface identifiers instead of embedding hardware MAC addresses into IPv6 packets (`net.ipv6.conf.all.addr_gen_mode = 2`).
- **Telemetry Blocking**: Default opt-out for desktop and package manager analytics.
- **DNS Privacy**: System supports encrypted DNS over TLS/HTTPS where configured.

### 2.2 Browser Privacy Tiers
- **Everyday Profile**: Standard modern browser engine with enhanced tracking protection, cookie sandboxing, and webRTC local IP leakage prevention.
- **Dedicated Privacy Profile**: Isolated container for high-anonymity sessions, routing through Mullvad / Tor without persistent cache or cross-site tracking state.

---

## 3. Log Bounding & Redaction Discipline

Logs represent a major vector for accidental secret leakage:
1. **Bounded Storage**: System journal size is capped at 200 MB (`SystemMaxUse=200M`) to prevent disk bloat on persistent storage and minimize the window of observable historical logs.
2. **Sensitive Data Redaction**:
   - Authentication tokens, passwords, and private key content must never be passed via CLI arguments (which appear in process lists and logs).
   - Vault paths and temporary unlock tokens are kept in volatile memory (`/run`) only.

---

## 4. Crash Dump & Memory Protection

Core dumps can unintentionally capture full process memory containing decrypted passwords, session cookies, and private cryptographic keys:
- **Core Dump Storage**: System-wide core dump persistence to disk is disabled (`Storage=none` or strictly in-memory transient).
- **Sensitive Process Dumps**: Critical security processes (vault manager, password prompt, SSH agent) enable `PR_SET_DUMPABLE=0` to block memory dumps and ptrace attachments even during catastrophic termination.

---

## 5. As Implemented

Sections 1–4 describe the posture. `nixos/security/privacy.nix` enforces this
much of it, and nothing beyond it:

| Control | Setting | Effect |
|---|---|---|
| Wi-Fi MAC | `wifi.macAddress = "stable-ssid"` | The factory MAC never goes on the wire; each SSID sees a different, stable address |
| Wi-Fi scanning | `wifi.scanRandMacAddress = true` | Probe requests do not carry a stable identifier while looking for networks |
| Ethernet MAC | `ethernet.macAddress = "stable"` | Same, per connection |
| DHCP hostname | `ipv4/ipv6.dhcp-send-hostname = false` | Every DHCP server the machine meets no longer learns its name |
| Connectivity check | `[connectivity] enabled=false` | NetworkManager stops fetching a probe URL after each network change |
| LLMNR / mDNS | `LLMNR=no`, `MulticastDNS=no` | The host no longer broadcasts or answers name queries on untrusted networks |
| IPv6 | `tempAddresses = "default"`, `addr_gen_mode = 2` | Temporary addresses preferred; interface identifiers are not MAC-derived |

### Deliberate choices

- **`stable`, not `random`.** Re-rolling the MAC on every connect breaks DHCP
  reservations and captive portals, and a device whose address changes each time
  is *more* distinctive on a network, not less. The goal is to stop leaking the
  hardware identifier, not to look unusual — §1's rule, applied.
- **DNS-over-TLS is off by default** (`security.mujo.privacy.dnsOverTls`). The
  Mullvad daemon manages DNS while a tunnel is up, including its ad, tracker and
  malware blocking. Forcing systemd-resolved to a different upstream fights it
  and can leave the machine with no resolver when the tunnel state changes.
  Enable it only on a machine not using Mullvad.

### Not implemented

- **Browser privacy tiers (§2.2).** Zen ships as a Flatpak here, so its profile
  is not declaratively managed; what *is* enforced is the Flatpak filesystem
  override in `nixos/apps/zen.nix`, which is the control that matters more. The
  everyday/anonymous profile split is not built.
- **Per-process dump suppression (§4).** `PR_SET_DUMPABLE=0` on the vault
  manager and prompter is not wired; system-wide core dump storage is handled in
  `nixos/security/storage.nix`.
