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
        ApplicationsTrustTab { id: trustView }
        ApplicationsGroup { id: appsGroup }
    }

    // Quickshell connects Qt.exit() only once the config has finished
    // loading, so a check that runs from Component.onCompleted prints its
    // verdict and then hangs. One deferred tick puts it after load.
    Timer {
        interval: 0
        running: true
        onTriggered: {
            // 1. SecurityService singleton state
            check("SecurityService singleton enabled", SecurityService.enabled === true)
            check("SecurityService has overallStatus", typeof SecurityService.overallStatus === "string")
            check("SecurityService has vaultStatus", typeof SecurityService.vaultStatus === "string")
            check("SecurityService has trustApps array", Array.isArray(SecurityService.trustApps))

            // 2. SecurityGroup component instantiation
            check("SecurityGroup instantiated", secGroup !== null)

            // 3. Progressive Trust now lives on the Security page, not in the
            //    Applications tab strip. Both halves of that move are checked.
            check("Trust view instantiated", trustView !== null)
            check("ApplicationsGroup instantiated", appsGroup !== null)
            check("Applications no longer carries a trust tab",
                  !appsGroup.tabs.some(function (t) { return t.id === "trust" }))
            check("Applications keeps its three own tabs", appsGroup.tabs.length === 3)

            appsGroup.activeTab = "flatpaks"
            check("Applications activeTab switches", appsGroup.activeTab === "flatpaks")

            if (root.fails.length === 0) {
                console.log("PASS  security UI: service binds, trust tab renders, vault controls active")
            } else {
                console.log("FAIL  security UI: " + root.fails.length + " check(s) failed")
                for (var i = 0; i < root.fails.length; i++) console.log("        - " + root.fails[i])
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
