pragma Singleton
import QtQuick

// Brand / service iconography. Each entry has a brand color and either an inline
// SVG glyph (`svg`, a 24×24 path body) or a Material Symbols name (`mat`) drawn
// on a brand-tinted tile. Used by BrandIcon across nav, integrations, Overview,
// and the Mullvad/Usage pages so services read with their real visual identity
// rather than monochrome placeholders.
QtObject {
    id: brand

    // Anthropic + Discord use their real logo paths; the rest use a tasteful
    // Material glyph on the brand color so the whole set stays consistent.
    readonly property var brands: ({
        anthropic: { color: "#D97757", fg: "#ffffff",
            svg: "M17.3041 3.541h-3.6718l6.696 16.918H24Zm-10.6082 0L0 20.459h3.7442l1.3693-3.5527h7.0052l1.3693 3.5528h3.7442L10.5363 3.541Zm-.3712 10.2232 2.2914-5.9456 2.2914 5.9456Z" },
        claude: { color: "#D97757", fg: "#ffffff",
            svg: "M17.3041 3.541h-3.6718l6.696 16.918H24Zm-10.6082 0L0 20.459h3.7442l1.3693-3.5527h7.0052l1.3693 3.5528h3.7442L10.5363 3.541Zm-.3712 10.2232 2.2914-5.9456 2.2914 5.9456Z" },
        discord: { color: "#5865F2", fg: "#ffffff",
            svg: "M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z" },
        mullvad:  { color: "#F6C915", fg: "#181818", mat: "vpn_key" },
        telegram: { color: "#26A5E4", fg: "#ffffff", mat: "send" },
        feishin:  { color: "#1DB954", fg: "#ffffff", mat: "library_music" },
        obsidian: { color: "#7C3AED", fg: "#ffffff", mat: "book" },
        zen:      { color: "#F76B15", fg: "#ffffff", mat: "public" },
        opencode: { color: "#10B981", fg: "#ffffff", mat: "code" },
        superprod:{ color: "#7C4DFF", fg: "#ffffff", mat: "checklist" },
        nixos:    { color: "#5277C3", fg: "#ffffff", text: "λ" },
        niri:     { color: "#4C8BF5", fg: "#ffffff", mat: "grid_view" },

        // Section identities
        appearance:  { color: "#E879C7", fg: "#ffffff", mat: "palette" },
        wallpaper:   { color: "#38BDF8", fg: "#ffffff", mat: "wallpaper" },
        desktop:     { color: "#F59E0B", fg: "#ffffff", mat: "desktop_windows" },
        display:     { color: "#22D3EE", fg: "#181818", mat: "monitor" },
        devices:     { color: "#A78BFA", fg: "#ffffff", mat: "keyboard" },
        keyboard:    { color: "#A78BFA", fg: "#ffffff", mat: "keyboard" },
        mouse:       { color: "#60A5FA", fg: "#ffffff", mat: "mouse" },
        network:     { color: "#34D399", fg: "#181818", mat: "vpn_lock" },
        keyring:     { color: "#FBBF24", fg: "#181818", mat: "key" },
        persistence: { color: "#F472B6", fg: "#ffffff", mat: "hard_drive" },
        applications:{ color: "#818CF8", fg: "#ffffff", mat: "apps" },
        integrations:{ color: "#818CF8", fg: "#ffffff", mat: "extension" },
        shortcuts:   { color: "#94A3B8", fg: "#181818", mat: "keyboard_command_key" },
        system:      { color: "#5277C3", fg: "#ffffff", text: "λ" },
        overview:    { color: "#F59E0B", fg: "#ffffff", mat: "dashboard" },
        usage:       { color: "#D97757", fg: "#ffffff", mat: "monitoring" }
    })

    function has(name) { return brands[name] !== undefined }
    function get(name) { return brands[name] || { color: "#888888", fg: "#ffffff", mat: "widgets" } }

    // Build a data: URI for the brand's SVG glyph, tinted `fill`.
    function svgUri(name, fill) {
        var b = get(name)
        if (!b.svg) return ""
        var f = encodeURIComponent(fill || b.fg)
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>"
             + "<path fill='" + f + "' d='" + b.svg + "'/></svg>"
    }
}
