import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

// Interactive Crash Recovery & AI Fix Modal.
// Provides AI root-cause analysis, one-click safe remediation recipes,
// raw log/stacktrace inspection, and interactive AI terminal handoff.
Item {
    id: root

    property bool showing: false
    property var crashData: null

    property bool analyzing: false
    property var diagnosis: null
    property string rawLog: ""
    property bool logExpanded: false
    property string fixStatus: ""

    function open(data) {
        if (typeof data === "string") {
            try { data = JSON.parse(data) } catch (e) { data = { comm: data, type: "coredump" } }
        }
        root.crashData = data || {}
        root.diagnosis = null
        root.rawLog = ""
        root.fixStatus = ""
        root.logExpanded = false
        root.showing = true

        // Fetch raw info and AI diagnosis
        var t = root.crashData.type || "coredump"
        var id = root.crashData.id || root.crashData.pid || root.crashData.comm || ""
        infoProc.targetType = t
        infoProc.targetId = String(id)
        infoProc.running = true

        root.analyzing = true
        diagProc.targetType = t
        diagProc.targetId = String(id)
        diagProc.running = true
    }

    function close() {
        root.showing = false
        root.analyzing = false
    }

    function applyFix(action, target) {
        root.fixStatus = "Applying fix…"
        fixProc.command = target ? ["mujo", "crash", "fix", action, String(target)]
                                 : ["mujo", "crash", "fix", action]
        fixProc.running = true
    }

    function openAiTerminal() {
        var comm = root.crashData ? (root.crashData.comm || "application") : "app"
        var prompt = "I encountered a crash in '" + comm + "'. Please help me investigate the root cause and fix it.\n\nCrash Log:\n" + root.rawLog
        AI.openInTerminal(prompt)
        root.close()
    }

    Process {
        id: infoProc
        property string targetType: ""
        property string targetId: ""
        command: ["mujo", "crash", "info", targetType, targetId]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    root.rawLog = d.raw || "(no raw logs)"
                } catch (e) {
                    root.rawLog = this.text || "(no logs)"
                }
            }
        }
    }

    Process {
        id: diagProc
        property string targetType: ""
        property string targetId: ""
        command: ["mujo", "crash", "diagnose", targetType, targetId]
        stdout: StdioCollector {
            onStreamFinished: {
                root.analyzing = false
                try {
                    root.diagnosis = JSON.parse(this.text)
                } catch (e) {
                    root.diagnosis = {
                        summary: this.text || "Crash analysis completed.",
                        rootCause: "Abnormal termination",
                        fixes: []
                    }
                }
            }
        }
        onExited: function (code) {
            root.analyzing = false
        }
    }

    Process {
        id: fixProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.fixStatus = this.text.trim() || "✓ Fix applied successfully"
            }
        }
        onExited: function (code) {
            if (code !== 0 && root.fixStatus === "Applying fix…") {
                root.fixStatus = "Fix failed"
            }
        }
    }

    // Modal Layer Window
    PanelWindow {
        id: win
        visible: root.showing
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        // Scrim backdrop
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.showing ? 0.6 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }

        // Modal Dialog Card
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(620, parent.width - 40)
            implicitHeight: col.implicitHeight + 40
            radius: Theme.radiusLg
            color: Theme.bg
            border.color: Theme.borderStrong
            border.width: 1
            clip: true

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    MaterialIcon {
                        iconName: root.crashData && root.crashData.type === "gpu" ? "videogame_asset"
                                : (root.crashData && root.crashData.type === "oom" ? "memory" : "bug_report")
                        pixelSize: 22
                        color: Theme.error
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text {
                            text: "Crash & Recovery Assistant"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeHeading
                            font.bold: true
                        }
                        Text {
                            text: root.crashData ? ((root.crashData.comm || "Process") + (root.crashData.pid ? (" · PID " + root.crashData.pid) : "")) : ""
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                    Rectangle {
                        implicitWidth: sigLbl.implicitWidth + 14; implicitHeight: 22
                        radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.error, 0.18)
                        border.color: Theme.error
                        Text {
                            id: sigLbl
                            anchors.centerIn: parent
                            text: root.crashData ? (root.crashData.signal || (root.crashData.type ? root.crashData.type.toUpperCase() : "CRASH")) : "CRASH"
                            color: Theme.error
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }
                    IconButton {
                        iconName: "close"
                        onClicked: root.close()
                    }
                }

                // AI Root Cause Analysis Section
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: aiCol.implicitHeight + 20
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.color: Theme.border

                    ColumnLayout {
                        id: aiCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            MaterialIcon { iconName: "neurology"; pixelSize: 16; color: Theme.accent }
                            Text {
                                text: "AI Diagnosis & Root Cause"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Spinner { size: 12; visible: root.analyzing }
                        }

                        Text {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                            visible: !root.analyzing && root.diagnosis !== null
                            text: root.diagnosis ? (root.diagnosis.summary || "No diagnostic summary.") : ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                        }

                        Text {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                            visible: !root.analyzing && root.diagnosis && root.diagnosis.rootCause
                            text: "Cause: " + (root.diagnosis ? root.diagnosis.rootCause : "")
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Text {
                            visible: root.analyzing
                            text: "Analyzing stacktrace and system journal logs…"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // One-Click Fix Actions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !root.analyzing && root.diagnosis && root.diagnosis.fixes && root.diagnosis.fixes.length > 0

                    SectionLabel { text: "Recommended Fix Actions" }

                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: root.diagnosis ? (root.diagnosis.fixes || []) : []
                            delegate: DialogButton {
                                required property var modelData
                                text: modelData.title || "Apply Fix"
                                primary: true
                                onClicked: root.applyFix(modelData.action, modelData.target)
                            }
                        }
                    }
                }

                // Fix Status Banner
                Text {
                    visible: root.fixStatus !== ""
                    text: root.fixStatus
                    color: root.fixStatus.indexOf("failed") >= 0 ? Theme.error : Theme.success
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                // Collapsible Log & Stacktrace
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        MaterialIcon {
                            iconName: root.logExpanded ? "expand_less" : "expand_more"
                            pixelSize: 15; color: Theme.textSecondary
                        }
                        Text {
                            text: root.logExpanded ? "Hide Diagnostic Logs" : "View Diagnostic Logs & Stacktrace"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            Layout.fillWidth: true
                        }
                        DialogButton {
                            text: "Copy Logs"
                            visible: root.logExpanded && root.rawLog !== ""
                            onClicked: Quickshell.execDetached(["wl-copy", root.rawLog])
                        }
                        TapHandler { onTapped: root.logExpanded = !root.logExpanded }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        visible: root.logExpanded
                        radius: Theme.radiusSm
                        color: Theme.bg
                        border.color: Theme.border

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 8
                            contentHeight: logTxt.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: logTxt
                                width: parent.width
                                text: root.rawLog || "No logs available."
                                color: Theme.textSecondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }
                        }
                    }
                }

                // Footer Actions
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    DialogButton {
                        text: "Open in AI Terminal"
                        onClicked: root.openAiTerminal()
                    }
                    Item { Layout.fillWidth: true }
                    DialogButton {
                        text: "Dismiss"
                        onClicked: root.close()
                    }
                }
            }
        }
    }
}
