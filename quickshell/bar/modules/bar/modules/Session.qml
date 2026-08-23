pragma Singleton
import QtQuick
import Quickshell

// Session actions (WP-10), one source for the `/` palette and the bar power
// button. Lock is always available (non-destructive); the rest are gated behind
// launcher.enableDangerousActions (default off) and callers add a confirm step.
QtObject {
    id: session

    readonly property bool dangerAllowed: SettingsBus.get("launcher.enableDangerousActions", false)

    // { id, title, icon, danger }. UIs filter danger ones out when !dangerAllowed.
    readonly property var actions: [
        { id: "lock",     title: "Lock",      icon: "lock",                danger: false },
        { id: "logout",   title: "Log out",   icon: "logout",              danger: true  },
        { id: "suspend",  title: "Suspend",   icon: "bedtime",             danger: true  },
        { id: "reboot",   title: "Reboot",    icon: "restart_alt",         danger: true  },
        { id: "shutdown", title: "Shut down", icon: "power_settings_new",  danger: true  }
    ]

    function available() {
        return session.actions.filter(function (a) { return !a.danger || session.dangerAllowed })
    }

    function run(id) {
        if (id === "lock") Lock.lock()   // WP-14: native session lock, same process
        else if (id === "logout") Quickshell.execDetached(["loginctl", "terminate-user", Quickshell.env("USER") || ""])
        else if (id === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (id === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
        else if (id === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
    }
}
