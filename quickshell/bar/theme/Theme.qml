pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Centralized, config-driven theme.  Reads ~/.config/quickshell/theme.json and
// exposes the full palette used by every shell surface AND the standalone
// Settings app (which imports this same singleton), so a theme change restyles
// the entire desktop live.  The file is written by `mujo theme …`; FileView
// watches it and reparses on change.
//
// theme.json schema (all optional):
//   { "preset": "ayu", "accent": "#5cc2ff", "transparency": 0.9 }
//   preset        one of presetOrder below (defaults to ayu)
//   accent        hex override, "" = use the preset's accent
//   transparency  0.6–1.0, alpha applied to the surface fills
QtObject {
    id: theme

    // ─── Config state (mirrors theme.json) ─────────────────────────────────────
    property string presetName: "ayu"
    property string accentOverride: ""   // "" → use preset accent
    property real transparency: 1.0      // 0.6–1.0

    readonly property string configPath:
        (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/theme.json"

    property FileView _cfg: FileView {
        path: theme.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme._parse(text())
        onLoadFailed: function(err) { /* keep defaults until the file exists */ }
    }

    function _parse(txt) {
        try {
            var c = JSON.parse(txt)
            if (c.preset && theme.presets[c.preset]) theme.presetName = c.preset
            theme.accentOverride = (typeof c.accent === "string") ? c.accent : ""
            if (typeof c.transparency === "number")
                theme.transparency = Math.max(0.6, Math.min(1.0, c.transparency))
        } catch (e) {
            console.warn("Theme: config parse error:", e)
        }
    }

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function _lum(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }

    // ─── Presets ────────────────────────────────────────────────────────────────
    // Each preset is a full role palette. Surface stack climbs
    // bg → surface → surfaceHover → surfaceActive; borders stay opaque so
    // transparency (applied only to the surface fills) never dissolves structure.
    readonly property var presetOrder: [
        "ayu", "catppuccin", "crimson", "bloodmoon",
        "dracula", "nord", "gruvbox", "tokyonight",
        "tokyodark", "rosepine", "horizon", "nightowl",
        "poimandres", "cyberpunk", "onedark", "everforest",
        "kanagawa", "monokaipro", "solarized", "githubdark",
        "synthwave", "oxocarbon", "palenight", "void"
    ]
    readonly property var presetLabels: ({
        ayu: "Ayu", catppuccin: "Catppuccin", crimson: "Crimson", bloodmoon: "Blood Moon",
        dracula: "Dracula", nord: "Nord", gruvbox: "Gruvbox", tokyonight: "Tokyo Night",
        tokyodark: "Tokyo Dark", rosepine: "Rosé Pine", horizon: "Horizon", nightowl: "Night Owl",
        poimandres: "Poimandres", cyberpunk: "Cyberpunk", onedark: "One Dark", everforest: "Everforest",
        kanagawa: "Kanagawa", monokaipro: "Monokai Pro", solarized: "Solarized Dark",
        githubdark: "GitHub Dark", synthwave: "Synthwave '84",
        oxocarbon: "Oxocarbon", palenight: "Palenight", void: "Void OLED"
    })

    readonly property var presets: ({
        ayu: {
            bg: "#0b0e13", surface: "#12161f", surfaceHover: "#1b212d", surfaceActive: "#232c3a",
            border: "#1d232e", borderStrong: "#2b3542", borderInteractive: "#2a3545",
            text: "#d7d4cb", textSecondary: "#7c8390", textDim: "#565d68",
            accent: "#5cc2ff", accentDim: "#16303f", accentText: "#0b0e13",
            success: "#b8cc52", warning: "#ffb454", error: "#f07178"
        },
        catppuccin: {
            bg: "#181825", surface: "#1e1e2e", surfaceHover: "#313244", surfaceActive: "#45475a",
            border: "#313244", borderStrong: "#45475a", borderInteractive: "#585b70",
            text: "#cdd6f4", textSecondary: "#a6adc8", textDim: "#6c7086",
            accent: "#89b4fa", accentDim: "#1e2a45", accentText: "#11111b",
            success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8"
        },
        crimson: {
            bg: "#12090b", surface: "#1a0f12", surfaceHover: "#27151b", surfaceActive: "#361c25",
            border: "#28141a", borderStrong: "#451e29", borderInteractive: "#632738",
            text: "#f5e6eb", textSecondary: "#b89da6", textDim: "#6e545c",
            accent: "#ff385c", accentDim: "#3d111b", accentText: "#ffffff",
            success: "#4ade80", warning: "#fbbf24", error: "#ff2a4b"
        },
        bloodmoon: {
            bg: "#0d0b0d", surface: "#161114", surfaceHover: "#24171b", surfaceActive: "#331c23",
            border: "#24171b", borderStrong: "#421d27", borderInteractive: "#5e2434",
            text: "#fae8ea", textSecondary: "#a89297", textDim: "#635155",
            accent: "#e63946", accentDim: "#380e14", accentText: "#ffffff",
            success: "#52b788", warning: "#f4a261", error: "#d90429"
        },
        dracula: {
            bg: "#21222c", surface: "#282a36", surfaceHover: "#343746", surfaceActive: "#44475a",
            border: "#343746", borderStrong: "#44475a", borderInteractive: "#6272a4",
            text: "#f8f8f2", textSecondary: "#bcc2cd", textDim: "#6272a4",
            accent: "#bd93f9", accentDim: "#2b2440", accentText: "#21222c",
            success: "#50fa7b", warning: "#f1fa8c", error: "#ff5555"
        },
        nord: {
            bg: "#2e3440", surface: "#3b4252", surfaceHover: "#434c5e", surfaceActive: "#4c566a",
            border: "#3b4252", borderStrong: "#4c566a", borderInteractive: "#5e81ac",
            text: "#eceff4", textSecondary: "#d8dee9", textDim: "#7b88a1",
            accent: "#88c0d0", accentDim: "#2a3a42", accentText: "#2e3440",
            success: "#a3be8c", warning: "#ebcb8b", error: "#bf616a"
        },
        gruvbox: {
            bg: "#1d2021", surface: "#282828", surfaceHover: "#32302f", surfaceActive: "#3c3836",
            border: "#32302f", borderStrong: "#504945", borderInteractive: "#665c54",
            text: "#ebdbb2", textSecondary: "#bdae93", textDim: "#928374",
            accent: "#fe8019", accentDim: "#3a2a17", accentText: "#1d2021",
            success: "#b8bb26", warning: "#fabd2f", error: "#fb4934"
        },
        tokyonight: {
            bg: "#16161e", surface: "#1a1b26", surfaceHover: "#24283b", surfaceActive: "#2f334d",
            border: "#24283b", borderStrong: "#2f334d", borderInteractive: "#414868",
            text: "#c0caf5", textSecondary: "#9aa5ce", textDim: "#565f89",
            accent: "#7aa2f7", accentDim: "#1c2740", accentText: "#16161e",
            success: "#9ece6a", warning: "#e0af68", error: "#f7768e"
        },
        tokyodark: {
            bg: "#11121d", surface: "#1a1b2a", surfaceHover: "#24263a", surfaceActive: "#31334d",
            border: "#24263a", borderStrong: "#353852", borderInteractive: "#4c5075",
            text: "#a0a8cd", textSecondary: "#71789c", textDim: "#4a506d",
            accent: "#ee6d85", accentDim: "#381c25", accentText: "#11121d",
            success: "#95c561", warning: "#d7a65f", error: "#f25b68"
        },
        rosepine: {
            bg: "#191724", surface: "#1f1d2e", surfaceHover: "#26233a", surfaceActive: "#393552",
            border: "#26233a", borderStrong: "#403d52", borderInteractive: "#524f67",
            text: "#e0def4", textSecondary: "#908caa", textDim: "#6e6a86",
            accent: "#c4a7e7", accentDim: "#2a2440", accentText: "#191724",
            success: "#9ccfd8", warning: "#f6c177", error: "#eb6f92"
        },
        horizon: {
            bg: "#1a1c23", surface: "#21232d", surfaceHover: "#2b2d3a", surfaceActive: "#373a4a",
            border: "#2b2d3a", borderStrong: "#3e4256", borderInteractive: "#595e7b",
            text: "#e0e2ea", textSecondary: "#9da2b8", textDim: "#626880",
            accent: "#e95678", accentDim: "#361b24", accentText: "#1a1c23",
            success: "#29d398", warning: "#fab795", error: "#f43e5c"
        },
        nightowl: {
            bg: "#011627", surface: "#0b253a", surfaceHover: "#11324d", surfaceActive: "#1d4263",
            border: "#11324d", borderStrong: "#1e4e78", borderInteractive: "#2c6b9e",
            text: "#d6deeb", textSecondary: "#89a4bb", textDim: "#5f7e97",
            accent: "#82aaff", accentDim: "#162842", accentText: "#011627",
            success: "#22da6e", warning: "#ecc48d", error: "#ef5350"
        },
        poimandres: {
            bg: "#1b1e28", surface: "#232735", surfaceHover: "#2d3243", surfaceActive: "#393f54",
            border: "#2d3243", borderStrong: "#41475d", borderInteractive: "#5a627e",
            text: "#e4f0fb", textSecondary: "#a6accd", textDim: "#5d637f",
            accent: "#5de4c7", accentDim: "#133833", accentText: "#1b1e28",
            success: "#5de4c7", warning: "#fffac2", error: "#d0679d"
        },
        cyberpunk: {
            bg: "#100e1f", surface: "#1a162e", surfaceHover: "#262042", surfaceActive: "#362d5a",
            border: "#262042", borderStrong: "#413669", borderInteractive: "#5e4d94",
            text: "#f2eefe", textSecondary: "#a99ec9", textDim: "#6a5d8f",
            accent: "#ffe600", accentDim: "#3d3708", accentText: "#100e1f",
            success: "#00ff9f", warning: "#ff9900", error: "#ff0055"
        },
        onedark: {
            bg: "#21252b", surface: "#282c34", surfaceHover: "#2f343d", surfaceActive: "#3b4048",
            border: "#2f343d", borderStrong: "#3e4451", borderInteractive: "#4b5263",
            text: "#abb2bf", textSecondary: "#828997", textDim: "#5c6370",
            accent: "#61afef", accentDim: "#17303f", accentText: "#21252b",
            success: "#98c379", warning: "#e5c07b", error: "#e06c75"
        },
        everforest: {
            bg: "#272e33", surface: "#2d353b", surfaceHover: "#374145", surfaceActive: "#475258",
            border: "#374145", borderStrong: "#475258", borderInteractive: "#4f5b58",
            text: "#d3c6aa", textSecondary: "#9da9a0", textDim: "#7a8478",
            accent: "#a7c080", accentDim: "#233324", accentText: "#272e33",
            success: "#a7c080", warning: "#dbbc7f", error: "#e67e80"
        },
        kanagawa: {
            bg: "#16161d", surface: "#1f1f28", surfaceHover: "#2a2a37", surfaceActive: "#363646",
            border: "#2a2a37", borderStrong: "#363646", borderInteractive: "#54546d",
            text: "#dcd7ba", textSecondary: "#938aa9", textDim: "#716e61",
            accent: "#7e9cd8", accentDim: "#1f2b45", accentText: "#16161d",
            success: "#76946a", warning: "#e6c384", error: "#c34043"
        },
        monokaipro: {
            bg: "#19181a", surface: "#221f22", surfaceHover: "#2d2a2e", surfaceActive: "#3a363b",
            border: "#2d2a2e", borderStrong: "#403e41", borderInteractive: "#727072",
            text: "#fcfcfa", textSecondary: "#939293", textDim: "#5b595c",
            accent: "#ffd866", accentDim: "#3d3518", accentText: "#19181a",
            success: "#a9dc76", warning: "#fc9867", error: "#ff6188"
        },
        solarized: {
            bg: "#002b36", surface: "#073642", surfaceHover: "#0c4352", surfaceActive: "#145365",
            border: "#0d4857", borderStrong: "#586e75", borderInteractive: "#657b83",
            text: "#839496", textSecondary: "#586e75", textDim: "#657b83",
            accent: "#268bd2", accentDim: "#073642", accentText: "#fdf6e3",
            success: "#859900", warning: "#b58900", error: "#dc322f"
        },
        githubdark: {
            bg: "#0d1117", surface: "#161b22", surfaceHover: "#21262d", surfaceActive: "#30363d",
            border: "#21262d", borderStrong: "#30363d", borderInteractive: "#484f58",
            text: "#c9d1d9", textSecondary: "#8b949e", textDim: "#484f58",
            accent: "#58a6ff", accentDim: "#162e4f", accentText: "#0d1117",
            success: "#3fb950", warning: "#d29922", error: "#f85149"
        },
        synthwave: {
            bg: "#1a102f", surface: "#241b35", surfaceHover: "#2d2244", surfaceActive: "#3b2d59",
            border: "#2d2244", borderStrong: "#46346b", borderInteractive: "#614392",
            text: "#f92aad", textSecondary: "#b68cf2", textDim: "#685588",
            accent: "#03edf9", accentDim: "#12384a", accentText: "#1a102f",
            success: "#72f1b8", warning: "#fede5d", error: "#fe4450"
        },
        oxocarbon: {
            bg: "#161616", surface: "#262626", surfaceHover: "#333333", surfaceActive: "#393939",
            border: "#333333", borderStrong: "#525252", borderInteractive: "#6f6f6f",
            text: "#f4f4f4", textSecondary: "#c6c6c6", textDim: "#6f6f6f",
            accent: "#3ddbd9", accentDim: "#123637", accentText: "#161616",
            success: "#42be65", warning: "#ffe97b", error: "#ee5396"
        },
        palenight: {
            bg: "#292d3e", surface: "#1f2233", surfaceHover: "#32374d", surfaceActive: "#3e445e",
            border: "#32374d", borderStrong: "#444b6a", borderInteractive: "#676e95",
            text: "#a6accd", textSecondary: "#717cb4", textDim: "#505777",
            accent: "#c792ea", accentDim: "#352747", accentText: "#1f2233",
            success: "#c3e88d", warning: "#ffcb6b", error: "#ff5370"
        },
        void: {
            bg: "#050505", surface: "#0e0e10", surfaceHover: "#18181c", surfaceActive: "#24242a",
            border: "#1c1c22", borderStrong: "#2e2e38", borderInteractive: "#464654",
            text: "#f5f5f7", textSecondary: "#9e9ea8", textDim: "#5c5c66",
            accent: "#ffffff", accentDim: "#26262b", accentText: "#050505",
            success: "#34d399", warning: "#fbbf24", error: "#f87171"
        }
    })

    readonly property var active: presets[presetName] || presets.ayu
    readonly property color rawAccent: accentOverride !== "" ? accentOverride : active.accent

    // ─── Palette (derived from active preset + overrides) ───────────────────────
    // Surface fills carry the transparency alpha; everything else stays opaque.
    property color bg: withAlpha(active.bg, transparency)
    property color surface: withAlpha(active.surface, transparency)
    property color surfaceHover: withAlpha(active.surfaceHover, transparency)
    property color surfaceActive: withAlpha(active.surfaceActive, transparency)
    property color border: active.border
    property color borderStrong: active.borderStrong
    property color borderInteractive: active.borderInteractive

    property color text: active.text
    property color textSecondary: active.textSecondary
    property color textDim: active.textDim

    property color accent: rawAccent
    property color accentDim: accentOverride !== "" ? withAlpha(rawAccent, 0.18) : active.accentDim
    property color accentText: accentOverride !== ""
        ? (_lum(rawAccent) > 0.55 ? active.bg : "#ffffff")
        : active.accentText

    property color success: active.success
    property color successDim: withAlpha(active.success, 0.18)
    property color warning: active.warning
    property color warningDim: withAlpha(active.warning, 0.18)
    property color error: active.error
    property color errorDim: withAlpha(active.error, 0.18)

    // ─── Typography ───────────────────────────────────────────────────────────
    property string fontFamily: "Ubuntu Sans"
    property string fontMono: "JetBrains Mono"

    property int fontSizeLabel: 10        // uppercase micro-labels
    property int fontSizeSmall: 11
    property int fontSizeBody: 12
    property int fontSizeTitle: 13
    property int fontSizeHeading: 15
    property real labelSpacing: 1.4       // letter-spacing for uppercase labels

    // ─── Radii ────────────────────────────────────────────────────────────────
    property int radiusSm: 7
    property int radiusMd: 11
    property int radiusLg: 16

    // ─── Bar layout ───────────────────────────────────────────────────────────
    // Sizing is store-backed (WP-17): change from bar.* and the bar restyles live.
    property int barHeight: SettingsBus.get("bar.height", 34)    // content height of the floating groups
    property int barMargin: SettingsBus.get("bar.margin", 7)     // gap between screen edge and groups
    property int groupPadding: 4          // inner padding inside a floating group
    property int groupRadius: radiusMd
    property real barGroupOpacity: SettingsBus.get("bar.opacity", 1)   // group background alpha

    // Bar position (WP-17). barBottom flips the panel anchor AND every menu
    // popup's vertical edge/gravity through these two tokens, so all popups open
    // away from the bar together (top bar → popups below; bottom bar → above).
    readonly property bool barBottom: SettingsBus.get("bar.position", "top") === "bottom"
    readonly property int popupEdge: barBottom ? Edges.Top : Edges.Bottom
    readonly property int popupGravity: barBottom ? Edges.Top : Edges.Bottom

    // Screen edge the bar reserves — 0 while it is auto-hidden, because then it
    // reserves nothing and a window really does reach the edge.
    readonly property int barReserved: SettingsBus.get("bar.autoHide", false)
        ? 0 : (barHeight + barMargin * 2)

    // ─── Desktop inset ────────────────────────────────────────────────────────
    // How far a niri window sits from the edge of the usable area: its struts
    // plus one gap, both set in modules/wrappers/niri.nix (struts 10 + gaps 10).
    // The desktop surface is inset by the same amount so icons and widgets live
    // exactly inside the rectangle an open window covers, instead of poking out
    // in the strip around it. Keep this in step with niri.nix, or override it
    // from desktop.inset.
    property int desktopInset: SettingsBus.get("desktop.inset", 20)
    readonly property int desktopInsetTop: desktopInset + (barBottom ? 0 : barReserved)
    readonly property int desktopInsetBottom: desktopInset + (barBottom ? barReserved : 0)

    // ─── Motion ───────────────────────────────────────────────────────────────
    // Motion lives entirely in Anim.qml — durations, easings and the
    // reduced-motion state. Theme used to re-export durationFast/durationSlow/
    // reduceMotion, which left the shell split across two spellings of the same
    // thing. Use Anim.d(Anim.fast) and Anim.reduceMotion directly.

    // ─── Workspaces ───────────────────────────────────────────────────────────
    property int workspacePillSize: 22
    property int workspacePillRadius: 7
    property int workspaceSpacing: 4

    // ─── Clock ────────────────────────────────────────────────────────────────
    property bool clock24h: true
    property bool clockShowSeconds: false
    property bool clockShowDate: true
    property int clockFontSize: 13

    // ─── Launcher ─────────────────────────────────────────────────────────────
    property int launcherWidth: 640
    property int launcherHeight: 540
}
