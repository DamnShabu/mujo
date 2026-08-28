import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Animations & Motion Control Panel — Mujo (無常).
// Dedicated showcase and configuration center for the Mujo motion system.
// Features a live interactive motion playground, 3-tier intensity tuning,
// granular motion domain toggles, and performance/accessibility controls.
Item {
    id: root

    // ── SettingsBus Bindings & Helpers ─────────────────────────────────────────
    function bget(key, fallback) { return SettingsBus.get(key, fallback) }
    function bset(key, val) { SettingsBus.set(key, val) }

    readonly property bool motionEnabled: bget("motion.enabled", true)
    readonly property string motionIntensity: bget("motion.intensity", "balanced")
    readonly property bool ambientMotion: bget("motion.ambient", true)
    readonly property bool pageTransitions: bget("motion.pageTransitions", true)
    readonly property bool microInteractions: bget("motion.microInteractions", true)
    readonly property bool animatedIllustrations: bget("motion.illustrations", true)
    readonly property bool backgroundEffects: bget("motion.backgroundEffects", true)
    readonly property bool reduceMotion: bget("motion.reduce", false)
    readonly property bool performanceMode: bget("motion.performanceMode", false)

    // Interactive playground state
    property bool demoToggle: true
    property real demoSlider: 0.65
    property string demoSegmented: "opt2"
    property real demoPulse: 0.0

    function triggerPulse() {
        demoPulseAnim.restart()
    }

    NumberAnimation {
        id: demoPulseAnim
        target: root
        property: "demoPulse"
        from: 1.0
        to: 0.0
        duration: Anim.pulse
        easing.type: Easing.OutQuad
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: mainCol.implicitHeight + 30
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 16

            // ── 1. Header ─────────────────────────────────────────────────────
            MujoHero {
                brand: "animations"
                title: "Animations & Motion"
                subtitle: "Motion architecture, animation timing profiles, and accessibility overrides."
                badgeText: root.motionIntensity.toUpperCase()
                badgeColor: Brand.get("animations").color
            }

            // ── 2. Live Interactive Motion Playground ─────────────────────────
            MujoCard {
                title: "Interactive Motion Playground"
                iconName: "play_circle"
                badgeText: root.motionEnabled ? (Anim.reduceMotion ? "REDUCED MOTION" : "INTERACTIVE") : "DISABLED"
                badgeColor: root.motionEnabled ? Theme.accent : Theme.textDim

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Playground interactive surface
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 140
                        radius: Theme.radiusMd
                        color: Theme.withAlpha(Theme.bg, 0.7)
                        border.color: Theme.border
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 14

                            // Top Info Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    implicitWidth: engPill.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: Theme.radiusSm
                                    color: Theme.surface
                                    border.color: Theme.border

                                    RowLayout {
                                        id: engPill
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Rectangle {
                                            width: 6; height: 6; radius: 3
                                            color: root.motionEnabled ? Theme.success : Theme.error
                                        }
                                        Text {
                                            text: root.motionEnabled ? "MOTION ENGINE ACTIVE" : "MOTION ENGINE INACTIVE"
                                            color: Theme.text
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeLabel - 1
                                            font.bold: true
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: scalePill.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: Theme.radiusSm
                                    color: Theme.accentDim
                                    border.color: Theme.withAlpha(Theme.accent, 0.3)

                                    Text {
                                        id: scalePill
                                        anchors.centerIn: parent
                                        text: "DURATION SCALE: " + (Anim.durationScale * 100).toFixed(0) + "%"
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        font.bold: true
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Trigger Pulse Test Button
                                Rectangle {
                                    implicitWidth: pulseTxt.implicitWidth + 18
                                    implicitHeight: 24
                                    radius: Theme.radiusSm
                                    color: pulseHh.hovered ? Theme.accent : Theme.surface
                                    border.color: Theme.accent
                                    Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        MaterialIcon {
                                            iconName: "bolt"
                                            pixelSize: 13
                                            color: pulseHh.hovered ? Theme.accentText : Theme.accent
                                        }
                                        Text {
                                            id: pulseTxt
                                            text: "Trigger Motion Pulse"
                                            color: pulseHh.hovered ? Theme.accentText : Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeLabel
                                            font.bold: true
                                        }
                                    }
                                    HoverHandler { id: pulseHh; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.triggerPulse() }
                                }
                            }

                            // Interactive Demo Controls Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20

                                // Interactive Toggle
                                RowLayout {
                                    spacing: 8
                                    ToggleSwitch {
                                        checked: root.demoToggle
                                        onToggled: function(c) { root.demoToggle = c }
                                    }
                                    Text {
                                        text: root.demoToggle ? "Active State" : "Dormant State"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                Rectangle { width: 1; height: 24; color: Theme.border }

                                // Interactive Slider
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    MaterialIcon {
                                        iconName: "tune"
                                        pixelSize: 15
                                        color: Theme.accent
                                    }
                                    Slider {
                                        Layout.fillWidth: true
                                        value: root.demoSlider
                                        from: 0.0
                                        to: 1.0
                                        format: "%"
                                        valueText: Math.round(root.demoSlider * 100) + "%"
                                        onMoved: function(v) { root.demoSlider = v }
                                    }
                                }

                                Rectangle { width: 1; height: 24; color: Theme.border }

                                // Interactive Segmented Choice
                                MujoSegmented {
                                    current: root.demoSegmented
                                    model: [
                                        { id: "opt1", label: "Fast", icon: "speed" },
                                        { id: "opt2", label: "Smooth", icon: "gesture" },
                                        { id: "opt3", label: "Fluid", icon: "waves" }
                                    ]
                                    onSelected: function(id) { root.demoSegmented = id }
                                }
                            }
                        }
                    }
                }
            }

            // ── 3. Master Hierarchy & Intensity Profile ───────────────────────
            MujoCard {
                title: "Motion Intensity Profile"
                iconName: "tune"

                // Master Switch
                MujoSettingRow {
                    iconName: "power_settings_new"
                    title: "Master Animation Engine"
                    description: "Global master switch for desktop animations, page transitions, and UI interactions."

                    ToggleSwitch {
                        checked: root.motionEnabled
                        onToggled: function(c) { root.bset("motion.enabled", c) }
                    }
                }

                // Intensity Segmented Selector
                MujoSettingRow {
                    iconName: "speed"
                    title: "Intensity Profile"
                    description: "Minimal: snappy and subtle with reduced motion ranges. Balanced: standard smooth physics. Expressive: wider kinetic travel and responsive curves."

                    MujoSegmented {
                        current: root.motionIntensity
                        model: [
                            { id: "minimal",    label: "Minimal",    icon: "air" },
                            { id: "balanced",   label: "Balanced",   icon: "balance" },
                            { id: "expressive", label: "Expressive", icon: "auto_awesome" }
                        ]
                        onSelected: function(id) {
                            root.bset("motion.intensity", id)
                            root.triggerPulse()
                        }
                    }
                }
            }

            // ── 4. Granular Motion Domains ────────────────────────────────────
            MujoCard {
                title: "Motion Domains"
                iconName: "layers"

                MujoSettingRow {
                    iconName: "view_carousel"
                    title: "Page Transitions"
                    description: "Smooth crossfade and vertical slide transitions when switching between settings panels and tabs."
                    ToggleSwitch {
                        checked: root.pageTransitions
                        onToggled: function(c) { root.bset("motion.pageTransitions", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "touch_app"
                    title: "Tactile Micro-interactions"
                    description: "Fluid hover highlights, switch elasticity, accordion drawer expansion, and button press feedback."
                    ToggleSwitch {
                        checked: root.microInteractions
                        onToggled: function(c) { root.bset("motion.microInteractions", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "air"
                    title: "Ambient Motion & Flow"
                    description: "Subtle continuous background dynamics, breathing loops, and particle effects."
                    ToggleSwitch {
                        checked: root.ambientMotion
                        onToggled: function(c) { root.bset("motion.ambient", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "blur_on"
                    title: "Background Glow & Visual Effects"
                    description: "Radial backdrop glow and accent lighting across desktop surfaces."
                    ToggleSwitch {
                        checked: root.backgroundEffects
                        onToggled: function(c) { root.bset("motion.backgroundEffects", c) }
                    }
                }
            }

            // ── 5. Accessibility & Performance Optimization ───────────────────
            MujoCard {
                title: "Accessibility & Performance"
                iconName: "accessibility_new"

                MujoSettingRow {
                    iconName: "accessibility"
                    title: "Reduced Motion"
                    description: "Accessibility mode eliminating spatial movement and transitions across all desktop surfaces."
                    ToggleSwitch {
                        checked: root.reduceMotion
                        onToggled: function(c) { root.bset("motion.reduce", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "bolt"
                    title: "Low-Power Performance Mode"
                    description: "Disables background particle effects and continuous ambient loops to conserve GPU/CPU power on laptops."
                    ToggleSwitch {
                        checked: root.performanceMode
                        onToggled: function(c) { root.bset("motion.performanceMode", c) }
                    }
                }
            }
        }
    }
}
