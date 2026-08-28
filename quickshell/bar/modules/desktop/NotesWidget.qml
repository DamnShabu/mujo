import QtQuick
import QtQuick.Controls
import Quickshell
import "../../theme"
import "../../components"

// Sticky note. The text lives in this widget's own config block in widgets.json,
// written through `mujo widgets set` (the single writer for that file) on a
// debounce, so a burst of keystrokes costs one write.
BaseWidget {
    id: root

    property var wcfg: ({})
    property string widgetId: ""

    title: ""
    iconName: ""

    // Only adopt the on-disk value when it actually differs: the FileView reload
    // that follows our own write would otherwise yank the cursor to the end.
    readonly property string storedText: wcfg.text !== undefined ? String(wcfg.text) : ""
    onStoredTextChanged: if (area.text !== storedText) area.text = storedText

    Flickable {
        anchors.fill: parent
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextArea.flickable: TextArea {
            id: area
            text: root.storedText
            placeholderText: "Note..."
            color: Theme.text
            placeholderTextColor: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(11, Math.min(16, Math.floor(root.height * 0.09)))
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            background: null
            onTextChanged: saveTimer.restart()
        }

        ScrollBar.vertical: ScrollBar {}
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: {
            if (root.widgetId === "" || area.text === root.storedText) return
            Quickshell.execDetached(["mujo", "widgets", "set", root.widgetId, "text", area.text])
        }
    }
}
