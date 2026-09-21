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
    property string mode: "dark"         // "dark" | "light" | "auto"
    property string scheduleType: "solar" // "solar" | "time"
    property string dayStart: "07:00"
    property string nightStart: "19:00"
    property string darkPreset: "ayu"
    property string lightPreset: "ayu_light"
    property bool isDaytime: true

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
            if (c.mode === "dark" || c.mode === "light" || c.mode === "auto")
                theme.mode = c.mode
            if (c.scheduleType === "solar" || c.scheduleType === "time")
                theme.scheduleType = c.scheduleType
            if (typeof c.dayStart === "string" && c.dayStart)
                theme.dayStart = c.dayStart
            if (typeof c.nightStart === "string" && c.nightStart)
                theme.nightStart = c.nightStart
            if (c.darkPreset && theme.presets[c.darkPreset])
                theme.darkPreset = c.darkPreset
            if (c.lightPreset && theme.presets[c.lightPreset])
                theme.lightPreset = c.lightPreset
            theme.updateSchedule()
        } catch (e) {
            console.warn("Theme: config parse error:", e)
        }
    }

    function withAlpha(c, a) {
        var qc = Qt.color(c)
        return Qt.rgba(qc.r, qc.g, qc.b, a)
    }
    function _lum(c) {
        var qc = Qt.color(c)
        return 0.299 * qc.r + 0.587 * qc.g + 0.114 * qc.b
    }

    // ─── Schedule Engine ────────────────────────────────────────────────────────
    function checkIsDaytime() {
        var now = new Date()
        var curMins = now.getHours() * 60 + now.getMinutes()
        if (theme.scheduleType === "solar" && Weather.hasData && Weather.sunrise && Weather.sunset) {
            try {
                var sr = new Date(Weather.sunrise)
                var ss = new Date(Weather.sunset)
                var srMins = sr.getHours() * 60 + sr.getMinutes()
                var ssMins = ss.getHours() * 60 + ss.getMinutes()
                if (!isNaN(srMins) && !isNaN(ssMins)) {
                    return curMins >= srMins && curMins < ssMins
                }
            } catch (e) {}
        }
        var dParts = (theme.dayStart || "07:00").split(":")
        var nParts = (theme.nightStart || "19:00").split(":")
        var dMins = parseInt(dParts[0] || "7", 10) * 60 + parseInt(dParts[1] || "0", 10)
        var nMins = parseInt(nParts[0] || "19", 10) * 60 + parseInt(nParts[1] || "0", 10)
        if (dMins < nMins) {
            return curMins >= dMins && curMins < nMins
        } else {
            return curMins >= dMins || curMins < nMins
        }
    }

    function updateSchedule() {
        isDaytime = checkIsDaytime()
    }

    property Timer _scheduleTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: theme.updateSchedule()
    }

    property Connections _weatherConn: Connections {
        target: Weather
        function onDataChanged() { theme.updateSchedule() }
    }

    onModeChanged: updateSchedule()
    onScheduleTypeChanged: updateSchedule()
    onDayStartChanged: updateSchedule()
    onNightStartChanged: updateSchedule()

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

    readonly property var lightPresetOrder: [
        "ayu_light", "catppuccin_latte", "crimson_light", "bloodmoon_light",
        "dracula_light", "nord_light", "gruvbox_light", "tokyoday",
        "tokyodark_light", "rosepine_dawn", "horizon_light", "nightowl_light",
        "poimandres_light", "cyberpunk_light", "onelight", "everforest_light",
        "kanagawa_lotus", "monokaipro_light", "solarized_light", "github_light",
        "synthwave_light", "oxocarbon_light", "palenight_light", "void_light"
    ]

    readonly property var darkToLight: ({
        ayu: "ayu_light", catppuccin: "catppuccin_latte", crimson: "crimson_light", bloodmoon: "bloodmoon_light",
        dracula: "dracula_light", nord: "nord_light", gruvbox: "gruvbox_light", tokyonight: "tokyoday",
        tokyodark: "tokyodark_light", rosepine: "rosepine_dawn", horizon: "horizon_light", nightowl: "nightowl_light",
        poimandres: "poimandres_light", cyberpunk: "cyberpunk_light", onedark: "onelight", everforest: "everforest_light",
        kanagawa: "kanagawa_lotus", monokaipro: "monokaipro_light", solarized: "solarized_light", githubdark: "github_light",
        synthwave: "synthwave_light", oxocarbon: "oxocarbon_light", palenight: "palenight_light", void: "void_light"
    })

    readonly property var lightToDark: ({
        ayu_light: "ayu", catppuccin_latte: "catppuccin", crimson_light: "crimson", bloodmoon_light: "bloodmoon",
        dracula_light: "dracula", nord_light: "nord", gruvbox_light: "gruvbox", tokyoday: "tokyonight",
        tokyodark_light: "tokyodark", rosepine_dawn: "rosepine", horizon_light: "horizon", nightowl_light: "nightowl",
        poimandres_light: "poimandres", cyberpunk_light: "cyberpunk", onelight: "onedark", everforest_light: "everforest",
        kanagawa_lotus: "kanagawa", monokaipro_light: "monokaipro", solarized_light: "solarized", github_light: "githubdark",
        synthwave_light: "synthwave", oxocarbon_light: "oxocarbon", palenight_light: "palenight", void_light: "void"
    })

    function isLightPreset(name) {
        if (!name) return false
        if (lightPresetOrder.indexOf(name) >= 0) return true
        if (presets[name]) return _lum(presets[name].bg) > 0.5
        return false
    }
    function isDarkPreset(name) {
        return !isLightPreset(name)
    }

    readonly property var presetLabels: ({
        ayu: "Ayu", catppuccin: "Catppuccin", crimson: "Crimson", bloodmoon: "Blood Moon",
        dracula: "Dracula", nord: "Nord", gruvbox: "Gruvbox", tokyonight: "Tokyo Night",
        tokyodark: "Tokyo Dark", rosepine: "Rosé Pine", horizon: "Horizon", nightowl: "Night Owl",
        poimandres: "Poimandres", cyberpunk: "Cyberpunk", onedark: "One Dark", everforest: "Everforest",
        kanagawa: "Kanagawa", monokaipro: "Monokai Pro", solarized: "Solarized Dark",
        githubdark: "GitHub Dark", synthwave: "Synthwave '84",
        oxocarbon: "Oxocarbon", palenight: "Palenight", void: "Void OLED",
        ayu_light: "Ayu Light", catppuccin_latte: "Catppuccin Latte", crimson_light: "Crimson Light", bloodmoon_light: "Blood Moon Light",
        dracula_light: "Dracula Light", nord_light: "Nord Snow", gruvbox_light: "Gruvbox Light", tokyoday: "Tokyo Day",
        tokyodark_light: "Tokyo Dark Light", rosepine_dawn: "Rosé Pine Dawn", horizon_light: "Horizon Light", nightowl_light: "Night Owl Light",
        poimandres_light: "Poimandres Light", cyberpunk_light: "Cyberpunk Light", onelight: "One Light", everforest_light: "Everforest Light",
        kanagawa_lotus: "Kanagawa Lotus", monokaipro_light: "Monokai Pro Light", solarized_light: "Solarized Light",
        github_light: "GitHub Light", synthwave_light: "Synthwave Light",
        oxocarbon_light: "Oxocarbon Light", palenight_light: "Palenight Light", void_light: "Void Light"
    })

    readonly property var presets: ({
        ayu: {
            bg: "#0b0e13", surface: "#12161f", surfaceHover: "#1b212d", surfaceActive: "#232c3a",
            border: "#1d232e", borderStrong: "#2b3542", borderInteractive: "#2a3545",
            text: "#d7d4cb", textSecondary: "#7c8390", textDim: "#565d68",
            accent: "#5cc2ff", accentDim: "#16303f", accentText: "#0b0e13",
            success: "#b8cc52", warning: "#ffb454", error: "#f07178"
        },
        ayu_light: {
            bg: "#fafafa", surface: "#ffffff", surfaceHover: "#f0f2f5", surfaceActive: "#e1e4e8",
            border: "#e1e4e8", borderStrong: "#d0d7de", borderInteractive: "#399ee6",
            text: "#575f66", textSecondary: "#8a9199", textDim: "#abb0b6",
            accent: "#399ee6", accentDim: "#e1f0fb", accentText: "#ffffff",
            success: "#86b300", warning: "#fa8d3e", error: "#f07171"
        },
        catppuccin: {
            bg: "#181825", surface: "#1e1e2e", surfaceHover: "#313244", surfaceActive: "#45475a",
            border: "#313244", borderStrong: "#45475a", borderInteractive: "#585b70",
            text: "#cdd6f4", textSecondary: "#a6adc8", textDim: "#6c7086",
            accent: "#89b4fa", accentDim: "#1e2a45", accentText: "#11111b",
            success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8"
        },
        catppuccin_latte: {
            bg: "#eff1f5", surface: "#e6e9ef", surfaceHover: "#dce0e8", surfaceActive: "#ccd0da",
            border: "#bcc0cc", borderStrong: "#acb0be", borderInteractive: "#1e66f5",
            text: "#4c4f69", textSecondary: "#6c6f85", textDim: "#9ca0b0",
            accent: "#1e66f5", accentDim: "#dce7fc", accentText: "#ffffff",
            success: "#40a02b", warning: "#df8e1d", error: "#d20f39"
        },
        crimson: {
            bg: "#12090b", surface: "#1a0f12", surfaceHover: "#27151b", surfaceActive: "#361c25",
            border: "#28141a", borderStrong: "#451e29", borderInteractive: "#632738",
            text: "#f5e6eb", textSecondary: "#b89da6", textDim: "#6e545c",
            accent: "#ff385c", accentDim: "#3d111b", accentText: "#ffffff",
            success: "#4ade80", warning: "#fbbf24", error: "#ff2a4b"
        },
        crimson_light: {
            bg: "#fff5f5", surface: "#ffe3e3", surfaceHover: "#fed0d0", surfaceActive: "#fca5a5",
            border: "#fca5a5", borderStrong: "#f87171", borderInteractive: "#e11d48",
            text: "#4c0519", textSecondary: "#9f1239", textDim: "#e11d48",
            accent: "#e11d48", accentDim: "#ffe4e6", accentText: "#ffffff",
            success: "#16a34a", warning: "#d97706", error: "#dc2626"
        },
        bloodmoon: {
            bg: "#0d0b0d", surface: "#161114", surfaceHover: "#24171b", surfaceActive: "#331c23",
            border: "#24171b", borderStrong: "#421d27", borderInteractive: "#5e2434",
            text: "#fae8ea", textSecondary: "#a89297", textDim: "#635155",
            accent: "#e63946", accentDim: "#380e14", accentText: "#ffffff",
            success: "#52b788", warning: "#f4a261", error: "#d90429"
        },
        bloodmoon_light: {
            bg: "#fff1f2", surface: "#ffe4e6", surfaceHover: "#fecdd3", surfaceActive: "#fda4af",
            border: "#fda4af", borderStrong: "#fb7185", borderInteractive: "#be123c",
            text: "#4c0519", textSecondary: "#881337", textDim: "#9f1239",
            accent: "#be123c", accentDim: "#ffe4e6", accentText: "#ffffff",
            success: "#059669", warning: "#d97706", error: "#b91c1c"
        },
        dracula: {
            bg: "#21222c", surface: "#282a36", surfaceHover: "#343746", surfaceActive: "#44475a",
            border: "#343746", borderStrong: "#44475a", borderInteractive: "#6272a4",
            text: "#f8f8f2", textSecondary: "#bcc2cd", textDim: "#6272a4",
            accent: "#bd93f9", accentDim: "#2b2440", accentText: "#21222c",
            success: "#50fa7b", warning: "#f1fa8c", error: "#ff5555"
        },
        dracula_light: {
            bg: "#f8f8f2", surface: "#edece6", surfaceHover: "#e2e0d8", surfaceActive: "#d4d1c7",
            border: "#d4d1c7", borderStrong: "#6272a4", borderInteractive: "#6b46c1",
            text: "#282a36", textSecondary: "#6272a4", textDim: "#999eb4",
            accent: "#6b46c1", accentDim: "#f0eafb", accentText: "#ffffff",
            success: "#22863a", warning: "#b08800", error: "#d73a49"
        },
        nord: {
            bg: "#2e3440", surface: "#3b4252", surfaceHover: "#434c5e", surfaceActive: "#4c566a",
            border: "#3b4252", borderStrong: "#4c566a", borderInteractive: "#5e81ac",
            text: "#eceff4", textSecondary: "#d8dee9", textDim: "#7b88a1",
            accent: "#88c0d0", accentDim: "#2a3a42", accentText: "#2e3440",
            success: "#a3be8c", warning: "#ebcb8b", error: "#bf616a"
        },
        nord_light: {
            bg: "#eceff4", surface: "#e5e9f0", surfaceHover: "#d8dee9", surfaceActive: "#c2d0e0",
            border: "#d8dee9", borderStrong: "#4c566a", borderInteractive: "#5e81ac",
            text: "#2e3440", textSecondary: "#3b4252", textDim: "#4c566a",
            accent: "#5e81ac", accentDim: "#e2ebf5", accentText: "#ffffff",
            success: "#a3be8c", warning: "#ebcb8b", error: "#bf616a"
        },
        gruvbox: {
            bg: "#1d2021", surface: "#282828", surfaceHover: "#32302f", surfaceActive: "#3c3836",
            border: "#32302f", borderStrong: "#504945", borderInteractive: "#665c54",
            text: "#ebdbb2", textSecondary: "#bdae93", textDim: "#928374",
            accent: "#fe8019", accentDim: "#3a2a17", accentText: "#1d2021",
            success: "#b8bb26", warning: "#fabd2f", error: "#fb4934"
        },
        gruvbox_light: {
            bg: "#fbf1c7", surface: "#f2e5bc", surfaceHover: "#ebdbb2", surfaceActive: "#d5c4a1",
            border: "#d5c4a1", borderStrong: "#bdae93", borderInteractive: "#af3a03",
            text: "#3c3836", textSecondary: "#665c54", textDim: "#928374",
            accent: "#af3a03", accentDim: "#f9e2d3", accentText: "#ffffff",
            success: "#79740e", warning: "#b57614", error: "#9d0006"
        },
        tokyonight: {
            bg: "#16161e", surface: "#1a1b26", surfaceHover: "#24283b", surfaceActive: "#2f334d",
            border: "#24283b", borderStrong: "#2f334d", borderInteractive: "#414868",
            text: "#c0caf5", textSecondary: "#9aa5ce", textDim: "#565f89",
            accent: "#7aa2f7", accentDim: "#1c2740", accentText: "#16161e",
            success: "#9ece6a", warning: "#e0af68", error: "#f7768e"
        },
        tokyoday: {
            bg: "#e1e2e7", surface: "#e9e9ed", surfaceHover: "#d5d6db", surfaceActive: "#c4c6cd",
            border: "#c4c6cd", borderStrong: "#8990b3", borderInteractive: "#3760bf",
            text: "#3760bf", textSecondary: "#6172b0", textDim: "#8990b3",
            accent: "#3760bf", accentDim: "#dfe5f7", accentText: "#ffffff",
            success: "#587539", warning: "#8c6c3e", error: "#f52a65"
        },
        tokyodark: {
            bg: "#11121d", surface: "#1a1b2a", surfaceHover: "#24263a", surfaceActive: "#31334d",
            border: "#24263a", borderStrong: "#353852", borderInteractive: "#4c5075",
            text: "#a0a8cd", textSecondary: "#71789c", textDim: "#4a506d",
            accent: "#ee6d85", accentDim: "#381c25", accentText: "#11121d",
            success: "#95c561", warning: "#d7a65f", error: "#f25b68"
        },
        tokyodark_light: {
            bg: "#f3f4f8", surface: "#e5e7f0", surfaceHover: "#d7dae6", surfaceActive: "#c5c9da",
            border: "#c5c9da", borderStrong: "#7b82a0", borderInteractive: "#e14a68",
            text: "#363a4d", textSecondary: "#5b627d", textDim: "#7b82a0",
            accent: "#e14a68", accentDim: "#fce8ed", accentText: "#ffffff",
            success: "#4f8a10", warning: "#d97706", error: "#e14a68"
        },
        rosepine: {
            bg: "#191724", surface: "#1f1d2e", surfaceHover: "#26233a", surfaceActive: "#393552",
            border: "#26233a", borderStrong: "#403d52", borderInteractive: "#524f67",
            text: "#e0def4", textSecondary: "#908caa", textDim: "#6e6a86",
            accent: "#c4a7e7", accentDim: "#2a2440", accentText: "#191724",
            success: "#9ccfd8", warning: "#f6c177", error: "#eb6f92"
        },
        rosepine_dawn: {
            bg: "#faf4ed", surface: "#fffaf3", surfaceHover: "#f2e9de", surfaceActive: "#e4dcd0",
            border: "#cecacd", borderStrong: "#9893a5", borderInteractive: "#907aa9",
            text: "#575279", textSecondary: "#797593", textDim: "#9893a5",
            accent: "#907aa9", accentDim: "#eee7f5", accentText: "#ffffff",
            success: "#56949f", warning: "#ea9d34", error: "#b4637a"
        },
        horizon: {
            bg: "#1a1c23", surface: "#21232d", surfaceHover: "#2b2d3a", surfaceActive: "#373a4a",
            border: "#2b2d3a", borderStrong: "#3e4256", borderInteractive: "#595e7b",
            text: "#e0e2ea", textSecondary: "#9da2b8", textDim: "#626880",
            accent: "#e95678", accentDim: "#361b24", accentText: "#1a1c23",
            success: "#29d398", warning: "#fab795", error: "#f43e5c"
        },
        horizon_light: {
            bg: "#fdf0ed", surface: "#fadad1", surfaceHover: "#f7c7b8", surfaceActive: "#f3ad9a",
            border: "#f3ad9a", borderStrong: "#da707a", borderInteractive: "#e95678",
            text: "#3b3842", textSecondary: "#6a6676", textDim: "#9a94a8",
            accent: "#e95678", accentDim: "#fde3ea", accentText: "#ffffff",
            success: "#21b380", warning: "#f2994a", error: "#e95678"
        },
        nightowl: {
            bg: "#011627", surface: "#0b253a", surfaceHover: "#11324d", surfaceActive: "#1d4263",
            border: "#11324d", borderStrong: "#1e4e78", borderInteractive: "#2c6b9e",
            text: "#d6deeb", textSecondary: "#89a4bb", textDim: "#5f7e97",
            accent: "#82aaff", accentDim: "#162842", accentText: "#011627",
            success: "#22da6e", warning: "#ecc48d", error: "#ef5350"
        },
        nightowl_light: {
            bg: "#f0f2f5", surface: "#e4e7eb", surfaceHover: "#d8dce2", surfaceActive: "#c6ccd6",
            border: "#c6ccd6", borderStrong: "#7e889b", borderInteractive: "#0c969b",
            text: "#403f53", textSecondary: "#5f687a", textDim: "#9099a8",
            accent: "#0c969b", accentDim: "#daf3f4", accentText: "#ffffff",
            success: "#2aa298", warning: "#da8b45", error: "#de3d35"
        },
        poimandres: {
            bg: "#1b1e28", surface: "#232735", surfaceHover: "#2d3243", surfaceActive: "#393f54",
            border: "#2d3243", borderStrong: "#41475d", borderInteractive: "#5a627e",
            text: "#e4f0fb", textSecondary: "#a6accd", textDim: "#5d637f",
            accent: "#5de4c7", accentDim: "#133833", accentText: "#1b1e28",
            success: "#5de4c7", warning: "#fffac2", error: "#d0679d"
        },
        poimandres_light: {
            bg: "#f4f6f8", surface: "#e7ebf0", surfaceHover: "#d9e0e8", surfaceActive: "#c8d2de",
            border: "#c8d2de", borderStrong: "#738091", borderInteractive: "#3e8fb0",
            text: "#303340", textSecondary: "#525968", textDim: "#7e8799",
            accent: "#3e8fb0", accentDim: "#e0f1f7", accentText: "#ffffff",
            success: "#3ba779", warning: "#dfa435", error: "#d0679d"
        },
        cyberpunk: {
            bg: "#100e1f", surface: "#1a162e", surfaceHover: "#262042", surfaceActive: "#362d5a",
            border: "#262042", borderStrong: "#413669", borderInteractive: "#5e4d94",
            text: "#f2eefe", textSecondary: "#a99ec9", textDim: "#6a5d8f",
            accent: "#ffe600", accentDim: "#3d3708", accentText: "#100e1f",
            success: "#00ff9f", warning: "#ff9900", error: "#ff0055"
        },
        cyberpunk_light: {
            bg: "#f8f7ff", surface: "#eeeafd", surfaceHover: "#e2dcfc", surfaceActive: "#d0c5fa",
            border: "#d0c5fa", borderStrong: "#9b8afb", borderInteractive: "#d9006c",
            text: "#201a35", textSecondary: "#584e78", textDim: "#8c7fae",
            accent: "#d9006c", accentDim: "#fce0ef", accentText: "#ffffff",
            success: "#00a86b", warning: "#d97706", error: "#d9006c"
        },
        onedark: {
            bg: "#21252b", surface: "#282c34", surfaceHover: "#2f343d", surfaceActive: "#3b4048",
            border: "#2f343d", borderStrong: "#3e4451", borderInteractive: "#4b5263",
            text: "#abb2bf", textSecondary: "#828997", textDim: "#5c6370",
            accent: "#61afef", accentDim: "#17303f", accentText: "#21252b",
            success: "#98c379", warning: "#e5c07b", error: "#e06c75"
        },
        onelight: {
            bg: "#fafafa", surface: "#f0f0f0", surfaceHover: "#e5e5e6", surfaceActive: "#d7d7d8",
            border: "#e5e5e6", borderStrong: "#a0a1a7", borderInteractive: "#4078f2",
            text: "#383a42", textSecondary: "#696c77", textDim: "#a0a1a7",
            accent: "#4078f2", accentDim: "#e0eafc", accentText: "#ffffff",
            success: "#50a14f", warning: "#c18401", error: "#e45649"
        },
        everforest: {
            bg: "#272e33", surface: "#2d353b", surfaceHover: "#374145", surfaceActive: "#475258",
            border: "#374145", borderStrong: "#475258", borderInteractive: "#4f5b58",
            text: "#d3c6aa", textSecondary: "#9da9a0", textDim: "#7a8478",
            accent: "#a7c080", accentDim: "#233324", accentText: "#272e33",
            success: "#a7c080", warning: "#dbbc7f", error: "#e67e80"
        },
        everforest_light: {
            bg: "#fdf6e3", surface: "#f4f0d9", surfaceHover: "#ebe5c8", surfaceActive: "#ded5b5",
            border: "#ded5b5", borderStrong: "#939f91", borderInteractive: "#8da101",
            text: "#5c6a72", textSecondary: "#708089", textDim: "#939f91",
            accent: "#8da101", accentDim: "#f0f4da", accentText: "#ffffff",
            success: "#8da101", warning: "#dfa000", error: "#f85552"
        },
        kanagawa: {
            bg: "#16161d", surface: "#1f1f28", surfaceHover: "#2a2a37", surfaceActive: "#363646",
            border: "#2a2a37", borderStrong: "#363646", borderInteractive: "#54546d",
            text: "#dcd7ba", textSecondary: "#938aa9", textDim: "#716e61",
            accent: "#7e9cd8", accentDim: "#1f2b45", accentText: "#16161d",
            success: "#76946a", warning: "#e6c384", error: "#c34043"
        },
        kanagawa_lotus: {
            bg: "#f2ecde", surface: "#e7e0ce", surfaceHover: "#ddd5c0", surfaceActive: "#cfc5ae",
            border: "#cfc5ae", borderStrong: "#8a8980", borderInteractive: "#4d699b",
            text: "#545464", textSecondary: "#716e61", textDim: "#8a8980",
            accent: "#4d699b", accentDim: "#e2e8f3", accentText: "#ffffff",
            success: "#6e915f", warning: "#de9800", error: "#c84053"
        },
        monokaipro: {
            bg: "#19181a", surface: "#221f22", surfaceHover: "#2d2a2e", surfaceActive: "#3a363b",
            border: "#2d2a2e", borderStrong: "#403e41", borderInteractive: "#727072",
            text: "#fcfcfa", textSecondary: "#939293", textDim: "#5b595c",
            accent: "#ffd866", accentDim: "#3d3518", accentText: "#19181a",
            success: "#a9dc76", warning: "#fc9867", error: "#ff6188"
        },
        monokaipro_light: {
            bg: "#fafafa", surface: "#ececec", surfaceHover: "#dfdfdf", surfaceActive: "#cccccc",
            border: "#cccccc", borderStrong: "#939293", borderInteractive: "#ff6188",
            text: "#403e41", textSecondary: "#69676c", textDim: "#939293",
            accent: "#ff6188", accentDim: "#ffe6ec", accentText: "#ffffff",
            success: "#78b833", warning: "#fc9867", error: "#ff6188"
        },
        solarized: {
            bg: "#002b36", surface: "#073642", surfaceHover: "#0c4352", surfaceActive: "#145365",
            border: "#0d4857", borderStrong: "#586e75", borderInteractive: "#657b83",
            text: "#839496", textSecondary: "#586e75", textDim: "#657b83",
            accent: "#268bd2", accentDim: "#073642", accentText: "#fdf6e3",
            success: "#859900", warning: "#b58900", error: "#dc322f"
        },
        solarized_light: {
            bg: "#fdf6e3", surface: "#eee8d5", surfaceHover: "#e4dcbe", surfaceActive: "#dacfa6",
            border: "#d3cbb7", borderStrong: "#93a1a1", borderInteractive: "#268bd2",
            text: "#586e75", textSecondary: "#657b83", textDim: "#93a1a1",
            accent: "#268bd2", accentDim: "#def0fa", accentText: "#fdf6e3",
            success: "#859900", warning: "#b58900", error: "#dc322f"
        },
        githubdark: {
            bg: "#0d1117", surface: "#161b22", surfaceHover: "#21262d", surfaceActive: "#30363d",
            border: "#21262d", borderStrong: "#30363d", borderInteractive: "#484f58",
            text: "#c9d1d9", textSecondary: "#8b949e", textDim: "#484f58",
            accent: "#58a6ff", accentDim: "#162e4f", accentText: "#0d1117",
            success: "#3fb950", warning: "#d29922", error: "#f85149"
        },
        github_light: {
            bg: "#ffffff", surface: "#f6f8fa", surfaceHover: "#eaeef2", surfaceActive: "#d0d7de",
            border: "#d0d7de", borderStrong: "#afb8c1", borderInteractive: "#0969da",
            text: "#24292f", textSecondary: "#57606a", textDim: "#8c959f",
            accent: "#0969da", accentDim: "#ddf4ff", accentText: "#ffffff",
            success: "#1a7f37", warning: "#9a6700", error: "#cf222e"
        },
        synthwave: {
            bg: "#1a102f", surface: "#241b35", surfaceHover: "#2d2244", surfaceActive: "#3b2d59",
            border: "#2d2244", borderStrong: "#46346b", borderInteractive: "#614392",
            text: "#f92aad", textSecondary: "#b68cf2", textDim: "#685588",
            accent: "#03edf9", accentDim: "#12384a", accentText: "#1a102f",
            success: "#72f1b8", warning: "#fede5d", error: "#fe4450"
        },
        synthwave_light: {
            bg: "#faf5ff", surface: "#f3e8ff", surfaceHover: "#e9d5ff", surfaceActive: "#d8b4fe",
            border: "#d8b4fe", borderStrong: "#a855f7", borderInteractive: "#9333ea",
            text: "#581c87", textSecondary: "#7e22ce", textDim: "#a855f7",
            accent: "#9333ea", accentDim: "#f3e8ff", accentText: "#ffffff",
            success: "#059669", warning: "#d97706", error: "#e11d48"
        },
        oxocarbon: {
            bg: "#161616", surface: "#262626", surfaceHover: "#333333", surfaceActive: "#393939",
            border: "#333333", borderStrong: "#525252", borderInteractive: "#6f6f6f",
            text: "#f4f4f4", textSecondary: "#c6c6c6", textDim: "#6f6f6f",
            accent: "#3ddbd9", accentDim: "#123637", accentText: "#161616",
            success: "#42be65", warning: "#ffe97b", error: "#ee5396"
        },
        oxocarbon_light: {
            bg: "#ffffff", surface: "#f2f4f8", surfaceHover: "#e5e8f0", surfaceActive: "#dde1eb",
            border: "#dde1eb", borderStrong: "#a2a9b7", borderInteractive: "#0f62fe",
            text: "#161616", textSecondary: "#525252", textDim: "#8d8d8d",
            accent: "#0f62fe", accentDim: "#edf5ff", accentText: "#ffffff",
            success: "#198038", warning: "#b28600", error: "#da1e28"
        },
        palenight: {
            bg: "#292d3e", surface: "#1f2233", surfaceHover: "#32374d", surfaceActive: "#3e445e",
            border: "#32374d", borderStrong: "#444b6a", borderInteractive: "#676e95",
            text: "#a6accd", textSecondary: "#717cb4", textDim: "#505777",
            accent: "#c792ea", accentDim: "#352747", accentText: "#1f2233",
            success: "#c3e88d", warning: "#ffcb6b", error: "#ff5370"
        },
        palenight_light: {
            bg: "#f5f6fa", surface: "#eaecf4", surfaceHover: "#dce0ee", surfaceActive: "#cbd2e4",
            border: "#cbd2e4", borderStrong: "#8792b5", borderInteractive: "#7c4dff",
            text: "#474b66", textSecondary: "#636888", textDim: "#8792b5",
            accent: "#7c4dff", accentDim: "#ede7ff", accentText: "#ffffff",
            success: "#388e3c", warning: "#f57c00", error: "#d32f2f"
        },
        void: {
            bg: "#050505", surface: "#0e0e10", surfaceHover: "#18181c", surfaceActive: "#24242a",
            border: "#1c1c22", borderStrong: "#2e2e38", borderInteractive: "#464654",
            text: "#f5f5f7", textSecondary: "#9e9ea8", textDim: "#5c5c66",
            accent: "#ffffff", accentDim: "#26262b", accentText: "#050505",
            success: "#34d399", warning: "#fbbf24", error: "#f87171"
        },
        void_light: {
            bg: "#ffffff", surface: "#f4f4f5", surfaceHover: "#e4e4e7", surfaceActive: "#d4d4d8",
            border: "#d4d4d8", borderStrong: "#a1a1aa", borderInteractive: "#18181b",
            text: "#18181b", textSecondary: "#52525b", textDim: "#71717a",
            accent: "#18181b", accentDim: "#f4f4f5", accentText: "#ffffff",
            success: "#16a34a", warning: "#d97706", error: "#dc2626"
        }
    })

    readonly property string effectivePreset: {
        if (mode === "light") {
            if (isLightPreset(presetName)) return presetName
            return darkToLight[presetName] || lightPreset || "ayu_light"
        }
        if (mode === "dark") {
            if (isDarkPreset(presetName)) return presetName
            return lightToDark[presetName] || darkPreset || "ayu"
        }
        // mode === "auto"
        if (isDaytime) {
            return isLightPreset(lightPreset) ? lightPreset : (darkToLight[lightPreset] || darkToLight[darkPreset] || "ayu_light")
        } else {
            return isDarkPreset(darkPreset) ? darkPreset : (lightToDark[darkPreset] || lightToDark[lightPreset] || "ayu")
        }
    }

    readonly property var active: presets[effectivePreset] || presets[presetName] || presets.ayu
    readonly property bool isLight: _lum(active.bg) > 0.5
    readonly property bool isDark: !isLight
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

    // ─── Media chrome (deliberately theme-independent) ────────────────────────
    // The wallpaper browsers render other people's images. Tinting the surface
    // around a thumbnail with the user's accent misreports the image's own
    // colours, so this group stays fixed across every preset -- the same reason
    // Brand.qml's colours do. Named here rather than repeated as literals in the
    // four browser files, which had already drifted apart.
    readonly property color mediaBackdrop: "#05070a"    // full-bleed image viewport
    readonly property color mediaDim: "#d9000000"       // scrim behind a detail modal
    readonly property color mediaScrim: "#cc000000"     // caption/badge plate over a thumbnail
    readonly property color mediaPanel: "#ee090c14"     // download-progress panel on a tile
    readonly property color mediaShield: "#ee0f121a"    // NSFW cover over a tile
    readonly property color ratingStar: "#ffca28"       // a rating star is gold in every theme

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
    readonly property int groupPadding: Math.max(2, Math.round(4 * barDensity))  // inner padding inside a floating group
    property int groupRadius: radiusMd

    // One height and one horizontal padding for every control that lives inside
    // a bar group. Each module used to pick its own -- triggers were barHeight-6,
    // the clock and the weather chip were the full barHeight, workspace squares
    // were a fixed 22 -- so hover plates of three different sizes sat next to
    // each other and raising bar.height stretched some of them and not others.
    readonly property int barItemHeight: Math.max(16, barHeight - 6)
    // bar.density is what the "Bar Element Density" control in settings writes.
    // It had no reader at all, so the control was inert; it scales the padding
    // the bar builds itself from. "auto" follows bar.height, on the reasoning
    // that someone who shrinks the bar wants the contents to tighten with it.
    readonly property real barDensity: {
        var d = SettingsBus.get("bar.density", "auto")
        if (d === "dense")   return 0.5
        if (d === "compact") return 0.75
        if (d === "normal")  return 1.0
        return barHeight >= 34 ? 1.0 : 0.8
    }
    readonly property int barItemPadding: Math.max(2, Math.round(7 * barDensity))
    // An icon-only control is square, so it scales with bar.height too.
    readonly property int barItemSquare: barItemHeight
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
    // Derived so every control inside a group is one height (see barItemHeight).
    readonly property int workspacePillSize: barItemHeight
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
