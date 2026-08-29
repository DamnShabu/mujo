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
        // Positioned with x/y, not anchors: `anchors.top: cond ? parent.top : undefined`
        // does not release the opposite anchor when `corner` changes after settings
        // load, so both vertical anchors stayed live and drove the column height
        // negative — which collapsed the input mask below and made the whole
        // overlay click-through (no hover, no click, no swipe).
        x: win.atRight ? parent.width - width - 14 : 14
        y: win.atBottom ? parent.height - height - 14
                        : Theme.barHeight + Theme.barMargin * 2 + 10

        Repeater {
            id: toastRepeater
            model: Notifications.popups

            delegate: Item {
                id: delegateRoot
                required property var modelData
                readonly property var rec: modelData.rec
                width: toastCol.width
                height: toastCard.height + 4

                // Swipe-to-dismiss displacement
                property real dragX: 0
                property bool isDragging: false
                property bool swipedOut: false

                // Rich media (album art, screenshots). One cheap 32px probe decode gives the
                // aspect ratio, which decides whether the image reads as a square thumbnail
                // beside the text or as a wide banner below it.
                readonly property string mediaSource: Notifications.resolveImage(rec.image)
                readonly property bool mediaReady: mediaProbe.status === Image.Ready
                readonly property real mediaAspect: mediaProbe.implicitHeight > 0
                    ? mediaProbe.implicitWidth / mediaProbe.implicitHeight : 1
                readonly property bool mediaWide: mediaAspect > 1.6

                Image {
                    id: mediaProbe
                    source: delegateRoot.mediaSource
                    sourceSize.width: 32        // aspect ratio only; never painted
                    asynchronous: true
                    visible: false
                }

                function checkGlobalDragging() {
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

                onIsDraggingChanged: checkGlobalDragging()

                function dismissWithAnim(direction) {
                    if (swipedOut) return
                    swipedOut = true
                    var dir = direction !== undefined ? direction : (win.atRight ? 1 : -1)
                    dismissAnim.targetX = dir > 0 ? (toastCol.width + 120) : -(toastCol.width + 120)
                    dismissAnim.start()
                }

                // Entrance animation
                Component.onCompleted: {
                    if (delegateRoot.rec && delegateRoot.rec.id === Notifications.lastPushedId)
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
                        from: win.atRight ? 90 : -90; to: 0
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
                        duration: Anim.d(160)
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: toastCard
                        property: "opacity"
                        to: 0
                        duration: Anim.d(160)
                        easing.type: Easing.OutCubic
                    }
                    onFinished: Notifications.closePopup(delegateRoot.rec.id)
                }

                // Return spring animation when released below threshold
                NumberAnimation {
                    id: returnAnim
                    target: delegateRoot
                    property: "dragX"
                    to: 0
                    duration: Anim.d(180)
                    easing.type: Anim.easeStandard
                }

                // Swipe-to-dismiss drag area attached to stationary delegateRoot
                MouseArea {
                    id: cardSwipeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    property real startX: 0
                    property bool isSwiping: false

                    onPressed: function(mouse) {
                        startX = mouse.x
                        isSwiping = false
                        returnAnim.stop()
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var diff = mouse.x - startX
                            if (!isSwiping && Math.abs(diff) > 5) {
                                isSwiping = true
                                delegateRoot.isDragging = true
                            }
                            if (isSwiping) {
                                delegateRoot.dragX = diff
                            }
                        }
                    }

                    onReleased: function(mouse) {
                        if (isSwiping) {
                            delegateRoot.isDragging = false
                            isSwiping = false
                            if (Math.abs(delegateRoot.dragX) > 60) {
                                delegateRoot.dismissWithAnim(delegateRoot.dragX > 0 ? 1 : -1)
                            } else {
                                returnAnim.start()
                            }
                        } else {
                            Notifications.invokeDefault(delegateRoot.rec.id)
                        }
                    }

                    onCanceled: {
                        delegateRoot.isDragging = false
                        isSwiping = false
                        returnAnim.start()
                    }
                }

                Rectangle {
                    id: toastCard
                    z: 1
                    width: parent.width
                    height: cardLayout.implicitHeight + 24
                    radius: Theme.radiusLg
                    color: Theme.bg
                    x: delegateRoot.dragX
                    rotation: (delegateRoot.dragX / toastCol.width) * 3.5
                    opacity: delegateRoot.swipedOut ? 0.0 : Math.max(0.12, 1.0 - (Math.abs(delegateRoot.dragX) / (toastCol.width * 0.75)))

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
                             ? Theme.withAlpha(Theme.error, 0.45)
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
                                delegateRoot.dismissWithAnim(win.atRight ? 1 : -1)
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

                        // ── 1. Header: App identity, time, snooze & close actions ──
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
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: Theme.radiusSm
                                color: snzMa.pressed ? Theme.surfaceActive : (snzMa.containsMouse ? Theme.surfaceHover : "transparent")
                                border.color: snzMa.containsMouse ? Theme.borderStrong : "transparent"
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                scale: Anim.microInteractions ? (snzMa.pressed ? 0.92 : (snzMa.containsMouse ? 1.05 : 1.0)) : 1.0
                                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: "schedule"
                                    pixelSize: 15
                                    color: snzMa.containsMouse ? Theme.accent : Theme.textDim
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                }
                                MouseArea {
                                    id: snzMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        delegateRoot.dismissWithAnim()
                                        Notifications.snooze(delegateRoot.rec.id, 5)
                                    }
                                }
                            }

                            // Close Button
                            Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: Theme.radiusSm
                                color: clsMa.pressed ? Theme.withAlpha(Theme.error, 0.3) : (clsMa.containsMouse ? Theme.withAlpha(Theme.error, 0.18) : "transparent")
                                border.color: clsMa.containsMouse ? Theme.withAlpha(Theme.error, 0.45) : "transparent"
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                scale: Anim.microInteractions ? (clsMa.pressed ? 0.92 : (clsMa.containsMouse ? 1.05 : 1.0)) : 1.0
                                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: "close"
                                    pixelSize: 15
                                    color: clsMa.containsMouse ? Theme.error : Theme.textDim
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                }
                                MouseArea {
                                    id: clsMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: delegateRoot.dismissWithAnim()
                                }
                            }
                        }

                        // ── 2. Content: media thumbnail + summary & body ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Square-ish art sits beside the text, so the card keeps a steady
                            // height instead of swinging with whatever the app sent.
                            Item {
                                id: thumbSlot
                                visible: delegateRoot.mediaReady && !delegateRoot.mediaWide
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                Layout.alignment: Qt.AlignTop

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    source: thumbSlot.visible ? delegateRoot.mediaSource : ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 112
                                    sourceSize.height: 112
                                    asynchronous: true
                                    smooth: true
                                    visible: false          // painted through the mask below
                                }

                                Rectangle {
                                    id: thumbMask
                                    anchors.fill: parent
                                    radius: Theme.radiusMd
                                    visible: false
                                    layer.enabled: true
                                }

                                // Genuine rounded corners. `clip` only ever cuts a rectangle, which is
                                // why the old banner left square corners poking out of its rounded frame.
                                MultiEffect {
                                    anchors.fill: parent
                                    source: thumbImg
                                    maskEnabled: true
                                    maskSource: thumbMask
                                }
                            }

                            ColumnLayout {
                                id: textContentCol
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
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
                                    maximumLineCount: 5
                                    elide: Text.ElideRight
                                    textFormat: Text.StyledText
                                    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                                }
                            }
                        }

                        // ── 3. Wide media banner ──
                        // Inset by cardLayout's padding rather than bled to the card edge: flush
                        // corners are square and collide with the card's own radius. No MouseArea
                        // here either — the old one swallowed presses, so a swipe that started on
                        // the image never began.
                        Item {
                            id: bannerSlot
                            visible: delegateRoot.mediaReady && delegateRoot.mediaWide
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(150, Math.round(width / Math.max(0.1, delegateRoot.mediaAspect)))

                            Image {
                                id: bannerImg
                                anchors.fill: parent
                                source: bannerSlot.visible ? delegateRoot.mediaSource : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 780
                                asynchronous: true
                                smooth: true
                                visible: false          // painted through the mask below
                            }

                            Rectangle {
                                id: bannerMask
                                anchors.fill: parent
                                radius: Theme.radiusMd
                                visible: false
                                layer.enabled: true
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: bannerImg
                                maskEnabled: true
                                maskSource: bannerMask
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
                                color: replyMa.pressed ? Theme.accent : (replyMa.containsMouse ? Theme.accentDim : Theme.surface)
                                border.color: Theme.accent
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                scale: Anim.microInteractions ? (replyMa.pressed ? 0.92 : (replyMa.containsMouse ? 1.05 : 1.0)) : 1.0
                                Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    iconName: "arrow_upward"
                                    pixelSize: 16
                                    color: replyMa.containsMouse ? Theme.accentText : Theme.accent
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                }
                                MouseArea {
                                    id: replyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
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
                                    color: actMa.pressed ? Theme.surfaceActive : (actMa.containsMouse ? Theme.surfaceHover : Theme.surface)
                                    border.color: actMa.containsMouse ? Theme.borderInteractive : Theme.borderStrong
                                    border.width: 1

                                    scale: Anim.microInteractions ? (actMa.pressed ? 0.96 : (actMa.containsMouse ? 1.02 : 1.0)) : 1.0
                                    Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Anim.easeStandard } }
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                    Behavior on border.color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                    RowLayout {
                                        id: actRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: actBtn.modelData.text || "Action"
                                            color: actMa.containsMouse ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: true
                                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                                        }
                                    }

                                    MouseArea {
                                        id: actMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifications.invokeAction(delegateRoot.rec.id, actBtn.modelData)
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


