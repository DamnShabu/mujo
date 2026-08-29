import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// AI Usage Desktop Widget: Omarchy-inspired dashboard card displaying rate
// limits, 7-day token activity, and model distribution for the selected AI provider.
BaseWidget {
    id: root

    property var wcfg: ({})
    property var providers: []
    property string defaultId: ""

    // Target provider: follows settings.json ai.agent, desktop pin, or active default
    readonly property string wantId: wcfg.provider !== undefined ? String(wcfg.provider)
        : (SettingsBus.get("ai.agent", "") !== "" ? SettingsBus.get("ai.agent", "")
        : SettingsBus.get("desktop.aiusage.provider", ""))
    readonly property bool showGauges: wcfg.showGauges !== undefined ? !!wcfg.showGauges : SettingsBus.get("desktop.aiusage.showGauges", true)
    readonly property bool showDays: wcfg.showDays !== undefined ? !!wcfg.showDays : true
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "glass"

    chromeless: cardStyle === "chromeless"

    readonly property var provider: {
        var want = root.wantId !== "" ? root.wantId : root.defaultId
        for (var i = 0; i < providers.length; i++)
            if (providers[i].id === want) return providers[i]
        return providers.length > 0 ? providers[0] : null
    }

    readonly property var limits: (root.showGauges && provider && provider.limits) ? provider.limits : []
    readonly property var days: (provider && provider.tokensByDay) ? provider.tokensByDay : []
    readonly property var models: (provider && provider.tokensByModel) ? provider.tokensByModel : []

    readonly property real todayTokens: {
        var d = root.days
        return d.length > 0 ? (d[d.length - 1].tokens || 0) : 0
    }

    title: ""
    iconName: ""
    onRetryClicked: { root.error = ""; root.loading = true; usageProc.running = true }

    function formatTokens(n) {
        if (!n || isNaN(n)) return "0"
        if (n >= 1000000000) return (n / 1000000000).toFixed(1) + "B"
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(1) + "k"
        return String(Math.round(n))
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

    Process {
        id: usageProc
        command: ["bash", Qt.resolvedUrl("../../llm-usage.sh").toString().slice(7)]
        running: true
        stderr: StdioCollector { id: usageErr }
        onExited: (code) => {
            root.loading = false
            if (code !== 0 && root.providers.length === 0)
                root.error = usageErr.text.split("\n")[0] || ("llm-usage.sh exited " + code)
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text)
                    root.providers = obj.providers || []
                    root.defaultId = obj.default || ""
                    root.loading = false
                    root.error = root.providers.length === 0 ? "No AI assistants detected" : ""
                } catch (e) {
                    root.loading = false
                }
            }
        }
    }

    Component.onCompleted: root.loading = true

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: usageProc.running = true
    }

    Connections {
        target: SettingsBus
        function onSettingsChanged(key) {
            if (key.indexOf("ai.") === 0) usageProc.running = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.chromeless ? 0 : 8
        spacing: 9

        // ---- Header: Icon, Name, Plan, Today total -------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: Theme.radiusSm
                color: Theme.accentDim
                border.color: Theme.accent
                border.width: 1

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: root.provider ? (root.provider.icon || "smart_toy") : "smart_toy"
                    pixelSize: 15
                    color: Theme.accent
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.provider ? root.provider.name : "AI Usage"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.provider && (root.provider.plan || "") !== ""
                radius: Theme.radiusSm
                color: Theme.accentDim
                implicitWidth: pBadge.implicitWidth + 8
                implicitHeight: pBadge.implicitHeight + 2
                Text {
                    id: pBadge
                    anchors.centerIn: parent
                    text: root.provider ? root.provider.plan : ""
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel - 2
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                }
            }

            Text {
                text: root.formatTokens(root.todayTokens) + " today"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                font.bold: true
            }
        }

        // ---- Rate Limits (Session / Weekly) --------------------------------
        Repeater {
            model: root.limits
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: modelData.label
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        Layout.fillWidth: true
                    }
                    Text {
                        text: modelData.percent + "%"
                        color: root.gaugeColor(modelData.severity, modelData.percent)
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.surfaceHover

                    Rectangle {
                        width: Math.max(height, parent.width * Math.max(0, Math.min(1, modelData.percent / 100)))
                        height: parent.height
                        radius: 3
                        visible: modelData.percent > 0
                        color: root.gaugeColor(modelData.severity, modelData.percent)
                        Behavior on width { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // ---- 7-Day Activity Bars -------------------------------------------
        ColumnLayout {
            id: dayCol
            Layout.fillWidth: true
            spacing: 4
            readonly property real dayMax: root.maxOf(root.days, "tokens")
            visible: root.showDays && root.days.length > 0

            Repeater {
                model: root.days
                delegate: RowLayout {
                    required property var modelData
                    readonly property bool isToday: modelData.label === "Today"
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: modelData.label
                        color: isToday ? Theme.text : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: isToday
                        Layout.preferredWidth: 32
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        radius: 2.5
                        color: Theme.surfaceHover

                        Rectangle {
                            width: parent.width * root.barFrac(modelData.tokens, dayCol.dayMax)
                            height: parent.height
                            radius: 2.5
                            visible: modelData.tokens > 0
                            color: isToday ? Theme.accent : Theme.accentDim
                            Behavior on width { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Easing.OutCubic } }
                        }
                    }

                    Text {
                        text: root.formatTokens(modelData.tokens)
                        color: isToday ? Theme.text : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.bold: isToday
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // ---- Empty State ---------------------------------------------------
        Text {
            Layout.fillWidth: true
            visible: root.limits.length === 0 && root.days.length === 0 && root.error === "" && !root.loading
            text: "Telemetry active · Monitored via local transcripts"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }
    }
}

