import QtQuick
import "../theme"

// Uppercase, letter-spaced monospace micro-label used as the eyebrow/header
// across popup cards — the small "// SYSTEM", "WI-FI", "OUTPUT DEVICE" style
// captions from the reference shells.
Text {
    id: root
    property bool accented: false

    text: ""
    font.family: Theme.fontMono
    font.pixelSize: Theme.fontSizeLabel
    font.letterSpacing: Theme.labelSpacing
    font.capitalization: Font.AllUppercase
    color: accented ? Theme.accent : Theme.textSecondary
}
