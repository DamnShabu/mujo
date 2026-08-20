import QtQuick
import QtQuick.Layouts
import Quickshell
import Niri

Rectangle {
    id: root
    property var niri
    property string screenName: ""
    property var myWorkspaces: computeWorkspaces()

    Timer {
        interval: 500
        repeat: true
        running: root.niri !== undefined
        onTriggered: root.myWorkspaces = root.computeWorkspaces()
      } // poll workspaces at 500ms

    function isWorkspaceActive(ws) {
        if (!ws) return false
        if (ws.isActive !== undefined) return !!ws.isActive
        if (ws.isFocused !== undefined) return !!ws.isFocused
        return false
    }

    function computeWorkspaces() {
        var result = []
        if (!root.niri || !root.niri.workspaces) return result
        var count = root.niri.workspaces.count
        for (var i = 0; i < count; i++) {
            var ws = root.niri.workspaces.get(i)
            if (ws && (ws.output === root.screenName || root.screenName === "")) {
                result.push({wsId: ws.id, wsActive: isWorkspaceActive(ws)})
            }
        }
        return result
    }

    function switchTo(wsId) {
        if (!root.niri || !root.niri.focusWorkspaceById) return
        root.niri.focusWorkspaceById(wsId)
        var result = []
        for (var i = 0; i < myWorkspaces.length; i++) {
            var ws = myWorkspaces[i]
            result.push({wsId: ws.wsId, wsActive: ws.wsId === wsId})
        }
        myWorkspaces = result
    }

    color: Theme.bg
    border.color: Theme.border
    implicitHeight: 25
    implicitWidth: Math.max(50, 20 + myWorkspaces.length * 20)
    radius: 5

    RowLayout {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            leftMargin: 10
            rightMargin: 10
        }
        spacing: Theme.workspaceSpacing

        Repeater {
            model: root.myWorkspaces

            Rectangle {
                id: wsPill
                property bool isActive: modelData.wsActive
                width: Theme.workspacePillSize
                height: Theme.workspacePillSize
                radius: Theme.workspacePillRadius
                color: Theme.workspaceInactive

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.workspacePillRadius
                    color: Theme.workspaceActive
                    opacity: wsPill.isActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.switchTo(modelData.wsId)
                    onEntered: if (!wsPill.isActive) wsPill.color = Theme.borderInteractive
                    onExited: if (!wsPill.isActive) wsPill.color = Theme.workspaceInactive
                }

                Text {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        horizontalCenter: parent.horizontalCenter
                    }
                    text: model.index + 1
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
