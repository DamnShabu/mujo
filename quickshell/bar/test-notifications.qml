import QtQuick
import Quickshell
import "./services"
import "./theme"

// Self-check for Notifications daemon & popup mechanisms.
// Run: qs -p ./test-notifications.qml
ShellRoot {
    Component.onCompleted: {
        var fails = []

        // 1. Initial State
        Notifications.clearHistory()
        if (Notifications.history.length !== 0) fails.push("clearHistory failed to empty history")

        // 2. Synthetic Notification injection
        Notifications.notify("Test Notification", "Testing notification body", "dialog-information", "normal", {
            appName: "TestApp",
            progress: 50
        })

        if (Notifications.popups.length !== 1) fails.push("Popup was not added to popups stack (length: " + Notifications.popups.length + ")")
        if (Notifications.history.length !== 1) fails.push("Notification was not recorded in history")

        var rec = Notifications.popups[0] ? Notifications.popups[0].rec : null
        if (!rec || rec.appName !== "TestApp") fails.push("Record appName mismatch")
        if (!rec || rec.progress !== 50) fails.push("Record progress mismatch")

        // 3. Icon resolution
        var resolvedIcon = Notifications.resolveIcon(rec)
        if (typeof resolvedIcon !== "string") fails.push("resolveIcon returned non-string")

        // 4. Multiple notifications & Grouping
        Notifications.notify("Second Test", "Body 2", "chat", "normal", { appName: "ChatApp" })
        Notifications.notify("Third Test", "Body 3", "chat", "normal", { appName: "ChatApp" })

        var groups = Notifications.grouped()
        if (groups.length !== 2) fails.push("grouped() expected 2 groups, got: " + groups.length)

        var chatGrp = null
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].appName === "ChatApp") chatGrp = groups[i]
        }
        if (!chatGrp || chatGrp.items.length !== 2) fails.push("ChatApp group expected 2 items, got: " + (chatGrp ? chatGrp.items.length : 0))

        // 5. Per-app clearing
        Notifications.clearAppHistory("ChatApp")
        if (Notifications.history.length !== 1) fails.push("clearAppHistory failed: history length is " + Notifications.history.length)

        // 6. Dismiss popup
        if (rec) Notifications.dismissPopup(rec.id)
        if (Notifications.popups.length !== 2) fails.push("dismissPopup failed: popups length is " + Notifications.popups.length)

        // Clean up
        Notifications.clearHistory()

        if (fails.length === 0) {
            console.log("PASS  Notifications: daemon, icon resolver, grouping, and history tests succeeded")
        } else {
            console.log("FAIL  Notifications: " + fails.length + " errors")
            for (var j = 0; j < fails.length; j++) console.log("        - " + fails[j])
        }
        Qt.exit(fails.length === 0 ? 0 : 1)
    }
}
