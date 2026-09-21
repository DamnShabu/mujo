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

    // View state only. Everything that talks to `mujo vm` lives in VmService.
    property string activeTab: "vms" // "vms", "catalog", "custom"
    property bool showLogs: false

    // Provisioning form state
    property bool showCreateModal: false
    property var targetPreset: null
    property string createName: ""
    property int createCores: 8
    property int createRamGb: 8
    property int createDiskGb: 40

    // Custom ISO form state
    property string customIsoPath: ""
    property string customIsoName: ""
    property int customIsoCores: 8
    property int customIsoRamGb: 8
    property int customIsoDiskGb: 40
    property string customIsoOs: "linux"

    Timer {
        id: pollTimer
        interval: 2000
        // Pages stay alive when another category is on screen, so the poll
        // follows visibility instead of running for the rest of the session.
        // This is why VmService does not poll itself.
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: VmService.refresh()
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
        VmService.create(root.targetPreset, root.createName,
                         root.createCores, root.createRamGb, root.createDiskGb)
    }

    function executeDeployIso() {
        if (!root.customIsoPath || !root.customIsoName) return
        VmService.createFromIso(root.customIsoName, root.customIsoPath,
                                root.customIsoCores, root.customIsoRamGb,
                                root.customIsoDiskGb, root.customIsoOs)
        root.customIsoPath = ""
        root.customIsoName = ""
        root.activeTab = "vms"
    }

    function osIconName(category, icon) {
        var key = (icon || "").toLowerCase()
        if (key === "nixos" || category === "NixOS") return "ac_unit"
        if (key === "windows" || category === "Windows") return "window"
        if (key === "macos" || category === "Apple") return "desktop_mac"
        if (key === "freebsd" || category === "BSD") return "whatshot"
        if (Brand.has(key) && Brand.get(key).mat) return Brand.get(key).mat
        if (key === "ubuntu") return "group_work"
        if (key === "fedora") return "policy"
        if (key === "arch") return "change_history"
        if (key === "debian") return "rotate_right"
        if (key === "alpine") return "landscape"
        return "terminal"
    }

    function osIconColor(category, icon) {
        var key = (icon || "").toLowerCase()
        if (key === "nixos" || category === "NixOS") return Brand.get("nixos").color
        if (Brand.has(key)) return Brand.get(key).color
        return Theme.accent
    }

    MujoCard {
        title: "Hypervisor"
        iconName: "memory"
        badgeText: VmService.inventory.kvm ? "KVM" : "SOFTWARE"
        badgeColor: VmService.inventory.kvm ? Theme.success : Theme.warning

        // Three facts about the host, not three cards about it. They were
        // 74px tiles with an icon plate each — a lot of chrome to say
        // "2 / 5 active".
        InfoRow {
            label: "Active machines"
            value: String(VmService.inventory.activeCount || 0) + " of " + String(VmService.inventory.totalCount || 0)
        }

        InfoRow {
            label: "vCPUs allocated"
            value: String(VmService.inventory.vcpusAllocated || 0)
        }

        InfoRow {
            label: "Virtualization"
            mono: false
            iconName: VmService.inventory.kvm ? "bolt" : "warning"
            iconColor: VmService.inventory.kvm ? Theme.success : Theme.warning
            value: VmService.inventory.kvm ? "Host KVM, hardware accelerated" : "Software fallback"
        }

        InfoRow {
            label: "Display"
            mono: false
            value: "SPICE — auto-resize, shared clipboard and audio"
        }

    }

    MujoCard {
        title: "Virtual Machines"
        iconName: "dns"
        badgeText: String(VmService.inventory.activeCount || 0) + " / " + String(VmService.inventory.totalCount || 0) + " ACTIVE"

        actions: DialogButton {
            text: "Refresh"
            iconName: "refresh"
            enabled: !VmService.running
            onClicked: VmService.refresh()
        }

        // Card-local mode switch, not navigation: the three views are one
        // domain and share the operation log below them.
        MujoSegmented {
            Layout.fillWidth: true
            model: [
                { id: "vms", label: "Configured (" + (VmService.inventory.vms ? VmService.inventory.vms.length : 0) + ")" },
                { id: "catalog", label: "Deploy an OS" },
                { id: "custom", label: "Custom ISO" }
            ]
            current: root.activeTab
            onSelected: function (id) { root.activeTab = id }
        }

        InsetPanel {
            Layout.fillWidth: true
            implicitHeight: opCol.implicitHeight + 28
            accentBorder: VmService.failed ? Theme.error : (VmService.running ? Theme.accent : Theme.border)
            visible: VmService.running || VmService.failed || (VmService.logLines.length > 0 && VmService.opProgress === 100)

            ColumnLayout {
                id: opCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Top Row: Status, Title, Percentage, and Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Spinner { visible: VmService.running; size: 14; Layout.alignment: Qt.AlignVCenter }

                    MaterialIcon {
                        visible: !VmService.running
                        iconName: VmService.failed ? "error" : "check_circle"
                        pixelSize: 17
                        color: VmService.failed ? Theme.error : Theme.success
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Title & Status details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8
                            Text {
                                text: VmService.opTitle || "Virtual Machine Operation"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                            }
                            // Speed / ETA pill if present
                            Text {
                                visible: VmService.opSpeed !== "" || VmService.opEta !== ""
                                text: (VmService.opSpeed ? "• " + VmService.opSpeed : "") + (VmService.opEta ? " • ETA: " + VmService.opEta : "")
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                            }
                        }

                        Text {
                            text: VmService.opStatus
                            color: VmService.failed ? Theme.error : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Percentage text
                    Text {
                        visible: VmService.opProgress >= 0
                        text: Math.round(VmService.opProgress) + "%"
                        color: VmService.failed ? Theme.error : Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeHeading
                        font.bold: true
                    }

                    // Toggle logs button
                    DialogButton {
                        text: root.showLogs ? "Hide log" : "Show log"
                        onClicked: root.showLogs = !root.showLogs
                    }

                    // Cancel / Dismiss button
                    DialogButton {
                        text: VmService.running ? "Cancel" : "Dismiss"
                        danger: VmService.running
                        onClicked: {
                            if (VmService.running) VmService.cancel()
                            else {
                                VmService.logLines = []
                                VmService.opProgress = -1
                                VmService.failed = false
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
                        width: VmService.opProgress >= 0 ? Math.max(6, parent.width * Math.min(1.0, VmService.opProgress / 100.0)) : 0
                        radius: 3
                        color: VmService.failed ? Theme.error : (VmService.opProgress >= 100 ? Theme.success : Theme.accent)
                        visible: VmService.opProgress >= 0

                        Behavior on width {
                            NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard }
                        }
                    }

                    // Indeterminate Shimmer (when VmService.opProgress < 0 && VmService.running)
                    Rectangle {
                        id: indeterminateShimmer
                        visible: VmService.opProgress < 0 && VmService.running
                        width: parent.width * 0.35
                        height: parent.height
                        radius: 3
                        color: Theme.accent

                        SequentialAnimation on x {
                            running: VmService.opProgress < 0 && VmService.running
                            loops: Animation.Infinite
                            NumberAnimation { from: -parent.width * 0.35; to: parent.width; duration: 1100; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // Live Log Terminal Stream (Expandable)
                InsetPanel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    visible: root.showLogs || VmService.failed

                    ListView {
                        id: logList
                        anchors.fill: parent
                        anchors.margins: 8
                        model: VmService.logLines
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


            EmptyState {
                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.bottomMargin: 24
                visible: !VmService.inventory.vms || VmService.inventory.vms.length === 0
                iconName: "dns"
                title: "No virtual machines yet"
                hint: "Machines live in ~/VMs. Deploy one from the catalog, or point at an ISO you already have."

                DialogButton {
                    text: "Browse the catalog"
                    iconName: "add"
                    primary: true
                    onClicked: root.activeTab = "catalog"
                }
            }

            Repeater {
                model: VmService.inventory.vms || []

                delegate: ListRow {
                    required property var modelData

                    readonly property bool isOpTarget: VmService.running && VmService.opTitle.indexOf(modelData.name) !== -1
                    readonly property bool isStarting: isOpTarget || (modelData.isSandbox && modelData.status === "running" && !modelData.displayReady)
                    readonly property bool isReady: modelData.status === "running" && (!modelData.isSandbox || modelData.displayReady)
                    readonly property color tone: isReady ? Theme.success : (isStarting ? Theme.warning : Theme.textDim)

                    implicitHeight: 62
                    border.color: isReady ? Theme.withAlpha(Theme.success, 0.5)
                                : (isStarting ? Theme.withAlpha(Theme.warning, 0.5) : Theme.border)

                    // The OS mark, unplated. A 46px tinted tile around a glyph
                    // is a lot of furniture for a row that already has a
                    // status tag saying the same thing in words.
                    MaterialIcon {
                        iconName: root.osIconName(modelData.category, modelData.icon)
                        pixelSize: 22
                        color: isReady || isStarting ? tone : root.osIconColor(modelData.category, modelData.icon)
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            spacing: 7

                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: Font.DemiBold
                            }

                            StatusTag {
                                text: isStarting ? "STARTING" : modelData.status.toUpperCase()
                                toneColor: tone
                            }

                            StatusTag {
                                visible: modelData.isSandbox === true
                                text: "SANDBOX"
                                tone: "accent"
                            }
                        }

                        Text {
                            text: {
                                if (isStarting) return "Booting the guest and starting its display server"
                                var spec = modelData.isSandbox
                                    ? "8 vCPUs · 4G · ephemeral tmpfs"
                                    : modelData.cores + " vCPUs · " + modelData.ram + " · " + modelData.diskSize
                                if (isReady && !modelData.isSandbox) spec += " · SPICE :" + modelData.spicePort
                                else if (isReady) spec += " · display on :5920"
                                return spec
                            }
                            color: isStarting ? Theme.warning : Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    DialogButton {
                        text: isStarting ? "Starting"
                            : (modelData.isSandbox ? (isReady ? "Observe" : "Start sandbox")
                            : (isReady ? "Display" : "Start"))
                        iconName: isStarting ? "hourglass_top" : (isReady ? "desktop_windows" : "play_arrow")
                        primary: isReady || !isStarting
                        enabled: !VmService.running && !isStarting
                        onClicked: {
                            if (isReady) VmService.display(modelData.name)
                            else VmService.start(modelData.name, false)
                        }
                    }

                    DialogButton {
                        visible: modelData.status === "running"
                        text: "Stop"
                        iconName: "stop"
                        enabled: !VmService.running
                        onClicked: VmService.stop(modelData.name, false)
                    }

                    DialogButton {
                        text: modelData.isSandbox ? "Reset" : "Delete"
                        iconName: modelData.isSandbox ? "restart_alt" : "delete"
                        danger: !modelData.isSandbox
                        enabled: !VmService.running
                        onClicked: VmService.remove(modelData.name)
                    }
                }
            }
        }


        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: root.activeTab === "catalog"

            // The catalog is the same kind of list as the machines above it —
            // pick one, act on it. It used to be a two-column grid of tiles, so
            // the same domain had two shapes on two tabs of one card.
            Repeater {
                model: VmService.catalog

                delegate: ListRow {
                    required property var modelData
                    implicitHeight: 62

                    MaterialIcon {
                        iconName: root.osIconName(modelData.category, modelData.icon)
                        pixelSize: 22
                        color: root.osIconColor(modelData.category, modelData.icon)
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: modelData.desc
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: modelData.defaultCores + " vCPUs · " + modelData.defaultRamGb + "G · " + modelData.defaultDiskGb + "G"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        Layout.alignment: Qt.AlignVCenter
                    }

                    DialogButton {
                        text: modelData.isSandbox ? "Start" : "Deploy"
                        iconName: modelData.isSandbox ? "play_arrow" : "add"
                        primary: true
                        enabled: !VmService.running
                        onClicked: {
                            if (modelData.isSandbox) VmService.start(modelData.id, false)
                            else root.openDeployModal(modelData)
                        }
                    }
                }
            }
        }

        // ── Custom ISO ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            visible: root.activeTab === "custom"

            Text {
                text: "Point at an installer image already on this machine and it becomes an accelerated virtual machine."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.bottomMargin: 8
            }

            MujoSettingRow {
                title: "Name"
                description: "What the machine will be called in the list above."

                TextField {
                    Layout.preferredWidth: 240
                    a11yName: "Virtual machine name"
                    placeholder: "windows-11"
                    text: root.customIsoName
                    onTextChanged: root.customIsoName = text
                }
            }

            MujoSettingRow {
                title: "Installer image"
                description: "Absolute path to the .iso file."

                TextField {
                    Layout.preferredWidth: 320
                    a11yName: "ISO file path"
                    placeholder: "~/Downloads/installer.iso"
                    text: root.customIsoPath
                    onTextChanged: root.customIsoPath = text
                }
            }

            MujoSettingRow {
                title: "CPU cores"
                description: "How many virtual cores the guest gets."

                Slider {
                    Layout.preferredWidth: 190
                    a11yName: "CPU cores"
                    from: 2
                    to: 16
                    value: root.customIsoCores
                    valueText: root.customIsoCores + " cores"
                    onMoved: v => root.customIsoCores = Math.round(v / 2) * 2
                }

                Text {
                    text: root.customIsoCores
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 46
                }
            }

            MujoSettingRow {
                title: "Memory"
                description: "How much RAM the guest gets."

                Slider {
                    Layout.preferredWidth: 190
                    a11yName: "Memory"
                    from: 2
                    to: 32
                    value: root.customIsoRamGb
                    valueText: root.customIsoRamGb + " GB"
                    onMoved: v => root.customIsoRamGb = Math.round(v / 2) * 2
                }

                Text {
                    text: root.customIsoRamGb + "G"
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 46
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 12

                Item { Layout.fillWidth: true }

                DialogButton {
                    text: "Create machine"
                    primary: true
                    enabled: root.customIsoPath.length > 0 && root.customIsoName.length > 0 && !VmService.running
                    onClicked: root.executeDeployIso()
                }
            }
        }
    }

    // Provisioning form — inline, where the modal overlay used to be.
    MujoCard {
        title: "Provision " + (root.targetPreset ? root.targetPreset.name : "virtual machine")
        iconName: "add_box"
        visible: root.showCreateModal

        actions: DialogButton {
            text: "Cancel"
            onClicked: root.showCreateModal = false
        }

        MujoSettingRow {
            title: "Name"
            description: "What the machine will be called in the list."

            TextField {
                Layout.preferredWidth: 240
                a11yName: "Virtual machine name"
                text: root.createName
                onTextChanged: root.createName = text
            }
        }

        MujoSettingRow {
            title: "CPU cores"

            Slider {
                Layout.preferredWidth: 190
                a11yName: "CPU cores"
                from: 2
                to: 16
                value: root.createCores
                onMoved: v => root.createCores = Math.round(v / 2) * 2
            }

            Text {
                text: root.createCores
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46
            }
        }

        MujoSettingRow {
            title: "Memory"

            Slider {
                Layout.preferredWidth: 190
                a11yName: "Memory"
                from: 2
                to: 32
                value: root.createRamGb
                onMoved: v => root.createRamGb = Math.round(v / 2) * 2
            }

            Text {
                text: root.createRamGb + "G"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46
            }
        }

        MujoSettingRow {
            title: "Disk"

            Slider {
                Layout.preferredWidth: 190
                a11yName: "Disk size"
                from: 10
                to: 120
                value: root.createDiskGb
                onMoved: v => root.createDiskGb = Math.round(v / 5) * 5
            }

            Text {
                text: root.createDiskGb + "G"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 12

            Item { Layout.fillWidth: true }

            DialogButton {
                text: "Deploy"
                primary: true
                onClicked: root.executeDeploy()
            }
        }
    }
}
