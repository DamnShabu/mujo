import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../bar/theme"
import "../bar/components"

Rectangle {
    id: root

    property string sourceText: ""
    property string translatedText: ""
    property string targetLang: "en"
    property bool busy: false
    property string errorMessage: ""

    signal languageChanged(string newLang)
    signal copyRequested(string text)
    signal copyBothRequested(string orig, string trans)
    signal closeRequested()

    readonly property var availableLanguages: [
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

    width: 480
    height: Math.min(460, mainCol.implicitHeight + 32)
    radius: Theme.cornerRadius + 4
    color: Theme.surface
    border.color: Theme.borderStrong
    border.width: 1
    clip: true
    z: 10000

    // Border glow
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
        id: mainCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialIcon {
                iconName: "translate"
                pixelSize: 20
                color: Theme.accent
            }

            Text {
                text: "Translation"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Theme.text
                Layout.fillWidth: true
            }

            Spinner {
                visible: root.busy
                spinning: root.busy
                size: 16
            }

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

        // Language Selector Chips (Horizontally scrollable)
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            contentHeight: 32
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Row {
                spacing: 6
                Repeater {
                    model: root.availableLanguages
                    delegate: Rectangle {
                        id: langChip
                        required property var modelData

                        height: 28
                        width: chipText.implicitWidth + 18
                        radius: 14
                        color: root.targetLang === modelData.code
                               ? Theme.accent
                               : (chipHover.hovered ? Theme.surfaceHover : Theme.surfaceActive)
                        border.color: root.targetLang === modelData.code ? Theme.accent : Theme.border
                        border.width: 1

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: langChip.modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: root.targetLang === langChip.modelData.code
                            color: root.targetLang === langChip.modelData.code ? Theme.accentText : Theme.text
                        }

                        HoverHandler { id: chipHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.targetLang !== langChip.modelData.code) {
                                    root.targetLang = langChip.modelData.code
                                    root.languageChanged(langChip.modelData.code)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Original Text (Compact preview)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "ORIGINAL TEXT"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                color: Theme.textDim
            }

            Rectangle {
                Layout.fillWidth: true
                height: Math.min(70, origText.implicitHeight + 16)
                radius: Theme.cornerRadius - 2
                color: Theme.bg
                border.color: Theme.border
                border.width: 1
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8

                    Text {
                        id: origText
                        text: root.sourceText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
            }
        }

        // Translated Text Box
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Text {
                text: "TRANSLATED RESULT"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                color: Theme.textDim
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120
                radius: Theme.cornerRadius
                color: Theme.bg
                border.color: Theme.border
                border.width: 1
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: !root.busy && root.errorMessage === ""

                    TextArea {
                        id: transEdit
                        text: root.translatedText
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.text
                        wrapMode: Text.Wrap
                        selectByMouse: true
                        background: null
                        readOnly: false
                    }
                }

                // Busy
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
                        text: "Translating via translate-shell..."
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textSecondary
                    }
                }

                // Error
                Text {
                    anchors.centerIn: parent
                    visible: !root.busy && root.errorMessage !== ""
                    text: root.errorMessage
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.warning
                }
            }
        }

        // Footer Actions
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
                    MaterialIcon {
                        iconName: "copy_all"
                        pixelSize: 14
                        color: Theme.text
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
                    MaterialIcon {
                        iconName: "content_copy"
                        pixelSize: 14
                        color: Theme.accentText
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
