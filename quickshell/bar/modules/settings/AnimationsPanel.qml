import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"
import "../../services"

// Animations & Motion Control Panel — Mujo (無常).
// Dedicated showcase and configuration center for the Mujo living motion system.
// Features a live interactive motion viewport, 3-tier intensity tuning,
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

    // Local state for interactive preview pulse
    property real previewPulse: 0.0
    function triggerPreviewPulse() {
        previewPulseAnim.restart()
    }

    NumberAnimation {
        id: previewPulseAnim
        target: root
        property: "previewPulse"
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

            // ── 1. Signature Hero Banner ──────────────────────────────────────
            MujoHero {
                brand: "animations"
                title: "Animations & Motion"
                subtitle: "Centralized motion architecture, living ambient dynamics, and accessibility."
                kanji: "動"
                badgeText: root.motionIntensity.toUpperCase()
                badgeColor: Brand.get("animations").color
            }

            // ── 2. Live Interactive Motion Showcase ───────────────────────────
            MujoCard {
                title: "Living Motion Showcase & Live Canvas"
                iconName: "motion_photos_on"
                badgeText: root.motionEnabled ? "LIVE PREVIEW" : "MOTION DISABLED"
                badgeColor: root.motionEnabled ? Theme.accent : Theme.textDim

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Live Interactive Viewport Frame
                    Rectangle {
                        id: previewBox
                        Layout.fillWidth: true
                        implicitHeight: 210
                        radius: Theme.radiusMd
                        color: Theme.withAlpha(Theme.bg, 0.85)
                        border.color: Theme.withAlpha(Theme.accent, 0.35)
                        border.width: 1
                        clip: true

                        // Ambient backdrop radial aura
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.9
                            height: parent.height * 0.9
                            radius: Math.min(width, height) / 2
                            color: Theme.withAlpha(Brand.get("animations").color, Anim.ambientAlpha(0.14))
                            Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }
                        }

                        // Generative procedural preview canvas
                        Canvas {
                            id: previewCanvas
                            anchors.fill: parent

                            property real phase: 0.0
                            NumberAnimation on phase {
                                running: root.motionEnabled && !Anim.reduceMotion && root.visible
                                from: 0.0
                                to: Math.PI * 2
                                duration: Math.max(1500, Anim.cycleDuration(10000))
                                loops: Animation.Infinite
                            }

                            onPhaseChanged: requestPaint()
                            Connections {
                                target: root
                                function onPreviewPulseChanged() { previewCanvas.requestPaint() }
                            }

                            // Qt's Canvas 2D context has no roundRect() (it is an HTML5-only addition):
                            // calling it threw on every paint, aborting the rest of the illustration.
                            // arcTo is supported, so build the path by hand.
                            function roundRectPath(ctx, x, y, w, h, r) {
                                var rr = Math.max(0, Math.min(r, Math.min(w, h) / 2))
                                ctx.moveTo(x + rr, y)
                                ctx.arcTo(x + w, y,     x + w, y + h, rr)
                                ctx.arcTo(x + w, y + h, x,     y + h, rr)
                                ctx.arcTo(x,     y + h, x,     y,     rr)
                                ctx.arcTo(x,     y,     x + w, y,     rr)
                                ctx.closePath()
                            }

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                var w = width
                                var h = height
                                if (w <= 0 || h <= 0) return

                                var p = Anim.reduceMotion ? 0.0 : phase
                                var pv = root.previewPulse
                                var intensity = root.motionIntensity
                                var intMult = Anim.intensityMultiplier
                                var acc = Theme.accent
                                var r = acc.r, g = acc.g, b = acc.b

                                ctx.save()

                                // 1. Multi-frequency fluid harmonics
                                if (root.motionEnabled && (root.backgroundEffects || root.ambientMotion)) {
                                    var waveCount = intensity === "minimal" ? 1 : (intensity === "expressive" ? 4 : 2)
                                    for (var wi = 0; wi < waveCount; wi++) {
                                        ctx.beginPath()
                                        var yBase = h * (0.50 + (wi - 1) * 0.15)
                                        var freq = 0.012 + wi * 0.006
                                        var amp = (12 + wi * 8 + pv * 22) * intMult
                                        var wPhase = p + wi * 1.5

                                        ctx.moveTo(0, yBase + Math.sin(wPhase) * amp)
                                        for (var x = 0; x <= w; x += 6) {
                                            var y = yBase + Math.sin(x * freq + wPhase) * amp
                                                          + Math.cos(x * freq * 0.5 - wPhase) * (amp * 0.35)
                                            ctx.lineTo(x, y)
                                        }

                                        var waveGrad = ctx.createLinearGradient(0, 0, w, 0)
                                        var wa = (0.45 - wi * 0.10 + pv * 0.3) * (intensity === "minimal" ? 0.4 : 0.9)
                                        waveGrad.addColorStop(0, Qt.rgba(r, g, b, 0.0))
                                        waveGrad.addColorStop(0.3, Qt.rgba(r, g, b, wa))
                                        waveGrad.addColorStop(0.7, Qt.rgba(0.8, 0.4, 0.95, wa * 0.85))
                                        waveGrad.addColorStop(1, Qt.rgba(r, g, b, 0.0))

                                        ctx.strokeStyle = waveGrad
                                        ctx.lineWidth = wi === 0 ? (2.2 * intMult) : 1.2
                                        ctx.stroke()
                                    }
                                }

                                // 2. Center Morphing Dynamic Shape
                                if (root.motionEnabled) {
                                    var cx = w * 0.50, cy = h * 0.50
                                    var baseS = (38 + pv * 14) * (intensity === "minimal" ? 0.85 : (intensity === "expressive" ? 1.2 : 1.0))
                                    var sw = baseS * (1.0 + Math.sin(p * 2) * (0.28 * intMult))
                                    var sh = baseS * (1.0 - Math.sin(p * 2) * (0.22 * intMult))
                                    var sRad = (sh / 2) * (0.35 + 0.65 * (0.5 + 0.5 * Math.cos(p)))

                                    ctx.save()
                                    ctx.translate(cx, cy)
                                    ctx.rotate(Math.sin(p) * (0.3 * intMult))

                                    // Outer kinetic ripple
                                    ctx.beginPath()
                                    roundRectPath(ctx, -sw * 0.72, -sh * 0.72, sw * 1.44, sh * 1.44, sRad * 1.3)
                                    ctx.strokeStyle = Qt.rgba(r, g, b, (0.32 + pv * 0.3) * intMult)
                                    ctx.lineWidth = 1.6
                                    ctx.stroke()

                                    // Core morphing body
                                    ctx.beginPath()
                                    roundRectPath(ctx, -sw / 2, -sh / 2, sw, sh, sRad)
                                    var bodyGrad = ctx.createLinearGradient(-sw / 2, -sh / 2, sw / 2, sh / 2)
                                    bodyGrad.addColorStop(0, Qt.rgba(r, g, b, 0.55 + pv * 0.35))
                                    bodyGrad.addColorStop(1, Qt.rgba(0.7, 0.3, 0.9, 0.25 + pv * 0.2))
                                    ctx.fillStyle = bodyGrad
                                    ctx.fill()
                                    ctx.strokeStyle = Qt.rgba(r, g, b, 0.9)
                                    ctx.lineWidth = 2.0
                                    ctx.stroke()

                                    ctx.restore()

                                    // 3. Orbital node cluster
                                    if (intensity !== "minimal" && root.ambientMotion) {
                                        var orbCount = intensity === "expressive" ? 5 : 3
                                        for (var oi = 0; oi < orbCount; oi++) {
                                            var oSpeed = (oi % 2 === 0 ? 1 : -1) * (1.0 + oi * 0.25)
                                            var oPhase = p * oSpeed + (oi * Math.PI * 2 / orbCount)
                                            var oRadX = (56 + oi * 10) * intMult
                                            var oRadY = (28 + oi * 6) * intMult
                                            var ox = cx + Math.cos(oPhase) * oRadX
                                            var oy = cy + Math.sin(oPhase) * oRadY

                                            // Orbit path trace
                                            ctx.beginPath()
                                            ctx.ellipse(cx, cy, oRadX, oRadY, 0, 0, Math.PI * 2)
                                            ctx.strokeStyle = Qt.rgba(r, g, b, 0.12 * intMult)
                                            ctx.lineWidth = 1.0
                                            ctx.stroke()

                                            // Node spark
                                            ctx.beginPath()
                                            ctx.arc(ox, oy, 2.6 + (oi === 0 ? pv * 2.0 : 0), 0, Math.PI * 2)
                                            ctx.fillStyle = Qt.rgba(r, g, b, 0.85 * intMult)
                                            ctx.fill()
                                        }
                                    }
                                }

                                // 4. Static / Reduced motion fallback indication
                                if (!root.motionEnabled || Anim.reduceMotion) {
                                    var scx = w * 0.50, scy = h * 0.50
                                    ctx.beginPath()
                                    ctx.arc(scx, scy, 22, 0, Math.PI * 2)
                                    ctx.strokeStyle = Qt.rgba(r, g, b, 0.4)
                                    ctx.lineWidth = 1.5
                                    ctx.stroke()
                                }

                                ctx.restore()
                            }
                        }

                        // Top Left Live HUD Pills
                        RowLayout {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8

                            Rectangle {
                                implicitWidth: hudTxt1.implicitWidth + 14
                                implicitHeight: 22
                                radius: Theme.radiusSm
                                color: Theme.withAlpha(Theme.surface, 0.85)
                                border.color: Theme.border

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        color: root.motionEnabled ? Theme.success : Theme.error
                                    }
                                    Text {
                                        id: hudTxt1
                                        text: root.motionEnabled ? "ENGINE ACTIVE" : "ENGINE PAUSED"
                                        color: Theme.text
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeLabel - 1
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: hudTxt2.implicitWidth + 14
                                implicitHeight: 22
                                radius: Theme.radiusSm
                                color: Theme.withAlpha(Theme.accent, 0.14)
                                border.color: Theme.withAlpha(Theme.accent, 0.4)

                                Text {
                                    id: hudTxt2
                                    anchors.centerIn: parent
                                    text: "INTENSITY: " + root.motionIntensity.toUpperCase()
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                visible: root.performanceMode
                                implicitWidth: hudTxt3.implicitWidth + 14
                                implicitHeight: 22
                                radius: Theme.radiusSm
                                color: Theme.withAlpha(Theme.warning, 0.14)
                                border.color: Theme.warning

                                Text {
                                    id: hudTxt3
                                    anchors.centerIn: parent
                                    text: "PERFORMANCE MODE"
                                    color: Theme.warning
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel - 1
                                    font.bold: true
                                }
                            }
                        }

                        // Bottom Action Controls Inside Preview
                        RowLayout {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 12
                            spacing: 8

                            Rectangle {
                                implicitWidth: pulseBtnTxt.implicitWidth + 24
                                implicitHeight: 30
                                radius: Theme.radiusSm
                                color: pulseBtnHh.hovered ? Theme.accent : Theme.accentDim
                                border.color: Theme.accent
                                Behavior on color { ColorAnimation { duration: Anim.d(Anim.fast) } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIcon {
                                        iconName: "bolt"
                                        pixelSize: 15
                                        color: pulseBtnHh.hovered ? Theme.accentText : Theme.accent
                                    }
                                    Text {
                                        id: pulseBtnTxt
                                        text: "Test Spring Pulse"
                                        color: pulseBtnHh.hovered ? Theme.accentText : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                    }
                                }

                                HoverHandler { id: pulseBtnHh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.triggerPreviewPulse() }
                            }
                        }
                    }
                }
            }

            // ── 3. Master Hierarchy & Intensity Tuning ────────────────────────
            MujoCard {
                title: "Motion Hierarchy & Intensity Scale"
                iconName: "tune"

                // Master Switch
                MujoSettingRow {
                    iconName: "power_settings_new"
                    title: "Master Animation Engine"
                    description: "Global master switch for desktop animation, page transitions, and living visuals."

                    ToggleSwitch {
                        checked: root.motionEnabled
                        onToggled: function(c) { root.bset("motion.enabled", c) }
                    }
                }

                // Intensity Segmented Selector
                MujoSettingRow {
                    iconName: "speed"
                    title: "Animation Intensity Profile"
                    description: "Minimal: subtle, fast, little ambient movement. Balanced: the signature Mujo flow and organic tactile response. Expressive: rich environmental motion, multi-layer hero art, vivid spring physics."

                    MujoSegmented {
                        current: root.motionIntensity
                        model: [
                            { id: "minimal",    label: "Minimal",    icon: "air" },
                            { id: "balanced",   label: "Balanced",   icon: "balance" },
                            { id: "expressive", label: "Expressive", icon: "auto_awesome" }
                        ]
                        onSelected: function(id) {
                            root.bset("motion.intensity", id)
                            root.triggerPreviewPulse()
                        }
                    }
                }

            }

            // ── 4. Granular Motion Domains ────────────────────────────────────
            MujoCard {
                title: "Motion Domains & Visual Layers"
                iconName: "layers"

                MujoSettingRow {
                    iconName: "air"
                    title: "Ambient Environmental Movement"
                    description: "Continuous subtle background flow, living Ensō breathing, and drifting particle constellations."
                    ToggleSwitch {
                        checked: root.ambientMotion
                        onToggled: function(c) { root.bset("motion.ambient", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "view_carousel"
                    title: "Page & Domain Transitions"
                    description: "Kinematic spatial transitions when switching between Zen domains, tabs, and settings panels."
                    ToggleSwitch {
                        checked: root.pageTransitions
                        onToggled: function(c) { root.bset("motion.pageTransitions", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "touch_app"
                    title: "Tactile Micro-interactions"
                    description: "Fluid hover highlights, switch elasticity, accordion drawer expansion, and button ripples."
                    ToggleSwitch {
                        checked: root.microInteractions
                        onToggled: function(c) { root.bset("motion.microInteractions", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "draw"
                    title: "Animated Page Hero Artwork"
                    description: "Domain-specific living vector illustrations embodying the character of each control surface."
                    ToggleSwitch {
                        checked: root.animatedIllustrations
                        onToggled: function(c) { root.bset("motion.illustrations", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "blur_on"
                    title: "Background Glow & Waveforms"
                    description: "Luminous radial gradient backdrops, living canvas wave dynamics, and chromatic lighting."
                    ToggleSwitch {
                        checked: root.backgroundEffects
                        onToggled: function(c) { root.bset("motion.backgroundEffects", c) }
                    }
                }
            }


            // ── 5. Accessibility & Hardware Optimization ──────────────────────
            MujoCard {
                title: "Accessibility & Hardware Optimization"
                iconName: "accessibility_new"

                MujoSettingRow {
                    iconName: "accessibility"
                    title: "Reduced Motion (Accessibility Override)"
                    description: "Honor system-wide accessibility preferences by eliminating continuous and spatial movement."
                    ToggleSwitch {
                        checked: root.reduceMotion
                        onToggled: function(c) { root.bset("motion.reduce", c) }
                    }
                }

                MujoSettingRow {
                    iconName: "bolt"
                    title: "Low-Power Performance Mode"
                    description: "Stop the continuous ambient loops and the per-frame canvas artwork — the two things that cost a weak GPU real work."
                    ToggleSwitch {
                        checked: root.performanceMode
                        onToggled: function(c) { root.bset("motion.performanceMode", c) }
                    }
                }
            }
        }
    }
}
