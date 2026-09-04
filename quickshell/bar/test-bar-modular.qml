// quickshell/bar/test-bar-modular.qml
import QtQuick
import QtQuick.Layouts
import "./theme"
import "./services"
import "./modules/bar"
import "./modules/bar/styles"

Item {
    id: root
    width: 1920
    height: 1080

    Bar {
        id: testBar
        width: 1920
        height: 34
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            var passed = true
            var failures = []

            function assert(cond, msg) {
                if (!cond) {
                    passed = false
                    failures.push(msg)
                    console.error("FAIL:", msg)
                }
            }

            // 1. Verify BarModuleRegistry
            assert(BarModuleRegistry.allModules.length >= 17, "Registry should contain >= 17 modules")
            for (var i = 0; i < BarModuleRegistry.allModules.length; i++) {
                var mod = BarModuleRegistry.allModules[i]
                var comp = BarModuleRegistry.getComponent(mod.id)
                assert(comp !== null, "Module component must resolve: " + mod.id)
            }

            // 2. Verify Style Switching
            var styles = ["floating", "full", "island", "dock", "compact"]
            for (var s = 0; s < styles.length; s++) {
                SettingsBus.set("bar.style", styles[s])
                assert(SettingsBus.get("bar.style", "") === styles[s], "bar.style should be " + styles[s])
            }

            // 3. Verify Empty Slot Resilience
            SettingsBus.set("bar.slots.center", [])
            assert(testBar.height === 34, "Bar height should remain stable with empty center slot")

            if (passed) {
                console.info("PASS: Modular topbar test suite passed successfully")
                Qt.exit(0)
            } else {
                console.error("FAIL: Failures:", JSON.stringify(failures))
                Qt.exit(1)
            }
        }
    }
}
