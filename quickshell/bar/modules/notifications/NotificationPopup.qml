import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

// Stacked toasts (WP-04). One transparent, click-through layer-shell overlay per
// screen (instantiated in shell.qml); input is masked to the toast column so the
// rest of the screen passes clicks through to apps below. Renders
// Notifications.popups at the configured corner; each toast auto-dismisses on its
// timeout (paused while hovered), animates in via Anim, and offers close +
// actions. Supports swipe dismissal, rich media, progress bars, and inline reply.
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
        width: 390
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

            delegate: Item {
                id: delegateRoot
                required property var modelData
                readonly property var rec: modelData.rec
                width: toastCol.width
                height: toastCard.height

                // Swipe-to-dismiss displacement
                property real dragOffset: 0
                property bool swipedOut: false

                // Entrance animation
                Component.onCompleted: {
                    if (delegateRoot.rec.id === Notifications.lastPushedId)
                        enterAnim.start()
                }
                ParallelAnimation {
                    id: enterAnim
                    NumberAnimation {
                        target: toastCard
                        property: "opacity"
                        from: 0; to: 1
                        duration: Anim.d(Anim.enter)
                        easing.type: Anim.easeEnter
                    }
                    NumberAnimation {
                        target: toastCard
                        property: "x"
                        from: win.atRight ? 50 : -50; to: 0
                        duration: Anim.d(Anim.enter)
                        easing.type: Anim.easeEnter
                    }
                }

                // Dismiss animation when swiped out
                ParallelAnimation {
                    id: dismissAnim
                    NumberAnimation {
                        target: toastCard
                        property: "opacity"
                        to: 0
                        duration: Anim.d(Anim.exit)
                        easing.type: Anim.easeExit
                    }
                    NumberAnimation {
                        target: toastCard
                        property: "x"
                        to: delegateRoot.dragOffset > 0 ? toastCol.width : -toastCol.width
                        duration: Anim.d(Anim.exit)
                        easing.type: Anim.easeExit
                    }
                    onFinished: Notifications.dismissPopup(delegateRoot.rec.id)
                }

                Rectangle {
                    id: toastCard
                    width: parent.width
                    height: cardLayout.implicitHeight + 24
                    radius: Theme.radiusLg
                    color: Theme.bg
                    x: delegateRoot.dragOffset
                    opacity: delegateRoot.swipedOut ? 0.0 : Math.max(0.2, 1.0 - Math.abs(delegateRoot.dragOffset) / 250)

                    border.color: delegateRoot.rec.urgency === "critical"
                                ? Theme.error
                                : (toastHover.hovered ? Theme.borderStrong : Theme.border)
                    border.width: delegateRoot.rec.urgency === "critical" ? 1.5 : 1

                    DragHandler {
                        id: swipeHandler
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        onActiveChanged: {
                            if (!active) {
                                if (Math.abs(delegateRoot.dragOffset) > 85) {
                                    delegateRoot.swipedOut = true
                                    dismissAnim.start()
                                } else {
                                    delegateRoot.dragOffset = 0
                                }
                            }
                        }
                        onTranslationChanged: {
                            if (active) {
                                delegateRoot.dragOffset = translation.x
                            }
                        }
                    }

                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                    Behavior on x {
                        enabled: !swipeHandler.active && !delegateRoot.swipedOut
                        NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard }
                    }

                    // Specular highlight line
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        radius: Theme.radiusLg
                        color: delegateRoot.rec.urgency === "critical"
                             ? Theme.withAlpha(Theme.error, 0.4)
                             : Theme.withAlpha("#ffffff", 0.06)
                    }

                    // Critical urgency pulse glow
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusLg
                        color: "transparent"
                        border.color: Theme.withAlpha(Theme.error, Anim.breath(0.2, 0.6))
                        border.width: 2
                        visible: delegateRoot.rec.urgency === "critical" && Anim.ambient
                    }

                    // Auto-dismiss; critical (expire<0) is sticky. Ticks down a
                    // remaining budget rather than gating a one-shot Timer on
                    // `running`: a Qt Timer restarts from zero when running goes
                    // true again, so hovering used to hand the toast a whole
                    // fresh timeout instead of pausing it.
                    Timer {
                        id: expiry
                        property real remaining: Math.max(1, delegateRoot.modelData.expire) * 1000
                        interval: 100
                        repeat: true
                        running: delegateRoot.modelData.expire > 0
                        onTriggered: {
                            if (toastHover.hovered || swipeHandler.active) return
                            expiry.remaining -= expiry.interval
                            if (expiry.remaining <= 0) Notifications.dismissPopup(delegateRoot.rec.id)
                        }
                    }
                    HoverHandler { id: toastHover }

                    // ReleaseWithinBounds takes an exclusive grab. With the
                    // default DragThreshold policy this handler also fired for
                    // every control nested inside the card — closing a toast
                    // invoked the notification's default action as well.
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Notifications.invokeDefault(delegateRoot.rec.id)
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 8

                        // ── 1. Header: App identity, urgency badge, actions ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // App Icon
                            Item {
                                implicitWidth: 20
                                implicitHeight: 20
                                Layout.alignment: Qt.AlignVCenter

                                readonly property string iconSrc: Notifications.resolveIcon(delegateRoot.rec)
                                readonly property bool hasBrand: Brand.has((delegateRoot.rec.appName || "").toLowerCase())

                                Image {
                                    id: appIconImg
                                    anchors.fill: parent
                                    source: parent.iconSrc
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 40
                                    sourceSize.height: 40
                                    smooth: true
                                    visible: parent.iconSrc !== "" && status === Image.Ready
                                }

                                BrandIcon {
                                    anchors.fill: parent
                                    brand: (delegateRoot.rec.appName || "").toLowerCase()
                                    size: 20
                                    visible: !appIconImg.visible && parent.hasBrand
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusSm
                                    visible: !appIconImg.visible && !parent.hasBrand
                                    color: delegateRoot.rec.urgency === "critical" ? Theme.error
                                         : delegateRoot.rec.urgency === "low" ? Theme.surfaceActive : Theme.accentDim
                                    Text {
                                        anchors.centerIn: parent
                                        text: (delegateRoot.rec.appName || "?").charAt(0).toUpperCase()
                                        color: delegateRoot.rec.urgency === "critical" ? Theme.accentText : Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                    }
                                }
                            }

                            Text {
                                text: delegateRoot.rec.appName || "Notification"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight
                                Layout.maximumWidth: 160
                            }

                            // Critical Badge
                            Rectangle {
                                visible: delegateRoot.rec.urgency === "critical"
                                implicitWidth: critLabel.implicitWidth + 8
                                implicitHeight: 16
                                radius: Theme.radiusSm
                                color: Theme.withAlpha(Theme.error, 0.18)
                                border.color: Theme.error
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: critLabel
                                    anchors.centerIn: parent
                                    text: "CRITICAL"
                                    color: Theme.error
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                    font.bold: true
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: Notifications.fmtTime(delegateRoot.rec.time)
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Snooze Button
                            MaterialIcon {
                                iconName: "schedule"
                                pixelSize: 15
                                color: snzHh.hovered ? Theme.accent : Theme.textDim
                                Layout.alignment: Qt.AlignVCenter
                                HoverHandler { id: snzHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: Notifications.snooze(delegateRoot.rec.id, 5)
                                }
                            }

                            // Close Button
                            MaterialIcon {
                                iconName: "close"
                                pixelSize: 15
                                color: clsHh.hovered ? Theme.text : Theme.textDim
                                Layout.alignment: Qt.AlignVCenter
                                HoverHandler { id: clsHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: Notifications.closePopup(delegateRoot.rec.id)
                                }
                            }
                        }

                        // ── 2. Content: Summary & Formatted Body ──
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: textContentCol.implicitHeight

                            ColumnLayout {
                                id: textContentCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    visible: delegateRoot.rec.summary !== ""
                                    text: delegateRoot.rec.summary
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    textFormat: Text.StyledText
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: delegateRoot.rec.body !== ""
                                    text: delegateRoot.rec.body
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    textFormat: Text.StyledText
                                    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                                }
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Notifications.invokeDefault(delegateRoot.rec.id)
                            }
                        }

                        // ── 3. Rich Image Banner / Thumbnail ──
                        Item {
                            id: richImgContainer
                            Layout.fillWidth: true
                            readonly property bool isPath: delegateRoot.rec.image !== "" &&
                                (delegateRoot.rec.image.indexOf("/") === 0 || delegateRoot.rec.image.indexOf("file://") === 0)
                            visible: isPath && richImg.status === Image.Ready
                            implicitHeight: visible ? Math.min(160, richImg.implicitHeight > 0 ? richImg.implicitHeight : 120) : 0

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusMd
                                color: Theme.surface
                                clip: true

                                Image {
                                    id: richImg
                                    anchors.fill: parent
                                    source: delegateRoot.rec.image || ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                }
                            }
                        }

                        // ── 4. Progress bar ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: delegateRoot.rec.progress >= 0
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Progress"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(Math.max(0, Math.min(100, delegateRoot.rec.progress))) + "%"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: Theme.surfaceActive

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * Math.max(0, Math.min(100, delegateRoot.rec.progress)) / 100
                                    color: Theme.accent
                                    Behavior on width { NumberAnimation { duration: Anim.d(150); easing.type: Easing.OutCubic } }
                                }
                            }
                        }

                        // ── 5. Inline Reply ──
                        RowLayout {
                            Layout.fillWidth: true
                            visible: delegateRoot.modelData.hasInlineReply
                            spacing: 6

                            TextField {
                                id: replyInput
                                Layout.fillWidth: true
                                placeholder: delegateRoot.modelData.inlineReplyPlaceholder || "Type a reply…"
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        Notifications.sendReply(delegateRoot.rec.id, text.trim())
                                        text = ""
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: 32; implicitHeight: 32
                                radius: Theme.radiusSm
                                color: replyBtnHh.hovered ? Theme.accent : Theme.accentDim
                                border.color: Theme.accent
                                Layout.alignment: Qt.AlignVCenter

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: "arrow_upward"
                                    pixelSize: 16
                                    color: replyBtnHh.hovered ? Theme.accentText : Theme.accent
                                }
                                HoverHandler { id: replyBtnHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: {
                                        if (replyInput.text.trim() !== "") {
                                            Notifications.sendReply(delegateRoot.rec.id, replyInput.text.trim())
                                            replyInput.text = ""
                                        }
                                    }
                                }
                            }
                        }

                        // ── 6. Action buttons ──
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: !!delegateRoot.modelData.actions && delegateRoot.modelData.actions.length > 0

                            Repeater {
                                model: delegateRoot.modelData.actions || null
                                delegate: Rectangle {
                                    id: actBtn
                                    required property var modelData
                                    implicitWidth: actRow.implicitWidth + 18
                                    implicitHeight: 28
                                    radius: Theme.radiusSm
                                    color: actHh.hovered ? Theme.surfaceHover : Theme.surface
                                    border.color: actHh.hovered ? Theme.borderInteractive : Theme.borderStrong

                                    RowLayout {
                                        id: actRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: actBtn.modelData.text || "Action"
                                            color: actHh.hovered ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: true
                                        }
                                    }

                                    HoverHandler { id: actHh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: Notifications.invokeAction(delegateRoot.rec.id, actBtn.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

