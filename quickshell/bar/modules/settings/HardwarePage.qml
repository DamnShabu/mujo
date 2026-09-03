import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Hardware & Devices — displays, idle/power, input, shortcuts, and virtual machines.
SettingsPage {
    brand: "display"
    title: "Hardware"
    subtitle: "Displays, input, machines & keys"
    isNixos: true

    DisplaysGroup {}
    IdlePowerGroup {}
    InputGroup {}
    ShortcutsGroup {}
    VmGroup {}
}

