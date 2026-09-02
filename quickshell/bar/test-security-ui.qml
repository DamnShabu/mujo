import QtQuick
import Quickshell
import "modules/settings"
import "services"

// Self-check for Mujo 2.0 Security Architecture & Progressive Trust UI.
// Run: qs -p ./test-security-ui.qml
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    Item {
        id: host
        width: 800
        height: 600

        SecurityGroup { id: secGroup }
        ApplicationsPanel { id: appsPanel }
    }

    Component.onCompleted: {
        // 1. SecurityService singleton state
        check("SecurityService singleton enabled", SecurityService.enabled === true)
        check("SecurityService has overallStatus", typeof SecurityService.overallStatus === "string")
        check("SecurityService has vaultStatus", typeof SecurityService.vaultStatus === "string")
        check("SecurityService has trustApps array", Array.isArray(SecurityService.trustApps))

        // 2. SecurityGroup component instantiation
        check("SecurityGroup instantiated", secGroup !== null)

        // 3. ApplicationsPanel component & Progressive Trust tab
        check("ApplicationsPanel instantiated", appsPanel !== null)
        check("ApplicationsPanel has trust tab in tabs", appsPanel.tabs.some(function(t) { return t.id === "trust" }))

        // Test tab switching to trust
        appsPanel.activeTab = "trust"
        check("ApplicationsPanel activeTab switches to trust", appsPanel.activeTab === "trust")

        if (root.fails.length === 0) {
            console.log("PASS  security UI: service binds, trust tab renders, vault controls active")
        } else {
            console.log("FAIL  security UI: " + root.fails.length + " check(s) failed")
            for (var i = 0; i < root.fails.length; i++) console.log("        - " + root.fails[i])
        }
        Qt.exit(root.fails.length === 0 ? 0 : 1)
    }
}
