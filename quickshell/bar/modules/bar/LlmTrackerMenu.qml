import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// AI Usage Menu & Bar Pill: Omarchy-inspired usage widget focused strictly
// on the active / selected AI provider. Left-click opens the usage dashboard,
// right-click launches the active agent in an interactive terminal.
Item {
    id: root
    property var panelWindow
    property string screenName: ""

    readonly property string popupId: root.screenName + ":llm"
    readonly property bool menuOpen: PopupCoordinator.activeId === root.popupId
    implicitWidth: trigger.width
    implicitHeight: trigger.height

    onMenuOpenChanged: if (root.menuOpen) {
        usageLoad.running = true
        root.now = new Date()
    }

    // ---- state --------------------------------------------------------------
    property var providers: []
    property string defaultId: ""
    property date now: new Date()

    // Scan lifecycle
    property bool loaded: false
    property string loadError: ""
    readonly property bool loading: usageLoad.running

    // Resolved selected provider ID (synced with settings.json ai.agent and llm-default.json)
    readonly property string selectedId: {
        var agent = SettingsBus.get("ai.agent", "")
        if (agent && agent !== "") return agent
        if (root.defaultId && root.defaultId !== "") return root.defaultId
        return root.providers.length > 0 ? root.providers[0].id : ""
    }

    readonly property var selectedProvider: {
        var list = root.providers
        for (var i = 0; i < list.length; i++)
            if (list[i].id === root.selectedId) return list[i]
        return list.length > 0 ? list[0] : null
    }

    readonly property var limits: (root.selectedProvider && root.selectedProvider.limits) ? root.selectedProvider.limits : []
    readonly property var days: (root.selectedProvider && root.selectedProvider.tokensByDay) ? root.selectedProvider.tokensByDay : []
    readonly property var models: (root.selectedProvider && root.selectedProvider.tokensByModel) ? root.selectedProvider.tokensByModel : []

    readonly property real activeTodayTokens: {
        var d = root.days
        return d.length > 0 ? (d[d.length - 1].tokens || 0) : 0
    }

    // Max limit percentage / highest severity across gauges for warning tint
    readonly property int maxGaugePercent: {
        var maxP = 0
        for (var i = 0; i < root.limits.length; i++) {
            var p = root.limits[i].percent || 0
            if (p > maxP) maxP = p
        }
        return maxP
    }

    readonly property string maxSeverity: {
        for (var i = 0; i < root.limits.length; i++) {
            var s = root.limits[i].severity || ""
            if (s === "critical" || s === "high") return "critical"
            if (s === "warning") return "warning"
        }
        return "normal"
    }

    function formatTokens(n) {
        if (!n || isNaN(n)) return "0"
        if (n >= 1000000000) return (n / 1000000000).toFixed(1) + "B"
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

    // ---- data loader --------------------------------------------------------
    Process {
        id: usageLoad
        running: false
        command: ["bash", Qt.resolvedUrl("../../llm-usage.sh").toString().slice(7)]

        onExited: function (exitCode) {
            if (exitCode !== 0)
                root.loadError = usageErr.text.split("\n")[0] || ("llm-usage.sh exited " + exitCode)
        }

        stderr: StdioCollector { id: usageErr }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text)
                    root.providers = obj.providers || []
                    root.defaultId = obj.default || ""
                    root.loadError = ""
                    root.loaded = true
                } catch (e) {
                    root.loadError = "Usage scan returned unreadable output"
                }
            }
        }
    }

    // Refresh timers
    Timer {
        interval: root.menuOpen ? 30000 : 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: usageLoad.running = true
    }

    Timer {
        interval: 30000
        running: root.menuOpen
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Re-scan when settings AI agent changes
    Connections {
        target: SettingsBus
        function onSettingsChanged(key) {
            if (key.indexOf("ai.") === 0) {
                usageLoad.running = true
            }
        }
    }

    // Hairline divider
    component HRule: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        color: Theme.border
    }

    readonly property bool showTokens: SettingsBus.get("bar.llm.showTokens", false)
    readonly property bool hasWarning: root.maxSeverity === "warning" || (root.maxGaugePercent >= 70 && root.maxGaugePercent < 90)
    readonly property bool hasCritical: root.maxSeverity === "critical" || root.maxGaugePercent >= 90

    // ---- Trigger Pill (Top Bar) ---------------------------------------------
    Rectangle {
        id: trigger
        implicitHeight: Theme.barHeight - 6
        implicitWidth: (root.showTokens || root.activeTodayTokens > 0) ? (trigRow.implicitWidth + 14) : 28
        radius: Theme.radiusSm
        color: root.menuOpen ? Theme.accentDim
             : (trigHh.hovered ? Theme.surfaceHover : "transparent")
        border.color: root.menuOpen ? Theme.accent
                    : (root.hasCritical ? Theme.error
                    : (root.hasWarning ? Theme.warning
                    : (trigHh.hovered ? Theme.borderStrong : "transparent")))
        border.width: 1

        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        RowLayout {
            id: trigRow
            anchors.centerIn: parent
            spacing: 5

            MaterialIcon {
                iconName: root.selectedProvider ? (root.selectedProvider.icon || "smart_toy") : "smart_toy"
                pixelSize: 16
                color: root.menuOpen ? Theme.accent
                     : (root.hasCritical ? Theme.error
                     : (root.hasWarning ? Theme.warning
                     : (trigHh.hovered ? Theme.text : Theme.textSecondary)))
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }

            Text {
                visible: root.showTokens || root.activeTodayTokens > 0
                text: root.formatTokens(root.activeTodayTokens)
                color: root.menuOpen ? Theme.accent
                     : (root.hasCritical ? Theme.error
                     : (root.hasWarning ? Theme.warning
                     : (trigHh.hovered ? Theme.text : Theme.textSecondary)))
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }
        }

        HoverHandler { id: trigHh; cursorShape: Qt.PointingHandCursor }

        // Left-click opens usage panel, Right-click launches interactive agent in terminal (Omarchy style)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    AI.openInTerminal()
                } else {
                    PopupCoordinator.toggle(root.popupId)
                }
            }
        }

        Tooltip {
            visible: trigHh.hovered && !root.menuOpen
            text: (root.selectedProvider ? root.selectedProvider.name : "AI Assistant")
                  + (root.activeTodayTokens > 0 ? (" · " + root.formatTokens(root.activeTodayTokens) + " tokens today") : "")
                  + "\nLeft-click: usage panel · Right-click: launch terminal"
        }
    }

    // ---- Usage Popup Card ---------------------------------------------------
    PopupWindow {
        id: popup
        visible: root.menuOpen
        color: "transparent"
        anchor.window: root.panelWindow
        anchor.item: trigger
        anchor.edges: Theme.popupEdge | Edges.Right
        anchor.gravity: Theme.popupGravity | Edges.Left
        anchor.adjustment: PopupAdjustment.Slide

        readonly property int screenHeight: root.panelWindow && root.panelWindow.screen
            ? root.panelWindow.screen.height : 1080

        implicitWidth: 320 + 32
        implicitHeight: Math.min(content.implicitHeight + 28 + 32, screenHeight - 96)

        onClosed: PopupCoordinator.close(root.popupId)

        PopupCard {
            anchors.fill: parent
            open: root.menuOpen

            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: content
                    width: parent.width
                    spacing: 12

                    // ---- Skeleton during initial load -----------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: !root.loaded && root.loadError === ""

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 9
                            Spinner { size: 15 }
                            Text {
                                Layout.fillWidth: true
                                text: "Loading usage data…"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: 4
                                color: Theme.surfaceHover
                                SequentialAnimation on opacity {
                                    running: !Anim.reduceMotion
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }

                    // ---- Scan failure notification --------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: root.loadError !== ""
                        MaterialIcon { iconName: "error"; pixelSize: 15; color: Theme.error }
                        Text {
                            Layout.fillWidth: true
                            text: root.loadError
                            color: Theme.error
                            font.pixelSize: Theme.fontSizeLabel
                            wrapMode: Text.WordWrap
                        }
                    }

                    // ---- Header: Selected Provider Identity -----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11
                        visible: root.selectedProvider !== null

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: Theme.radiusMd
                            color: Theme.accentDim
                            border.color: Theme.accent
                            border.width: 1
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: root.selectedProvider ? (root.selectedProvider.icon || "smart_toy") : "smart_toy"
                                pixelSize: 22
                                color: Theme.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: root.selectedProvider ? root.selectedProvider.name : "AI Assistant"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                            }
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    visible: root.selectedProvider && (root.selectedProvider.plan || "") !== ""
                                    radius: Theme.radiusSm
                                    color: Theme.accentDim
                                    implicitWidth: planText.implicitWidth + 10
                                    implicitHeight: planText.implicitHeight + 4
                                    Text {
                                        id: planText
                                        anchors.centerIn: parent
                                        text: root.selectedProvider ? (root.selectedProvider.plan || "") : ""
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        font.bold: true
                                        font.letterSpacing: Theme.labelSpacing
                                        font.capitalization: Font.AllUppercase
                                    }
                                }

                                Text {
                                    readonly property real cost: (root.selectedProvider && root.selectedProvider.cost) || 0
                                    visible: cost > 0
                                    text: "$" + cost.toFixed(2)
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                }

                                Text {
                                    visible: root.selectedProvider && (root.selectedProvider.email || "") !== ""
                                    text: root.selectedProvider ? (root.selectedProvider.email || "") : ""
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Terminal Launch Button
                        IconButton {
                            iconName: "terminal"
                            Tooltip { text: "Launch terminal session" }
                            onClicked: {
                                AI.openInTerminal()
                                PopupCoordinator.close(root.popupId)
                            }
                        }

                        // Refresh indicator
                        Spinner {
                            size: 14
                            color: Theme.textDim
                            opacity: root.loading ? 1 : 0
                            spinning: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
                        }
                    }

                    // ---- Rate Limits & Quota Section ------------------------
                    HRule {}

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        SectionLabel { text: "Limits & Quota" }

                        // Limit gauges (when usage API is available)
                        Repeater {
                            model: root.limits
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.label
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.percent + "%"
                                        color: root.gaugeColor(modelData.severity, modelData.percent)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
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
                                        Behavior on width { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Easing.OutCubic } }
                                    }
                                }

                                RowLayout {
                                    visible: root.resetLabel(modelData.resetsAt) !== ""
                                    spacing: 4
                                    MaterialIcon {
                                        iconName: "schedule"
                                        pixelSize: 12
                                        color: Theme.textDim
                                    }
                                    Text {
                                        text: root.resetLabel(modelData.resetsAt)
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                    }
                                }
                            }
                        }

                        // Status banner when provider doesn't report API rate limits
                        Rectangle {
                            visible: root.limits.length === 0 && root.selectedProvider !== null
                            Layout.fillWidth: true
                            implicitHeight: bannerCol.implicitHeight + 16
                            radius: Theme.radiusMd
                            color: Theme.surfaceHover
                            border.color: Theme.border
                            border.width: 1

                            RowLayout {
                                id: bannerCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                MaterialIcon {
                                    iconName: "bolt"
                                    pixelSize: 18
                                    color: Theme.accent
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Active & Telemetry Monitored"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                    }
                                    Text {
                                        text: root.selectedProvider && root.selectedProvider.approx
                                            ? "Usage tracked via local conversation transcripts"
                                            : "Usage monitored from local session records"
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }

                    // ---- 7-Day Activity / Tokens By Day ---------------------
                    HRule { visible: dayGroup.visible }

                    ColumnLayout {
                        id: dayGroup
                        Layout.fillWidth: true
                        spacing: 7
                        readonly property real dayMax: root.maxOf(root.days, "tokens")
                        visible: root.days.length > 0

                        RowLayout {
                            Layout.fillWidth: true
                            SectionLabel {
                                text: "Tokens by day" + (root.selectedProvider && root.selectedProvider.approx ? " (est.)" : "")
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.formatTokens(root.activeTodayTokens) + " today"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }

                        Repeater {
                            model: root.days
                            delegate: RowLayout {
                                required property var modelData
                                readonly property bool isToday: modelData.label === "Today"
                                Layout.fillWidth: true
                                spacing: 9

                                Text {
                                    text: modelData.label
                                    color: isToday ? Theme.text : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: isToday
                                    Layout.preferredWidth: 38
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
                                        Behavior on width { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    text: root.formatTokens(modelData.tokens)
                                    color: isToday ? Theme.text : Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: isToday
                                    Layout.preferredWidth: 54
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }

                    // ---- Tokens By Model ------------------------------------
                    HRule { visible: modelGroup.visible }

                    ColumnLayout {
                        id: modelGroup
                        Layout.fillWidth: true
                        spacing: 7
                        readonly property real modelMax: root.maxOf(root.models, "tokens")
                        visible: root.models.length > 0

                        SectionLabel {
                            text: "Tokens by model" + (root.selectedProvider && root.selectedProvider.approx ? " (est.)" : "")
                        }

                        Repeater {
                            model: root.models
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 9

                                Text {
                                    text: modelData.name
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.preferredWidth: 84
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
                                        Behavior on width { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    text: root.formatTokens(modelData.tokens)
                                    color: Theme.textSecondary
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    Layout.preferredWidth: 54
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }

                    // ---- Empty State ----------------------------------------
                    Text {
                        Layout.fillWidth: true
                        visible: root.loaded && root.selectedProvider === null
                        text: "No AI coding assistants detected. Install Claude Code, Antigravity CLI, or OpenCode."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        wrapMode: Text.WordWrap
                    }

                    // ---- Footer: Quick Actions ------------------------------
                    HRule {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        DialogButton {
                            text: "Open Terminal"
                            iconName: "terminal"
                            primary: true
                            Layout.fillWidth: true
                            onClicked: {
                                AI.openInTerminal()
                                PopupCoordinator.close(root.popupId)
                            }
                        }

                        IconButton {
                            iconName: "settings"
                            Tooltip { text: "AI Settings" }
                            onClicked: {
                                Quickshell.execDetached(["mujo", "settings"])
                                PopupCoordinator.close(root.popupId)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Right-click bar icon to quickly launch terminal"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel - 1
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
