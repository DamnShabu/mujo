.pragma library

// Omni-search index for the Settings app.
//
// Lives in its own library so settings.qml stays navigation config and
// test-settings-ui.qml can assert against the same data the app ships.
//
// `key`   routes like SettingsLayout.route() — a category key or any alias in
//         that category's `keys: [...]`.
// `card`  names a MujoCard title on the destination page, so a hit scrolls to
//         the control instead of the top of the page. On Wallpapers it names a
//         sub-view id instead (library/wallhaven/wallpaperengine), because the
//         catalogue browsers have no cards.
//         Every value must match verbatim; test-settings-ui.qml checks that.
// `cat`   must be one of: "System", "Appearance", "Workspace", "Hardware",
//         "Security & Privacy".
// `tags`  semantic keywords used by SettingsLayout.score() for search ranking.

var entries = [
    // ── 1. System ────────────────────────────────────────────────────────────
    {
        title: "NixOS Rebuild & Switch",
        desc: "Apply and switch host configuration with pkexec escalation and generation tracking",
        cat: "System",
        key: "rebuild",
        card: "NixOS Generation & Store",
        brand: "nixos",
        tags: ["nixos", "rebuild", "switch", "flake", "generation", "deploy", "system", "host", "upgrade", "pkexec", "apply"]
    },
    {
        title: "System Generation History",
        desc: "Inspect current and past bootable system generations, roll back to prior builds",
        cat: "System",
        key: "rebuild",
        card: "System Generation History",
        brand: "nixos",
        tags: ["generations", "history", "rollback", "boot", "nix", "versions", "revert", "previous", "switch"]
    },
    {
        title: "Nix Store Usage & Flake Status",
        desc: "View Nix store disk consumption, store paths, and flake.lock currency",
        cat: "System",
        key: "rebuild",
        card: "NixOS Generation & Store",
        brand: "nixos",
        tags: ["nix", "store", "disk", "usage", "flake", "lock", "nixpkgs", "space", "packages"]
    },
    {
        title: "Local Module Overrides",
        desc: "Machine-local drop-in overrides and flake inspect status",
        cat: "System",
        key: "rebuild",
        card: "Local Module Overrides",
        brand: "system",
        tags: ["overrides", "modules", "machine", "local", "drop-ins", "flake", "inspect", "config", "custom"]
    },
    {
        title: "System Health Sentinel",
        desc: "Real-time process anomaly tracker, zombie reaper, and storage monitor",
        cat: "System",
        key: "health",
        card: "System Health Sentinel",
        brand: "system",
        tags: ["health", "sentinel", "monitor", "cpu", "ram", "memory", "storage", "performance", "anomalies", "load"]
    },
    {
        title: "Sentinel Automation & Rules",
        desc: "Enable automatic zombie reaping, runaway process limits, and background checks",
        cat: "System",
        key: "health",
        card: "Sentinel Automation",
        brand: "system",
        tags: ["sentinel", "automation", "zombies", "reap", "runaway", "auto-kill", "daemon", "rules", "background"]
    },
    {
        title: "Problematic Processes & Task Manager",
        desc: "Terminate runaway CPU and memory tasks, reap defunct zombies",
        cat: "System",
        key: "health",
        card: "Process Sentinel & Anomaly Tracker",
        brand: "system",
        tags: ["processes", "kill", "terminate", "zombies", "tasks", "cpu", "memory", "top", "runaway", "freeze"]
    },
    {
        title: "Storage Reclamation & Cleaner",
        desc: "Vacuum journal logs, clean Nix store, purge cache, trash, thumbnails, and compact ZRAM",
        cat: "System",
        key: "health",
        card: "Storage Reclamation & Cleaner",
        brand: "system",
        tags: ["cleaner", "storage", "disk", "gc", "garbage", "vacuum", "journal", "cache", "trash", "thumbnails", "zram", "memory", "free space"]
    },
    {
        title: "Default Applications (XDG MIME)",
        desc: "Configure default browser, editor, terminal, file manager, and media handlers",
        cat: "System",
        key: "preferences",
        card: "Default Applications",
        brand: "applications",
        tags: ["defaults", "applications", "browser", "editor", "terminal", "file manager", "mime", "xdg", "open", "associations"]
    },
    {
        title: "System Hostname & Timezone",
        desc: "Declarative hostname, regional timezone clock mapping, CPU energy governor, and chime alerts",
        cat: "System",
        key: "preferences",
        card: "System Parameters & Host Config",
        brand: "general",
        tags: ["hostname", "timezone", "clock", "power", "governor", "energy", "chime", "sound", "alerts", "host", "region"]
    },
    {
        title: "Clipboard History (cliphist)",
        desc: "Configure clipboard history depth, sensitive data filter, image capture, and history wipe",
        cat: "System",
        key: "preferences",
        card: "Clipboard History (cliphist)",
        brand: "clipboard",
        tags: ["clipboard", "cliphist", "history", "copy", "paste", "privacy", "clear", "wipe", "passwords", "images"]
    },
    {
        title: "Companion App Integrations & Flatpaks",
        desc: "Discord, Obsidian, Steam, VS Code, Spotify desktop integrations and Flatpak management",
        cat: "System",
        key: "apps",
        card: "Applications & Integrations",
        brand: "integrations",
        tags: ["apps", "applications", "integrations", "discord", "obsidian", "steam", "vscode", "spotify", "flatpak", "launcher", "pins"]
    },

    // ── 2. Appearance ────────────────────────────────────────────────────────
    {
        title: "Appearance Mode (Dark & Light)",
        desc: "Permanent dark, permanent light, or automated day and night schedules",
        cat: "Appearance",
        key: "appearance",
        card: "Appearance Mode",
        brand: "appearance",
        tags: ["dark", "light", "mode", "theme", "schedule", "day", "night", "solar", "appearance", "style", "switch"]
    },
    {
        title: "Automated Day & Night Schedule",
        desc: "Solar sunrise/sunset cycle or custom time-based theme automation",
        cat: "Appearance",
        key: "appearance",
        card: "Automated Day & Night Schedule",
        brand: "appearance",
        tags: ["schedule", "automation", "sunrise", "sunset", "day", "night", "time", "clock", "auto", "timer"]
    },
    {
        title: "Theme Presets & Color Palettes",
        desc: "Curated palettes: Crimson, Catppuccin, Ayu, Dracula, Nord, Gruvbox, Tokyo Night",
        cat: "Appearance",
        key: "appearance",
        card: "Theme Presets",
        brand: "appearance",
        tags: ["presets", "palette", "theme", "colors", "nord", "catppuccin", "dracula", "gruvbox", "ayu", "crimson", "tokyo night"]
    },
    {
        title: "Accent Color & Surface Opacity",
        desc: "Custom hex or 34-color palette swatch, translucent glass alpha, and blur levels",
        cat: "Appearance",
        key: "appearance",
        card: "Accent Color & Surface Opacity",
        brand: "appearance",
        tags: ["accent", "color", "hex", "swatch", "transparency", "opacity", "glass", "blur", "surface", "window"]
    },
    {
        title: "Wallpaper Library",
        desc: "Browse and apply curated high-resolution wallpapers from your local collection",
        cat: "Appearance",
        key: "wallpapers",
        card: "library",
        brand: "wallpaper",
        tags: ["wallpaper", "background", "library", "images", "photos", "desktop", "local", "static", "picture"]
    },
    {
        title: "Wallhaven Online Explorer",
        desc: "Search millions of wallpapers from Wallhaven API with purity filters and NVMe cache",
        cat: "Appearance",
        key: "wallhaven",
        card: "wallhaven",
        brand: "wallhaven",
        tags: ["wallhaven", "wallpaper", "online", "search", "api", "purity", "anime", "general", "people", "cache", "download"]
    },
    {
        title: "Wallpaper Engine Steam Workshop",
        desc: "Browse and launch live animated wallpapers from Steam Workshop (431960)",
        cat: "Appearance",
        key: "wallpaperengine",
        card: "wallpaperengine",
        brand: "wallpaperengine",
        tags: ["wallpaperengine", "steam", "workshop", "animated", "live", "video", "431960", "scene", "background"]
    },
    {
        title: "Wallpaper Engine Performance",
        desc: "Live wallpaper FPS limits, audio automute when media plays, and background volume",
        cat: "Appearance",
        key: "effects",
        card: "Wallpaper Engine Performance",
        brand: "wallpaperengine",
        tags: ["wallpaper", "engine", "fps", "performance", "audio", "volume", "automute", "mute", "live"]
    },
    {
        title: "Cursor Parallax & Letterbox Background",
        desc: "Dynamic mouse parallax depth motion and letterbox background fill color",
        cat: "Appearance",
        key: "effects",
        card: "Parallax & Background",
        brand: "animations",
        tags: ["parallax", "depth", "motion", "cursor", "mouse", "letterbox", "fill", "aspect", "ratio", "background"]
    },
    {
        title: "Motion Intensity Profile",
        desc: "Minimal, Balanced, or Expressive physics and kinetic curves across the shell",
        cat: "Appearance",
        key: "motion",
        card: "Motion Intensity Profile",
        brand: "motion",
        tags: ["motion", "animations", "physics", "springs", "speed", "curves", "intensity", "expressive", "smooth"]
    },
    {
        title: "Interactive Motion Playground",
        desc: "Test real-time duration scaling, spring dynamics, pulses, and tactile feedback",
        cat: "Appearance",
        key: "motion",
        card: "Interactive Motion Playground",
        brand: "motion",
        tags: ["motion", "playground", "test", "springs", "physics", "timing", "feedback", "duration", "haptic"]
    },
    {
        title: "Granular Motion Domains",
        desc: "Fine-tune page transitions, tactile micro-interactions, ambient flow, and glow",
        cat: "Appearance",
        key: "motion",
        card: "Granular Motion Domains",
        brand: "motion",
        tags: ["transitions", "micro-interactions", "ambient", "flow", "glow", "lighting", "animations", "domains", "tactile"]
    },
    {
        title: "Reduced Motion & Accessibility",
        desc: "Eliminate spatial motion for accessibility or enable low-power mode to save battery",
        cat: "Appearance",
        key: "motion",
        card: "Accessibility & Performance",
        brand: "motion",
        tags: ["accessibility", "reduced motion", "a11y", "low power", "battery", "performance", "disable animations"]
    },

    // ── 3. Workspace ─────────────────────────────────────────────────────────
    {
        title: "Desktop Bar Layout & Geometry",
        desc: "Top or bottom screen placement, bar height, screen margin, and auto-hide behavior",
        cat: "Workspace",
        key: "bar",
        card: "Desktop Bar Layout & Geometry",
        brand: "desktop",
        tags: ["bar", "layout", "position", "top", "bottom", "height", "margin", "autohide", "geometry", "dock", "panel"]
    },
    {
        title: "3-Zone Slot Canvas Builder",
        desc: "Drag, reorder, add, and remove bar modules across Left, Center, and Right zones",
        cat: "Workspace",
        key: "bar",
        card: "3-Zone Slot Canvas Builder",
        brand: "desktop",
        tags: ["bar", "slots", "builder", "modules", "layout", "left", "center", "right", "reorder", "canvas", "drag"]
    },
    {
        title: "Status Cluster & Tray Modules",
        desc: "Configure system tray, volume slider, battery gauge, network pill, and clock order",
        cat: "Workspace",
        key: "bar",
        card: "Right Cluster Modules & Order",
        brand: "desktop",
        tags: ["tray", "cluster", "status", "volume", "battery", "network", "clock", "indicators", "order", "audio"]
    },
    {
        title: "Bar Widget Style Customizer",
        desc: "Workspace numerals (1 2 3, •, I II, 一 二), morphic gliders, clock format, and window pills",
        cat: "Workspace",
        key: "bar",
        card: "Bar Widget Style Customizer",
        brand: "desktop",
        tags: ["workspaces", "glider", "numerals", "kanji", "roman", "dots", "clock", "date", "pill", "launcher icon", "style", "font"]
    },
    {
        title: "Dynamic Island Notch",
        desc: "Floating status notch: active media playback, timer alerts, audio, and quick actions",
        cat: "Workspace",
        key: "island",
        card: "Dynamic Island Notch",
        brand: "island",
        tags: ["island", "notch", "dynamic island", "status", "media", "pill", "hud", "floating", "mpris"]
    },
    {
        title: "Island Geometry & Surface",
        desc: "Configure dynamic island max width, corner radius, vertical offset, and glass opacity",
        cat: "Workspace",
        key: "island",
        card: "Island Geometry & Surface",
        brand: "island",
        tags: ["island", "width", "radius", "geometry", "glass", "opacity", "offset", "surface", "roundness"]
    },
    {
        title: "Island Auto-Expand & Alerts",
        desc: "Expansion animation duration, spring bounce, and notification toast trigger rules",
        cat: "Workspace",
        key: "island",
        card: "Expansion & Alert Behavior",
        brand: "island",
        tags: ["island", "expand", "alerts", "notification", "bounce", "animation", "behavior", "trigger"]
    },
    {
        title: "Desktop Overlay Widgets",
        desc: "Freely place, reposition, resize, and lock desktop widgets across all monitors",
        cat: "Workspace",
        key: "widgets",
        card: "Desktop Overlay Widgets",
        brand: "desktop",
        tags: ["widgets", "desktop", "clock", "cava", "notes", "meters", "overlay", "monitors", "grid", "lock"]
    },
    {
        title: "Widget Glassmorphism & Shadows",
        desc: "Configure global widget surface opacity, corner radius, drop shadows, and border glow",
        cat: "Workspace",
        key: "widgets",
        card: "Global Widget Styles & Glassmorphism",
        brand: "desktop",
        tags: ["widgets", "glass", "glassmorphism", "shadows", "glow", "radius", "opacity", "style", "blur"]
    },
    {
        title: "Sticky Notes & Cava Spectrum Visualizer",
        desc: "Customize sticky notes color themes and Cava equalizer visualizer bars, wave, and opacity",
        cat: "Workspace",
        key: "widgets",
        card: "Widget Customization & Styles",
        brand: "desktop",
        tags: ["notes", "sticky notes", "cava", "equalizer", "audio", "spectrum", "visualizer", "widgets", "style", "sound"]
    },
    {
        title: "Do Not Disturb (DND) & Toast Behavior",
        desc: "Suppress notification toasts, hold banners during fullscreen apps, and toggle DND",
        cat: "Workspace",
        key: "notifications",
        card: "Behavior & Do Not Disturb",
        brand: "notifications",
        tags: ["dnd", "do not disturb", "notifications", "quiet", "fullscreen", "gaming", "suppression", "banners", "toast"]
    },
    {
        title: "Notification Sounds & Screen Placement",
        desc: "Audio chimes, urgency threshold filtering, screen gravity corner, and auto-dismiss timeouts",
        cat: "Workspace",
        key: "notifications",
        card: "Sound Alerts & Placement",
        brand: "notifications",
        tags: ["notifications", "sound", "chime", "audio", "placement", "corner", "gravity", "timeout", "urgency", "alerts"]
    },
    {
        title: "Per-App Notification Rules",
        desc: "Selectively silence noisy applications while preserving alert items in notification history",
        cat: "Workspace",
        key: "notifications",
        card: "Per-App Mute Rules",
        brand: "notifications",
        tags: ["notifications", "mute", "apps", "rules", "silence", "per-app", "filter", "history", "blacklist"]
    },
    {
        title: "Notification Testing Lab",
        desc: "Preview and test notifications with low, normal, and critical urgencies and action buttons",
        cat: "Workspace",
        key: "notifications",
        card: "Notification Testing Lab",
        brand: "notifications",
        tags: ["notifications", "test", "lab", "preview", "toast", "urgency", "actions", "demo"]
    },
    {
        title: "Weather Telemetry & 5-Day Forecast",
        desc: "Live Open-Meteo atmospheric conditions, hourly telemetry, and 5-day weather forecast",
        cat: "Workspace",
        key: "weather",
        card: "Current Atmospheric Conditions",
        brand: "weather",
        tags: ["weather", "temperature", "forecast", "humidity", "wind", "rain", "sun", "open-meteo", "conditions", "climate"]
    },
    {
        title: "Weather Location & Units",
        desc: "Geocoded city search, IP geolocation fallback, temperature units, and refresh interval",
        cat: "Workspace",
        key: "weather",
        card: "Location & Geocoding",
        brand: "weather",
        tags: ["weather", "location", "city", "geocoding", "gps", "ip", "celsius", "fahrenheit", "units", "refresh", "metric"]
    },
    {
        title: "Shelf File Staging Drop Zone",
        desc: "Screen-edge staging strip for collecting, holding, and dragging files between windows",
        cat: "Workspace",
        key: "shelf",
        card: "Shelf File Staging Drop Zone",
        brand: "persistence",
        tags: ["shelf", "files", "staging", "drop zone", "drag", "drop", "clipboard", "pins", "storage", "collector"]
    },

    // ── 4. Hardware ──────────────────────────────────────────────────────────
    {
        title: "Display Resolution & Refresh Rate",
        desc: "Configure resolution, refresh rate Hz, HiDPI scaling, and drag-and-drop monitor layout",
        cat: "Hardware",
        key: "hardware",
        card: "Arrangement",
        brand: "display",
        tags: ["display", "monitors", "screens", "resolution", "hz", "refresh rate", "hidpi", "scale", "arrangement", "primary", "dual monitor"]
    },
    {
        title: "Keyboard Repeat & Sensitivity",
        desc: "Configure key repeat rate, initial delay, and XKB keymap layout and variant options",
        cat: "Hardware",
        key: "input",
        card: "Keyboard",
        brand: "keyboard",
        tags: ["keyboard", "repeat", "delay", "rate", "sensitivity", "layout", "xkb", "variant", "input", "typing"]
    },
    {
        title: "Pointer & Mouse Dynamics",
        desc: "Adjust pointer speed, mouse acceleration profiles (flat / adaptive), and sensitivity",
        cat: "Hardware",
        key: "input",
        card: "Pointer",
        brand: "mouse",
        tags: ["mouse", "pointer", "speed", "acceleration", "sensitivity", "cursor", "flat", "adaptive", "sensitivity"]
    },
    {
        title: "Touchpad Dynamics & Gestures",
        desc: "Natural scrolling direction, tap-to-click, and multi-finger touchpad gestures",
        cat: "Hardware",
        key: "input",
        card: "Touchpad",
        brand: "mouse",
        tags: ["touchpad", "trackpad", "scrolling", "natural scrolling", "tap to click", "gestures", "input", "swipe"]
    },
    {
        title: "Keyboard Shortcuts Matrix",
        desc: "Searchable interactive matrix of Niri window manager keybindings and custom shortcuts",
        cat: "Hardware",
        key: "shortcuts",
        card: "Keyboard Shortcuts",
        brand: "shortcuts",
        tags: ["shortcuts", "keybindings", "hotkeys", "niri", "window manager", "binds", "keyboard", "navigation"]
    },
    {
        title: "Idle & Power Sleep Timers",
        desc: "Screen dimming, display turn-off timeout, lock on suspend, and system sleep timers",
        cat: "Hardware",
        key: "power",
        card: "Idle & Power",
        brand: "system",
        tags: ["power", "idle", "sleep", "suspend", "dim", "screen off", "lock", "timeout", "energy", "battery", "inactivity"]
    },
    {
        title: "Mullvad WireGuard VPN Tunnel",
        desc: "Connection status, killswitch protection, auto-connect on boot, and WireGuard status",
        cat: "Hardware",
        key: "vpn",
        card: "Mullvad WireGuard Tunnel",
        brand: "mullvad",
        tags: ["vpn", "mullvad", "wireguard", "tunnel", "privacy", "killswitch", "network", "security", "connection"]
    },
    {
        title: "Mullvad Keyring Credentials",
        desc: "Manage keyring-stored 16-digit Mullvad account number with instant login and verification",
        cat: "Hardware",
        key: "vpn",
        card: "Keyring Credentials & Login",
        brand: "mullvad",
        tags: ["mullvad", "account", "keyring", "login", "token", "credentials", "vpn", "auth", "secret"]
    },
    {
        title: "VPN Relay Locations & Exit Nodes",
        desc: "Pick WireGuard exit node countries, cities, and specific server relays",
        cat: "Hardware",
        key: "vpn",
        card: "Relay Locations & Exit Nodes",
        brand: "mullvad",
        tags: ["vpn", "relays", "servers", "exit node", "country", "city", "wireguard", "mullvad", "location", "proxy"]
    },
    {
        title: "Virtual Machines & Lab",
        desc: "Launch throwaway Windows, Ubuntu, Fedora, and Arch guests in KVM with SPICE display",
        cat: "Hardware",
        key: "vm",
        card: "Virtual Machines",
        brand: "vm",
        tags: ["vm", "virtual machines", "kvm", "qemu", "spice", "windows", "ubuntu", "arch", "fedora", "guests", "lab", "virtualization"]
    },

    // ── 5. Security & Privacy ────────────────────────────────────────────────
    {
        title: "Verified Boot & System Integrity",
        desc: "UEFI Secure Boot status, TPM 2.0 PCR state measurements, Lanzaboote, and kernel lockdown",
        cat: "Security & Privacy",
        key: "security",
        card: "Verified Boot & System Integrity",
        brand: "security",
        tags: ["secure boot", "tpm", "uefi", "lanzaboote", "integrity", "boot", "verified", "measurements", "security"]
    },
    {
        title: "LUKS2 Encrypted Storage Vault",
        desc: "Unlock, lock, and manage the encrypted /persist/secure/mujo-vault.luks container and passphrase",
        cat: "Security & Privacy",
        key: "vault",
        card: "LUKS2 Encrypted Storage Vault",
        brand: "security",
        tags: ["vault", "luks", "luks2", "encryption", "secure", "passphrase", "storage", "unlock", "lock", "container", "encrypted"]
    },
    {
        title: "Host Hardening & Memory Isolation",
        desc: "Kernel lockdown level, hardened malloc, memory isolation, and sudo privilege escalation policy",
        cat: "Security & Privacy",
        key: "security",
        card: "Host Hardening & Memory Isolation",
        brand: "security",
        tags: ["hardening", "kernel", "lockdown", "memory", "isolation", "sudo", "security", "privileges", "polkit", "malloc"]
    },
    {
        title: "Progressive Trust & Sandboxing",
        desc: "Application isolation tiers (Native, Sandbox, MicroVM, Blocked) and violation detection",
        cat: "Security & Privacy",
        key: "trust",
        card: "Progressive Trust & Isolation Engine",
        brand: "security",
        tags: ["trust", "sandbox", "microvm", "isolation", "tiers", "security", "broker", "progressive trust", "violations", "quarantine"]
    },
    {
        title: "Application Trust Registry",
        desc: "Inspect /var/lib/mujo-trust/registry.json, view graduated binaries, revocations, and rollback rules",
        cat: "Security & Privacy",
        key: "trust",
        card: "Application Trust Registry",
        brand: "security",
        tags: ["trust", "registry", "graduated", "revoke", "rollback", "binaries", "applications", "policies", "registry.json"]
    },
    {
        title: "Keyring Credentials Manager",
        desc: "Inspect Secret Service credentials, API keys, tokens, reveal passwords, and delete entries",
        cat: "Security & Privacy",
        key: "keyring",
        card: "Stored credentials",
        brand: "keyring",
        tags: ["keyring", "credentials", "passwords", "secrets", "secret service", "tokens", "auth", "keys", "api keys"]
    },
    {
        title: "Add Keyring Credential",
        desc: "Store a new service credential, password, or API token securely in the system keyring",
        cat: "Security & Privacy",
        key: "keyring",
        card: "Add credential",
        brand: "keyring",
        tags: ["keyring", "add", "new credential", "secret", "store", "token", "password", "save"]
    },
    {
        title: "Coding Assistant CLI Engine",
        desc: "Configure desktop AI engine: Claude Code, opencode, Antigravity (agy), Codex, Gemini CLI, or Pi",
        cat: "Security & Privacy",
        key: "ai",
        card: "Coding Assistant CLI",
        brand: "ai",
        tags: ["ai", "assistant", "claude", "opencode", "antigravity", "agy", "codex", "gemini", "pi", "cli", "llm", "agent"]
    },
    {
        title: "AI API Provider & Endpoint",
        desc: "Set up local Ollama models or OpenAI-compatible API base URL, endpoint model name, and temperature",
        cat: "Security & Privacy",
        key: "ai",
        card: "API Provider & Endpoint",
        brand: "ai",
        tags: ["ai", "ollama", "openai", "endpoint", "api", "model", "url", "local ai", "provider", "llm", "temperature"]
    },
    {
        title: "AI Privacy & Safety Guardrails",
        desc: "Control shell context telemetry, crash report sharing, and interactive action confirmation gates",
        cat: "Security & Privacy",
        key: "ai",
        card: "AI Privacy & Safety Guardrails",
        brand: "ai",
        tags: ["ai", "privacy", "guardrails", "safety", "telemetry", "context", "confirmation", "crash reports", "opt-in"]
    },
    {
        title: "Impermanence Persistence Paths",
        desc: "Manage persistent directories and files that survive the btrfs root tmpfs wipe on boot",
        cat: "Security & Privacy",
        key: "persistence",
        card: "Managed Persistence Paths",
        brand: "persistence",
        tags: ["persistence", "impermanence", "btrfs", "root wipe", "persist", "directories", "files", "bind mounts", "storage", "paths"]
    },
    {
        title: "Local Activity Trail & Privacy",
        desc: "Configure launcher recent applications history trail and weather IP geolocation fallback",
        cat: "Security & Privacy",
        key: "privacy",
        card: "Local Activity Trail",
        brand: "privacy",
        tags: ["privacy", "activity", "recent apps", "trail", "history", "geolocation", "weather", "ip", "tracking", "telemetry"]
    }
]


