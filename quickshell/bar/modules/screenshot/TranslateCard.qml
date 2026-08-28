import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root

    property string sourceText: ""
    property string translatedText: ""
    property string targetLang: "en"
    property bool busy: false
    property string errorMessage: ""

    signal closeRequested()
    signal copyRequested(string text)
    signal copyBothRequested(string orig, string trans)
    signal languageChanged(string lang)

    width: 480
    height: 380
    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.borderStrong
    border.width: 1
    z: 10000

    readonly property var supportedLangs: [
        { code: "en", name: "English" },
        { code: "uk", name: "Ukrainian" },
        { code: "de", name: "German" },
        { code: "es", name: "Spanish" },
        { code: "fr", name: "French" },
        { code: "ja", name: "Japanese" },
        { code: "pl", name: "Polish" },
        { code: "it", name: "Italian" },
        { code: "zh", name: "Chinese" }
    ]

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
                text: "translate"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: Theme.accent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: "Translation"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Theme.text
                Layout.fillWidth: true
            }

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

        // Language Selector Chips
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            RowLayout {
                spacing: 6
                Repeater {
                    model: root.supportedLangs
                    delegate: Rectangle {
                        required property var modelData
                        height: 26
                        width: langChipText.implicitWidth + 16
                        radius: 13
                        color: root.targetLang === modelData.code ? Theme.accent : (chipHover.hovered ? Theme.surfaceHover : Theme.bg)
                        border.color: root.targetLang === modelData.code ? Theme.accent : Theme.border
                        border.width: 1

                        Text {
                            id: langChipText
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: root.targetLang === modelData.code
                            color: root.targetLang === modelData.code ? Theme.accentText : Theme.text
                        }

                        HoverHandler { id: chipHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.targetLang = modelData.code
                                root.languageChanged(modelData.code)
                            }
                        }
                    }
                }
            }
        }

        // Body split: Source vs Translation
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Source box
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        text: "ORIGINAL TEXT"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.textDim
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        TextArea {
                            text: root.sourceText
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: Theme.textSecondary
                            wrapMode: Text.Wrap
                            selectByMouse: true
                            background: null
                            readOnly: true
                        }
                    }
                }
            }

            // Translation box
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        text: "TRANSLATION"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.accent
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.busy && root.errorMessage === ""

                        TextArea {
                            id: transEdit
                            text: root.translatedText
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: Theme.text
                            wrapMode: Text.Wrap
                            selectByMouse: true
                            background: null
                            readOnly: false
                        }
                    }

                    // Busy
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.busy

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

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
                                text: "Translating via translate-shell..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textSecondary
                            }
                        }
                    }

                    // Error
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.busy && root.errorMessage !== ""

                        Text {
                            anchors.centerIn: parent
                            text: root.errorMessage
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.error
                        }
                    }
                }
            }
        }

        // Footer: Copy Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            // Copy Both button
            Rectangle {
                height: 32
                width: copyBothRow.implicitWidth + 20
                radius: 16
                color: copyBothHover.hovered ? Theme.surfaceHover : Theme.surface
                border.color: Theme.borderStrong
                border.width: 1
                visible: !root.busy && transEdit.text.trim().length > 0

                RowLayout {
                    id: copyBothRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "copy_all"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 14
                        color: Theme.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: "Copy Both"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.text
                    }
                }

                HoverHandler { id: copyBothHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyBothRequested(root.sourceText, transEdit.text)
                }
            }

            // Copy Translation button
            Rectangle {
                height: 32
                width: copyTransRow.implicitWidth + 20
                radius: 16
                color: copyTransHover.hovered ? Theme.withAlpha(Theme.accent, 0.8) : Theme.accent
                visible: !root.busy && transEdit.text.trim().length > 0

                RowLayout {
                    id: copyTransRow
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
                        text: "Copy Translation"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.accentText
                    }
                }

                HoverHandler { id: copyTransHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyRequested(transEdit.text)
                }
            }
        }
    }
}
