import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../services"

// Workspaces: Living Morphic Workspace Tracker for Mujo (無常)
// Features an elastic sliding glider backplate with velocity stretch,
// living window-presence micro-pips, and responsive scroll physics.
Item {
    id: root
    property var niri
    property string screenName: ""
    property var workspaceList: []
    property int focusedIndex: 0
    property int previousIndex: 0

    implicitHeight: Theme.workspacePillSize
    implicitWidth: rowLayout.implicitWidth

    // Scroll over the workspaces pill to switch workspace (WP-17 scroll actions).
    WheelHandler {
        enabled: SettingsBus.get("bar.scrollActions", true)
        onWheel: function (e) {
            Quickshell.execDetached(["niri", "msg", "action", e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down"])
        }
    }

    // niri's is_focused is global (exactly one per session); is_active is per-output,
    // which is what a per-screen bar wants. Reading is_focused here left every pill on
    // the non-focused monitor unselected and parked the glider on slot 1.
    function isWorkspaceFocused(ws) {
        return !!(ws && ws.isActive)
    }

    function workspaceHasWindows(ws) {
        if (!ws) return false
        if (ws.activeWindowId !== undefined && ws.activeWindowId !== null && ws.activeWindowId !== 0) return true
        return false
    }

    readonly property string wsStyle: SettingsBus.get("bar.workspaces.style", "numbers")
    readonly property string gliderStyle: SettingsBus.get("bar.workspaces.gliderStyle", "morphic")
    readonly property bool showWindowDots: SettingsBus.get("bar.workspaces.showWindowDots", true)
    readonly property bool hideEmpty: SettingsBus.get("bar.workspaces.hideEmpty", false)

    function formatWsLabel(idx) {
        if (root.wsStyle === "dots") return "•"
        if (root.wsStyle === "roman") {
            var romans = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
            return romans[idx - 1] || String(idx)
        }
        return String(idx)
    }

    function refresh() {
        var result = []
        var foundFocused = 0
        if (root.niri && root.niri.workspaces) {
            var count = root.niri.workspaces.count
            for (var i = 0; i < count; i++) {
                var ws = root.niri.workspaces.get(i)
                if (ws && (root.screenName === "" || ws.output === root.screenName)) {
                    var isFoc = root.isWorkspaceFocused(ws)
                    var hasWin = root.workspaceHasWindows(ws)
                    if (root.hideEmpty && !isFoc && !hasWin) continue
                    var currentIdx = result.length
                    if (isFoc) foundFocused = currentIdx
                    result.push({
                        wsId: ws.id,
                        wsFocused: isFoc,
                        wsIndex: currentIdx + 1,
                        hasWindows: hasWin
                    })
                }
            }
        }
        if (foundFocused !== root.focusedIndex) {
            root.previousIndex = root.focusedIndex
            root.focusedIndex = foundFocused
        }
        root.workspaceList = result
    }

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

    Component.onCompleted: root.refresh()

    // ─── Morphic Glider Calculations ─────────────────────────────────────────
    readonly property int pillW: Theme.workspacePillSize
    readonly property int pillExpandedW: root.gliderStyle === "morphic" ? (Theme.workspacePillSize + 12) : Theme.workspacePillSize
    readonly property int gap: Theme.workspaceSpacing

    function gliderTargetX() {
        var x = 0
        for (var i = 0; i < root.focusedIndex; i++) {
            x += root.pillW + root.gap
        }
        return x
    }

    // Morphic Glider Backplate
    Rectangle {
        id: morphicGlider
        visible: root.workspaceList.length > 0 && root.gliderStyle !== "none"
        height: root.gliderStyle === "underline" ? 3 : root.pillW
        y: root.gliderStyle === "underline" ? (parent.height - 3) : ((parent.height - height) / 2)
        radius: root.gliderStyle === "underline" ? 1.5 : Theme.workspacePillRadius
        color: root.gliderStyle === "outline" ? "transparent" : Theme.accent
        border.color: root.gliderStyle === "outline" ? Theme.accent : "transparent"
        border.width: root.gliderStyle === "outline" ? 1.5 : 0

        x: root.gliderTargetX()
        width: root.pillExpandedW

        Behavior on x {
            NumberAnimation {
                duration: Anim.d(Anim.slow)
                easing.type: Anim.easeStandard
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Anim.d(Anim.fast)
                easing.type: Anim.easeStandard
            }
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.workspaceList

            Item {
                id: wsItem
                required property var modelData
                required property int index
                property bool focused: modelData.wsFocused
                property bool hovered: wsHover.hovered
                property bool hasWindows: modelData.hasWindows

                Layout.preferredWidth: (focused && root.gliderStyle === "morphic") ? root.pillExpandedW : root.pillW
                Layout.preferredHeight: root.pillW

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard }
                }

                // Inactive Hover Highlight Plate
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.workspacePillRadius
                    color: Theme.surfaceHover
                    opacity: (!wsItem.focused && wsItem.hovered) ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
                }

                // Workspace Numeral / Label / Icon
                Text {
                    anchors.centerIn: parent
                    text: root.formatWsLabel(wsItem.modelData.wsIndex)
                    font.family: Theme.fontMono
                    font.pixelSize: root.wsStyle === "dots" ? (Theme.fontSizeHeading + 2) : Theme.fontSizeSmall
                    font.bold: wsItem.focused
                    color: (wsItem.focused && root.gliderStyle !== "underline" && root.gliderStyle !== "outline")
                           ? Theme.accentText
                           : (wsItem.hovered ? Theme.text : (wsItem.focused ? Theme.accent : Theme.textSecondary))

                    Behavior on color {
                        ColorAnimation { duration: Anim.d(Anim.fast) }
                    }
                }

                // Window Presence Indicator (clean micro-dot)
                Rectangle {
                    visible: root.showWindowDots && wsItem.hasWindows && !wsItem.focused
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 2
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: 3
                    height: 3
                    radius: 1.5
                    color: wsItem.hovered ? Theme.text : Theme.textSecondary
                    opacity: 0.7

                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                }

                HoverHandler {
                    id: wsHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        PopupCoordinator.closeAll()
                        if (root.niri) root.niri.focusWorkspaceById(wsItem.modelData.wsId)
                    }
                }
            }
        }
    }
}
