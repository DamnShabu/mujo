import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Io
import "calc.js" as Calc

Item {
    id: root

    property bool open: false
    property string screenName: ""
    property int baseWidth: Theme.launcherWidth
    property int baseHeight: Theme.launcherHeight
    signal requestClose

    property var results: []
    property int selectedIndex: 0
    property string answer: ""

    Timer {
        id: searchDebounce
        interval: 150
        repeat: false
        onTriggered: root.doUpdateResults()
    }

    function focusSearch() { searchField.forceActiveFocus() }

    function updateResults() {
        searchDebounce.restart()
    }

    function doUpdateResults() {
        var q = searchField.text.trim().toLowerCase()
        root.answer = q === "" ? "" : (Calc.tryEvaluate(q) || "")

        // DesktopEntries.applications is an UntypedObjectModel; .values gives the array.
        var appsModel = DesktopEntries && DesktopEntries.applications
        var apps = appsModel ? appsModel.values : null
        if (!apps) {
            root.results = []
            return
        }

        var out = []
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i]
            if (!app || !app.name) continue
            if (!q) { out.push(app); continue }
            var nameMatch = app.name.toLowerCase().includes(q)
            var genericMatch = app.genericName && app.genericName.toLowerCase().includes(q)
            var commentMatch = app.comment && app.comment.toLowerCase().includes(q)
            // keywords is a list of strings on the DesktopEntry (e.g. "browser").
            var keywordMatch = false
            if (app.keywords) {
                for (var k = 0; k < app.keywords.length; k++) {
                    if (String(app.keywords[k]).toLowerCase().includes(q)) { keywordMatch = true; break }
                }
            }
            // Also match the executable, so e.g. "chromium" finds an app whose
            // display name differs from its binary.
            var execMatch = app.execString && app.execString.toLowerCase().includes(q)
            if (nameMatch || genericMatch || commentMatch || keywordMatch || execMatch) {
                app._rank = nameMatch ? 0 : genericMatch ? 1 : keywordMatch ? 2 : commentMatch ? 3 : 4
                out.push(app)
            }
        }
        out.sort(function (a, b) {
            if (!q) return a.name.localeCompare(b.name)
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
            Launch.app(root.results[root.selectedIndex], root.screenName)
            root.requestClose()
        }
    }

    Process { id: copyProcess; command: ["wl-copy"] }

    onOpenChanged: {
        if (root.open) {
            searchField.text = ""
            doUpdateResults()
            root.selectedIndex = 0
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusLg
        clip: true
        color: Theme.bg
        border.color: Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 8

                Text {
                    text: "力"
                    color: Theme.accent
                    font.pixelSize: 15
                }
                SectionLabel {
                    text: "Launcher"
                    accented: false
                    Layout.fillWidth: true
                }
                SectionLabel {
                    text: root.results.length + " result" + (root.results.length === 1 ? "" : "s")
                    visible: searchField.text !== ""
                }
            }

            Rectangle {
                id: searchWrap
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: Theme.radiusMd
                color: Theme.surface
                border.color: searchField.activeFocus ? Theme.accent : Theme.border

                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    iconName: "search"
                    pixelSize: 17
                    color: searchField.activeFocus ? Theme.accent : Theme.textSecondary
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    leftPadding: 42
                    rightPadding: 12
                    focus: true
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
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
                        leftPadding: 42
                        rightPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        text: "Search apps or type a sum…"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        visible: searchField.text === ""
                    }
                }
            }

            Rectangle {
                id: answerWrap
                Layout.fillWidth: true
                Layout.preferredHeight: root.answer === "" ? 0 : 42
                clip: true
                visible: root.answer !== ""
                radius: Theme.radiusMd
                color: Theme.accentDim
                border.color: Theme.accent
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }

                MouseArea { anchors.fill: parent; onClicked: root.confirmSelection() }

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
                        color: Theme.accent
                    }

                    Text {
                        anchors.left: ansIcon.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "= " + root.answer
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        font.bold: true
                    }

                    SectionLabel {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter to copy"
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: searchField.text === "" ? "Type to search installed apps" : "No matches"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                ListView {
                    id: resultList
                    anchors.fill: parent
                    clip: true
                    spacing: 3
                    model: root.results

                    delegate: LauncherResult {
                        width: resultList.width
                        highlighted: index === root.selectedIndex
                        entry: modelData

                        HoverHandler { onHoveredChanged: { if (hovered) root.selectedIndex = index } }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Launch.app(modelData, root.screenName)
                                root.requestClose()
                            }
                        }
                    }
                }
            }

            LauncherActionBar {
                id: actionBar
                selectedEntry: root.results[root.selectedIndex]
                screenName: root.screenName
                dropdownParent: root
                onRequestClose: root.requestClose()
                onTriggered: root.requestClose()
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
        radius: Theme.radiusMd
        color: Theme.surface
        border.color: Theme.borderStrong

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
                    radius: Theme.radiusSm
                    color: dropdown.hoverIndex === index ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MaterialIcon { iconName: modelData.icon; pixelSize: 13; color: Theme.textSecondary }
                        Text { text: modelData.label; color: Theme.text; font.pixelSize: 12; Layout.fillWidth: true }
                        Text { text: modelData.shortcut; color: Theme.textSecondary; font.pixelSize: 10; visible: modelData.shortcut !== "" }
                    }

                    HoverHandler { onHoveredChanged: dropdown.hoverIndex = hovered ? index : -1 }

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
