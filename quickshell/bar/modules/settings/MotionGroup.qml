import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Motion Architecture, Interactive Playground, and Performance Controls Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    function bget(key, fallback) { return SettingsBus.get(key, fallback) }
    function bset(key, val) { SettingsBus.set(key, val) }

    readonly property bool motionEnabled: bget("motion.enabled", true)
    readonly property string motionIntensity: bget("motion.intensity", "balanced")
    readonly property bool ambientMotion: bget("motion.ambient", true)
    readonly property bool pageTransitions: bget("motion.pageTransitions", true)
    readonly property bool microInteractions: bget("motion.microInteractions", true)
    readonly property bool backgroundEffects: bget("motion.backgroundEffects", true)
    readonly property bool reduceMotion: bget("motion.reduce", false)
    readonly property bool performanceMode: bget("motion.performanceMode", false)

    // Interactive playground state
    property bool demoToggle: true
    property real demoSlider: 0.65
    property string demoSegmented: "opt2"
    property real demoPulse: 0.0

    function triggerPulse() { demoPulseAnim.restart() }

    NumberAnimation {
        id: demoPulseAnim
        target: root
        property: "demoPulse"
        from: 1.0
        to: 0.0
        duration: Anim.pulse
        easing.type: Easing.OutQuad
    }

    // ── 1. Interactive Motion Playground Card ─────────────────────────────────
    MujoCard {
        title: "Interactive Motion Playground"
        iconName: "play_circle"
        badgeText: root.motionEnabled ? (Anim.reduceMotion ? "REDUCED MOTION" : "INTERACTIVE") : "DISABLED"
        badgeColor: root.motionEnabled ? Theme.accent : Theme.textDim

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 140
                radius: Theme.radiusMd
                color: Theme.withAlpha(Theme.bg, 0.7)
                border.color: Theme.border
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            implicitWidth: engPill.implicitWidth + 12
                            implicitHeight: 22
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
                            implicitHeight: 22
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

                        Rectangle {
                            implicitWidth: pulseTxt.implicitWidth + 18
                            implicitHeight: 26
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
                                    text: "Trigger Pulse"
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

                        RowLayout {
                            spacing: 8
                            ToggleSwitch {
                                checked: root.demoToggle
                                onToggled: function(c) { root.demoToggle = c }
                            }
                            Text {
                                text: root.demoToggle ? "Active" : "Dormant"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        Rectangle { width: 1; height: 24; color: Theme.border }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialIcon { iconName: "tune"; pixelSize: 15; color: Theme.accent }
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

    // ── 2. Master Intensity Profile Card ──────────────────────────────────────
    MujoCard {
        title: "Motion Intensity Profile"
        iconName: "tune"

        SettingRow {
            path: "motion.enabled"
            def: true
            kind: "toggle"
            iconName: "power_settings_new"
            title: "Master Animation Engine"
            description: "Global master switch for desktop animations, page transitions, and UI interactions."
        }

        MujoSettingRow {
            iconName: "speed"
            title: "Intensity Profile"
            description: "Minimal: snappy with reduced travel. Balanced: standard smooth physics. Expressive: wider kinetic curves."

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

    // ── 3. Granular Motion Domains Card ───────────────────────────────────────
    MujoCard {
        title: "Granular Motion Domains"
        iconName: "layers"

        SettingRow {
            path: "motion.pageTransitions"
            def: true
            kind: "toggle"
            iconName: "view_carousel"
            title: "Page & Tab Transitions"
            description: "Smooth crossfade and vertical slide animations when switching panels."
        }

        SettingRow {
            path: "motion.microInteractions"
            def: true
            kind: "toggle"
            iconName: "touch_app"
            title: "Tactile Micro-interactions"
            description: "Fluid hover highlights, switch elasticity, and accordion drawer physics."
        }

        SettingRow {
            path: "motion.ambient"
            def: true
            kind: "toggle"
            iconName: "air"
            title: "Ambient Motion & Flow"
            description: "Subtle continuous background dynamics, breathing loops, and particle effects."
        }

        SettingRow {
            path: "motion.backgroundEffects"
            def: true
            kind: "toggle"
            iconName: "blur_on"
            title: "Background Glow & Lighting"
            description: "Backdrop radial lighting and interactive specular border highlights."
        }

        SettingRow {
            path: "motion.illustrations"
            def: true
            kind: "toggle"
            iconName: "animation"
            title: "Animated Illustrations"
            description: "Looping empty-state and hero artwork. Anim.illustrations gates every animated illustration on this."
        }
    }

    // ── 4. Accessibility & Performance Card ───────────────────────────────────
    MujoCard {
        title: "Accessibility & Performance"
        iconName: "accessibility_new"

        SettingRow {
            path: "motion.reduce"
            def: false
            kind: "toggle"
            iconName: "accessibility"
            title: "Reduced Motion Mode"
            description: "Eliminates spatial movement and transitions across all desktop surfaces."
        }

        SettingRow {
            path: "motion.performanceMode"
            def: false
            kind: "toggle"
            iconName: "bolt"
            title: "Low-Power Performance Mode"
            description: "Disables background particle effects and continuous loops to save GPU/battery."
        }
    }
}
