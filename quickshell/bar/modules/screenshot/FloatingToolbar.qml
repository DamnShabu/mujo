import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root

    property int selX: 0
    property int selY: 0
    property int selWidth: 0
    property int selHeight: 0
    property bool annotateActive: false

    signal copyRequested()
    signal saveRequested()
    signal ocrRequested()
    signal translateRequested()
    signal annotateToggled()
    signal pinRequested()
    signal cancelRequested()

    visible: selWidth > 10 && selHeight > 10
    z: 9998

    height: 44
    width: toolbarRow.implicitWidth + 16
    radius: 22

    color: Theme.surface
    border.color: Theme.borderStrong
    border.width: 1

    // Smooth entry
    opacity: visible ? 1.0 : 0.0
    scale: visible ? 1.0 : 0.9
    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }
    Behavior on scale { NumberAnimation { duration: Anim.d(Anim.fast); easing.type: Easing.OutBack } }

    // Position relative to selection with screen bounds clamping
    x: {
        var idealX = selX + (selWidth - width) / 2
        if (parent) {
            idealX = Math.max(10, Math.min(parent.width - width - 10, idealX))
        }
        return idealX
    }
    y: {
        var idealY = selY + selHeight + 12
        if (parent && idealY + height > parent.height - 10) {
            // Flip above selection
            idealY = selY - height - 12
        }
        return Math.max(10, idealY)
    }

    // Action button component
    component ToolButton: Rectangle {
        id: btn
        property string iconName: ""
        property string toolTipText: ""
        property bool isPrimary: false
        property bool isToggled: false
        signal clicked()

        width: 34
        height: 34
        radius: 17
        color: {
            if (btn.isToggled) return Theme.accent
            if (btnHover.hovered) return Theme.surfaceHover
            if (btn.isPrimary) return Theme.withAlpha(Theme.accent, 0.15)
            return "transparent"
        }
        border.color: btn.isPrimary ? Theme.accent : "transparent"
        border.width: btn.isPrimary ? 1 : 0

        Text {
            anchors.centerIn: parent
            text: btn.iconName
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
            color: btn.isToggled ? Theme.accentText : (btn.isPrimary ? Theme.accent : Theme.text)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        HoverHandler { id: btnHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        // Hover Tooltip Badge
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            visible: btnHover.hovered && btn.toolTipText !== ""
            width: tipText.implicitWidth + 14
            height: 24
            radius: 12
            color: Theme.bg
            border.color: Theme.borderStrong
            border.width: 1
            z: 99999

            Text {
                id: tipText
                anchors.centerIn: parent
                text: btn.toolTipText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
                color: Theme.text
            }
        }
    }

    RowLayout {
        id: toolbarRow
        anchors.centerIn: parent
        spacing: 4

        // Copy (Primary)
        ToolButton {
            iconName: "content_copy"
            toolTipText: "Copy to Clipboard (Enter / Ctrl+C)"
            isPrimary: true
            onClicked: root.copyRequested()
        }

        // Save
        ToolButton {
            iconName: "save"
            toolTipText: "Save to Disk (Ctrl+S)"
            onClicked: root.saveRequested()
        }

        // Divider
        Rectangle {
            width: 1
            height: 20
            color: Theme.border
            Layout.alignment: Qt.AlignVCenter
        }

        // OCR
        ToolButton {
            iconName: "document_scanner"
            toolTipText: "Extract Text / OCR (Ctrl+O)"
            onClicked: root.ocrRequested()
        }

        // Translate
        ToolButton {
            iconName: "translate"
            toolTipText: "Translate Text (Ctrl+T)"
            onClicked: root.translateRequested()
        }

        // Divider
        Rectangle {
            width: 1
            height: 20
            color: Theme.border
            Layout.alignment: Qt.AlignVCenter
        }

        // Annotate Toggle
        ToolButton {
            iconName: "draw"
            toolTipText: "Annotate / Draw (A)"
            isToggled: root.annotateActive
            onClicked: root.annotateToggled()
        }

        // Pin
        ToolButton {
            iconName: "push_pin"
            toolTipText: "Pin to Screen (P)"
            onClicked: root.pinRequested()
        }

        // Cancel / Close
        ToolButton {
            iconName: "close"
            toolTipText: "Cancel (Esc)"
            onClicked: root.cancelRequested()
        }
    }
}
