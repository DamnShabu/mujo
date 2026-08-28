import QtQuick
import "../theme"
import "../services"

// A single ~/Desktop entry drawn in one grid cell.
//
// Deliberately chrome-less at rest: no card, no border, no fill. Desktop widgets
// are cards with visible boundaries, so leaving files bare is what makes the two
// object types legible as different things while they share one grid — the
// distinction is carried by the visual language rather than by a badge.
//
// Purely presentational. DesktopIcons.qml owns every pointer interaction so that
// hit-testing, selection and drag live in one place; the only input here is the
// rename field, which needs its own focus.
Item {
    id: root

    property string name: ""
    property bool isDir: false
    property bool selected: false
    property bool hovered: false
    property bool renaming: false
    property bool cut: false              // on the clipboard as a cut, drawn faded
    property bool dropInvalid: false      // shown while this icon is being dragged nowhere valid
    property bool dropTarget: false       // a drag is hovering this folder, release moves into it

    signal renameAccepted(string text)
    signal renameCancelled()

    // The pictogram takes half the cell, which keeps the freedesktop 48px size at
    // the default 96px cell and scales with desktop.iconSize without the label
    // ever losing its two lines.
    readonly property int iconPx: Math.round(Math.min(root.width, root.height) * 0.5)

    // Icons come from the system icon theme, keyed by extension, exactly as a
    // file manager picks them: ~/Desktop entries are overwhelmingly
    // recognisable by extension, and asking `file` per item would cost a
    // process per icon on every poll. Full colour rather than symbolic here —
    // colour file-type icons are the desktop convention, and they are what
    // makes a folder distinguishable from a PDF at a glance.
    readonly property string iconSource: Icons.fileIcon(root.name, root.isDir)

    // Fallback tint, used only when no icon theme is installed and the glyph
    // draws instead. Folders take the accent, files stay neutral.
    readonly property color glyphColor: root.dropInvalid ? Theme.error
                                      : root.isDir ? Theme.accent
                                      : Theme.text

    // A wallpaper is arbitrary, so label contrast cannot come from the palette
    // alone: the halo is whatever the text is not. Dark text on a light theme
    // gets a light halo, light text gets a dark one, and either stays readable
    // over any photo.
    readonly property bool lightText: (Theme.text.r * 0.299 + Theme.text.g * 0.587 + Theme.text.b * 0.114) > 0.5
    readonly property color haloColor: root.lightText ? "#000000" : "#ffffff"
    readonly property int labelSize: SettingsBus.get("desktop.labelSize", 12)
    // Height of a two-line label — the resting layout. The column is placed from
    // this rather than from its live height, so a name that grows to four lines
    // on selection grows downwards over the row below instead of dragging the
    // pictogram up with it.
    readonly property int restLabelPx: Math.round(root.labelSize * 1.15 * 2)

    opacity: root.cut ? 0.45 : 1
    Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.fast) } }

    // ─── Selection field ──────────────────────────────────────────────────────
    // Hugs the icon and its label rather than the whole grid cell, so a selected
    // name reads as one object the way it does in a file manager — and so a long
    // name that has grown to three lines is still enclosed by it.
    Rectangle {
        anchors.fill: content
        anchors.margins: -5
        radius: Theme.radiusMd
        color: root.dropInvalid ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
             : root.dropTarget ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.32)
             : root.selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
             : root.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
             : "transparent"
        border.width: (root.selected || root.dropInvalid || root.dropTarget) ? 1 : 0
        border.color: root.dropInvalid ? Theme.error
                    : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                              root.dropTarget ? 0.9 : 0.55)
        Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
    }

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        // Anchored to the top rather than centred: a selected name may grow past
        // the cell, and it has to grow downwards over the row below (the way a
        // desktop does it) instead of dragging the pictogram up with it.
        y: Math.round((root.height - root.iconPx - root.restLabelPx - content.spacing) / 2)
        width: root.width - 8
        spacing: 4

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.iconPx
            height: root.iconPx

            Image {
                anchors.fill: parent
                visible: root.iconSource !== ""
                source: root.iconSource
                // Never crop or stretch a file icon: fit it whole in the box.
                fillMode: Image.PreserveAspectFit
                sourceSize.width: root.iconPx
                sourceSize.height: root.iconPx
                smooth: true
                mipmap: true
            }

            MaterialIcon {
                anchors.fill: parent
                visible: root.iconSource === ""
                iconName: root.isDir ? "folder" : "draft"
                color: root.glyphColor
                // An outline costs one draw call; a shadow layer per icon would
                // cost a render target each.
                outlineStyle: Text.Outline
                outlineColor: root.haloColor
            }
        }

        // The label sits in its own host so the shadow copy can be offset without
        // moving the Column's layout, and so the field replaces it in place.
        Item {
            id: labelHost
            width: parent.width
            height: root.renaming ? renameField.implicitHeight + 6 : label.implicitHeight

            // Cast copy: the same glyphs one pixel down in translucent halo
            // colour. Two Text draws, no render target — a per-icon MultiEffect
            // would cost an offscreen buffer each, and this reads the same.
            Text {
                x: label.x
                y: label.y + 1
                visible: label.visible
                width: label.width
                horizontalAlignment: Text.AlignHCenter
                text: label.text
                color: Qt.rgba(root.lightText ? 0 : 1, root.lightText ? 0 : 1, root.lightText ? 0 : 1, 0.45)
                font: label.font
                style: Text.Outline
                styleColor: Qt.rgba(root.lightText ? 0 : 1, root.lightText ? 0 : 1, root.lightText ? 0 : 1, 0.35)
                wrapMode: label.wrapMode
                maximumLineCount: label.maximumLineCount
                elide: label.elide
                lineHeight: label.lineHeight
            }

            Text {
                id: label
                visible: !root.renaming
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.labelSize
                font.weight: Font.Medium
                style: Text.Outline
                styleColor: Qt.rgba(root.lightText ? 0 : 1, root.lightText ? 0 : 1, root.lightText ? 0 : 1, 0.6)
                // Two lines at rest keeps the rows apart; a selected or hovered
                // icon shows the rest of the name, which is the only way to read
                // a long one without opening a rename field.
                wrapMode: Text.Wrap
                maximumLineCount: (root.selected || root.hovered) ? 4 : 2
                elide: Text.ElideRight
                lineHeight: 1.15
            }

            // Rename happens in place, on the icon, so the name never leaves the
            // spot the user is looking at.
            TextInput {
                id: renameField
                visible: root.renaming
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 3
                width: parent.width - 6
                horizontalAlignment: Text.AlignHCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.labelSize
                wrapMode: Text.Wrap
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText

                Rectangle {
                    z: -1
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: Theme.radiusSm
                    color: Theme.bg
                    border.color: Theme.accent
                    border.width: 1
                }

                onVisibleChanged: {
                    if (!visible) return
                    text = root.name
                    forceActiveFocus()
                    // Select the stem, not the extension — the part being retyped.
                    var dot = root.isDir ? -1 : root.name.lastIndexOf(".")
                    if (dot > 0) select(0, dot); else selectAll()
                }
                onAccepted: root.renameAccepted(renameField.text.trim())
                Keys.onEscapePressed: root.renameCancelled()
                onActiveFocusChanged: {
                    // Clicking away commits, the way a desktop rename normally does.
                    if (!activeFocus && root.renaming) root.renameAccepted(renameField.text.trim())
                }
            }
        }
    }
}
