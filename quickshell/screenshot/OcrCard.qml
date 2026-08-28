import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../bar/theme"
import "../bar/components"

Rectangle {
    id: root

    property string recognizedText: ""
    property bool busy: false
    property string errorMessage: ""

    signal copyRequested(string text)
    signal translateRequested(string text)
    signal closeRequested()

    width: 440
    height: Math.min(380, contentCol.implicitHeight + 32)
    radius: Theme.cornerRadius + 4
    color: Theme.surface
    border.color: Theme.borderStrong
    border.width: 1
    clip: true
    z: 10000

    // Subtle drop shadow / border glow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: "transparent"
        border.color: Theme.withAlpha(Theme.accent, 0.3)
        border.width: 1
        z: -1
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialIcon {
                iconName: "document_scanner"
                pixelSize: 20
                color: Theme.accent
            }

            Text {
                text: "Optical Character Recognition"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Theme.text
                Layout.fillWidth: true
            }

            // Spinner if busy
            Spinner {
                visible: root.busy
                spinning: root.busy
                size: 16
            }

            // Close button
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeHover.hovered ? Theme.surfaceHover : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "close"
                    pixelSize: 16
                    color: Theme.textDim
                }

                HoverHandler { id: closeHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Body: Text area or Status
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 160
            radius: Theme.cornerRadius
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            clip: true

            ScrollView {
                id: scrollView
                anchors.fill: parent
                anchors.margins: 10
                visible: !root.busy && root.errorMessage === ""

                TextArea {
                    id: textEdit
                    text: root.recognizedText
                    font.family: Theme.fontFamilyMono || "monospace"
                    font.pixelSize: 13
                    color: Theme.text
                    wrapMode: Text.Wrap
                    selectByMouse: true
                    background: null
                    placeholderText: "No text found in selection..."
                    placeholderTextColor: Theme.textDim
                }
            }

            // Busy state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: root.busy

                Spinner {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spinning: root.busy
                    size: 28
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Extracting text with Tesseract..."
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }
            }

            // Error state
            Text {
                anchors.centerIn: parent
                visible: !root.busy && root.errorMessage !== ""
                text: root.errorMessage
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.warning
            }
        }

        // Footer: Char count & Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: {
                    var len = textEdit.text.length
                    var words = textEdit.text.trim().length > 0 ? textEdit.text.trim().split(/\s+/).length : 0
                    return len + " chars • " + words + " words"
                }
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textDim
                Layout.fillWidth: true
            }

            // Translate button
            Rectangle {
                height: 32
                width: transRow.implicitWidth + 20
                radius: 16
                color: transHover.hovered ? Theme.surfaceHover : Theme.surface
                border.color: Theme.borderStrong
                border.width: 1
                visible: !root.busy && textEdit.text.trim().length > 0

                RowLayout {
                    id: transRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon {
                        iconName: "translate"
                        pixelSize: 14
                        color: Theme.text
                    }
                    Text {
                        text: "Translate"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.text
                    }
                }

                HoverHandler { id: transHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.translateRequested(textEdit.text)
                }
            }

            // Copy Text button
            Rectangle {
                height: 32
                width: copyRow.implicitWidth + 20
                radius: 16
                color: copyHover.hovered ? Theme.withAlpha(Theme.accent, 0.8) : Theme.accent
                visible: !root.busy && textEdit.text.trim().length > 0

                RowLayout {
                    id: copyRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon {
                        iconName: "content_copy"
                        pixelSize: 14
                        color: Theme.accentText
                    }
                    Text {
                        text: "Copy Text"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.accentText
                    }
                }

                HoverHandler { id: copyHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyRequested(textEdit.text)
                }
            }
        }
    }
}
