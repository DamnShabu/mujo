import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../components"
import "../../services"

// Stacked notification toasts (WP-04). One transparent layer-shell overlay per
// screen (instantiated in shell.qml). Input is masked to the toast column during idle,
// and dynamically expands during swipe-to-dismiss gestures so dragging across
// the screen never loses pointer capture.
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

    readonly property bool atBottom: Notifications.corner.indexOf("bottom") === 0
    readonly property bool atRight: Notifications.corner.indexOf("right") >= 0

    // Set when any toast card is actively being dragged
    property bool anyDragging: false

    // Input mask: tight to toastCol when idle; full interactive lane across screen when dragging
    mask: Region { item: win.anyDragging ? dragLane : toastCol }

    Item {
        id: dragLane
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toastCol.top
        anchors.bottom: toastCol.bottom
    }

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
            id: toastRepeater
            model: Notifications.popups

            delegate: Item {
                id: delegateRoot
                required property var modelData
                readonly property var rec: modelData.rec
                width: toastCol.width
                height: toastCard.height

                // Swipe-to-dismiss displacement
                property real dragX: 0
                property bool isDragging: false
                property bool swipedOut: false

                onIsDraggingChanged: {
                    var dragging = false
                    for (var i = 0; i < toastRepeater.count; i++) {
                        var it = toastRepeater.itemAt(i)
                        if (it && it.isDragging) {
                            dragging = true
                            break
                        }
                    }
                    win.anyDragging = dragging
                }

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
                        target: delegateRoot
                        property: "dragX"
                        from: win.atRight ? 80 : -80; to: 0
                        duration: Anim.d(Anim.enter)
                        easing.type: Anim.easeEnter
                    }
                }

                // Dismiss animation when swiped out or expired
                ParallelAnimation {
                    id: dismissAnim
                    property real targetX: 0
                    NumberAnimation {
                        target: delegateRoot
                        property: "dragX"
                        to: dismissAnim.targetX
                        duration: Anim.d(Anim.fast)
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: toastCard
                        property: "opacity"
                        to: 0
                        duration: Anim.d(Anim.fast)
                        easing.type: Easing.OutQuad
                    }
                    onFinished: Notifications.dismissPopup(delegateRoot.rec.id)
                }

                // Return spring animation when released below threshold
                NumberAnimation {
                    id: returnAnim
                    target: delegateRoot
                    property: "dragX"
                    to: 0
                    duration: Anim.d(Anim.standard)
                    easing.type: Anim.easeStandard
                }

                // MultiEffect elevation drop shadow
                Rectangle {
                    id: shadowSrc
                    anchors.fill: toastCard
                    radius: toastCard.radius
                    color: "#000000"
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: shadowSrc
                    source: shadowSrc
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 0.7
                    shadowVerticalOffset: 4
                    shadowOpacity: 0.5
                    opacity: toastCard.opacity
                    x: toastCard.x
                    rotation: toastCard.rotation
                }

                Rectangle {
                    id: toastCard
                    width: parent.width
                    height: cardLayout.implicitHeight + 24
                    radius: Theme.radiusLg
                    color: Theme.bg
                    x: delegateRoot.dragX
                    rotation: (delegateRoot.dragX / toastCol.width) * 3
                    opacity: delegateRoot.swipedOut ? 0.0 : Math.max(0.15, 1.0 - Math.abs(delegateRoot.dragX) / 260)

                    border.color: delegateRoot.rec.urgency === "critical"
                                ? Theme.error
                                : (toastHover.hovered ? Theme.borderStrong : Theme.border)
                    border.width: delegateRoot.rec.urgency === "critical" ? 1.5 : 1

                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                    // Specular highlight line
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 1
                        height: 1
                        radius: Theme.radiusLg
                        color: delegateRoot.rec.urgency === "critical"
                             ? Theme.withAlpha(Theme.error, 0.4)
                             : Theme.withAlpha("#ffffff", 0.08)
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

                    // Swipe gesture handler
                    DragHandler {
                        id: swipeHandler
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        grabPermissions: PointerHandler.CanTakeOverFromAnything

                        onActiveChanged: {
                            delegateRoot.isDragging = active
                            if (!active) {
                                if (Math.abs(delegateRoot.dragX) > 85) {
                                    delegateRoot.swipedOut = true
                                    dismissAnim.targetX = delegateRoot.dragX > 0 ? (toastCol.width + 120) : -(toastCol.width + 120)
                                    dismissAnim.start()
                                } else {
                                    returnAnim.start()
                                }
                            } else {
                                returnAnim.stop()
                            }
                        }
                        onTranslationChanged: {
                            if (active) {
                                delegateRoot.dragX = translation.x
                            }
                        }
                    }

                    // Auto-dismiss Timer
                    Timer {
                        id: expiry
                        property real remaining: Math.max(1, delegateRoot.modelData.expire) * 1000
                        interval: 100
                        repeat: true
                        running: delegateRoot.modelData.expire > 0 && !delegateRoot.swipedOut
                        onTriggered: {
                            if (toastHover.hovered || delegateRoot.isDragging) return
                            expiry.remaining -= expiry.interval
                            if (expiry.remaining <= 0) {
                                running = false
                                delegateRoot.swipedOut = true
                                dismissAnim.targetX = win.atRight ? (toastCol.width + 120) : -(toastCol.width + 120)
                                dismissAnim.start()
                            }
                        }
                    }
                    HoverHandler { id: toastHover }

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
                                implicitWidth: 22
                                implicitHeight: 22
                                Layout.alignment: Qt.AlignVCenter

                                readonly property string iconSrc: Notifications.resolveIcon(delegateRoot.rec)
                                readonly property bool hasBrand: Brand.has((delegateRoot.rec.appName || "").toLowerCase())

                                Image {
                                    id: appIconImg
                                    anchors.fill: parent
                                    source: parent.iconSrc
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 44
                                    sourceSize.height: 44
                                    smooth: true
                                    asynchronous: true
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
                                Layout.maximumWidth: 150
                            }

                            // Critical Badge
                            Rectangle {
                                visible: delegateRoot.rec.urgency === "critical"
                                implicitWidth: critLabel.implicitWidth + 8
                                implicitHeight: 18
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
                            Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: Theme.radiusSm
                                color: snzHh.hovered ? Theme.surfaceHover : "transparent"
                                border.color: snzHh.hovered ? Theme.borderStrong : "transparent"
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: "schedule"
                                    pixelSize: 14
                                    color: snzHh.hovered ? Theme.accent : Theme.textDim
                                }
                                HoverHandler { id: snzHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: Notifications.snooze(delegateRoot.rec.id, 5)
                                }
                            }

                            // Close Button
                            Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: Theme.radiusSm
                                color: clsHh.hovered ? Theme.withAlpha(Theme.error, 0.18) : "transparent"
                                border.color: clsHh.hovered ? Theme.withAlpha(Theme.error, 0.4) : "transparent"
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: "close"
                                    pixelSize: 14
                                    color: clsHh.hovered ? Theme.error : Theme.textDim
                                }
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
                                spacing: 4

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

                            HoverHandler { id: textHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Notifications.invokeDefault(delegateRoot.rec.id)
                            }
                        }

                        // ── 3. Rich Image Banner / Thumbnail ──
                        Item {
                            id: richImgContainer
                            Layout.fillWidth: true
                            readonly property string resolvedImg: Notifications.resolveImage(delegateRoot.rec.image)
                            visible: resolvedImg !== "" && richImg.status !== Image.Error
                            implicitHeight: visible ? (richImg.status === Image.Ready ? Math.min(160, Math.max(80, richImg.implicitHeight > 0 ? (richImg.implicitHeight * (toastCol.width - 24) / Math.max(1, richImg.implicitWidth)) : 120)) : 110) : 0

                            Behavior on implicitHeight {
                                NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusMd
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                clip: true

                                Image {
                                    id: richImg
                                    anchors.fill: parent
                                    source: richImgContainer.resolvedImg
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation { duration: Anim.d(Anim.fast) }
                                    }
                                }
                            }

                            HoverHandler { id: imgHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Notifications.invokeDefault(delegateRoot.rec.id)
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
                                border.width: 1
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
                                    implicitWidth: actRow.implicitWidth + 20
                                    implicitHeight: 28
                                    radius: Theme.radiusSm
                                    color: actHh.hovered ? (actHh.pressed ? Theme.surfaceActive : Theme.surfaceHover) : Theme.surface
                                    border.color: actHh.hovered ? Theme.borderInteractive : Theme.borderStrong
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

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

