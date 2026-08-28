import QtQuick
import QtQuick.Controls
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

// Sticky note. The text lives in this widget's own config block in widgets.json,
// written through `mujo widgets set` (the single writer for that file) on a
// debounce, so a burst of keystrokes costs one write.
BaseWidget {
    id: root

    property var wcfg: ({})
    property string widgetId: ""

    readonly property string noteTheme: wcfg.theme !== undefined ? wcfg.theme : SettingsBus.get("desktop.notes.theme", "slate")
    readonly property string noteFontSize: wcfg.fontSize !== undefined ? wcfg.fontSize : SettingsBus.get("desktop.notes.fontSize", "medium")

    title: ""
    iconName: ""

    // Note theme palette mapping
    surfaceColor: {
        if (noteTheme === "yellow") return "#fef08a"
        if (noteTheme === "rose") return "#fecdd3"
        if (noteTheme === "emerald") return "#a7f3d0"
        if (noteTheme === "dark") return "#18181b"
        if (noteTheme === "accent") return Theme.accentDim
        return Theme.withAlpha(Theme.surface, Theme.transparency * root.glassOpacity)
    }

    readonly property color noteTextColor: {
        if (noteTheme === "yellow") return "#422006"
        if (noteTheme === "rose") return "#4c0519"
        if (noteTheme === "emerald") return "#022c22"
        if (noteTheme === "dark") return "#f4f4f5"
        return Theme.text
    }

    readonly property color notePlaceholderColor: {
        if (noteTheme === "yellow") return "#a16207"
        if (noteTheme === "rose") return "#9f1239"
        if (noteTheme === "emerald") return "#115e59"
        if (noteTheme === "dark") return "#71717a"
        return Theme.textDim
    }

    readonly property real baseFontSize: {
        var base = Math.max(11, Math.min(16, Math.floor(root.height * 0.09)))
        if (noteFontSize === "small") return base * 0.85
        if (noteFontSize === "large") return base * 1.25
        return base
    }

    // Only adopt the on-disk value when it actually differs: the FileView reload
    // that follows our own write would otherwise yank the cursor to the end.
    readonly property string storedText: wcfg.text !== undefined ? String(wcfg.text) : ""
    onStoredTextChanged: if (area.text !== storedText) area.text = storedText

    Flickable {
        anchors.fill: parent
        anchors.margins: 4
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextArea.flickable: TextArea {
            id: area
            text: root.storedText
            placeholderText: "Note..."
            color: root.noteTextColor
            placeholderTextColor: root.notePlaceholderColor
            font.family: Theme.fontFamily
            font.pixelSize: root.baseFontSize
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
