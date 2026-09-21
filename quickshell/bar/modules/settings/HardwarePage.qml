import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Hardware — the machine this desktop runs on: its screens, its input devices,
// its power behaviour, its network VPN, and the VMs it builds.
SettingsPage {
    id: root

    brand: "display"
    title: "Hardware"
    subtitle: "Displays, input devices, keyboard shortcuts, power, network VPN and virtual machines."
    isNixos: true
    tab: "displays"

    sections: [
        { id: "displays", label: "Displays", component: displaysSection,
          description: "Arrange your monitors and set resolution, refresh rate and scale." },
        { id: "input", label: "Input & Keys", component: inputSection,
          description: "Keyboard layout, pointer behavior, and the compositor's shortcuts." },
        { id: "power", label: "Power & Sleep", component: powerSection,
          description: "When the screen dims, when it locks, and when the machine suspends." },
        { id: "network", label: "Network & VPN", component: networkSection,
          description: "The Mullvad tunnel, keyring credentials, and relay exit nodes." },
        { id: "vm", label: "Virtual Machines", component: vmSection,
          description: "Build and run throwaway virtual machines from this flake." }
    ]

    aliases: ({ "shortcuts": "input", "vpn": "network" })

    cardMap: ({
        "Arrangement": "displays",
        "Keyboard": "input",
        "Pointer": "input",
        "Touchpad": "input",
        "Keyboard Shortcuts": "input",
        "Idle & Power": "power",
        "Mullvad WireGuard Tunnel": "network",
        "Keyring Credentials & Login": "network",
        "Relay Locations & Exit Nodes": "network",
        "Tunnel Automation & Behavior": "network",
        "Hypervisor": "vm",
        "Virtual Machines": "vm"
    })

    Component { id: displaysSection; ColumnLayout { spacing: 14; DisplaysGroup { Layout.fillWidth: true } } }
    Component {
        id: inputSection
        ColumnLayout {
            spacing: 14
            InputGroup { Layout.fillWidth: true }
            ShortcutsGroup { Layout.fillWidth: true }
        }
    }
    Component { id: powerSection; ColumnLayout { spacing: 14; IdlePowerGroup { Layout.fillWidth: true } } }
    Component {
        id: networkSection
        ColumnLayout {
            spacing: 14
            NetworkGroup { Layout.fillWidth: true }
        }
    }
    Component { id: vmSection; ColumnLayout { spacing: 14; VmGroup { Layout.fillWidth: true } } }
}

