// Hardware & security — displays, idle/power, input, shortcuts, machines and
// the keyring, as one scrolling column of cards. Two levels deep: this page,
// then its cards. Nothing below opens a sub-page.
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
    KeyringGroup {}
}
