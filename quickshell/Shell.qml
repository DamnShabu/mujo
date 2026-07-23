import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Item {

  PanelWindow {
    id: notifdRoot

    WlrLayershell.namespace: "qs-notifd"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; right: true }
    margins { top: 60; right: 20 }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    width: 350
    height: Math.min(popupList.contentHeight, Screen.height * 0.8)

    Behavior on height {
      NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
    }

    property bool isStartup: true
    Timer {
      interval: 500
      running: true
      onTriggered: notifdRoot.isStartup = false
    }

    readonly property string dndFile: Quickshell.env("HOME") + "/.cache/quickshell/dnd/state"
    property bool dndEnabled: false

    Process {
      id: dndReader
      command: ["bash", "-c", "cat '" + notifdRoot.dndFile + "' 2>/dev/null || echo '0'"]
      stdout: StdioCollector {
        onStreamFinished: notifdRoot.dndEnabled = (this.text.trim() === "1")
      }
    }
    Timer {
      interval: 1000; running: true; repeat: true; triggeredOnStart: true
      onTriggered: dndReader.running = true
    }

    readonly property color base: "@base00@"
    readonly property color text: "@base05@"
    readonly property color subtext0: "@base04@"
    readonly property color surface0: "@base02@"
    readonly property color surface1: "@base03@"
    readonly property color surface2: "@base03@"
    readonly property color overlay1: "#7F849C"
    readonly property color crust: "@base00@"
    readonly property color blue: "@base0D@"
    readonly property color mauve: "@base0E@"
    readonly property color peach: "@base09@"
    readonly property color green: "@base0B@"
    readonly property color pink: "#F5C2E7"
    readonly property color sapphire: "#74C7EC"
    readonly property color teal: "@base0C@"
    readonly property color maroon: "@base0F@"
    readonly property color yellow: "@base0A@"
    readonly property color red: "@base08@"

    readonly property var blobPalette1: [mauve, blue, peach, green, pink]
    readonly property var blobPalette2: [sapphire, teal, maroon, yellow, red]
    property real globalOrbitAngle: 0

    NumberAnimation on globalOrbitAngle {
      from: 0; to: Math.PI * 2; duration: 25000; loops: Animation.Infinite; running: true
    }

    ListModel { id: activePopups }
    property var liveNotifs: ({})
    property int popupCounter: 0

    NotificationServer {
      id: notifServer
      bodySupported: true
      actionsSupported: true
      imageSupported: true

      onNotification: (n) => {
        n.tracked = true;

        let actions = [];
        if (n.actions) {
          for (let i = 0; i < n.actions.length; i++) {
            actions.push({
              "id": n.actions[i].identifier || "",
              "text": n.actions[i].text || n.actions[i].name || "Action"
            });
          }
        }

        notifdRoot.popupCounter++;
        let uid = notifdRoot.popupCounter;
        notifdRoot.liveNotifs[uid] = n;

        let data = {
          "appName":     n.appName  !== "" ? n.appName  : "System",
          "summary":     n.summary  !== "" ? n.summary  : "No Title",
          "body":        n.body     !== "" ? n.body     : "",
          "iconPath":    n.appIcon  !== "" ? n.appIcon  : "",
          "actionsJson": JSON.stringify(actions),
          "uid":         uid
        };

        if (!notifdRoot.isStartup) {
          activePopups.append(data);
        }
      }
    }

    function removePopup(uid) {
      for (let i = 0; i < activePopups.count; i++) {
        if (activePopups.get(i).uid === uid) {
          activePopups.remove(i);
          break;
        }
      }
    }

    Item {
      anchors.fill: parent
      opacity: notifdRoot.dndEnabled ? 0.0 : 1.0
      visible: opacity > 0.01
      Behavior on opacity { NumberAnimation { duration: 300 } }

      ListView {
        id: popupList
        anchors.fill: parent
        model: activePopups
        spacing: 12
        interactive: false
        clip: false

        add: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
            NumberAnimation { property: "x"; from: 140; to: 0; duration: 500; easing.type: Easing.OutQuint }
            NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 500; easing.type: Easing.OutQuint }
          }
        }

        remove: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0.0; duration: 350; easing.type: Easing.OutQuint }
            NumberAnimation { property: "x"; to: 140; duration: 400; easing.type: Easing.OutQuint }
            NumberAnimation { property: "scale"; to: 0.9; duration: 400; easing.type: Easing.OutQuint }
          }
        }

        displaced: Transition {
          NumberAnimation { properties: "x,y"; duration: 450; easing.type: Easing.OutQuint }
        }

        delegate: Item {
          id: delegateRoot
          width: ListView.view.width
          height: contentCol.height + 24

          property string fullSummary: model.summary || ""
          property string fullBody: model.body || ""
          property int typeLenSum: 0
          property int typeLenBody: 0
          property int popupUid: model.uid

          property var sourceNotif: notifdRoot.liveNotifs[model.uid]

          property var actionArray: {
            try {
              let parsed = model.actionsJson ? JSON.parse(model.actionsJson) : [];
              return parsed;
            } catch (e) { return []; }
          }

          property int effectiveTimeout: {
            var n = notifdRoot.liveNotifs[model.uid];
            if (!n || n.timeout === undefined) return 5000;
            if (n.timeout === 0) return 0;
            if (n.timeout > 0) return n.timeout;
            return 5000;
          }

          Connections {
            target: delegateRoot.sourceNotif || null
            function onClosed() {
              notifdRoot.removePopup(delegateRoot.popupUid);
            }
          }

          ParallelAnimation {
            running: true
            NumberAnimation {
              target: delegateRoot; property: "typeLenSum"
              from: 0; to: fullSummary.length
              duration: Math.min(fullSummary.length * 20, 600)
              easing.type: Easing.OutCubic
            }
            SequentialAnimation {
              PauseAnimation { duration: 150 }
              NumberAnimation {
                target: delegateRoot; property: "typeLenBody"
                from: 0; to: fullBody.length
                duration: Math.min(fullBody.length * 15, 1200)
                easing.type: Easing.OutCubic
              }
            }
          }

          Rectangle {
            id: popupCard
            anchors.fill: parent
            radius: 14
            color: notifdRoot.base
            border.color: notifdRoot.surface1
            border.width: 1
            clip: true

            property color blob1Color: notifdRoot.blobPalette1[index % 5]
            property color blob2Color: notifdRoot.blobPalette2[index % 5]

            Rectangle {
              width: parent.width * 0.7; height: width; radius: width / 2
              x: (parent.width / 2 - width / 2) + Math.cos(notifdRoot.globalOrbitAngle * 2 + index) * 60
              y: (parent.height / 2 - height / 2) + Math.sin(notifdRoot.globalOrbitAngle * 2 + index) * 30
              color: popupCard.blob1Color
              opacity: 0.12
            }
            Rectangle {
              width: parent.width * 0.5; height: width; radius: width / 2
              x: (parent.width / 2 - width / 2) + Math.sin(notifdRoot.globalOrbitAngle * 1.5 - index) * -50
              y: (parent.height / 2 - height / 2) + Math.cos(notifdRoot.globalOrbitAngle * 1.5 - index) * -40
              color: popupCard.blob2Color
              opacity: 0.10
            }

            Timer {
              interval: delegateRoot.effectiveTimeout > 0 ? delegateRoot.effectiveTimeout : 5000
              running: delegateRoot.effectiveTimeout > 0
              onTriggered: notifdRoot.removePopup(delegateRoot.popupUid)
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: {
                var n = notifdRoot.liveNotifs[delegateRoot.popupUid];
                if (n && n.actions) {
                  for (var i = 0; i < n.actions.length; i++) {
                    if (n.actions[i].identifier === "default") {
                      n.actions[i].invoke(); break;
                    }
                  }
                }
                Qt.callLater(function() { notifdRoot.removePopup(delegateRoot.popupUid); });
              }

              Rectangle {
                anchors.fill: parent
                radius: popupCard.radius
                color: notifdRoot.surface0
                opacity: parent.containsMouse ? 0.3 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }
              }
            }

            ColumnLayout {
              id: contentCol
              z: 1
              anchors.left: parent.left; anchors.right: parent.right
              anchors.top: parent.top; anchors.margins: 12
              spacing: 6

              Text {
                text: model.appName || "System"
                font.family: "JetBrains Mono"
                font.weight: Font.Medium
                font.pixelSize: 12
                color: notifdRoot.overlay1
                Layout.fillWidth: true
              }

              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: hiddenSummary.implicitHeight

                Text {
                  id: hiddenSummary
                  text: delegateRoot.fullSummary
                  width: parent.width
                  font.family: "JetBrains Mono"
                  font.weight: Font.Bold
                  font.pixelSize: 15
                  wrapMode: Text.Wrap
                  visible: false
                }
                Text {
                  anchors.fill: parent
                  text: delegateRoot.fullSummary.substring(0, delegateRoot.typeLenSum)
                  font: hiddenSummary.font
                  color: notifdRoot.text
                  wrapMode: Text.Wrap
                }
              }

              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: hiddenBody.implicitHeight
                visible: delegateRoot.fullBody !== ""

                Text {
                  id: hiddenBody
                  text: delegateRoot.fullBody
                  width: parent.width
                  font.family: "JetBrains Mono"
                  font.weight: Font.Medium
                  font.pixelSize: 13
                  wrapMode: Text.Wrap
                  textFormat: Text.StyledText
                  visible: false
                }
                Text {
                  anchors.fill: parent
                  text: delegateRoot.fullBody.substring(0, delegateRoot.typeLenBody)
                  font: hiddenBody.font
                  color: notifdRoot.subtext0
                  wrapMode: Text.Wrap
                  textFormat: Text.StyledText
                }
              }

              RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: delegateRoot.actionArray.length > 0 ? 6 : 0
                spacing: 8
                visible: delegateRoot.actionArray.length > 0

                Repeater {
                  model: delegateRoot.actionArray
                  delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8

                    property bool isPrimary: index === 0

                    color: {
                      if (isPrimary) {
                        return actionMouse.containsMouse ? notifdRoot.blue : Qt.darker(notifdRoot.blue, 1.2)
                      } else {
                        return actionMouse.containsMouse ? notifdRoot.surface2 : notifdRoot.surface1
                      }
                    }

                    border.color: isPrimary ? notifdRoot.blue : notifdRoot.surface2
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                      anchors.centerIn: parent
                      text: modelData.text || "Action"
                      font.family: "JetBrains Mono"
                      font.weight: Font.Bold
                      font.pixelSize: 12
                      color: isPrimary ? notifdRoot.crust : notifdRoot.text
                    }

                    MouseArea {
                      id: actionMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      z: 10

                      onClicked: {
                        var n = notifdRoot.liveNotifs[delegateRoot.popupUid];
                        if (n && n.actions) {
                          for (var i = 0; i < n.actions.length; i++) {
                            if (n.actions[i].identifier === modelData.id) {
                              n.actions[i].invoke(); break;
                            }
                          }
                        }
                        Qt.callLater(function() { notifdRoot.removePopup(delegateRoot.popupUid); });
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
  }

  Desktop {}

  Wallpaper {}
}
