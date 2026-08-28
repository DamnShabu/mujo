import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// AI usage on the desktop: the same llm-usage.sh scan the bar's LLM tracker menu
// runs, reduced to the active provider's rate-limit gauges plus today's token
// count. The script caches its usage-API result, so the recurring cost here is a
// transcript scan every 5 minutes.
BaseWidget {
    id: root

    property var wcfg: ({})
    property var providers: []
    property string defaultId: ""

    // wcfg.provider pins the widget to one assistant; otherwise it follows the
    // provider the user made active in the bar widget or settings default.
    readonly property string wantId: wcfg.provider !== undefined ? String(wcfg.provider) : SettingsBus.get("desktop.aiusage.provider", "")
    readonly property bool showGauges: wcfg.showGauges !== undefined ? !!wcfg.showGauges : SettingsBus.get("desktop.aiusage.showGauges", true)
    readonly property string cardStyle: wcfg.cardStyle !== undefined ? wcfg.cardStyle : "glass"

    chromeless: cardStyle === "chromeless"

    readonly property var provider: {
        var want = root.wantId !== "" ? root.wantId : root.defaultId
        for (var i = 0; i < providers.length; i++)
            if (providers[i].id === want) return providers[i]
        return providers.length > 0 ? providers[0] : null
    }
    readonly property var limits: (root.showGauges && provider && provider.limits) ? provider.limits : []
    readonly property real todayTokens: {
        var d = provider && provider.tokensByDay ? provider.tokensByDay : []
        return d.length > 0 ? (d[d.length - 1].tokens || 0) : 0
    }

    title: ""
    iconName: ""
    onRetryClicked: { root.error = ""; root.loading = true; usageProc.running = true }

    function formatTokens(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(1) + "k"
        return String(Math.round(n))
    }

    Process {
        id: usageProc
        command: ["bash", Qt.resolvedUrl("../../llm-usage.sh").toString().slice(7)]
        running: true
        stderr: StdioCollector { id: usageErr }
        // A failed scan keeps the last good numbers on screen: blanking would
        // read as "no usage" rather than "couldn't measure".
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialIcon {
                iconName: "neurology"
                pixelSize: 18
                color: Theme.accent
            }
            Text {
                Layout.fillWidth: true
                text: root.provider ? root.provider.name : "AI usage"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                text: root.formatTokens(root.todayTokens) + " today"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
            }
        }

        Repeater {
            model: root.limits
            delegate: SysBar {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.label || ""
                value: modelData.percent || 0
                caption: (modelData.percent || 0) + "%"
            }
        }

        // No gauges is normal for providers without a usage API - say so rather
        // than leaving an empty card.
        Text {
            Layout.fillWidth: true
            visible: root.limits.length === 0 && root.error === "" && !root.loading
            text: "No rate-limit data for this provider"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }
    }
}
