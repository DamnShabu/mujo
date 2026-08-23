import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":llm"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    // Always show fresh numbers the moment the user opens the menu — the timers
    // below keep it live while open, but this removes the "stale until it next
    // polls" feel without waiting on a tick.
    onMenuOpenChanged: if (root.menuOpen) {
        statusLoad.running = true
        ollamaLoad.running = true
        usageLoad.running = true
        root.now = new Date()
    }

    // ---- state --------------------------------------------------------------
    property var trackedModels: []
    property real tokens: 0
    property string updated: ""
    property var localModels: []

    // Providers detected + measured by llm-usage.sh (Claude, Codex, …).
    property var providers: []
    // Persisted "default"/active provider id, and the one the user is viewing.
    property string defaultId: ""
    property string selectedId: ""
    property date now: new Date()

    readonly property var selectedProvider: {
        var list = root.providers
        for (var i = 0; i < list.length; i++)
            if (list[i].id === root.selectedId) return list[i]
        return list.length > 0 ? list[0] : null
    }

    function formatTokens(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(1) + "k"
        return String(Math.round(n))
    }

    function formatDuration(ms) {
        if (ms <= 0) return "now"
        var totalMin = Math.round(ms / 60000)
        var h = Math.floor(totalMin / 60)
        var m = totalMin % 60
        var d = Math.floor(h / 24)
        if (d > 0) return d + "d " + (h % 24) + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    // Reset label for a usage gauge: relative ("Resets in …") when under a day
    // away, absolute weekday/time otherwise.
    function resetLabel(resetsAt) {
        if (!resetsAt) return ""
        var reset = new Date(resetsAt)
        var ms = reset.getTime() - root.now.getTime()
        if (ms <= 0) return "Resets soon"
        if (ms < 24 * 3600 * 1000) return "Resets in " + root.formatDuration(ms)
        return "Resets " + Qt.formatDateTime(reset, "ddd h:mm AP")
    }

    function gaugeColor(severity, percent) {
        if (severity === "critical" || severity === "high" || percent >= 90) return Theme.error
        if (severity === "warning" || percent >= 70) return Theme.warning
        return Theme.accent
    }

    // Fraction 0..1 for a horizontal token bar relative to the group's max.
    function barFrac(value, max) {
        if (!max || max <= 0) return 0
        return Math.max(0, Math.min(1, value / max))
    }

    function maxOf(list, key) {
        var m = 0
        for (var i = 0; i < (list ? list.length : 0); i++)
            if (list[i][key] > m) m = list[i][key]
        return m
    }

    readonly property int activeCount: root.providers.length + root.trackedModels.length + root.localModels.length

    // Persist the chosen provider as the new default and switch the view.
    function selectProvider(id) {
        root.selectedId = id
        persistDefault.selection = id
        persistDefault.running = true
    }

    // ---- data loaders -------------------------------------------------------
    Process {
        id: statusLoad
        running: false
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || echo '{}'", "_", Quickshell.env("HOME") + "/.config/qsshell/llm-status.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text)
                    root.trackedModels = obj.models || []
                    root.tokens = obj.tokens || 0
                    root.updated = obj.updated || ""
                } catch (e) {
                    root.trackedModels = []
                    root.tokens = 0
                }
            }
        }
    }

    Process {
        id: ollamaLoad
        running: false
        command: ["sh", "-c", "command -v ollama >/dev/null 2>&1 && ollama ps 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n").filter(function(l) { return l.trim() !== "" })
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    if (i === 0 && lines[i].trim().indexOf("NAME") === 0) continue
                    var cols = lines[i].trim().split(/\s{2,}/)
                    if (cols.length > 0 && cols[0] !== "") {
                        out.push({name: cols[0], size: cols.length > 2 ? cols[2] : ""})
                    }
                }
                root.localModels = out
            }
        }
    }

    Process {
        id: usageLoad
        running: false
        command: ["bash", Qt.resolvedUrl("../../../llm-usage.sh").toString().slice(7)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text)
                    root.providers = obj.providers || []
                    root.defaultId = obj.default || ""
                    // Keep the user's active tab if it still exists; otherwise
                    // fall back to the persisted default.
                    var ok = false
                    for (var i = 0; i < root.providers.length; i++)
                        if (root.providers[i].id === root.selectedId) ok = true
                    if (!ok) root.selectedId = root.defaultId
                } catch (e) {
                    root.providers = []
                }
            }
        }
    }

    Process {
        id: persistDefault
        running: false
        property string selection: ""
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '{\"default\":\"%s\"}' \"$2\" > \"$1\"",
            "_", Quickshell.env("HOME") + "/.config/qsshell/llm-default.json", selection]
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statusLoad.running = true
            ollamaLoad.running = true
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: usageLoad.running = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Hairline section divider used between popup sections.
    component HRule: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        color: Theme.border
    }

    IconButton {
        id: trigger
        iconName: "smart_toy"
        active: root.menuOpen
        onClicked: PopupCoordinator.toggle(root.popupId)

        Rectangle {
            visible: root.activeCount > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: -2
            width: 14
            height: 14
            radius: 7
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: root.activeCount
                color: Theme.accentText
                font.family: Theme.fontMono
                font.pixelSize: 9
                font.bold: true
            }
        }
    }

    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: 300 + 32
        implicitHeight: content.implicitHeight + 28 + 32

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // ---- header: active provider identity ----------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 11
                    visible: root.selectedProvider !== null

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: Theme.radiusMd
                        color: Theme.accentDim
                        border.color: Theme.accent
                        border.width: 1
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: root.selectedProvider ? (root.selectedProvider.icon || "smart_toy") : "smart_toy"
                            pixelSize: 21
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: root.selectedProvider ? root.selectedProvider.name : ""
                            color: Theme.text; font.pixelSize: 15; font.bold: true
                        }
                        RowLayout {
                            spacing: 6
                            Rectangle {
                                visible: root.selectedProvider && root.selectedProvider.plan
                                radius: Theme.radiusSm
                                color: Theme.accentDim
                                implicitWidth: planText.implicitWidth + 12
                                implicitHeight: planText.implicitHeight + 5
                                Text {
                                    id: planText
                                    anchors.centerIn: parent
                                    text: root.selectedProvider ? (root.selectedProvider.plan || "") : ""
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: Theme.labelSpacing
                                    font.capitalization: Font.AllUppercase
                                }
                            }
                            Text {
                                visible: root.selectedProvider && root.selectedProvider.email
                                text: root.selectedProvider ? (root.selectedProvider.email || "") : ""
                                color: Theme.textDim
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // ---- provider tabs: click switches the default provider ----
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 7
                    visible: root.providers.length > 1

                    Repeater {
                        model: root.providers
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: modelData.id === root.selectedId
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.radiusMd
                            color: selected ? Theme.accentDim : (tabHover.hovered ? Theme.surfaceHover : Theme.surface)
                            border.color: selected ? Theme.accent : Theme.border
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialIcon {
                                    iconName: modelData.icon || "smart_toy"
                                    pixelSize: 14
                                    color: selected ? Theme.accent : Theme.textSecondary
                                }
                                Text {
                                    text: modelData.name
                                    color: selected ? Theme.accent : Theme.textSecondary
                                    font.pixelSize: 11
                                    font.bold: selected
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.selectProvider(modelData.id) }
                        }
                    }
                }

                // ---- LIMITS ------------------------------------------------
                HRule { visible: root.selectedProvider && root.selectedProvider.limits && root.selectedProvider.limits.length > 0 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 13
                    visible: root.selectedProvider && root.selectedProvider.limits && root.selectedProvider.limits.length > 0

                    SectionLabel { text: "Limits" }

                    Repeater {
                        model: root.selectedProvider ? (root.selectedProvider.limits || []) : []
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.label; color: Theme.text; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                                Text {
                                    text: modelData.percent + "%"
                                    color: root.gaugeColor(modelData.severity, modelData.percent)
                                    font.family: Theme.fontMono; font.pixelSize: 13; font.bold: true
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: 4
                                color: Theme.surfaceHover

                                Rectangle {
                                    width: Math.max(height, parent.width * Math.max(0, Math.min(1, modelData.percent / 100)))
                                    height: parent.height
                                    radius: 4
                                    visible: modelData.percent > 0
                                    color: root.gaugeColor(modelData.severity, modelData.percent)
                                    Behavior on width { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                visible: root.resetLabel(modelData.resetsAt) !== ""
                                text: root.resetLabel(modelData.resetsAt)
                                color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: 9
                            }
                        }
                    }
                }

                // ---- TOKENS BY DAY -----------------------------------------
                HRule { visible: dayGroup.visible }

                ColumnLayout {
                    id: dayGroup
                    Layout.fillWidth: true
                    spacing: 7
                    readonly property var days: root.selectedProvider ? (root.selectedProvider.tokensByDay || []) : []
                    readonly property real dayMax: root.maxOf(days, "tokens")
                    visible: days.length > 0

                    SectionLabel { text: "Tokens by day" }

                    Repeater {
                        model: dayGroup.days
                        delegate: RowLayout {
                            required property var modelData
                            readonly property bool isToday: modelData.label === "Today"
                            Layout.fillWidth: true
                            spacing: 9

                            Text {
                                text: modelData.label
                                color: isToday ? Theme.text : Theme.textSecondary
                                font.pixelSize: 11
                                font.bold: isToday
                                Layout.preferredWidth: 36
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 7
                                radius: 3.5
                                color: Theme.surfaceHover

                                Rectangle {
                                    width: parent.width * root.barFrac(modelData.tokens, dayGroup.dayMax)
                                    height: parent.height
                                    radius: 3.5
                                    visible: modelData.tokens > 0
                                    color: isToday ? Theme.accent : Theme.accentDim
                                    Behavior on width { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                text: root.formatTokens(modelData.tokens)
                                color: isToday ? Theme.text : Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.bold: isToday
                                Layout.preferredWidth: 54
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // ---- TOKENS BY MODEL ---------------------------------------
                HRule { visible: modelGroup.visible }

                ColumnLayout {
                    id: modelGroup
                    Layout.fillWidth: true
                    spacing: 7
                    readonly property var models: root.selectedProvider ? (root.selectedProvider.tokensByModel || []) : []
                    readonly property real modelMax: root.maxOf(models, "tokens")
                    visible: models.length > 0

                    SectionLabel { text: "Tokens by model" }

                    Repeater {
                        model: modelGroup.models
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 9

                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.pixelSize: 11
                                Layout.preferredWidth: 78
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 7
                                radius: 3.5
                                color: Theme.surfaceHover

                                Rectangle {
                                    width: parent.width * root.barFrac(modelData.tokens, modelGroup.modelMax)
                                    height: parent.height
                                    radius: 3.5
                                    visible: modelData.tokens > 0
                                    color: Theme.accent
                                    Behavior on width { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                text: root.formatTokens(modelData.tokens)
                                color: Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                Layout.preferredWidth: 54
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // ---- per-provider empty state ------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 7
                    visible: root.selectedProvider
                        && (!root.selectedProvider.limits || root.selectedProvider.limits.length === 0)
                        && (!root.selectedProvider.tokensByModel || root.selectedProvider.tokensByModel.length === 0)
                        && root.localModels.length === 0
                    MaterialIcon { iconName: "info"; pixelSize: 14; color: Theme.textDim }
                    Text {
                        Layout.fillWidth: true
                        text: "No usage data for " + (root.selectedProvider ? root.selectedProvider.name : "") + " — detected only."
                        color: Theme.textDim
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }

                // ---- fallbacks: local ollama + manually tracked ------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: root.localModels.length > 0

                    SectionLabel { text: "Local · ollama" }

                    Repeater {
                        model: root.localModels
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialIcon { iconName: "memory"; pixelSize: 13; color: Theme.accent }
                            Text { text: modelData.name; color: Theme.text; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: modelData.size; color: Theme.textSecondary; font.pixelSize: 10 }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: root.trackedModels.length > 0

                    SectionLabel { text: "Tracked" }

                    Repeater {
                        model: root.trackedModels
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialIcon { iconName: "smart_toy"; pixelSize: 13; color: Theme.accent }
                            Text { text: modelData.name; color: Theme.text; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: modelData.note || ""; color: Theme.textSecondary; font.pixelSize: 10; elide: Text.ElideRight }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.activeCount === 0
                    text: "No AI assistants detected. Sign in to Claude Code or start a local ollama model."
                    color: Theme.textSecondary
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
