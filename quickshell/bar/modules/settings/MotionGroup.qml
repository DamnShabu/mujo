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

    // A place to feel the timings before committing to them. The controls are
    // live but write nothing — that is the point.
    MujoCard {
        title: "Interactive Motion Playground"
        badgeText: root.motionEnabled ? (Anim.reduceMotion ? "REDUCED MOTION" : "INTERACTIVE") : "DISABLED"
        badgeColor: root.motionEnabled ? Theme.accent : Theme.textDim

        actions: DialogButton {
            text: "Trigger pulse"
            iconName: "bolt"
            onClicked: root.triggerPulse()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            StatusTag {
                text: root.motionEnabled ? "ENGINE ACTIVE" : "ENGINE OFF"
                tone: root.motionEnabled ? "success" : "error"
            }

            StatusTag {
                text: "SPEED " + (Anim.durationScale * 100).toFixed(0) + "%"
                tone: "accent"
            }

            Item { Layout.fillWidth: true }
        }

        InsetPanel {
            Layout.fillWidth: true
            Layout.topMargin: 10
            implicitHeight: 92

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 20

                RowLayout {
                    spacing: 9

                    ToggleSwitch {
                        a11yName: "Demonstration toggle"
                        checked: root.demoToggle
                        onToggled: function (c) { root.demoToggle = c }
                    }

                    Text {
                        text: root.demoToggle ? "Active" : "Dormant"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.border }

                Slider {
                    Layout.fillWidth: true
                    a11yName: "Demonstration slider"
                    value: root.demoSlider
                    from: 0.0
                    to: 1.0
                    format: "%"
                    valueText: Math.round(root.demoSlider * 100) + "%"
                    onMoved: function (v) { root.demoSlider = v }
                }

                Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.border }

                MujoSegmented {
                    a11yName: "Demonstration choice"
                    current: root.demoSegmented
                    model: [
                        { id: "opt1", label: "Fast", icon: "speed" },
                        { id: "opt2", label: "Smooth", icon: "gesture" },
                        { id: "opt3", label: "Fluid", icon: "waves" }
                    ]
                    onSelected: function (id) { root.demoSegmented = id }
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
