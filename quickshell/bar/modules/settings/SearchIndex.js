.pragma library

// Omni-search index for the Settings app.
//
// Lives in its own library so settings.qml stays navigation config and
// test-settings-ui.qml can assert against the same data the app ships.
//
// `key`  routes like SettingsLayout.route() — a category key or any alias in
//        that category's `keys: [...]`.
// `card` names a MujoCard title on the destination page, so a hit scrolls to
//        the control instead of the top of the page. On Wallpapers it names a
//        tab id instead, because the three catalogue browsers have no cards.
//        Every value must match verbatim; test-settings-ui.qml checks that.

var entries = [
    // ── 1. System ──
    { title: "NixOS Rebuild & Switch", desc: "Apply and switch host configuration with pkexec escalation", cat: "System", key: "system", card: "NixOS Generation & Store" },
    { title: "System Generation History", desc: "Inspect current and past bootable system generations", cat: "System", key: "system", card: "System Generation History" },
    { title: "Nix Store Usage & Flake Status", desc: "View store disk consumption and flake.lock currency", cat: "System", key: "system", card: "NixOS Generation & Store" },
    { title: "Local Module Overrides", desc: "Machine-local drop-in overrides and flake inspect", cat: "System", key: "system", card: "Local Module Overrides" },
    { title: "System Health Sentinel", desc: "Real-time process anomaly tracker, zombie reaper & storage cleaner", cat: "System", key: "system", card: "System Health Sentinel" },
    { title: "Sentinel Automation", desc: "Enable the process sentinel, silent zombie reaping and runaway auto-kill", cat: "System", key: "system", card: "Sentinel Automation" },
    { title: "Problematic Processes", desc: "Terminate runaway CPU/RAM tasks and reap defunct zombies", cat: "System", key: "system", card: "Process Sentinel & Anomaly Tracker" },
    { title: "Storage Reclamation & Cleaner", desc: "Vacuum journal logs, clean Nix store, purge thumbnails and trash", cat: "System", key: "system", card: "Storage Reclamation & Cleaner" },
    { title: "Memory Compaction & ZRAM", desc: "Compact ZRAM swap buffers and drop inactive kernel page cache", cat: "System", key: "system", card: "Storage Reclamation & Cleaner" },
    { title: "Default Applications (XDG MIME)", desc: "MIME handlers for browser, editor, terminal, file manager, media", cat: "System", key: "system", card: "Default Applications" },
    { title: "System Hostname & Timezone", desc: "Declarative hostname and regional timezone clock mapping", cat: "System", key: "system", card: "System Parameters & Host Config" },
    { title: "Hardware Power Profile", desc: "CPU energy performance scaling governor (performance/balanced/eco)", cat: "System", key: "system", card: "System Parameters & Host Config" },
    { title: "System Sound Alerts", desc: "Play the system chime for alerts and completion events", cat: "System", key: "system", card: "System Parameters & Host Config" },
    { title: "Clipboard History (cliphist)", desc: "History depth, sensitive filter, image capture, and wipe", cat: "System", key: "system", card: "Clipboard History (cliphist)" },
    { title: "Companion App Integrations", desc: "Discord, Obsidian, Steam, VS Code, Spotify desktop integrations", cat: "System", key: "system", card: "Applications & Integrations" },
    { title: "Flatpak Applications & Permissions", desc: "Installed Flatpaks, filesystem access, and socket permissions", cat: "System", key: "system", card: "Applications & Integrations" },
    { title: "Launcher Pins & Workflows", desc: "Pinned favorite apps, recent launches, and search history", cat: "System", key: "system", card: "Applications & Integrations" },

    // ── 2. Appearance ──
    { title: "Theme Presets", desc: "Crimson, Blood Moon, Catppuccin, Ayu, Dracula, Nord, Gruvbox…", cat: "Appearance", key: "appearance", card: "Theme Presets" },
    { title: "Accent Color Override", desc: "Custom hex or curated 34-color palette accent swatch", cat: "Appearance", key: "appearance", card: "Accent Color & Surface Opacity" },
    { title: "Surface Transparency", desc: "Translucent glass alpha and blur opacity across panels and bars", cat: "Appearance", key: "appearance", card: "Accent Color & Surface Opacity" },
    { title: "Motion Intensity Profile", desc: "Minimal, Balanced, or Expressive physics and kinetic curves", cat: "Appearance", key: "appearance", card: "Motion Intensity Profile" },
    { title: "Interactive Motion Playground", desc: "Test real-time duration scaling, pulses, and spring feedback", cat: "Appearance", key: "appearance", card: "Interactive Motion Playground" },
    { title: "Page & Tab Transitions", desc: "Fluid crossfade and spatial slide transitions between pages", cat: "Appearance", key: "appearance", card: "Granular Motion Domains" },
    { title: "Tactile Micro-interactions", desc: "Fluid hover highlights, switch elasticity, and accordion physics", cat: "Appearance", key: "appearance", card: "Granular Motion Domains" },
    { title: "Ambient Motion & Flow", desc: "Subtle continuous background dynamics and breathing loops", cat: "Appearance", key: "appearance", card: "Granular Motion Domains" },
    { title: "Background Glow & Lighting", desc: "Backdrop radial lighting and interactive specular highlights", cat: "Appearance", key: "appearance", card: "Granular Motion Domains" },
    { title: "Animated Illustrations", desc: "Looping empty-state and hero artwork across the shell", cat: "Appearance", key: "appearance", card: "Granular Motion Domains" },
    { title: "Reduced Motion Mode", desc: "Accessibility preference eliminating spatial movement and transitions", cat: "Appearance", key: "appearance", card: "Accessibility & Performance" },
    { title: "Low-Power Performance Mode", desc: "Disable background particle effects and continuous loops to save battery", cat: "Appearance", key: "appearance", card: "Accessibility & Performance" },

    // ── 3. Workspace ──
    { title: "Desktop Bar Layout & Position", desc: "Attach floating bar to top or bottom edge of screen", cat: "Workspace", key: "workspace", card: "Desktop Bar Layout & Geometry" },
    { title: "Bar Height & Edge Margin", desc: "Vertical pill height, screen border margin, and cluster spacing", cat: "Workspace", key: "workspace", card: "Desktop Bar Layout & Geometry" },
    { title: "Bar Auto-Hide", desc: "Intelligent auto-hide when windows approach the screen edge", cat: "Workspace", key: "workspace", card: "Desktop Bar Layout & Geometry" },
    { title: "Right Cluster Modules & Order", desc: "Drag, reorder, add, and remove modules in the right cluster", cat: "Workspace", key: "workspace", card: "Right Cluster Modules & Order" },
    { title: "Workspaces Numeral Style", desc: "Numbers (1 2 3), Dots (•), Roman (I II), or Kanji (一 二)", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Workspaces Glider Indicator", desc: "Morphic glider, pill, underline, or outline active workspace indicator", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Clock Time Format & Seconds", desc: "24-hour format, live seconds counter, date pattern, monospace font", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Launcher Trigger Icon & Label", desc: "Search glass, Mujō logo, app grid, or custom text label", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Active Window Pill Style", desc: "App icon, window title text, max width elision, pill or glass style", cat: "Workspace", key: "workspace", card: "Bar Widget Style Customizer" },
    { title: "Dynamic Island Notch", desc: "Floating status notch: modules, geometry, animations, and auto-expand", cat: "Workspace", key: "workspace", card: "Dynamic Island Notch" },
    { title: "Island Geometry & Surface", desc: "Island max width, corner radius, vertical offset and opacity", cat: "Workspace", key: "workspace", card: "Island Geometry & Surface" },
    { title: "Island Auto-Expand & Alerts", desc: "Expansion duration and expand-on-notification banners", cat: "Workspace", key: "workspace", card: "Expansion & Alert Behavior" },
    { title: "Desktop Overlay Widgets", desc: "Freely place, drag, resize, and lock widgets across monitors", cat: "Workspace", key: "workspace", card: "Desktop Overlay Widgets" },
    { title: "Widget Glassmorphism & Shadows", desc: "Glass opacity, corner radius, drop shadows, and specular border glow", cat: "Workspace", key: "workspace", card: "Global Widget Styles & Glassmorphism" },
    { title: "Sticky Notes Widget Theme", desc: "Slate, yellow, rose, emerald, dark color themes and font sizes", cat: "Workspace", key: "workspace", card: "Widget Customization & Styles" },
    { title: "Cava Spectrum Visualizer", desc: "Equalizer bars, wave, dots, opacity, and mirror reflection", cat: "Workspace", key: "workspace", card: "Widget Customization & Styles" },
    { title: "Shelf File Staging Drop Zone", desc: "Screen-edge staging strip for collecting dragged files across folders", cat: "Workspace", key: "workspace", card: "Shelf File Staging Drop Zone" },

    // ── 4. Wallpapers ──
    { title: "Wallpaper Library", desc: "Apply from local curated high-resolution wallpaper collection", cat: "Wallpapers", key: "wallpapers", card: "library" },
    { title: "Wallhaven Online Explorer", desc: "Search millions of wallpapers, purity filters, NVMe thumbnail cache", cat: "Wallpapers", key: "wallhaven", card: "wallhaven" },
    { title: "Wallpaper Engine Steam Workshop", desc: "Browse Steam Workshop (431960) and installed live animated wallpapers", cat: "Wallpapers", key: "wallpaperengine", card: "wallpaperengine" },
    { title: "Wallpaper Engine Performance", desc: "Live FPS limit, audio automute, and background volume", cat: "Wallpapers", key: "effects", card: "Wallpaper Engine Performance" },
    { title: "Cursor Parallax & Depth", desc: "Dynamic wallpaper pan and parallax depth motion on mouse move", cat: "Wallpapers", key: "effects", card: "Parallax & Background" },
    { title: "Letterbox Fill Colour", desc: "Background shown around wallpapers that do not fill the screen", cat: "Wallpapers", key: "effects", card: "Parallax & Background" },

    // ── 5. Intelligence ──
    { title: "Assistant CLI Engine", desc: "Claude Code, opencode, Antigravity, Codex, Gemini CLI, Pi, custom argv", cat: "Intelligence", key: "intelligence", card: "Coding Assistant CLI" },
    { title: "API Provider & Endpoint", desc: "Local Ollama model, OpenAI-compatible API base URL, model name", cat: "Intelligence", key: "intelligence", card: "API Provider & Endpoint" },
    { title: "Keyring API Credentials", desc: "Secure keyring storage for AI provider tokens", cat: "Intelligence", key: "intelligence", card: "API Provider & Endpoint" },
    { title: "AI Privacy & Guardrails", desc: "Shell context, crash data opt-in, and interactive action confirmation", cat: "Intelligence", key: "intelligence", card: "AI Privacy & Safety Guardrails" },
    { title: "Do Not Disturb (DND)", desc: "Suppress notification toasts; alerts are still recorded in history", cat: "Intelligence", key: "dnd", card: "Behavior & Do Not Disturb" },
    { title: "Fullscreen Toast Suppression", desc: "Hold notification banners while focused window is fullscreen", cat: "Intelligence", key: "notifications", card: "Behavior & Do Not Disturb" },
    { title: "Notification Audio Chimes", desc: "Sound alerts, urgency threshold filter, and chime preview", cat: "Intelligence", key: "notifications", card: "Sound Alerts & Placement" },
    { title: "Notification Screen Gravity Corner", desc: "Screen corner placement (bottom-right, top-right, etc.) and auto-dismiss", cat: "Intelligence", key: "notifications", card: "Sound Alerts & Placement" },
    { title: "Per-App Notification Rules", desc: "Selectively mute noisy applications while keeping history", cat: "Intelligence", key: "notifications", card: "Per-App Mute Rules" },
    { title: "Mullvad WireGuard VPN", desc: "Connection status, relay country picker, and boot auto-connect", cat: "Intelligence", key: "vpn", card: "Mullvad WireGuard Tunnel" },
    { title: "Mullvad Keyring Account", desc: "Keyring-stored 16-digit account number and instant login", cat: "Intelligence", key: "vpn", card: "Keyring Credentials & Login" },
    { title: "VPN Relay Locations", desc: "Pick an exit node country and relay for the WireGuard tunnel", cat: "Intelligence", key: "vpn", card: "Relay Locations & Exit Nodes" },
    { title: "Weather Telemetry & Forecast", desc: "Open-Meteo current conditions, 5-day forecast, and auto-IP geolocation", cat: "Intelligence", key: "weather", card: "Current Atmospheric Conditions" },
    { title: "Weather Location & Units", desc: "Geocoded city search, metric or imperial units, refresh interval", cat: "Intelligence", key: "weather", card: "Location & Geocoding" },

    // ── 6. Hardware ──
    { title: "Display Resolution & Refresh Rate", desc: "Resolution, Hz, and HiDPI scaling per connected monitor", cat: "Hardware", key: "hardware", card: "Arrangement" },
    { title: "Visual Monitor Arrangement", desc: "Spatial drag-and-drop monitor layout and primary screen setup", cat: "Hardware", key: "hardware", card: "Arrangement" },
    { title: "Idle & Power Sleep Timers", desc: "Dim screen, display turn-off, lock screen, and suspend timers", cat: "Hardware", key: "idle", card: "Idle & Power" },
    { title: "Lock Screen", desc: "Lock on suspend and the grace period before the session locks", cat: "Hardware", key: "idle", card: "Idle & Power" },
    { title: "Keyboard Repeat & Sensitivity", desc: "Key repeat rate, delay, and XKB keymap layout variants", cat: "Hardware", key: "input", card: "Keyboard" },
    { title: "Pointer & Touchpad Dynamics", desc: "Mouse acceleration profile, natural scrolling, tap-to-click", cat: "Hardware", key: "input", card: "Pointer" },
    { title: "Keyboard Shortcuts Matrix", desc: "Interactive searchable matrix of Niri window manager bindings", cat: "Hardware", key: "shortcuts", card: "Keyboard Shortcuts" },
    { title: "Virtual Machines & Lab", desc: "Launch Windows, Ubuntu, Fedora, Arch in KVM with SPICE display", cat: "Hardware", key: "vm", card: "Virtual Machines" },
    { title: "Provision a Virtual Machine", desc: "Create a new guest from the image catalogue", cat: "Hardware", key: "vm", card: "Virtual Machines" },

    // ── 7. Security ──
    { title: "Verified Boot & Security Architecture", desc: "UEFI Secure Boot, TPM 2.0 PCR state, kernel lockdown, and sudo policies", cat: "Security", key: "security", card: "Verified Boot & System Integrity" },
    { title: "Encrypted Storage Vault", desc: "Unlock and lock /persist/secure/mujo-vault.luks container", cat: "Security", key: "vault", card: "LUKS2 Encrypted Storage Vault" },
    { title: "Host Hardening & Memory Isolation", desc: "Kernel lockdown, memory isolation and sudo policy", cat: "Security", key: "security", card: "Host Hardening & Memory Isolation" },
    { title: "Keyring Credentials Manager", desc: "Secret Service credentials, API keys, reveal tokens, and deletions", cat: "Security", key: "keyring", card: "Stored credentials" },
    { title: "Progressive Trust & Isolation Engine", desc: "Tier statistics, app sandbox policies (Native, Sandbox, MicroVM, Blocked)", cat: "Security", key: "trust", card: "Progressive Trust & Isolation Engine" },
    { title: "Impermanence Persistence Paths", desc: "Managed directories and files surviving btrfs root wipe on boot", cat: "Security", key: "persistence", card: "Managed Persistence Paths" },
    { title: "Recent Files & Location Privacy", desc: "Launcher recent-apps trail and the weather IP geolocation fallback", cat: "Security", key: "privacy", card: "Local Activity Trail" },
    { title: "Lock Before Suspend", desc: "Lock the session in swayidle's before-sleep hook", cat: "Security", key: "privacy", card: "Session Lock" }
]
