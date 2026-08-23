import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Stacked toasts (WP-04). One transparent, click-through layer-shell overlay per
// screen (instantiated in shell.qml); input is masked to the toast column so the
// rest of the screen passes clicks through to apps below. Renders
// Notifications.popups at the configured corner; each toast auto-dismisses on its
// timeout (paused while hovered), animates in via Anim, and offers close +
// actions. reduceMotion → instant.
PanelWindow {
    id: win
    required property var modelData     // screen (from Variants)
    property bool active: true          // show toasts on this screen?
    screen: modelData

    visible: Notifications.popups.length > 0 && win.active
    color: "transparent"
    WlrLayershell.namespace: "qs-notifications"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { item: toastCol }     // only the toasts capture input

    readonly property bool atBottom: Notifications.corner.indexOf("bottom") === 0
    readonly property bool atRight: Notifications.corner.indexOf("right") >= 0

    Column {
        id: toastCol
        width: 380
        spacing: 10
        anchors.top: win.atBottom ? undefined : parent.top
        anchors.bottom: win.atBottom ? parent.bottom : undefined
        anchors.left: win.atRight ? undefined : parent.left
        anchors.right: win.atRight ? parent.right : undefined
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: win.atBottom ? 0 : (Theme.barHeight + Theme.barMargin * 2 + 10)
        anchors.bottomMargin: win.atBottom ? 14 : 0

        Repeater {
            model: Notifications.popups

            delegate: Rectangle {
                id: toast
                required property var modelData
                readonly property var rec: modelData.rec
                width: toastCol.width
                implicitHeight: toastBody.implicitHeight + 24
                radius: Theme.radiusLg
                color: Theme.bg
                border.color: toast.rec.urgency === "critical" ? Theme.error : Theme.border

                // Entrance: only the newest toast animates (array reassignment
                // recreates all delegates; keying off lastPushedId avoids a flash).
                opacity: 1
                Component.onCompleted: if (toast.rec.id === Notifications.lastPushedId) enterAnim.start()
                ParallelAnimation {
                    id: enterAnim
                    NumberAnimation { target: toast; property: "opacity"; from: 0; to: 1; duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter }
                    NumberAnimation { target: toast; property: "x"; from: win.atRight ? 40 : -40; to: 0; duration: Anim.d(Anim.enter); easing.type: Anim.easeEnter }
                }

                // Auto-dismiss (paused on hover); critical (expire<0) is sticky.
                Timer {
                    interval: Math.max(1, modelData.expire) * 1000
                    running: modelData.expire > 0 && !toastHover.hovered
                    onTriggered: Notifications.dismissPopup(toast.rec.id)
                }
                HoverHandler { id: toastHover }

                RowLayout {
                    id: toastBody
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 12 }
                    spacing: 12

                    // App identity: notification image if any, else a monogram tile.
                    Item {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 34; implicitHeight: 34
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusMd
                            visible: img.status !== Image.Ready
                            color: toast.rec.urgency === "critical" ? Theme.error
                                 : toast.rec.urgency === "low" ? Theme.surfaceActive : Theme.accentDim
                            border.color: toast.rec.urgency === "critical" ? Theme.error : Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: (toast.rec.appName || "?").charAt(0).toUpperCase()
                                color: toast.rec.urgency === "critical" ? Theme.accentText : Theme.accent
                                font.family: Theme.fontFamily; font.pixelSize: 17; font.bold: true
                            }
                        }
                        Image {
                            id: img
                            anchors.fill: parent
                            source: toast.rec.image || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: toast.rec.summary
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: toast.rec.appName
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLabel
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: toast.rec.body !== ""
                            text: toast.rec.body
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        // progress-bar hint
                        Rectangle {
                            Layout.fillWidth: true
                            visible: toast.rec.progress >= 0
                            implicitHeight: 5; radius: 2.5
                            color: Theme.surfaceActive
                            Rectangle {
                                height: parent.height; radius: parent.radius
                                width: parent.width * Math.max(0, Math.min(100, toast.rec.progress)) / 100
                                color: Theme.accent
                            }
                        }
                        // action buttons
                        RowLayout {
                            Layout.topMargin: 2
                            spacing: 6
                            visible: !!modelData.actions && modelData.actions.length > 0
                            Repeater {
                                model: modelData.actions || null
                                delegate: Rectangle {
                                    required property var modelData
                                    implicitWidth: actLabel.implicitWidth + 20; implicitHeight: 26
                                    radius: Theme.radiusSm
                                    color: actHover.hovered ? Theme.surfaceHover : Theme.surface
                                    border.color: Theme.borderStrong
                                    Text { id: actLabel; anchors.centerIn: parent; text: parent.modelData.text || "Action"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                    HoverHandler { id: actHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: Notifications.invokeAction(toast.rec.id, parent.modelData) }
                                }
                            }
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        iconName: "close"
                        onClicked: Notifications.closePopup(toast.rec.id)
                    }
                }
            }
        }
    }
}
