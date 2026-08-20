import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Io
import "calc.js" as Calc

Item {
    id: root

    property bool open: false
    property int baseWidth: Theme.launcherWidth
    property int baseHeight: Theme.launcherHeight
    signal requestClose

    property var results: []
    property int selectedIndex: 0
    property string answer: ""
    property bool browsing: searchField.text.trim() === ""
    property var weather
    property string wallpaperPath: ""
    property string cityName: ""

    Timer {
        id: searchDebounce
        interval: 150
        repeat: false
        onTriggered: root.doUpdateResults()
      } // 150ms search debounce

    function focusSearch() { searchField.forceActiveFocus() }

    function updateResults() {
        searchDebounce.restart()
    }

    function doUpdateResults() {
        var q = searchField.text.trim().toLowerCase()
        root.answer = q === "" ? "" : (Calc.tryEvaluate(q) || "")

        var appsModel = DesktopEntries && DesktopEntries.applications
        if (!appsModel) {
            root.results = []
            return
        }

        var out = []
        var count = appsModel.count
        for (var i = 0; i < count; i++) {
            var app = appsModel.get(i)
            if (!app || !app.name) continue
            if (!q) { out.push(app); continue }
            var nameMatch = app.name.toLowerCase().includes(q)
            var genericMatch = app.genericName && app.genericName.toLowerCase().includes(q)
            var commentMatch = app.comment && app.comment.toLowerCase().includes(q)
            var fileMatch = app.fileName && app.fileName.toLowerCase().includes(q)
            if (nameMatch || genericMatch || commentMatch || fileMatch) {
                app._rank = nameMatch ? 0 : genericMatch ? 1 : commentMatch ? 2 : 3
                out.push(app)
            }
        }
        out.sort(function (a, b) {
            if (a._rank !== b._rank) return (a._rank || 0) - (b._rank || 0)
            return a.name.localeCompare(b.name)
        })
        root.results = out
    }

    Connections {
        target: DesktopEntries && DesktopEntries.applications
        function onValuesChanged() { if (root.open) updateResults() }
    }

    function confirmSelection() {
        if (root.answer !== "") {
            copyProcess.command = ["wl-copy", root.answer]
            copyProcess.running = true
            root.requestClose()
        } else if (root.selectedIndex >= 0 && root.selectedIndex < root.results.length) {
            root.results[root.selectedIndex].execute()
            root.requestClose()
        }
    }

    Process {
        id: copyProcess
        command: ["wl-copy"]
    }

    onOpenChanged: {
        if (root.open) {
            searchField.text = ""
            doUpdateResults()
            root.selectedIndex = 0
        }
    }

    Rectangle {
        id: bg
        anchors.centerIn: parent
        readonly property int collapsedWidth: 150
        readonly property int collapsedHeight: 30
        width: root.open ? parent.width : collapsedWidth
        height: root.open ? parent.height : collapsedHeight
        radius: 5
        clip: true
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        opacity: root.open ? 1 : 0
        Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Rectangle {
                id: searchWrap
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 5
                color: Theme.surface
                border.color: searchField.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 120 } }

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    iconName: "bolt"
                    pixelSize: 15
                    color: Theme.textSecondary
                }

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    leftPadding: 36
                    rightPadding: 10
                    focus: true
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    color: Theme.text
                    font.pixelSize: 13
                    selectByMouse: true
                    activeFocusOnPress: true
                    onTextChanged: {
                        updateResults()
                        root.selectedIndex = 0
                    }
                    Keys.onEscapePressed: {
                        if (actionBar.dropdownOpen) actionBar.dropdownOpen = false
                        else root.requestClose()
                    }
                    Keys.onReturnPressed: {
                        if (actionBar.dropdownOpen) {
                            if (dropdown.hoverIndex >= 0) {
                                actionBar.dropdownOpen = false
                                actionBar.triggerAction(dropdown.hoverIndex)
                            }
                            return
                        }
                        root.confirmSelection()
                    }
                    Keys.onUpPressed: {
                        if (actionBar.dropdownOpen) {
                            dropdown.hoverIndex = Math.max(0, dropdown.hoverIndex - 1)
                            return
                        }
                        if (root.results.length === 0) return
                        root.selectedIndex = (root.selectedIndex - 1 + root.results.length) % root.results.length
                        resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    Keys.onDownPressed: {
                        if (actionBar.dropdownOpen) {
                            dropdown.hoverIndex = Math.min(dropdown.model.length - 1, dropdown.hoverIndex + 1)
                            return
                        }
                        if (root.results.length === 0) return
                        root.selectedIndex = (root.selectedIndex + 1) % root.results.length
                        resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                            actionBar.dropdownOpen = !actionBar.dropdownOpen
                            event.accepted = true
                        }
                    }

                    Text {
                        anchors.fill: parent
                        leftPadding: 36
                        rightPadding: 10
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignLeft
                        text: "Search apps..."
                        color: Theme.textSecondary
                        font.pixelSize: 13
                        visible: searchField.text === ""
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    LauncherOverview {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        weather: root.weather
                        wallpaperPath: root.wallpaperPath
                        cityName: root.cityName
                        visible: root.browsing
                        opacity: root.browsing ? 1 : 0
                        scale: root.browsing ? 1 : 0.96
                        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.browsing
                        spacing: 8

                        Rectangle {
                            id: answerWrap
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.answer === "" ? 0 : 38
                            clip: true
                            visible: root.answer !== ""
                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }

                            Rectangle {
                                anchors.fill: parent
                                radius: 5
                                color: Theme.surface
                                border.color: Theme.borderInteractive

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.confirmSelection()
                                }

                                Item {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10

                                    MaterialIcon {
                                        id: ansIcon
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        iconName: "calculate"
                                        pixelSize: 15
                                        color: Theme.textSecondary
                                    }

                                    Text {
                                        anchors.left: ansIcon.right
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "= " + root.answer
                                        color: Theme.text
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Enter to copy"
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }

                        ListView {
                            id: resultList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: root.results

                            delegate: LauncherResult {
                                width: resultList.width
                                highlighted: index === root.selectedIndex
                                entry: modelData

                                HoverHandler {
                                    onHoveredChanged: { if (hovered) root.selectedIndex = index }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        modelData.execute()
                                        root.requestClose()
                                    }
                                }
                            }
                        }

                        LauncherActionBar {
                            id: actionBar
                            selectedEntry: root.results[root.selectedIndex]
                            dropdownParent: root
                            onRequestClose: root.requestClose()
                            onTriggered: root.requestClose()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: dropdown
        visible: actionBar.dropdownOpen
        z: 100
        x: actionBar.dropdownPos.x
        y: actionBar.dropdownPos.y
        width: 240
        height: dropdownCol.implicitHeight + 12
        radius: 5
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        property int hoverIndex: -1

        property var model: [
            { label: "Open Application", icon: "open_in_new", shortcut: "Enter" },
            { label: "Copy App Name", icon: "content_copy", shortcut: "" },
            { label: "Copy Desktop Entry Path", icon: "description", shortcut: "" },
            { label: "Open File Manager", icon: "folder_open", shortcut: "" },
            { label: "Copy Exec Path", icon: "folder_copy", shortcut: "" }
        ]

        Column {
            id: dropdownCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: dropdown.model

                delegate: Rectangle {
                    required property int index
                    required property var modelData

                    width: dropdownCol.width
                    height: 28
                    radius: 3
                    color: dropdown.hoverIndex === index ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MaterialIcon {
                            iconName: modelData.icon
                            pixelSize: 13
                            color: Theme.textSecondary
                        }

                        Text {
                            text: modelData.label
                            color: Theme.text
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.shortcut
                            color: Theme.textSecondary
                            font.pixelSize: 10
                            visible: modelData.shortcut !== ""
                        }
                    }

                    HoverHandler {
                        onHoveredChanged: dropdown.hoverIndex = hovered ? index : -1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            actionBar.dropdownOpen = false
                            actionBar.triggerAction(index)
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 99
        visible: actionBar.dropdownOpen
        onClicked: actionBar.dropdownOpen = false
    }
}
