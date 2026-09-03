import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Screen-Edge Shelf File Staging Drop Zone Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    MujoCard {
        title: "Shelf File Staging Drop Zone"
        iconName: "inbox"
        badgeText: SettingsBus.get("shelf.enabled", true) ? "ENABLED" : "OFF"
        badgeColor: SettingsBus.get("shelf.enabled", true) ? Theme.success : Theme.textDim

        SettingRow {
            path: "shelf.enabled"
            def: true
            kind: "toggle"
            iconName: "layers"
            title: "Screen Edge Staging Strip"
            description: "Collect dragged files along the screen edge for effortless multi-folder transfer."
        }

        MujoSettingRow {
            iconName: "border_right"
            title: "Attached Screen Edge"
            description: "Which display border hosts the staging drop strip."

            MujoSegmented {
                model: [
                    { id: "left", label: "Left" },
                    { id: "right", label: "Right" },
                    { id: "top", label: "Top" },
                    { id: "bottom", label: "Bottom" }
                ]
                current: SettingsBus.get("shelf.edge", "right")
                onSelected: function(id) { SettingsBus.set("shelf.edge", id) }
            }
        }

        SettingRow {
            path: "shelf.stripLength"
            def: 0.4
            kind: "slider"
            from: 0.15
            to: 0.8
            roundValue: false
            format: "%"
            valueText: (Number(SettingsBus.get("shelf.stripLength", 0.4)) * 100).toFixed(0) + "%"
            iconName: "straighten"
            title: "Strip Length Ratio"
            description: "Proportion of vertical edge occupied by the staging strip."
        }

        SettingRow {
            path: "shelf.restoreOnRestart"
            def: true
            kind: "toggle"
            iconName: "restart_alt"
            title: "Restore Items on Restart"
            description: "Keep collected items in Shelf across desktop reloads and reboots."
        }
    }
}
