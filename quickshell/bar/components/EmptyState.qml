import QtQuick
import QtQuick.Layouts
import "../theme"

// Nothing here yet. An empty screen is an invitation to act, so this says what
// is missing and what to do about it — never an apology.
//
// The outer item is what fills the section; the centred column lives inside it.
// A nested Layout takes its own maximumWidth from its widest-constrained child,
// so a wrapped hint with `Layout.maximumWidth` used to cap the whole block and
// park it left of centre.
Item {
    id: empty

    property string iconName: "inbox"
    property string title: ""
    property string hint: ""
    property int hintWidth: 420

    default property alias action: actionSlot.children

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(empty.hintWidth, empty.width)
        spacing: 10

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            iconName: empty.iconName
            pixelSize: 36
            color: Theme.textDim
        }

        Text {
            Layout.fillWidth: true
            text: empty.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            visible: empty.hint !== ""
            Layout.fillWidth: true
            text: empty.hint
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            lineHeight: 1.25
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        RowLayout {
            id: actionSlot
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 8
        }
    }
}
