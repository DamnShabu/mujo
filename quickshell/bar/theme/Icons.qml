pragma Singleton
import QtQuick
import Quickshell

// Standard-action icons, resolved from the desktop's own icon theme.
//
// The shell names its icons after Material Symbols. This maps those names onto
// the freedesktop names the installed theme actually ships (Colloid, set in
// nixos/desktop/gtk.nix, with Adwaita behind it) so that every standard control
// — close, refresh, copy, lock, search — draws the icon the user's GTK apps
// draw. A name with no honest freedesktop equivalent is simply absent here:
// MaterialIcon keeps its glyph for those, which is why a missing entry is much
// better than an approximate one.
//
// Only *symbolic* variants are mapped. They are monochrome line art meant to be
// recoloured by the caller, which is what lets a 16px bar icon inherit the theme
// foreground; the full-colour variants of the same names turn to mud that small.
// File-type icons are the opposite case — full colour is the desktop convention
// there — so `fileIcon` deliberately skips the symbolic set.
QtObject {
    id: root

    // ─── Standard UI actions ──────────────────────────────────────────────────
    readonly property var actions: ({
        "accessibility": "preferences-desktop-accessibility",
        "accessibility_new": "preferences-desktop-accessibility",
        "account_circle": "avatar-default",
        "add": "list-add",
        "add_circle": "list-add",
        "add_circle_outline": "list-add",
        "apps": "view-app-grid",
        "arrow_back": "go-previous",
        "arrow_upward": "go-up",
        "calculate": "accessories-calculator",
        "category": "applications-other",
        "check": "object-select",
        "check_circle": "emblem-ok",
        "close": "window-close",
        "cloud_off": "network-offline",
        "content_copy": "edit-copy",
        "content_paste": "edit-paste",
        "delete": "user-trash",
        "delete_outline": "user-trash",
        "delete_sweep": "user-trash-full",
        "dns": "network-server",
        "do_not_disturb_on": "notifications-disabled",
        "download": "browser-download",
        "drag_indicator": "list-drag-handle",
        "draw": "document-edit",
        "drive_file_move": "edit-move",
        "edit": "document-edit",
        "equalizer": "multimedia-equalizer",
        "error": "dialog-error",
        "error_outline": "dialog-error",
        "event_upcoming": "appointment-soon",
        "extension": "application-x-addon",
        "file_download": "document-save",
        "flip": "object-flip-horizontal",
        "folder_open": "folder-open",
        "format_list_numbered": "format-justify-fill",
        "grid_view": "view-grid",
        "history": "document-open-recent",
        "hourglass_top": "process-working",
        "image": "image-x-generic",
        "inbox": "mail-inbox",
        "info": "dialog-information",
        "inventory_2": "package-x-generic",
        "key": "dialog-password",
        "key_vertical": "dialog-password",
        "keyboard_arrow_down": "pan-down",
        "keyboard_arrow_up": "pan-up",
        "location_on": "mark-location",
        "lock": "changes-prevent",
        "lock_clock": "system-lock-screen",
        "lock_open": "changes-allow",
        "minimize": "window-minimize",
        "monitor": "video-display",
        "monitoring": "utilities-system-monitor",
        "more_horiz": "view-more",
        "mouse": "input-mouse",
        "music_note": "audio-x-generic",
        "notifications_paused": "notifications-disabled",
        "open_in_new": "window-new",
        "palette": "applications-graphics",
        "password": "dialog-password",
        "power_settings_new": "system-shutdown",
        "progress_activity": "process-working",
        "refresh": "view-refresh",
        "restart_alt": "system-reboot",
        "schedule": "alarm",
        "search": "system-search",
        "security": "security-high",
        "settings_suggest": "preferences-system",
        "shield": "security-high",
        "skip_next": "media-skip-forward",
        "skip_previous": "media-skip-backward",
        "speaker": "audio-speakers",
        "star": "starred",
        "terminal": "utilities-terminal",
        "timer": "alarm",
        "translate": "accessories-dictionary",
        "tune": "preferences-other",
        "vertical_align_top": "go-top",
        "view_carousel": "view-continuous",
        "view_day": "view-list",
        "visibility_off": "view-conceal",
        "volume_up": "audio-volume-high",
        "wallpaper": "preferences-desktop-wallpaper",
        "warning": "dialog-warning",
        "web_asset": "web-browser",
        "widgets": "applications-utilities",
        "wifi": "network-wireless-signal-excellent"
    })

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

    // Themed symbolic icon for a Material Symbol name, or "".
    function path(icon) {
        var fd = root.actions[icon]
        return fd === undefined ? "" : root.first([fd + "-symbolic"])
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
