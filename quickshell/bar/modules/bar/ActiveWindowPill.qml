import QtQuick
import QtQuick.Layouts
import "../../theme"

// ActiveWindowPill: Living Application & Window Nexus for Mujo (無常)
// Displays the currently focused application icon and title with directional
// crossfades and a living aura.
Item {
    id: root
    property var niri
    property string screenName: ""
    property string focusedOutput: ""

    // niri.focusedWindow is session-global, so every bar used to mirror the same
    // title. Gate it on our own output: hasWindow drives visible, implicitWidth and
    // the icon, so one condition hides the lot off-focus.
    readonly property bool onFocusedScreen: root.screenName === root.focusedOutput
    readonly property var window: root.niri ? root.niri.focusedWindow : null
    readonly property bool hasWindow: root.onFocusedScreen && root.window !== null && root.window.title !== undefined && String(root.window.title).trim().length > 0
    readonly property string appTitle: root.hasWindow ? String(root.window.title).trim() : ""
    readonly property string appId: root.hasWindow && root.window.appId ? String(root.window.appId).toLowerCase() : ""

    // The real application icon from the system: .desktop entry, then icon
    // theme, then the generic executable icon. No per-app table to maintain.
    readonly property string appIcon: root.hasWindow ? Icons.appIcon(root.appId) : ""

    // Fade out in place rather than vanishing: visible:false would pull the item
    // out of the RowLayout in one frame, so the width Behavior below never ran
    // and the whole left cluster resized around the hole instead.
    opacity: root.hasWindow ? 1 : 0
    visible: root.opacity > 0
    implicitHeight: Theme.workspacePillSize
    implicitWidth: root.hasWindow ? pillRect.width : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Anim.d(Anim.standard)
            easing.type: Anim.easeStandard
        }
    }

    // Same duration as the fade, so the footprint and the pixels finish together
    // and `visible` drops exactly when both are done.
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Anim.d(Anim.standard)
            easing.type: Anim.easeStandard
        }
    }

    // Transition tracking for silky smooth directional crossfades. Seeded once
    // rather than bound, so a binding cannot blank them out from under the
    // fade-out when the focused window goes away.
    property string _displayTitle: ""
    property string _displayIcon: ""
    Component.onCompleted: {
        root._displayTitle = root.appTitle
        root._displayIcon = root.appIcon
    }
    property real _contentOpacity: 1.0
    property real _contentOffset: 0.0

    onAppTitleChanged: {
        // On the way out keep the last title: crossfading to "" would shrink the
        // pill mid-fade instead of letting it leave whole.
        if (!root.hasWindow) return
        if (Anim.reduceMotion || !Anim.enabled) {
            root._displayTitle = root.appTitle
            root._displayIcon = root.appIcon
            return
        }
        fadeSeq.restart()
    }

    SequentialAnimation {
        id: fadeSeq
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_contentOpacity"
                to: 0.0
                duration: Anim.d(60)
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root
                property: "_contentOffset"
                to: -6
                duration: Anim.d(60)
                easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: {
                root._displayTitle = root.appTitle
                root._displayIcon = root.appIcon
                root._contentOffset = 6
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_contentOpacity"
                to: 1.0
                duration: Anim.d(140)
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "_contentOffset"
                to: 0.0
                duration: Anim.d(140)
                easing.type: Easing.OutBack
            }
        }
    }

    Rectangle {
        id: pillRect
        anchors.verticalCenter: parent.verticalCenter
        width: contentRow.implicitWidth + 18
        height: Theme.workspacePillSize
        radius: Theme.workspacePillRadius
        color: hh.hovered ? Theme.surfaceHover : Theme.withAlpha(Theme.surfaceActive, 0.35)
        border.color: hh.hovered ? Theme.borderStrong : Theme.border
        border.width: 1
        clip: true

        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
        Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6
            opacity: root._contentOpacity
            transform: Translate { x: root._contentOffset }

            // The application's own icon, full colour — the desktop convention,
            // same call `Icons.fileIcon` makes for file types.
            Image {
                source: root._displayIcon
                visible: source !== ""
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                sourceSize.width: 32       // 2× so it stays crisp on the 22px pill
                sourceSize.height: 32
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
            }

            // Window Title
            Text {
                id: titleText
                text: root._displayTitle
                color: hh.hovered ? Theme.text : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.maximumWidth: 190
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
            }
        }

        HoverHandler {
            id: hh
            cursorShape: Qt.PointingHandCursor
        }
    }
}
