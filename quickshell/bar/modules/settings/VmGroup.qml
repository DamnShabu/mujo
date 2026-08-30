import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Virtual machines & visual server. Hypervisor telemetry, ready-to-deploy OS
// presets, custom ISO installer, and the SPICE visual server — as cards inside
// the Hardware page. Provisioning used to be a modal overlay; it is an inline
// card now, so nothing here opens a second layer.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property var vmData: ({ kvm: true, vms: [], totalCount: 0, activeCount: 0, vcpusAllocated: 0 })
    property var catalog: []
    property bool runningOp: false
    property bool failedOp: false
    property string opTitle: ""
    property string opStatus: ""
    property real opProgress: -1
    property string opSpeed: ""
    property string opEta: ""
    property var logLines: []
    property bool showLogs: false
    property string activeTab: "vms" // "vms", "catalog", "custom"

    // Creation modal state
    property bool showCreateModal: false
    property var targetPreset: null
    property string createName: ""
    property int createCores: 8
    property int createRamGb: 8
    property int createDiskGb: 40

    // Custom ISO state
    property string customIsoPath: ""
    property string customIsoName: ""
    property int customIsoCores: 8
    property int customIsoRamGb: 8
    property int customIsoDiskGb: 40
    property string customIsoOs: "linux"

    function refresh() {
        if (!listProc.running) listProc.running = true
        if (root.catalog.length === 0 && !catalogProc.running) catalogProc.running = true
    }

    Timer {
        id: pollTimer
        interval: 2000
        // Panels now stay alive when another category is on screen, so the poll
        // follows visibility instead of running for the rest of the session.
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    Process {
        id: listProc
        command: ["mujo", "vm", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.vmData = JSON.parse(this.text)
                } catch (e) {
                    root.vmData = ({ kvm: true, vms: [], totalCount: 0, activeCount: 0, vcpusAllocated: 0 })
                }
            }
        }
    }

    Process {
        id: catalogProc
        command: ["mujo", "vm", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.catalog = JSON.parse(this.text)
                } catch (e) {
                    root.catalog = []
                }
            }
        }
    }

    Process {
        id: actionProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root._handleLogLine(line)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => root._handleLogLine(line)
        }
        onExited: function(code) {
            root.runningOp = false
            if (code !== 0) {
                root.failedOp = true
                root.opStatus = "Operation failed (exit code " + code + ")"
            } else {
                root.failedOp = false
                root.opProgress = 100
                root.opStatus = "Setup completed successfully"
            }
            root.refresh()
        }
    }

    function _handleLogLine(raw) {
        if (!raw || raw.trim() === "") return
        var line = raw.trim()
        
        var logs = root.logLines.slice()
        if (logs.length > 300) logs.shift()
        logs.push(line)
        root.logLines = logs

        if (line.startsWith("{") && line.endsWith("}")) {
            try {
                var obj = JSON.parse(line)
                if (obj.type === "progress") {
                    if (obj.percent !== undefined) root.opProgress = obj.percent
                    if (obj.status) root.opStatus = obj.status
                    if (obj.speed) root.opSpeed = obj.speed
                    if (obj.eta) root.opEta = obj.eta
                    return
                }
            } catch (e) {}
        }

        var pctMatch = line.match(/\b([0-9]{1,3}(?:\.[0-9]+)?)\s*%/)
        if (pctMatch && pctMatch[1]) {
            var val = parseFloat(pctMatch[1])
            if (!isNaN(val) && val >= 0 && val <= 100) {
                root.opProgress = val
            }
        }

        var spdMatch = line.match(/([0-9.]+\s*[kMG]B\/s|[0-9.]+\s*[kMG]b\/s)/i)
        if (spdMatch) root.opSpeed = spdMatch[1]

        var etaMatch = line.match(/(?:ETA|eta|time)\s*([0-9:]+)/i)
        if (etaMatch) root.opEta = etaMatch[1]

        if (!line.startsWith("{") && line.length > 3 && !line.match(/^[0-9\s%#=-]+$/)) {
            root.opStatus = line
        }
    }

    function cancelOp() {
        if (actionProc.running) {
            actionProc.running = false
            root.runningOp = false
            root.failedOp = true
            root.opStatus = "Operation cancelled"
            _handleLogLine("[!] Process cancelled by user")
        }
    }

    function runVmAction(args, titleMsg, statusMsg) {
        if (actionProc.running) return
        root.runningOp = true
        root.failedOp = false
        root.opProgress = -1
        root.opSpeed = ""
        root.opEta = ""
        root.opTitle = titleMsg || "Virtual Machine Operation"
        root.opStatus = statusMsg || "Initializing..."
        root.logLines = []
        actionProc.command = ["mujo", "vm"].concat(args)
        actionProc.running = true
    }

    function startVm(name, openViewer) {
        runVmAction(["start", name, "--viewer", openViewer ? "true" : "false"], "Starting " + name, "Launching QEMU and connecting SPICE visual server...")
    }

    function stopVm(name, force) {
        var args = ["stop", name]
        if (force) args.push("--force")
        runVmAction(args, "Stopping " + name, "Sending ACPI shutdown signal...")
    }

    function displayVm(name) {
        runVmAction(["display", name], "Connecting Display", "Opening SPICE viewer for " + name + "...")
    }

    function deleteVm(name) {
        runVmAction(["delete", name], "Deleting " + name, "Removing VM disk and configuration files...")
    }

    function openDeployModal(preset) {
        root.targetPreset = preset
        root.createName = preset.os + "-" + preset.release
        root.createCores = preset.defaultCores || 8
        root.createRamGb = preset.defaultRamGb || 8
        root.createDiskGb = preset.defaultDiskGb || 40
        root.showCreateModal = true
    }

    function executeDeploy() {
        if (!root.targetPreset) return
        root.showCreateModal = false
        runVmAction([
            "create", root.targetPreset.os, root.targetPreset.release,
            "--name", root.createName,
            "--cores", String(root.createCores),
            "--ram", String(root.createRamGb),
            "--disk", String(root.createDiskGb)
        ], "Provisioning " + root.createName, "Fetching OS image and preparing VM environment...")
    }

    function executeDeployIso() {
        if (!root.customIsoPath || !root.customIsoName) return
        runVmAction([
            "create-iso", root.customIsoName, root.customIsoPath,
            "--cores", String(root.customIsoCores),
            "--ram", String(root.customIsoRamGb),
            "--disk", String(root.customIsoDiskGb),
            "--os", root.customIsoOs
        ], "Creating Custom VM: " + root.customIsoName, "Configuring VM from ISO " + root.customIsoName + "...")
        root.customIsoPath = ""
        root.customIsoName = ""
        root.activeTab = "vms"
    }

    MujoCard {
        title: "Hypervisor"
        iconName: "memory"
        badgeText: root.vmData.kvm ? "KVM" : "SOFTWARE"
        badgeColor: root.vmData.kvm ? Theme.success : Theme.warning
        collapsible: false

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 74
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 12
                    Rectangle {
                        implicitWidth: 38; implicitHeight: 38; radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.accent, 0.14)
                        BrandIcon { brand: "vm"; size: 20; anchors.centerIn: parent }
                    }
                    // fillWidth + elide: the cards are equal width, so the
                    // longest subtitle used to push its text into the card
                    // border instead of truncating inside it.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: String(root.vmData.activeCount || 0) + " / " + String(root.vmData.totalCount || 0) + " Active VMs"
                            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: "Virtual machines configured in ~/VMs"
                            color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 74
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 12
                    Rectangle {
                        implicitWidth: 38; implicitHeight: 38; radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.success, 0.14)
                        Text { text: "⚡"; font.pixelSize: 18; anchors.centerIn: parent }
                    }
                    // fillWidth + elide: the cards are equal width, so the
                    // longest subtitle used to push its text into the card
                    // border instead of truncating inside it.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: String(root.vmData.vcpusAllocated || 0) + " vCPUs Allocated"
                            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: root.vmData.kvm ? "Host Linux KVM direct virtualization active" : "Software virtualization fallback"
                            color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 74
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 12
                    Rectangle {
                        implicitWidth: 38; implicitHeight: 38; radius: Theme.radiusSm
                        color: Theme.withAlpha(Theme.accent, 0.14)
                        Text { text: "🖥️"; font.pixelSize: 18; anchors.centerIn: parent }
                    }
                    // fillWidth + elide: the cards are equal width, so the
                    // longest subtitle used to push its text into the card
                    // border instead of truncating inside it.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "SPICE Visual Server"
                            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: "Auto-resize, shared clipboard & audio stream"
                            color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }
        }

    }

    MujoCard {
        title: "Virtual machines"
        iconName: "dns"
        badgeText: String(root.vmData.activeCount || 0) + " / " + String(root.vmData.totalCount || 0) + " ACTIVE"
        collapsible: false

        actions: DialogButton {
            text: "Refresh"
            enabled: !root.runningOp
            onClicked: root.refresh()
        }

        // Card-local mode switch, not navigation: the three views are one
        // domain and share the operation log below them.
        MujoSegmented {
            Layout.fillWidth: true
            model: [
                { id: "vms", label: "Configured (" + (root.vmData.vms ? root.vmData.vms.length : 0) + ")" },
                { id: "catalog", label: "Deploy an OS" },
                { id: "custom", label: "Custom ISO" }
            ]
            current: root.activeTab
            onSelected: function (id) { root.activeTab = id }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: opCol.implicitHeight + 24
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: root.failedOp ? Theme.error : (root.runningOp ? Theme.accent : Theme.border)
            border.width: root.runningOp || root.failedOp ? 1.5 : 1
            visible: root.runningOp || root.failedOp || (root.logLines.length > 0 && root.opProgress === 100)

            ColumnLayout {
                id: opCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Top Row: Status, Title, Percentage, and Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Spinner / Status Icon
                    Rectangle {
                        implicitWidth: 32; implicitHeight: 32; radius: Theme.radiusSm
                        color: root.failedOp ? Theme.withAlpha(Theme.error, 0.16) : (root.runningOp ? Theme.withAlpha(Theme.accent, 0.16) : Theme.withAlpha(Theme.success, 0.16))
                        Spinner {
                            visible: root.runningOp
                            size: 14
                            anchors.centerIn: parent
                        }
                        MaterialIcon {
                            visible: !root.runningOp
                            iconName: root.failedOp ? "error" : "check_circle"
                            pixelSize: 16
                            color: root.failedOp ? Theme.error : Theme.success
                            anchors.centerIn: parent
                        }
                    }

                    // Title & Status details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8
                            Text {
                                text: root.opTitle || "Virtual Machine Operation"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                            }
                            // Speed / ETA pill if present
                            Text {
                                visible: root.opSpeed !== "" || root.opEta !== ""
                                text: (root.opSpeed ? "• " + root.opSpeed : "") + (root.opEta ? " • ETA: " + root.opEta : "")
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                            }
                        }

                        Text {
                            text: root.opStatus
                            color: root.failedOp ? Theme.error : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Percentage text
                    Text {
                        visible: root.opProgress >= 0
                        text: Math.round(root.opProgress) + "%"
                        color: root.failedOp ? Theme.error : Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeHeading
                        font.bold: true
                    }

                    // Toggle logs button
                    DialogButton {
                        text: root.showLogs ? "Hide Logs" : "Show Logs"
                        onClicked: root.showLogs = !root.showLogs
                    }

                    // Cancel / Dismiss button
                    DialogButton {
                        text: root.runningOp ? "Cancel" : "Dismiss"
                        danger: root.runningOp
                        onClicked: {
                            if (root.runningOp) root.cancelOp()
                            else {
                                root.logLines = []
                                root.opProgress = -1
                                root.failedOp = false
                            }
                        }
                    }
                }

                // Progress Bar Track
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Theme.surfaceActive
                    clip: true

                    // Determinate Fill
                    Rectangle {
                        id: progressFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: root.opProgress >= 0 ? Math.max(6, parent.width * Math.min(1.0, root.opProgress / 100.0)) : 0
                        radius: 3
                        color: root.failedOp ? Theme.error : (root.opProgress >= 100 ? Theme.success : Theme.accent)
                        visible: root.opProgress >= 0

                        Behavior on width {
                            NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard }
                        }
                    }

                    // Indeterminate Shimmer (when root.opProgress < 0 && root.runningOp)
                    Rectangle {
                        id: indeterminateShimmer
                        visible: root.opProgress < 0 && root.runningOp
                        width: parent.width * 0.35
                        height: parent.height
                        radius: 3
                        color: Theme.accent

                        SequentialAnimation on x {
                            running: root.opProgress < 0 && root.runningOp
                            loops: Animation.Infinite
                            NumberAnimation { from: -parent.width * 0.35; to: parent.width; duration: 1100; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // Live Log Terminal Stream (Expandable)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    visible: root.showLogs || root.failedOp
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: Theme.border
                    clip: true

                    ListView {
                        id: logList
                        anchors.fill: parent
                        anchors.margins: 8
                        model: root.logLines
                        boundsBehavior: Flickable.DragAndOvershootBounds
                        onCountChanged: positionViewAtEnd()
                        delegate: Text {
                            required property var modelData
                            width: logList.width
                            text: modelData
                            color: modelData.startsWith("[!]") ? Theme.error : (modelData.startsWith("{") ? Theme.accent : Theme.textSecondary)
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                    }
                }
            }
        }


        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: root.activeTab === "vms"

            RowLayout {
                Layout.fillWidth: true
                SectionLabel { text: "Active & Configured Virtual Machines"; Layout.fillWidth: true }
                DialogButton {
                    text: "🔄 Refresh"
                    enabled: !listProc.running
                    onClicked: root.refresh()
                }
            }

            // Empty State
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 140
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border
                visible: !root.vmData.vms || root.vmData.vms.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "No virtual machines found in ~/VMs"
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                        Layout.alignment: Qt.AlignHCenter
                    }
                    DialogButton {
                        text: "Deploy Windows, Ubuntu, or Fedora"
                        Layout.alignment: Qt.AlignHCenter
                        onClicked: root.activeTab = "catalog"
                    }
                }
            }

            // VM Cards Repeater
            Repeater {
                model: root.vmData.vms || []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 88

                    readonly property bool isOpTarget: root.runningOp && root.opTitle.indexOf(modelData.name) !== -1
                    readonly property bool isStarting: isOpTarget || (modelData.isSandbox && modelData.status === "running" && !modelData.displayReady)
                    readonly property bool isReady: modelData.status === "running" && (!modelData.isSandbox || modelData.displayReady)

                    radius: Theme.radiusMd
                    color: isReady ? Theme.withAlpha(Theme.success, 0.08)
                         : isStarting ? Theme.withAlpha(Theme.warning, 0.08)
                         : Theme.surface
                    border.color: isReady ? Theme.success
                                : isStarting ? Theme.warning
                                : Theme.border
                    border.width: (isReady || isStarting) ? 1.5 : 1

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 14

                        // OS Avatar Badge
                        Rectangle {
                            implicitWidth: 46; implicitHeight: 46; radius: Theme.radiusSm
                            color: isReady ? Theme.withAlpha(Theme.success, 0.2)
                                 : isStarting ? Theme.withAlpha(Theme.warning, 0.2)
                                 : Theme.withAlpha(Theme.accent, 0.12)
                            Text {
                                text: modelData.category === "Windows" ? "🪟"
                                    : modelData.category === "Apple" ? "🍎"
                                    : modelData.category === "NixOS" ? "❄️"
                                    : (modelData.icon === "ubuntu" ? "🟠" : modelData.icon === "fedora" ? "🔵" : modelData.icon === "arch" ? "🏹" : "🐧")
                                font.pixelSize: 22
                                anchors.centerIn: parent
                            }
                        }

                        // VM Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData.name
                                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true
                                }
                                Rectangle {
                                    implicitWidth: stText.implicitWidth + 12; implicitHeight: 20; radius: Theme.radiusSm
                                    color: isReady ? Theme.withAlpha(Theme.success, 0.2)
                                         : isStarting ? Theme.withAlpha(Theme.warning, 0.2)
                                         : Theme.withAlpha(Theme.textDim, 0.14)
                                    border.color: isReady ? Theme.success
                                                : isStarting ? Theme.warning
                                                : Theme.border
                                    Text {
                                        id: stText
                                        anchors.centerIn: parent
                                        text: isStarting ? "INITIALIZING..."
                                            : modelData.status.toUpperCase()
                                        color: isReady ? Theme.success
                                             : isStarting ? Theme.warning
                                             : Theme.textDim
                                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel; font.bold: true
                                    }
                                }
                                Rectangle {
                                    visible: modelData.isSandbox === true
                                    implicitWidth: sbTag.implicitWidth + 12; implicitHeight: 20; radius: Theme.radiusSm
                                    color: Theme.withAlpha(Theme.accent, 0.15)
                                    border.color: Theme.accent
                                    Text {
                                        id: sbTag
                                        anchors.centerIn: parent
                                        text: "SANDBOX"
                                        color: Theme.accent
                                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel; font.bold: true
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 12
                                Text {
                                    text: isStarting ? "⏳ Booting guest OS and starting Wayland display server..."
                                        : modelData.isSandbox ? "Cores: 8 vCPUs · RAM: 4G · Disk: Ephemeral tmpfs (9p live mount)"
                                        : "Cores: " + modelData.cores + " vCPUs · RAM: " + modelData.ram + " · Disk: " + modelData.diskSize
                                    color: isStarting ? Theme.warning : Theme.textSecondary
                                    font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel
                                }
                                Text {
                                    visible: isReady && !modelData.isSandbox
                                    text: "· SPICE Port: " + modelData.spicePort
                                    color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel
                                }
                                Text {
                                    visible: isReady && modelData.isSandbox
                                    text: "· Display Stream Active (Port 5920)"
                                    color: Theme.success; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel
                                }
                            }
                        }

                        // Explicit spacer so the action group lands on the
                        // card's right edge. Relying on the info column's
                        // fillWidth alone left the buttons ~75px short of it.
                        Item { Layout.fillWidth: true }

                        // Quick Actions
                        RowLayout {
                            Layout.fillWidth: false
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            // Action Buttons
                            DialogButton {
                                text: isStarting ? "⏳ Initializing..."
                                    : (modelData.isSandbox ? (isReady ? "🖥️ Observe Workspace" : "▶ Start Sandbox")
                                    : (isReady ? "🖥️ Display" : "▶ Start VM"))
                                primary: isReady || !isStarting
                                enabled: !root.runningOp && !isStarting
                                onClicked: {
                                    if (isReady) {
                                        root.displayVm(modelData.name)
                                    } else {
                                        root.startVm(modelData.name, false)
                                    }
                                }
                            }

                            DialogButton {
                                visible: modelData.status === "running"
                                text: "⏹ Stop"
                                enabled: !root.runningOp
                                onClicked: root.stopVm(modelData.name, false)
                            }

                            DialogButton {
                                text: modelData.isSandbox ? "🔄 Reset" : "🗑️ Delete"
                                enabled: !root.runningOp
                                onClicked: root.deleteVm(modelData.name)
                            }
                        }
                    }
                }
            }
        }


        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: root.activeTab === "catalog"

            SectionLabel { text: "Preconfigured OS Images & Workstations" }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: root.catalog
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 116
                        radius: Theme.radiusMd
                        color: Theme.surface
                        border.color: Theme.border

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14; spacing: 8

                            RowLayout {
                                Layout.fillWidth: true; spacing: 10
                                Text {
                                    text: modelData.category === "Windows" ? "🪟"
                                        : modelData.category === "Apple" ? "🍎"
                                        : modelData.category === "NixOS" ? "❄️"
                                        : (modelData.icon === "ubuntu" ? "🟠" : modelData.icon === "fedora" ? "🔵" : modelData.icon === "arch" ? "🏹" : "🐧")
                                    font.pixelSize: 20
                                }
                                Text {
                                    text: modelData.name
                                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true
                                    Layout.fillWidth: true
                                }
                                DialogButton {
                                    text: modelData.isSandbox ? "Start" : "Deploy"
                                    primary: true
                                    enabled: !root.runningOp
                                    onClicked: {
                                        if (modelData.isSandbox) {
                                            root.startVm(modelData.id, false)
                                        } else {
                                            root.openDeployModal(modelData)
                                        }
                                    }
                                }
                            }

                            Text {
                                text: modelData.desc
                                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }

                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "Default: " + modelData.defaultCores + " Cores · " + modelData.defaultRamGb + " GB RAM · " + modelData.defaultDiskGb + " GB Disk"
                                    color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel
                                }
                            }
                        }
                    }
                }
            }
        }


        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: root.activeTab === "custom"

            SectionLabel { text: "Create Virtual Machine from Local ISO Image" }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 290
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 14

                    Text {
                        text: "Specify an ISO installer image path on your local system to create a custom accelerated virtual machine."
                        color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "VM Name:"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 100 }
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bg; border.color: Theme.border
                            TextInput {
                                anchors.fill: parent; anchors.margins: 8
                                text: root.customIsoName
                                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                                onTextChanged: root.customIsoName = text
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "ISO File Path:"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 100 }
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bg; border.color: Theme.border
                            TextInput {
                                anchors.fill: parent; anchors.margins: 8
                                text: root.customIsoPath
                                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                                onTextChanged: root.customIsoPath = text
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 20
                        Text { text: "CPU Cores: " + root.customIsoCores; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 100 }
                        Slider {
                            Layout.fillWidth: true; from: 2; to: 16; value: root.customIsoCores
                            onMoved: v => root.customIsoCores = Math.round(v / 2) * 2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 20
                        Text { text: "RAM: " + root.customIsoRamGb + " GB"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 100 }
                        Slider {
                            Layout.fillWidth: true; from: 2; to: 32; value: root.customIsoRamGb
                            onMoved: v => root.customIsoRamGb = Math.round(v / 2) * 2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Item { Layout.fillWidth: true }
                        DialogButton {
                            text: "Create VM Configuration"
                            primary: true
                            enabled: root.customIsoPath.length > 0 && root.customIsoName.length > 0 && !root.runningOp
                            onClicked: root.executeDeployIso()
                        }
                    }
                }
            }
        }
    }

    // Provisioning form — inline, where the modal overlay used to be.
    MujoCard {
        title: "Provision " + (root.targetPreset ? root.targetPreset.name : "virtual machine")
        iconName: "add_box"
        visible: root.showCreateModal
        collapsible: false

        actions: DialogButton {
            text: "Cancel"
            onClicked: root.showCreateModal = false
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Text { text: "VM Name:"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 90 }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bg; border.color: Theme.border
                TextInput {
                    anchors.fill: parent; anchors.margins: 8
                    text: root.createName
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    onTextChanged: root.createName = text
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 16
            Text { text: "Cores: " + root.createCores; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 90 }
            Slider {
                Layout.fillWidth: true; from: 2; to: 16; value: root.createCores
                onMoved: v => root.createCores = Math.round(v / 2) * 2
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 16
            Text { text: "RAM: " + root.createRamGb + " GB"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 90 }
            Slider {
                Layout.fillWidth: true; from: 2; to: 32; value: root.createRamGb
                onMoved: v => root.createRamGb = Math.round(v / 2) * 2
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 16
            Text { text: "Disk: " + root.createDiskGb + " GB"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; Layout.preferredWidth: 90 }
            Slider {
                Layout.fillWidth: true; from: 10; to: 120; value: root.createDiskGb
                onMoved: v => root.createDiskGb = Math.round(v / 5) * 5
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 12; Layout.topMargin: 6
            DialogButton {
                text: "Cancel"
                onClicked: root.showCreateModal = false
            }
            Item { Layout.fillWidth: true }
            DialogButton {
                text: "Deploy & Prepare VM"
                primary: true
                onClicked: root.executeDeploy()
            }
        }
    }
}
