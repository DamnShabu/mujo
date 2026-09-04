pragma Singleton
import QtQuick
import Quickshell

// Freedesktop system icon resolution for application entries and file MIME types.
//
// Standard UI controls use Material Symbols directly via MaterialIcon.qml.
// This singleton resolves full-colour freedesktop icon theme assets for:
// 1. Application launcher / window icons (appIcon, iconSource)
// 2. Desktop file MIME types (fileIcon, fileTypes)
QtObject {
    id: root

    // ─── File types ───────────────────────────────────────────────────────────
    // Keyed by extension because ~/Desktop entries are overwhelmingly
    // recognisable by one, and asking `file` per item would cost a process per
    // icon on every poll. Anything unlisted lands on the generic document icon,
    // exactly as a file manager would show it.
    readonly property var fileTypes: ({
        "png": "image-x-generic", "jpg": "image-x-generic", "jpeg": "image-x-generic",
        "gif": "image-x-generic", "webp": "image-x-generic", "svg": "image-svg+xml",
        "bmp": "image-x-generic", "avif": "image-x-generic",
        "mp4": "video-x-generic", "mkv": "video-x-generic", "webm": "video-x-generic",
        "mov": "video-x-generic", "avi": "video-x-generic",
        "mp3": "audio-x-generic", "flac": "audio-x-generic", "wav": "audio-x-generic",
        "ogg": "audio-x-generic", "m4a": "audio-x-generic",
        "pdf": "application-pdf",
        "zip": "package-x-generic", "tar": "package-x-generic", "gz": "package-x-generic",
        "xz": "package-x-generic", "zst": "package-x-generic", "7z": "package-x-generic",
        "rar": "package-x-generic",
        "txt": "text-x-generic", "md": "text-x-markdown", "rst": "text-x-generic",
        "org": "text-x-generic",
        "sh": "application-x-shellscript", "py": "text-x-python",
        "js": "text-x-javascript", "ts": "text-x-typescript", "nix": "text-x-script",
        "qml": "text-x-qml", "rs": "text-x-rust", "go": "text-x-go",
        "c": "text-x-csrc", "cpp": "text-x-c++src",
        "json": "application-json", "yaml": "text-x-generic", "yml": "text-x-generic",
        "toml": "text-x-generic", "xml": "text-xml",
        "ttf": "font-x-generic", "otf": "font-x-generic",
        "desktop": "application-x-executable"
    })

    // First name the theme actually ships, or "" if it ships none. Callers treat
    // "" as "keep whatever you were drawing before", so a theme with holes in it
    // degrades one icon at a time instead of leaving blank squares.
    function first(names) {
        for (var i = 0; i < names.length; i++)
            if (Quickshell.hasThemeIcon(names[i])) return Quickshell.iconPath(names[i])
        return ""
    }

    // An icon name, absolute path or URI as an Image source. Bare names go
    // through the icon theme and land on the generic executable icon when it
    // ships none, so a caller always has something to draw.
    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") >= 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    // Full-colour application icon for a window's appId, the way a taskbar shows
    // it: the app's own .desktop entry first, the appId as a theme icon name
    // second (many apps ship one under their window class), generic last.
    function appIcon(appId) {
        if (!appId) return ""
        var entry = DesktopEntries.heuristicLookup(appId)
        return root.iconSource(entry && entry.icon ? entry.icon : appId)
    }

    // Full-colour MIME icon for a ~/Desktop entry, or "".
    function fileIcon(name, isDir) {
        if (isDir) return root.first(["folder", "inode-directory"])
        var dot = name.lastIndexOf(".")
        var ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : ""
        var fd = root.fileTypes[ext]
        return root.first(fd === undefined ? ["text-x-generic"] : [fd, "text-x-generic"])
    }
}
