import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root

    property string recognizedText: ""
    property bool busy: false
    property string errorMessage: ""

    signal closeRequested()
    signal copyRequested(string text)
    signal translateRequested(string text)

    width: 440
    height: 300
    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.borderStrong
    border.width: 1
    z: 10000

    // Shadow / outline effect
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: root.radius + 1
        color: "transparent"
        border.color: Theme.border
        border.width: 1
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "document_scanner"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: Theme.accent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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
            Item {
                width: 16
                height: 16
                visible: root.busy

                Text {
                    anchors.centerIn: parent
                    text: "progress_activity"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.busy
                    }
                }
            }

            // Close button
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeHover.hovered ? Theme.surfaceHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.textDim
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
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
            radius: Theme.radiusMd
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
                    font.family: Theme.fontMono
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

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 28
                    height: 28

                    Text {
                        anchors.centerIn: parent
                        text: "progress_activity"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 28
                        color: Theme.accent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: root.busy
                        }
                    }
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
                font.pixelSize: 13
                color: Theme.error
            }
        }

        // Footer: Status and Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Character count
            Text {
                text: root.recognizedText.length > 0 ? (root.recognizedText.length + " chars · " + root.recognizedText.trim().split(/\s+/).length + " words") : ""
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
                    Text {
                        text: "translate"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 14
                        color: Theme.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                    Text {
                        text: "content_copy"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 14
                        color: Theme.accentText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
