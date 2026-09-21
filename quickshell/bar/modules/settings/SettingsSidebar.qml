import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../theme"
import "../../components"

// The sidebar: search, the category tree, and a footer with the live theme and
// the way out. Search sits at the top because it is the first thing you reach
// for in a settings app with two hundred settings in it; the brand block that
// used to occupy those three lines said only what the window title already
// says.
Rectangle {
    id: bar

    property var shell: null          // the SettingsLayout that owns the state
    property alias searchText: field.text
    property bool compact: false

    signal searchRequested()

    function focusField() { field.forceActiveFocus() }
    function clearField() { field.text = "" }
    function focusRail() { rail.forceActiveFocus() }

    implicitWidth: bar.compact ? 60 : 236
    color: Theme.surface

    Behavior on implicitWidth {
        NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard }
    }

    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 1
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.rightMargin: 13
        spacing: 10

        // ── Search ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 34
            radius: Theme.radiusSm
            color: field.activeFocus ? Theme.bg : Theme.withAlpha(Theme.bg, 0.6)
            border.width: 1
            border.color: field.activeFocus ? Theme.borderInteractive : Theme.border
            Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: bar.searchRequested()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: bar.compact ? 0 : 10
                anchors.rightMargin: bar.compact ? 0 : 8
                spacing: bar.compact ? 0 : 8

                Item { visible: bar.compact; Layout.fillWidth: true }

                MaterialIcon {
                    iconName: "search"
                    pixelSize: 16
                    color: field.activeFocus ? Theme.text : Theme.textDim
                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                }

                Item { visible: bar.compact; Layout.fillWidth: true }

                TextInput {
                    id: field
                    visible: !bar.compact
                    Layout.fillWidth: !bar.compact
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    activeFocusOnTab: true
                    cursorVisible: activeFocus

                    onTextChanged: if (bar.shell) { bar.shell.query = text; bar.shell.searchSel = 0 }
                    Keys.onDownPressed: if (bar.shell) bar.shell.stepResult(1)
                    Keys.onUpPressed: if (bar.shell) bar.shell.stepResult(-1)
                    Keys.onReturnPressed: if (bar.shell) bar.shell.activateResult(bar.shell.searchSel)
                    Keys.onEscapePressed: {
                        if (text === "") Qt.quit()
                        else if (bar.shell) bar.shell.clearSearch()
                    }
                    // Let the rail collapse again once an empty search is left
                    // behind.
                    onActiveFocusChanged: if (!activeFocus && text === "" && bar.shell) bar.shell.searchExpanded = false

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "Search settings"
                        color: Theme.textDim
                        font: field.font
                    }
                }

                MaterialIcon {
                    visible: !bar.compact && field.text !== ""
                    iconName: "close"
                    pixelSize: 15
                    color: clearHh.hovered ? Theme.text : Theme.textDim
                    HoverHandler { id: clearHh; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: if (bar.shell) bar.shell.clearSearch()
                    }
                }
            }
        }

        // ── Category tree ────────────────────────────────────────────────────
        Flickable {
            id: rail
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 4
            clip: true
            contentHeight: railCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            activeFocusOnTab: true
            Keys.onUpPressed: if (bar.shell) bar.shell.step(-1)
            Keys.onDownPressed: if (bar.shell) bar.shell.step(1)
            // Keys has no onHome/onEndPressed attached signal.
            Keys.onPressed: function (event) {
                if (!bar.shell) return
                if (event.key === Qt.Key_Home) { bar.shell.step(-bar.shell.railRows.length); event.accepted = true }
                else if (event.key === Qt.Key_End) { bar.shell.step(bar.shell.railRows.length); event.accepted = true }
            }

            Accessible.role: Accessible.PageTabList
            Accessible.name: "Settings categories"

            ColumnLayout {
                id: railCol
                width: rail.width
                spacing: 2

                Repeater {
                    model: bar.shell ? bar.shell.railRows : []

                    delegate: SettingsNavRow {
                        required property var modelData
                        entry: modelData
                        compact: bar.compact
                        focused: rail.activeFocus
                        active: bar.shell ? bar.shell.rowIsActive(modelData) : false
                        inBranch: bar.shell ? (modelData.kind === "cat" && modelData.cat === bar.shell.current && !bar.shell.searching) : false
                        open: bar.shell ? (modelData.kind === "cat" && modelData.cat === bar.shell.expandedKey) : false
                        onActivated: {
                            if (bar.shell) bar.shell.activateRow(modelData)
                            bar.focusRail()
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

        // ── Footer ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: 8

            Text {
                visible: !bar.compact
                Layout.fillWidth: true
                Layout.leftMargin: 12
                text: Theme.presetLabels[Theme.presetName] || Theme.presetName
                color: themeHh.hovered ? Theme.text : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                HoverHandler { id: themeHh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (bar.shell) bar.shell.route("appearance") }
            }

            Item { visible: bar.compact; Layout.fillWidth: true }

            IconButton {
                iconName: "close"
                onClicked: Qt.quit()
            }

            Item { visible: bar.compact; Layout.fillWidth: true }
        }
    }
}
