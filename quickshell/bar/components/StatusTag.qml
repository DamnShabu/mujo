import QtQuick
import "../theme"

// The one badge shape in the settings app: a short machine word, tinted, no
// border. NIXOS, ON, ABSENT, 3 OVERRIDES, reboot to apply.
//
// The groups drew this by hand some thirty times — heights of 15, 16, 20 and
// 22, padding of 8, 10 and 14, half of them with a border and half without —
// so a card could show three badges of three different sizes in one row.
Rectangle {
    id: tag

    property string text: ""
    // neutral | accent | success | warning | error
    property string tone: "neutral"
    // A tone the caller computes itself (a per-item colour, a brand colour).
    property color toneColor: tag.tone === "accent"  ? Theme.accent
                            : tag.tone === "success" ? Theme.success
                            : tag.tone === "warning" ? Theme.warning
                            : tag.tone === "error"   ? Theme.error
                            : Theme.textSecondary

    implicitWidth: label.implicitWidth + 10
    implicitHeight: 16
    radius: 4
    color: Theme.withAlpha(tag.toneColor, 0.14)

    Accessible.role: Accessible.StaticText
    Accessible.name: tag.text

    Text {
        id: label
        anchors.centerIn: parent
        text: tag.text
        color: tag.toneColor
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeLabel
    }
}
