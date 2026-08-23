import QtQuick
import QtQuick.Layouts
import Quickshell
import Niri

Item {
    id: root
    property var niri
    property string screenName: ""
    property var workspaceList: []

    implicitHeight: Theme.workspacePillSize
    implicitWidth: rowLayout.implicitWidth

    // Scroll over the workspaces pill to switch workspace (WP-17 scroll actions).
    WheelHandler {
        enabled: SettingsBus.get("bar.scrollActions", true)
        onWheel: function (e) {
            Quickshell.execDetached(["niri", "msg", "action", e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down"])
        }
    }

    // niri's WorkspaceModel.get() returns a plain QVariantMap with no change
    // notification per-field, so we poll rather than bind directly.
    function isWorkspaceFocused(ws) {
        if (!ws) return false
        if (ws.isFocused !== undefined) return !!ws.isFocused
        if (ws.isActive !== undefined) return !!ws.isActive
        return false
    }

    function refresh() {
        var result = []
        if (root.niri && root.niri.workspaces) {
            var count = root.niri.workspaces.count
            for (var i = 0; i < count; i++) {
                var ws = root.niri.workspaces.get(i)
                if (ws && (root.screenName === "" || ws.output === root.screenName)) {
                    result.push({wsId: ws.id, wsFocused: root.isWorkspaceFocused(ws), wsIndex: result.length + 1})
                }
            }
        }
        root.workspaceList = result
    }

    // niri's WorkspaceModel is a QAbstractListModel: it emits dataChanged when a
    // workspace's focus role flips and count/rows/reset signals on layout
    // changes. Binding to those makes switches show *immediately* instead of on
    // the next 500ms tick. focusedWindowChanged covers focusing a window that
    // lives on another workspace. A slow safety Timer catches anything the
    // plugin doesn't signal, without adding perceptible latency.
    Connections {
        target: root.niri ? root.niri.workspaces : null
        function onDataChanged() { root.refresh() }
        function onCountChanged() { root.refresh() }
        function onModelReset() { root.refresh() }
        function onRowsInserted() { root.refresh() }
        function onRowsRemoved() { root.refresh() }
        function onLayoutChanged() { root.refresh() }
    }

    Connections {
        target: root.niri
        function onFocusedWindowChanged() { root.refresh() }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: root.refresh()

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: Theme.workspaceSpacing

        Repeater {
            model: root.workspaceList

            Rectangle {
                id: wsPill
                required property var modelData
                property bool focused: modelData.wsFocused
                property bool hovered: wsHover.hovered

                Layout.preferredWidth: focused ? Theme.workspacePillSize + 12 : Theme.workspacePillSize
                Layout.preferredHeight: Theme.workspacePillSize
                radius: Theme.workspacePillRadius
                // Only the active pill carries a fill (accent); inactive pills are
                // bare numbers so the cluster stays calm, lighting up on hover.
                color: focused ? Theme.accent
                               : (hovered ? Theme.surfaceHover : "transparent")

                Behavior on color { ColorAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast } }
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    text: wsPill.modelData.wsIndex
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: wsPill.focused
                    color: wsPill.focused ? Theme.accentText
                                          : (wsPill.hovered ? Theme.text : Theme.textSecondary)

                    // Subtle pop as a pill becomes active — communicates the
                    // switch without adding latency (fast, overshoot easing).
                    scale: wsPill.focused ? 1.0 : 0.92
                    Behavior on scale {
                        NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.durationFast; easing.type: Easing.OutBack }
                    }
                }

                HoverHandler { id: wsHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        PopupCoordinator.closeAll()
                        if (root.niri) root.niri.focusWorkspaceById(wsPill.modelData.wsId)
                    }
                }
            }
        }
    }
}
