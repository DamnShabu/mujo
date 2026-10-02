// The greeting popup: a card centred on the focused output. Started by
// `mujo-greeting boot|unlock`; the text comes from `mujo-greeting stream`, which
// sends the headline first so the card is up before the model has answered.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property string headline: ""
    property string body: ""
    property string screenName: ""
    property bool done: false
    property bool closing: false
    property int tick: 0

    function pickScreen() {
        const all = Quickshell.screens;
        for (let i = 0; i < all.length; i++)
            if (all[i].name === root.screenName)
                return all[i];
        return all[0];
    }

    function dismiss() {
        if (closing)
            return;
        closing = true;
        exitTimer.start();
    }

    Process {
        running: true
        command: [Quickshell.env("MUJO_GREETING_BIN") || "mujo-greeting", "stream", Quickshell.env("MUJO_GREETING_TRIGGER") || "boot", Quickshell.env("MUJO_GREETING_AWAY") || "0"]
        stdout: SplitParser {
            onRead: line => {
                let m;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m.head !== undefined) {
                    root.screenName = m.screen || "";
                    root.headline = m.head;
                } else if (m.t !== undefined) {
                    root.body += m.t;
                } else if (m.done) {
                    root.body = m.text || root.body;
                    root.done = true;
                }
            }
        }
        onExited: {
            root.done = true;
            if (root.headline === "")
                Qt.quit();
        }
    }

    // Reading time scales with the line; hovering the card holds it open.
    Timer {
        interval: 5500 + root.body.length * 45
        running: root.done && !hover.hovered && !root.closing
        onTriggered: root.dismiss()
    }
    Timer {
        interval: 45000
        running: true
        onTriggered: root.dismiss()
    }
    Timer {
        id: exitTimer
        interval: 320
        onTriggered: Qt.quit()
    }
    Timer {
        interval: 380
        repeat: true
        running: root.body === ""
        onTriggered: root.tick++
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PanelWindow {
        visible: root.headline !== ""
        screen: root.pickScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "mujo-greeting"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // No anchors: layer-shell centres the surface on the output.
        implicitWidth: card.width + 48
        implicitHeight: card.height + 48
        mask: Region {
            item: card
        }

        Rectangle {
            id: card

            property bool shown: false

            anchors.centerIn: parent
            width: 540
            height: col.implicitHeight + 64
            radius: 28
            color: "@bg@"
            border.width: 1
            border.color: "@border@"
            opacity: shown && !root.closing ? 1 : 0
            scale: shown && !root.closing ? 1 : 0.94
            Component.onCompleted: shown = true

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: hover
            }
            TapHandler {
                onTapped: root.dismiss()
            }

            Column {
                id: col

                anchors.centerIn: parent
                width: parent.width - 72
                spacing: 12

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "dddd · d MMMM · HH:mm").toUpperCase()
                    color: "@muted@"
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.headline
                    color: "@fg@"
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 36
                    height: 3
                    radius: 2
                    color: "@accent@"
                }
                Text {
                    width: parent.width
                    // Two lines reserved up front, so the card does not grow
                    // (and the centred surface jump) as the words stream in.
                    height: Math.max(implicitHeight, 2 * font.pixelSize * 1.5)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                    text: root.body !== "" ? root.body : "•".repeat(root.tick % 3 + 1)
                    color: root.body !== "" ? "@text@" : "@muted@"
                    font.pixelSize: 17
                }
            }
        }
    }
}
