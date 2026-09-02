import QtQuick
import Quickshell
import "modules/settings"
import "services"

// Self-check for the settings shell primitives. Run: qs -p ./test-settings-ui.qml
//
// Read-only: it asserts that SettingRow reads the live store and that
// SettingsLayout resolves a panel key to its owning category. Nothing is
// written, so running it never touches settings.json.
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    Item {
        id: host
        width: 400
        height: 300

        SettingRow { id: rToggle; path: "bar.autoHide"; kind: "toggle"; def: false; title: "t" }
        SettingRow { id: rSlider; path: "bar.height"; kind: "slider"; def: 34; from: 20; to: 60; title: "s" }
        SettingRow { id: rSeg; path: "bar.position"; kind: "segment"; def: "top"; options: ["top", "bottom"]; title: "g" }
        SettingRow { id: rText; path: "general.hostname"; kind: "text"; def: "main"; title: "x" }

        SettingsPage { id: page; title: "Probe"; brand: "system" }

        SettingsLayout {
            id: layout
            categories: [
                { key: "alpha", label: "Alpha", icon: "tune", panels: [{ key: "one", label: "One" }, { key: "two", label: "Two" }] },
                { key: "beta", label: "Beta", icon: "palette", keys: ["extra"], badge: 3 }
            ]
        }
    }

    // Quickshell connects Qt.exit() only once the config has finished
    // loading, so a check that runs from Component.onCompleted prints its
    // verdict and then hangs. One deferred tick puts it after load.
    Timer {
        interval: 0
        running: true
        onTriggered: {
            // Rows mirror the store, so a panel never has to re-read it by hand.
            check("toggle reads store", rToggle.value === SettingsBus.get("bar.autoHide", false))
            check("slider reads store", Number(rSlider.value) === Number(SettingsBus.get("bar.height", 34)))
            check("segment reads store", rSeg.value === SettingsBus.get("bar.position", "top"))
            check("text reads store", String(rText.value) === String(SettingsBus.get("general.hostname", "main")))

            // Page host exists and scrolls from the top.
            check("page starts unscrolled", page.contentY === 0)

            // Routing: category key, panel key, page-claimed key, unknown key.
            layout.route("beta")
            check("route to category", layout.current === "beta")
            layout.route("two")
            check("route to panel selects category", layout.current === "alpha")
            check("route to panel selects panel", layout.panelOf(layout.categories[0]) === "two")
            layout.route("extra")
            check("route via page keys", layout.current === "beta")
            layout.route("nonexistent")
            check("unknown key changes nothing", layout.current === "beta")

            // Default panel is the first one when none was chosen.
            check("default panel", layout.panelOf(layout.categories[1]) === "")

            if (root.fails.length === 0) {
                console.log("PASS  settings UI: rows bind, page hosts, routing resolves")
            } else {
                console.log("FAIL  settings UI: " + root.fails.length + " check(s) failed")
                for (var i = 0; i < root.fails.length; i++) console.log("        - " + root.fails[i])
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
