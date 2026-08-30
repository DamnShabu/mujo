import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"

// Keyboard shortcuts — parsed live from the running niri config (the same
// bindings niri actually uses), with a local filter. Read-only reference; the
// bindings themselves are defined in the NixOS niri configuration.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property var binds: []
    property string filter: ""

    readonly property var shown: {
        var q = filter.trim().toLowerCase()
        if (q === "") return binds
        return binds.filter(function(b) {
            return b.key.toLowerCase().indexOf(q) >= 0 || b.action.toLowerCase().indexOf(q) >= 0
        })
    }

    function humanize(a) {
        // "focus-workspace 9" → "Focus workspace 9"; strip store paths.
        // Only the leading action name is kebab-case. Everything after the
        // first space is the command the bind spawns, where a hyphen is a real
        // flag — de-kebabbing the whole string turned "qs -p …" into "qs  p …"
        // and "set-column-width -5%" into "Set column width  5%".
        var s = a.replace(/\/nix\/store\/[^ ]+\//g, "").trim()
        var i = s.indexOf(" ")
        var head = (i < 0 ? s : s.slice(0, i)).replace(/-/g, " ")
        s = (head + (i < 0 ? "" : s.slice(i))).trim()
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    Process {
        id: bindsProc
        command: ["sh", "-c",
            "CFG=$(tr '\\0' '\\n' < /proc/$(pgrep -x niri | head -1)/environ | sed -n 's/^NIRI_CONFIG=//p'); "
          + "[ -z \"$CFG\" ] && CFG=$(systemctl --user cat niri.service 2>/dev/null | grep -oE '/nix/store/[^ ]*niri-config.kdl' | head -1); "
          + "awk 'BEGIN{inb=0} /^\"binds\"/{inb=1;next} inb&&/^}/{inb=0} "
          + "inb&&/{[ ]*$/{k=$0;gsub(/^[ ]*\"/,\"\",k);gsub(/\".*/,\"\",k);key=k;next} "
          + "inb&&/^[ ]+\"/{a=$0;gsub(/^[ ]+/,\"\",a);gsub(/\"/,\"\",a);print key\"\\t\"a}' \"$CFG\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")
                    if (p.length >= 2 && p[0] !== "") out.push({ key: p[0], action: p[1] })
                }
                out.sort(function(a, b) { return a.key < b.key ? -1 : 1 })
                root.binds = out
            }
        }
    }
    Component.onCompleted: bindsProc.running = true

    MujoCard {
        title: "Keyboard shortcuts"
        iconName: "keyboard_command_key"
        badgeText: root.binds.length + " BINDS"

        actions: TextField {
            Layout.preferredWidth: 200
            placeholder: "Filter shortcuts…"
            onTextChanged: root.filter = text
        }

        // The page owns the scroll, so this is a plain Repeater rather than a
        // ListView — a virtualised view inside a scrolling column has no
        // height to virtualise against.
        Repeater {
            model: root.shown
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Theme.radiusSm
                color: Theme.bg
                border.color: Theme.border
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: root.humanize(modelData.action)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        elide: Text.ElideRight
                    }
                    Row {
                        spacing: 4
                        Repeater {
                            model: modelData.key.split("+")
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: kc.implicitWidth + 14; implicitHeight: 22
                                radius: Theme.radiusSm
                                color: Theme.surface
                                border.color: Theme.borderStrong
                                Text {
                                    id: kc
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Theme.textSecondary
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.shown.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: root.binds.length === 0 ? "Reading shortcuts…" : "No shortcuts match the filter."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
        }
    }
}
