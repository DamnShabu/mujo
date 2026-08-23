pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
        "ayu", "catppuccin", "dracula", "nord",
        "gruvbox", "tokyonight", "rosepine", "onedark"
    ]
    readonly property var presetLabels: ({
        ayu: "Ayu", catppuccin: "Catppuccin", dracula: "Dracula", nord: "Nord",
        gruvbox: "Gruvbox", tokyonight: "Tokyo Night", rosepine: "Rosé Pine",
        onedark: "One Dark"
    })

    readonly property var presets: ({
        ayu: {
            bg: "#0b0e13", surface: "#12161f", surfaceHover: "#1b212d", surfaceActive: "#232c3a",
            border: "#1d232e", borderStrong: "#2b3542", borderInteractive: "#2a3545",
            text: "#d7d4cb", textSecondary: "#7c8390", textDim: "#565d68",
            accent: "#5cc2ff", accentDim: "#16303f", accentText: "#0b0e13",
            success: "#b8cc52", warning: "#ffb454", error: "#f07178", workspaceInactive: "#39424f"
        },
        catppuccin: {
            bg: "#181825", surface: "#1e1e2e", surfaceHover: "#313244", surfaceActive: "#45475a",
            border: "#313244", borderStrong: "#45475a", borderInteractive: "#585b70",
            text: "#cdd6f4", textSecondary: "#a6adc8", textDim: "#6c7086",
            accent: "#89b4fa", accentDim: "#1e2a45", accentText: "#11111b",
            success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8", workspaceInactive: "#45475a"
        },
        dracula: {
            bg: "#21222c", surface: "#282a36", surfaceHover: "#343746", surfaceActive: "#44475a",
            border: "#343746", borderStrong: "#44475a", borderInteractive: "#6272a4",
            text: "#f8f8f2", textSecondary: "#bcc2cd", textDim: "#6272a4",
            accent: "#bd93f9", accentDim: "#2b2440", accentText: "#21222c",
            success: "#50fa7b", warning: "#f1fa8c", error: "#ff5555", workspaceInactive: "#44475a"
        },
        nord: {
            bg: "#2e3440", surface: "#3b4252", surfaceHover: "#434c5e", surfaceActive: "#4c566a",
            border: "#3b4252", borderStrong: "#4c566a", borderInteractive: "#5e81ac",
            text: "#eceff4", textSecondary: "#d8dee9", textDim: "#7b88a1",
            accent: "#88c0d0", accentDim: "#2a3a42", accentText: "#2e3440",
            success: "#a3be8c", warning: "#ebcb8b", error: "#bf616a", workspaceInactive: "#4c566a"
        },
        gruvbox: {
            bg: "#1d2021", surface: "#282828", surfaceHover: "#32302f", surfaceActive: "#3c3836",
            border: "#32302f", borderStrong: "#504945", borderInteractive: "#665c54",
            text: "#ebdbb2", textSecondary: "#bdae93", textDim: "#928374",
            accent: "#fe8019", accentDim: "#3a2a17", accentText: "#1d2021",
            success: "#b8bb26", warning: "#fabd2f", error: "#fb4934", workspaceInactive: "#504945"
        },
        tokyonight: {
            bg: "#16161e", surface: "#1a1b26", surfaceHover: "#24283b", surfaceActive: "#2f334d",
            border: "#24283b", borderStrong: "#2f334d", borderInteractive: "#414868",
            text: "#c0caf5", textSecondary: "#9aa5ce", textDim: "#565f89",
            accent: "#7aa2f7", accentDim: "#1c2740", accentText: "#16161e",
            success: "#9ece6a", warning: "#e0af68", error: "#f7768e", workspaceInactive: "#414868"
        },
        rosepine: {
            bg: "#191724", surface: "#1f1d2e", surfaceHover: "#26233a", surfaceActive: "#393552",
            border: "#26233a", borderStrong: "#403d52", borderInteractive: "#524f67",
            text: "#e0def4", textSecondary: "#908caa", textDim: "#6e6a86",
            accent: "#c4a7e7", accentDim: "#2a2440", accentText: "#191724",
            success: "#9ccfd8", warning: "#f6c177", error: "#eb6f92", workspaceInactive: "#403d52"
        },
        onedark: {
            bg: "#21252b", surface: "#282c34", surfaceHover: "#2f343d", surfaceActive: "#3b4048",
            border: "#2f343d", borderStrong: "#3e4451", borderInteractive: "#4b5263",
            text: "#abb2bf", textSecondary: "#828997", textDim: "#5c6370",
            accent: "#61afef", accentDim: "#17303f", accentText: "#21252b",
            success: "#98c379", warning: "#e5c07b", error: "#e06c75", workspaceInactive: "#3b4048"
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
    property color warning: active.warning
    property color error: active.error

    property color workspaceActive: rawAccent
    property color workspaceInactive: active.workspaceInactive

    // ─── Typography ───────────────────────────────────────────────────────────
    property string fontFamily: "Ubuntu Sans"
    property string fontMono: "JetBrains Mono"

    property int fontSizeLabel: 10        // uppercase micro-labels
    property int fontSizeSmall: 11
    property int fontSizeBody: 12
    property int fontSizeTitle: 13
    property real labelSpacing: 1.4       // letter-spacing for uppercase labels

    // ─── Radii ────────────────────────────────────────────────────────────────
    property int radiusSm: 7
    property int radiusMd: 11
    property int radiusLg: 16

    // ─── Bar layout ───────────────────────────────────────────────────────────
    property int barHeight: 34            // content height of the floating groups
    property int barMargin: 7             // gap between screen edge and groups
    property int barPadding: 6            // spacing between groups
    property int groupPadding: 4          // inner padding inside a floating group
    property int groupRadius: radiusMd

    // ─── Motion ───────────────────────────────────────────────────────────────
    property bool reduceMotion: false
    property int durationFast: 120
    property int durationSlow: 200

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
    property int launcherWidth: 620
    property int launcherHeight: 520
    property real launcherOpacity: 1.0
}
