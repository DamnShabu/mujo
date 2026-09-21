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

    // A deliberately cramped bar: three full clusters cannot fit in 640px, which
    // is what the zone arbitration in BarLayout exists to survive.
    BarLayout {
        id: narrow
        width: 640
        height: 34
    }

    // Two one-module zones for the collapse check below. `battery` reports
    // absent until its probe answers -- and on this desktop, for good -- so it
    // stands in for any module that hides itself.
    BarSlot { id: hiddenSlot; modules: ["battery"]; wrapInCluster: false }
    BarSlot { id: shownSlot;  modules: ["volume"];  wrapInCluster: false }

    // The window-title pill, driven directly so its width cap can be measured
    // against different bar widths without a compositor.
    ActiveWindowPill { id: titlePill }

    // Room for everything, so the centre zone should sit dead centre.
    BarLayout {
        id: wide
        width: 2560
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
            SettingsBus.set("bar.style", "floating")

            // 3. Verify Empty Slot Resilience
            SettingsBus.set("bar.slots.center", [])
            assert(testBar.height === 34, "Bar height should remain stable with empty center slot")

            // 4. A slot stored as a JSON *string* — which is what
            //    `mujo settings set bar.slots.left '[...]'` writes without
            //    --json — must fall back to the default, not empty the bar.
            SettingsBus.set("bar.slots.left", "[\"launcher\"]")
            assert(BarModuleRegistry.slot("left").length === BarModuleRegistry.defaultSlots["left"].length,
                   "slot() must reject a string and fall back to the default")
            SettingsBus.set("bar.slots.left", BarModuleRegistry.defaultSlots["left"])
            SettingsBus.set("bar.slots.center", BarModuleRegistry.defaultSlots["center"])

            // Geometry assertions read x directly, and the centre zone glides to a
            // new x with a Behavior. Turn motion off first, or every measurement
            // below reads the frame before the move.
            SettingsBus.set("motion.reduce", true)

            // 5. Zones must never overlap, at any width. This is the whole point
            //    of BarLayout: three independently anchored slots could and did
            //    draw on top of each other.
            function zonesDisjoint(l, tag) {
                var lx = l.leftItem.x + l.leftItem.width
                var rx = l.rightItem.x
                assert(lx <= rx, tag + ": left zone must end before the right zone starts")
                if (l.centerItem.visible) {
                    assert(l.centerItem.x >= lx, tag + ": centre zone must start after the left zone")
                    assert(l.centerItem.x + l.centerItem.width <= rx, tag + ": centre zone must end before the right zone")
                }
            }
            // Self-calibrating: measure what the three zones want on a roomy bar,
            // then hand `narrow` less than that. Hard-coding a width here would
            // pass by accident the day a module gets narrower.
            var wanted = wide.leftItem.width + wide.centerItem.width + wide.rightItem.width
            assert(wanted > 0, "zones should have some width to test against")

            narrow.width = Math.round(wanted * 1.3)   // centre clamped, still visible
            zonesDisjoint(narrow, "narrow(clamped)")

            narrow.width = Math.round(wanted * 0.6)   // no gap at all: centre drops out
            zonesDisjoint(narrow, "narrow(no gap)")
            assert(!narrow.centerItem.visible, "narrow(no gap): centre zone should drop out rather than overlap")

            zonesDisjoint(wide, "wide(2560)")

            // 5b. The window title cap is a ceiling *and* a fraction of the bar,
            //     so one stored maxWidth behaves on a 1280 panel and a 3440
            //     ultrawide instead of eating a fifth of the narrow one.
            titlePill.barWidth = 2560
            var wideCap = titlePill.titleCap
            titlePill.barWidth = 600
            var narrowCap = titlePill.titleCap
            assert(narrowCap < wideCap, "title cap must shrink with the bar (" + narrowCap + " vs " + wideCap + ")")
            assert(wideCap <= titlePill.maxTitleWidth, "title cap must never exceed the stored ceiling")
            assert(narrowCap >= 72, "title cap must stay legible on a narrow bar")

            // 5c. A module that hides itself must give its cell back. The Loader
            //     around it takes its implicit size from the item whatever the
            //     item's visibility, which is what left a hole between the
            //     volume and notification icons on a machine with no battery.
            assert(shownSlot.implicitWidth > 0, "a visible module should have width")
            assert(hiddenSlot.implicitWidth === 0,
                   "a hidden module must reserve no width (got " + hiddenSlot.implicitWidth + ")")

            // 6. Given room, the centre zone is centred on the screen, not merely
            //    parked in the leftover gap.
            var centreErr = Math.abs((wide.centerItem.x + wide.centerItem.width / 2) - wide.width / 2)
            assert(wide.centerItem.visible && centreErr <= 1,
                   "wide: centre zone should be screen-centred (off by " + centreErr + ")")

            // 7. Both zones stay inside the bar.
            assert(narrow.leftItem.x >= 0 && narrow.rightItem.x + narrow.rightItem.width <= narrow.width,
                   "narrow: zones must stay within the bar")

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
